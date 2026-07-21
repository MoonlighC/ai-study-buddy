import { PdfOcrResult, sanitizeWarnings } from "./pdf_ocr_adapter.ts";

export const maxPdfBytes = 40 * 1024 * 1024;
export const maxPdfPages = 10;
export const maxStoredCharacters = 100_000;
export const extractionVersion = "scanned-pdf-ocr-v1";
export const pageLimitMessage = "This version can scan PDFs up to 10 pages. Split the PDF and upload a smaller file.";

export type MaterialRow = Record<string, unknown> & { id: string; user_id: string; kind: string; source_kind: string; content_text: string | null; summary: string | null; storage_bucket: string | null; storage_path: string | null; mime_type: string | null; file_size_bytes: number | null; processing_status: string; metadata: Record<string, unknown> };
export type Dependencies = {
  verifyJwt(jwt: string): Promise<string | null>; loadOwnedMaterial(userId: string, materialId: string): Promise<MaterialRow | null>;
  claim(material: MaterialRow, token: string, claimedAt: string): Promise<MaterialRow | null>;
  download(material: MaterialRow): Promise<Uint8Array>; pageCount(bytes: Uint8Array): Promise<number>;
  ocr(bytes: Uint8Array, candidates: number[]): Promise<PdfOcrResult>;
  succeed(input: { material: MaterialRow; token: string; text: string; metadata: Record<string, unknown> }): Promise<MaterialRow | null>;
  fail(input: { material: MaterialRow; token: string; code: string; message: string }): Promise<MaterialRow | null>;
  token(): string; now(): string; provider: string; model: string;
};
const cors = { "Access-Control-Allow-Origin": "*", "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type", "Access-Control-Allow-Methods": "POST, OPTIONS" };

export function createHandler(deps: Dependencies) {
  return async (request: Request): Promise<Response> => {
    if (request.method === "OPTIONS") return new Response("ok", { headers: cors });
    if (request.method !== "POST") return json({ error: "Method not allowed." }, 405);
    const auth = request.headers.get("Authorization") ?? ""; const jwt = auth.startsWith("Bearer ") ? auth.slice(7).trim() : "";
    if (!jwt) return json({ error: "Authentication required." }, 401);
    const userId = await deps.verifyJwt(jwt); if (!userId) return json({ error: "Authentication required." }, 401);
    let materialId = "";
    try { const body: unknown = await request.json(); if (!isRecord(body) || Object.keys(body).length !== 1 || typeof body.material_id !== "string") throw 0; materialId = body.material_id.trim(); }
    catch (_) { return json({ error: "Invalid request." }, 400); }
    if (!uuid.test(materialId)) return json({ error: "Invalid request." }, 400);
    let material = await deps.loadOwnedMaterial(userId, materialId);
    if (!material) return json({ error: "Material unavailable." }, 404);
    if (material.processing_status === "ready" && useful(material.content_text ?? "")) return json({ ok: true, idempotent: true, material });
    if (material.processing_status === "processing") return json({ error: "Scanned PDF OCR is already processing." }, 409);
    const classification = readClassification(material);
    if (!eligible(material, userId, materialId) || !classification) return json({ error: "Material is not eligible for scanned PDF OCR." }, 422);
    if (classification.pageCount > maxPdfPages) return json({ error: { code: "page_limit_exceeded", message: pageLimitMessage }, material }, 422);
    const token = deps.token(); const claimed = await deps.claim(material, token, deps.now());
    if (!claimed) { material = await deps.loadOwnedMaterial(userId, materialId) ?? material; if (material.processing_status === "ready" && useful(material.content_text ?? "")) return json({ ok: true, idempotent: true, material }); return json({ error: "Scanned PDF OCR is already processing." }, 409); }
    material = claimed;
    let bytes: Uint8Array;
    try { bytes = await deps.download(material); }
    catch (_) { return knownFailure(deps, material, token, "download_failed", "Could not read the uploaded PDF."); }
    if (bytes.length < 1 || bytes.length > maxPdfBytes || bytes.length !== material.file_size_bytes || !pdfSignature(bytes)) return knownFailure(deps, material, token, "invalid_pdf", "The uploaded file is not a valid PDF.");
    try {
      const actualPages = await deps.pageCount(bytes);
      if (actualPages !== classification.pageCount) return knownFailure(deps, material, token, "pdf_changed", "The PDF no longer matches its extracted metadata.");
      if (actualPages < 1 || actualPages > maxPdfPages) return knownFailure(deps, material, token, "page_limit_exceeded", pageLimitMessage);
      const result = await deps.ocr(bytes, classification.candidates);
      const accepted = validateProviderPages(result.pages, classification.candidates);
      const ocrByPage = new Map<number, ReturnType<typeof normalizePage>>();
      for (const page of accepted) { const normalized = normalizePage(page); if (useful(normalized.text)) ocrByPage.set(page.page_number, normalized); }
      if (ocrByPage.size === 0) return knownFailure(deps, material, token, "no_readable_text", "No readable text was found in the scanned PDF.");
      const selectable = new Map(classification.selectable.map((page) => [page.page_number, page.text]));
      const sections: string[] = []; const processed: number[] = []; const failed: number[] = [];
      for (let page = 1; page <= actualPages; page++) { const text = selectable.get(page) ?? ocrByPage.get(page)?.text; if (text) { sections.push(`--- Page ${page} ---\n\n${text}`); processed.push(page); } else failed.push(page); }
      const capped = capUtf16(sections.join("\n\n"), maxStoredCharacters);
      if (capped.text.length < 200 || countLetters(capped.text) < 50) return knownFailure(deps, material, token, "no_readable_text", "No readable text was found in the scanned PDF.");
      const ocrPages = [...ocrByPage.values()]; const truncated = capped.truncated || ocrPages.some((page) => page.truncated);
      const metadata = { extracted_at: deps.now(), processed_pages: processed, total_pages: actualPages, failed_pages: failed,
        partial: failed.length > 0 || truncated, truncated, character_count: capped.text.length,
        detected_languages: [...new Set(ocrPages.map((p) => p.detected_language).filter((v): v is string => !!v))].slice(0, 10),
        handwriting_detected: ocrPages.some((page) => page.handwriting_present),
        warning_codes: sanitizeWarnings(ocrPages.flatMap((page) => page.warning_codes)), extraction_version: extractionVersion,
        provider: deps.provider, model: deps.model, model_calls: 1, input_tokens: result.usage.inputTokens, output_tokens: result.usage.outputTokens };
      const saved = await deps.succeed({ material, token, text: capped.text, metadata });
      return saved ? json({ ok: true, idempotent: false, material: saved }) : json({ error: "Could not save extracted text." }, 500);
    } catch (_) { return knownFailure(deps, material, token, "provider_failed", "Could not scan this PDF. Try again."); }
  };
}

