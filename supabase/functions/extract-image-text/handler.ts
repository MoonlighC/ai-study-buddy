import { OcrResult, sanitizeWarningCodes } from "./ocr_adapter.ts";

export const maxImageBytes = 8 * 1024 * 1024;
export const maxStoredCharacters = 50_000;
export const minimumOcrCharacters = 80;
export const minimumOcrLettersOrNumbers = 20;
export const extractionVersion = "image-ocr-v1";
export const noReadableTextMessage = "No readable text was found in this image.";

export type MaterialRow = Record<string, unknown> & {
  id: string; user_id: string; kind: string; source_kind: string;
  content_text: string | null; summary: string | null;
  storage_bucket: string | null; storage_path: string | null;
  mime_type: string | null; file_size_bytes: number | null;
  processing_status: string; metadata: Record<string, unknown>;
};

export type ExtractImageDependencies = {
  verifyJwt(jwt: string): Promise<string | null>;
  loadOwnedMaterial(userId: string, materialId: string): Promise<MaterialRow | null>;
  claim(material: MaterialRow, token: string): Promise<MaterialRow | null>;
  restoreReady(material: MaterialRow): Promise<MaterialRow | null>;
  download(material: MaterialRow): Promise<Uint8Array>;
  ocr(input: { bytes: Uint8Array; mime: string }): Promise<OcrResult>;
  succeed(input: { material: MaterialRow; token: string; text: string; metadata: Record<string, unknown> }): Promise<MaterialRow | null>;
  fail(input: { material: MaterialRow; token: string; code: string; message: string }): Promise<MaterialRow | null>;
  token(): string; now(): string; provider: string; model: string;
};

const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type",
  "Access-Control-Allow-Methods": "POST, OPTIONS",
};

export function createExtractImageTextHandler(deps: ExtractImageDependencies) {
  return async (request: Request): Promise<Response> => {
    if (request.method === "OPTIONS") return new Response("ok", { headers: corsHeaders });
    if (request.method !== "POST") return json({ error: "Method not allowed." }, 405);
    const authorization = request.headers.get("Authorization") ?? "";
    const jwt = authorization.startsWith("Bearer ") ? authorization.slice(7).trim() : "";
    if (!jwt) return json({ error: "Authentication required." }, 401);
    const userId = await deps.verifyJwt(jwt);
    if (!userId) return json({ error: "Authentication required." }, 401);

    let materialId = "";
    try {
      const body: unknown = await request.json();
      if (!isRecord(body) || Object.keys(body).length !== 1 || typeof body.material_id !== "string") {
        return json({ error: "Invalid request." }, 400);
      }
      materialId = body.material_id.trim();
    } catch (_) { return json({ error: "Invalid request." }, 400); }
    if (!uuidPattern.test(materialId)) return json({ error: "Invalid request." }, 400);

    let material = await deps.loadOwnedMaterial(userId, materialId);
    if (!material) return json({ error: "Material unavailable." }, 404);
    if (!isEligibleShape(material, userId, materialId)) {
      return json({ error: "Material is not eligible for image text extraction." }, 422);
    }
    const existing = normalizeText(material.content_text ?? "");
    if (material.processing_status === "ready" && isUseful(existing)) {
      return json({ ok: true, idempotent: true, material });
    }
    if (["pending", "failed"].includes(material.processing_status) && isUseful(existing)) {
      const restored = await deps.restoreReady(material);
      if (restored) return json({ ok: true, idempotent: true, material: restored });
    }
    if (material.processing_status === "processing") {
      return json({ error: "Image text extraction is already processing." }, 409);
    }
    if (!["pending", "failed"].includes(material.processing_status)) {
      return json({ error: "Material is not eligible for image text extraction." }, 422);
    }

    const token = deps.token();
    const claimed = await deps.claim(material, token);
    if (!claimed) {
      material = await deps.loadOwnedMaterial(userId, materialId);
      if (material?.processing_status === "ready" && isUseful(normalizeText(material.content_text ?? ""))) {
        return json({ ok: true, idempotent: true, material });
      }
      return json({ error: "Image text extraction is already processing." }, 409);
    }
    material = claimed;

    let bytes: Uint8Array;
    try { bytes = await deps.download(material); }
    catch (_) { return knownFailure(deps, material, token, "download_failed", "Could not read the uploaded image."); }
    const image = inspectImage(bytes);
    if (bytes.length < 1 || bytes.length > maxImageBytes || bytes.length !== material.file_size_bytes ||
      !image || image.mime !== material.mime_type || image.width > 12_000 || image.height > 12_000 ||
      image.width * image.height > 20_000_000) {
      return knownFailure(deps, material, token, "invalid_image", "The uploaded file is not a valid supported image.");
    }

    try {
      // TODO: Enforce daily_usage_limits and write usage_logs before this paid request.
      const result = await deps.ocr({ bytes, mime: image.mime });
      const normalized = normalizeText(result.text);
      if (!isUseful(normalized)) return knownFailure(deps, material, token, "no_readable_text", noReadableTextMessage);
      const capped = capUtf16(normalized, maxStoredCharacters);
      const metadata = {
        extracted_at: deps.now(), character_count: capped.text.length,
        detected_language: cleanLanguage(result.detected_language),
        handwriting_detected: result.handwriting_present,
        warning_codes: sanitizeWarningCodes(result.warning_codes),
        truncated: result.truncated || capped.truncated,
        extraction_version: extractionVersion, provider: deps.provider, model: deps.model,
      };
      const saved = await deps.succeed({ material, token, text: capped.text, metadata });
      if (!saved) return json({ error: "Could not save extracted text." }, 500);
      return json({ ok: true, idempotent: false, material: saved });
    } catch (_) {
      return knownFailure(deps, material, token, "provider_failed", "Could not extract image text. Try again.");
    }
  };
}