function readClassification(material: MaterialRow) {
  const pdf = isRecord(material.metadata?.pdf_extraction) ? material.metadata.pdf_extraction : null;
  if (!pdf || !["ocr_available", "mixed_ocr_available"].includes(String(pdf.classification)) || !Number.isInteger(pdf.page_count)) return null;
  const pageCount = pdf.page_count as number; const candidates = integerList(pdf.ocr_candidate_pages);
  if (!candidates || candidates.length < 1 || candidates.some((p) => p < 1 || p > pageCount)) return null;
  const raw = Array.isArray(pdf.selectable_pages) ? pdf.selectable_pages : []; const selectable: { page_number: number; text: string }[] = [];
  for (const item of raw) if (isRecord(item) && Number.isInteger(item.page_number) && typeof item.text === "string" && item.text.trim()) selectable.push({ page_number: item.page_number as number, text: normalize(item.text) });
  if (selectable.some((p) => candidates.includes(p.page_number))) return null;
  return { pageCount, candidates, selectable };
}
function validateProviderPages(pages: PdfOcrResult["pages"], candidates: number[]) { const seen = new Set<number>(); for (const page of pages) { if (!candidates.includes(page.page_number) || seen.has(page.page_number)) throw new Error("provider_response_invalid"); seen.add(page.page_number); } return [...pages].sort((a, b) => a.page_number - b.page_number); }
function normalizePage(page: PdfOcrResult["pages"][number]) { return { ...page, text: capUtf16(normalize(page.text), 50_000).text, detected_language: page.detected_language?.trim().slice(0, 64) || null, warning_codes: sanitizeWarnings(page.warning_codes) }; }
function normalize(value: string) { return value.normalize("NFC").replace(/\r\n?/g, "\n").replace(/[\u0000-\u0008\u000B\u000C\u000E-\u001F\u007F]/g, "").replace(/[\t\p{Zs}]+/gu, " ").split("\n").map((line) => line.trimEnd()).join("\n").replace(/\n{3,}/g, "\n\n").trim(); }
function useful(value: string) { return normalize(value).length >= 80 && countLetters(value) >= 20; }
function countLetters(value: string) { return value.match(/[\p{L}\p{N}]/gu)?.length ?? 0; }
function capUtf16(value: string, limit: number) { if (value.length <= limit) return { text: value, truncated: false }; let end = limit; if (/^[\uD800-\uDBFF]$/.test(value[end - 1])) end--; return { text: value.slice(0, end), truncated: true }; }
function integerList(value: unknown) { if (!Array.isArray(value) || !value.every(Number.isInteger)) return null; const list = value as number[]; return new Set(list).size === list.length ? [...list].sort((a, b) => a - b) : null; }
function eligible(m: MaterialRow, userId: string, id: string) { const path = m.storage_path?.split("/") ?? []; return m.user_id === userId && m.id === id && m.kind === "pdf" && m.source_kind === "upload" && m.storage_bucket === "study-materials" && m.mime_type === "application/pdf" && Number.isInteger(m.file_size_bytes) && (m.file_size_bytes ?? 0) >= 1 && (m.file_size_bytes ?? 0) <= maxPdfBytes && m.processing_status === "failed" && !isRecord(m.metadata?.scanned_pdf_ocr) && !useful(m.content_text ?? "") && path.length === 3 && path[0] === userId && path[1] === id && path[2].trim().length > 0; }
async function knownFailure(deps: Dependencies, material: MaterialRow, token: string, code: string, message: string) { const failed = await deps.fail({ material, token, code, message }); return failed ? json({ ok: false, material: failed, error: { code, message } }) : json({ error: "Could not save OCR status." }, 500); }
function pdfSignature(b: Uint8Array) { return b.length >= 5 && String.fromCharCode(...b.subarray(0, 5)) === "%PDF-"; }
function isRecord(v: unknown): v is Record<string, unknown> { return typeof v === "object" && v !== null && !Array.isArray(v); }
const uuid = /^[0-9a-f]{8}-[0-9a-f]{4}-[1-5][0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$/i;
function json(body: Record<string, unknown>, status = 200) { return new Response(JSON.stringify(body), { status, headers: { ...cors, "Content-Type": "application/json" } }); }