async function knownFailure(deps: ExtractImageDependencies, material: MaterialRow, token: string, code: string, message: string) {
  const failed = await deps.fail({ material, token, code, message });
  return failed ? json({ ok: false, material: failed, error: { code, message } }) : json({ error: "Could not save extraction status." }, 500);
}

export function normalizeText(value: string) {
  return value.normalize("NFC").replace(/\r\n?/g, "\n")
    .replace(/[\u0000-\u0008\u000B\u000C\u000E-\u001F\u007F]/g, "")
    .replace(/[\t\p{Zs}]+/gu, " ").split("\n").map((line) => line.trimEnd())
    .join("\n").replace(/\n{3,}/g, "\n\n").trim();
}
export function isUseful(text: string) {
  return text.length >= minimumOcrCharacters && (text.match(/[\p{L}\p{N}]/gu)?.length ?? 0) >= minimumOcrLettersOrNumbers;
}
export function capUtf16(value: string, limit: number) {
  if (value.length <= limit) return { text: value, truncated: false };
  let end = limit; const last = value.charCodeAt(end - 1);
  if (last >= 0xD800 && last <= 0xDBFF) end--;
  return { text: value.slice(0, end), truncated: true };
}

export function inspectImage(bytes: Uint8Array): { mime: string; width: number; height: number } | null {
  if (match(bytes, [0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A]) && bytes.length >= 24 &&
    be32(bytes, 8) === 13 && String.fromCharCode(...bytes.subarray(12, 16)) === "IHDR") {
    const width = be32(bytes, 16), height = be32(bytes, 20);
    return validDimensions(width, height) ? { mime: "image/png", width, height } : null;
  }
  if (match(bytes, [0xFF, 0xD8, 0xFF])) return inspectJpeg(bytes);
  if (bytes.length >= 30 && match(bytes, [0x52, 0x49, 0x46, 0x46]) &&
    String.fromCharCode(...bytes.subarray(8, 12)) === "WEBP") return inspectWebp(bytes);
  return null;
}
function inspectJpeg(bytes: Uint8Array) {
  let offset = 2;
  while (offset + 4 <= bytes.length) {
    if (bytes[offset] !== 0xFF) return null;
    while (bytes[offset] === 0xFF) offset++;
    const marker = bytes[offset++];
    if (marker === 0xD9 || marker === 0xDA) return null;
    if (offset + 2 > bytes.length) return null;
    const length = (bytes[offset] << 8) | bytes[offset + 1];
    if (length < 2 || offset + length > bytes.length) return null;
    if ([0xC0,0xC1,0xC2,0xC3,0xC5,0xC6,0xC7,0xC9,0xCA,0xCB,0xCD,0xCE,0xCF].includes(marker) && length >= 7) {
      const height = (bytes[offset + 3] << 8) | bytes[offset + 4];
      const width = (bytes[offset + 5] << 8) | bytes[offset + 6];
      return validDimensions(width, height) ? { mime: "image/jpeg", width, height } : null;
    }
    offset += length;
  }
  return null;
}
function inspectWebp(bytes: Uint8Array) {
  const kind = String.fromCharCode(...bytes.subarray(12, 16));
  let width = 0, height = 0;
  if (kind === "VP8X" && bytes.length >= 30) {
    width = le24(bytes, 24) + 1; height = le24(bytes, 27) + 1;
  } else if (kind === "VP8 " && bytes.length >= 30 && bytes[23] === 0x9D && bytes[24] === 0x01 && bytes[25] === 0x2A) {
    width = ((bytes[27] << 8) | bytes[26]) & 0x3FFF; height = ((bytes[29] << 8) | bytes[28]) & 0x3FFF;
  } else if (kind === "VP8L" && bytes.length >= 25 && bytes[20] === 0x2F) {
    const bits = bytes[21] | (bytes[22] << 8) | (bytes[23] << 16) | (bytes[24] << 24);
    width = (bits & 0x3FFF) + 1; height = ((bits >>> 14) & 0x3FFF) + 1;
  }
  return validDimensions(width, height) ? { mime: "image/webp", width, height } : null;
}
function isEligibleShape(m: MaterialRow, userId: string, materialId: string) {
  const path = m.storage_path?.split("/") ?? [];
  return m.user_id === userId && m.id === materialId && m.kind === "image" && m.source_kind === "upload" &&
    m.storage_bucket === "study-images" && ["image/png","image/jpeg","image/webp"].includes(m.mime_type ?? "") &&
    Number.isInteger(m.file_size_bytes) && (m.file_size_bytes ?? 0) >= 1 && (m.file_size_bytes ?? 0) <= maxImageBytes &&
    path.length === 3 && path[0] === userId && path[1] === materialId && path[2].trim().length > 0;
}
function cleanLanguage(value: string | null) { const clean = value?.trim().slice(0, 64); return clean || null; }
function match(bytes: Uint8Array, sig: number[]) { return bytes.length >= sig.length && sig.every((v, i) => bytes[i] === v); }
function be32(b: Uint8Array, i: number) { return ((b[i] * 0x1000000) + (b[i+1] << 16) + (b[i+2] << 8) + b[i+3]) >>> 0; }
function le24(b: Uint8Array, i: number) { return b[i] | (b[i+1] << 8) | (b[i+2] << 16); }
function validDimensions(w: number, h: number) { return Number.isInteger(w) && Number.isInteger(h) && w > 0 && h > 0; }
function isRecord(v: unknown): v is Record<string, unknown> { return typeof v === "object" && v !== null && !Array.isArray(v); }
const uuidPattern = /^[0-9a-f]{8}-[0-9a-f]{4}-[1-5][0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$/i;
function json(body: Record<string, unknown>, status = 200) { return new Response(JSON.stringify(body), { status, headers: { ...corsHeaders, "Content-Type": "application/json" } }); }
