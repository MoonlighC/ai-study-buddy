export const maxPdfBytes = 40 * 1024 * 1024;
export const maxStoredCharacters = 100_000;
export const extractionVersion = "pdf-text-v2";
export const noSelectableTextMessage =
  "No usable selectable text was found. Scan this PDF with OCR.";
export const minimumPageCharacters = 80;
export const minimumPageLettersOrNumbers = 20;

export type MaterialRow = Record<string, unknown> & {
  id: string;
  user_id: string;
  kind: string;
  source_kind: string;
  content_text: string | null;
  summary: string | null;
  storage_bucket: string | null;
  storage_path: string | null;
  mime_type: string | null;
  file_size_bytes: number | null;
  processing_status: string;
  metadata: Record<string, unknown>;
};

export type ExtractPdfDependencies = {
  verifyJwt(jwt: string): Promise<string | null>;
  loadOwnedMaterial(userId: string, materialId: string): Promise<MaterialRow | null>;
  claim(material: MaterialRow, token: string): Promise<MaterialRow | null>;
  restoreReady(material: MaterialRow): Promise<MaterialRow | null>;
  download(material: MaterialRow): Promise<Uint8Array>;
  parse(bytes: Uint8Array): Promise<{ pages: string[]; pageCount: number }>;
  succeed(input: {
    material: MaterialRow;
    token: string;
    text: string;
    metadata: Record<string, unknown>;
  }): Promise<MaterialRow | null>;
  fail(input: {
    material: MaterialRow;
    token: string;
    code: string;
    message: string;
    metadata?: Record<string, unknown>;
  }): Promise<MaterialRow | null>;
  token(): string;
  now(): string;
};

const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type",
  "Access-Control-Allow-Methods": "POST, OPTIONS",
};

export function createExtractPdfTextHandler(deps: ExtractPdfDependencies) {
  return async (request: Request): Promise<Response> => {
    if (request.method === "OPTIONS") return new Response("ok", { headers: corsHeaders });
    if (request.method !== "POST") return json({ error: "Method not allowed." }, 405);

    const authorization = request.headers.get("Authorization") ?? "";
    const jwt = authorization.startsWith("Bearer ")
      ? authorization.slice("Bearer ".length).trim()
      : "";
    if (!jwt) return json({ error: "Authentication required." }, 401);
    const userId = await deps.verifyJwt(jwt);
    if (!userId) return json({ error: "Authentication required." }, 401);

    let materialId = "";
    try {
      const body: unknown = await request.json();
      if (!isRecord(body) || Object.keys(body).length !== 1 ||
        typeof body.material_id !== "string") {
        return json({ error: "Invalid request." }, 400);
      }
      materialId = body.material_id.trim();
    } catch (_) {
      return json({ error: "Invalid request." }, 400);
    }
    if (!uuidPattern.test(materialId)) return json({ error: "Invalid request." }, 400);

    let material = await deps.loadOwnedMaterial(userId, materialId);
    if (!material) return json({ error: "Material unavailable." }, 404);
    if (!isEligibleShape(material, userId, materialId)) {
      return json({ error: "Material is not eligible for PDF extraction." }, 422);
    }
    const existingText = cleanText(material.content_text);
    if (material.processing_status === "ready" && existingText) {
      return json({ ok: true, idempotent: true, material });
    }
    if ((material.processing_status === "pending" || material.processing_status === "failed") &&
      existingText) {
      const restored = await deps.restoreReady(material);
      if (restored) return json({ ok: true, idempotent: true, material: restored });
    }
    if (material.processing_status === "processing") {
      return json({ error: "PDF text extraction is already processing." }, 409);
    }
    if (material.processing_status !== "pending" && material.processing_status !== "failed") {
      return json({ error: "Material is not eligible for PDF extraction." }, 422);
    }

    const token = deps.token();
    const claimed = await deps.claim(material, token);
    if (!claimed) {
      material = await deps.loadOwnedMaterial(userId, materialId);
      if (material?.processing_status === "ready" && cleanText(material.content_text)) {
        return json({ ok: true, idempotent: true, material });
      }
      return json({ error: "PDF text extraction is already processing." }, 409);
    }
    material = claimed;

    let bytes: Uint8Array;
    try {
      bytes = await deps.download(material);
    } catch (_) {
      return knownFailure(deps, material, token, "download_failed", "Could not read the uploaded PDF.");
    }
    if (bytes.length === 0 || bytes.length > maxPdfBytes ||
      bytes.length !== material.file_size_bytes || !hasPdfSignature(bytes)) {
      return knownFailure(deps, material, token, "invalid_pdf", "The uploaded file is not a valid PDF.");
    }

    try {
      const parsed = await deps.parse(bytes);
      const classified = classifyPdfPages(parsed.pages, parsed.pageCount);
      let selectableBudget = maxStoredCharacters;
      const pageMetadata = classified.pages.map((page) => {
        const text = page.useful && selectableBudget > 0
          ? capUtf16(page.text, selectableBudget).text
          : "";
        selectableBudget -= text.length;
        return { page_number: page.pageNumber, text };
      });
      const boundedCombined = capUtf16(classified.combined, maxStoredCharacters);
      const metadata = {
        extracted_at: deps.now(),
        character_count: boundedCombined.text.length,
        page_count: parsed.pageCount,
        classification: classified.classification,
        useful_pages: classified.usefulPages,
        ocr_candidate_pages: classified.candidatePages,
        selectable_pages: pageMetadata,
        truncated: boundedCombined.truncated,
        extraction_version: extractionVersion,
      };
      if (classified.classification !== "selectable") {
        const failed = await deps.fail({
          material,
          token,
          code: classified.classification,
          message: classified.classification === "mixed_ocr_available"
            ? "Some pages need OCR before this PDF is ready."
            : noSelectableTextMessage,
          metadata,
        });
        if (!failed) return json({ error: "Could not save extraction status." }, 500);
        return json({ ok: false, material: failed, error: {
          code: classified.classification,
          message: classified.classification === "mixed_ocr_available"
            ? "Some pages need OCR before this PDF is ready."
            : noSelectableTextMessage,
        } });
      }
      const capped = capUtf16(classified.combined, maxStoredCharacters);
      metadata.character_count = capped.text.length;
      metadata.truncated = capped.truncated;
      const saved = await deps.succeed({ material, token, text: capped.text, metadata });
      if (!saved) return json({ error: "Could not save extracted text." }, 500);
      return json({ ok: true, idempotent: false, material: saved });
    } catch (_) {
      return knownFailure(deps, material, token, "parser_failed", "Could not extract text from this PDF.");
    }
  };
}

async function knownFailure(
  deps: ExtractPdfDependencies,
  material: MaterialRow,
  token: string,
  code: string,
  message: string,
) {
  const failed = await deps.fail({ material, token, code, message });
  if (!failed) return json({ error: "Could not save extraction status." }, 500);
  return json({ ok: false, material: failed, error: { code, message } });
}

export function normalizePdfPages(pages: string[]): string {
  return normalizePdfPageList(pages).filter(Boolean).join("\n\n");
}

export function classifyPdfPages(pages: string[], pageCount: number) {
  const normalized = normalizePdfPageList(pages);
  while (normalized.length < pageCount) normalized.push("");
  const result = normalized.slice(0, pageCount).map((text, index) => ({
    pageNumber: index + 1,
    text,
    useful: isUsefulPageText(text),
  }));
  const usefulPages = result.filter((page) => page.useful).map((page) => page.pageNumber);
  const candidatePages = result.filter((page) => !page.useful).map((page) => page.pageNumber);
  return {
    pages: result,
    usefulPages,
    candidatePages,
    classification: usefulPages.length === pageCount
      ? "selectable"
      : usefulPages.length === 0 ? "ocr_available" : "mixed_ocr_available",
    combined: result.filter((page) => page.useful).map((page) => page.text).join("\n\n"),
  };
}

export function isUsefulPageText(text: string) {
  return text.length >= minimumPageCharacters &&
    (text.match(/[\p{L}\p{N}]/gu)?.length ?? 0) >= minimumPageLettersOrNumbers;
}

function normalizePdfPageList(pages: string[]): string[] {
  const normalizedPages = pages.map((page, index) => {
    const lines = page
      .normalize("NFC")
      .replace(/\r\n?/g, "\n")
      .replace(/[\u0000-\u0008\u000B\u000C\u000E-\u001F\u007F]/g, "")
      .replace(/[\t\p{Zs}]+/gu, " ")
      .split("\n")
      .map((line) => line.trim());
    return removeIsolatedPageNumber(lines, index + 1, pages.length);
  });

  removeRepeatedEdgeLine(normalizedPages, "first");
  removeRepeatedEdgeLine(normalizedPages, "last");

  return normalizedPages.map((lines) =>
    lines.join("\n").replace(/\n{3,}/g, "\n\n").trim()
  );
}

function removeIsolatedPageNumber(
  lines: string[],
  pageNumber: number,
  pageCount: number,
): string[] {
  const result = [...lines];
  const nonEmptyIndexes = result
    .map((line, index) => line ? index : -1)
    .filter((index) => index >= 0);
  if (nonEmptyIndexes.length <= 1) return result;

  for (const edgeIndex of [nonEmptyIndexes[0], nonEmptyIndexes.at(-1)!]) {
    if (isPageNumberLine(result[edgeIndex], pageNumber, pageCount)) {
      result[edgeIndex] = "";
    }
  }
  return result;
}

function isPageNumberLine(line: string, pageNumber: number, pageCount: number) {
  const escapedPage = String(pageNumber);
  const escapedCount = String(pageCount);
  return new RegExp(
    `^(?:page\\s+)?${escapedPage}(?:\\s*(?:/|of)\\s*${escapedCount})?$`,
    "i",
  ).test(line);
}

function removeRepeatedEdgeLine(
  pages: string[][],
  edge: "first" | "last",
) {
  const eligible = pages
    .map((lines) => {
      const nonEmpty = lines.filter(Boolean);
      if (nonEmpty.length <= 1) return null;
      return edge === "first" ? nonEmpty[0] : nonEmpty.at(-1)!;
    })
    .filter((line): line is string => line !== null);
  if (eligible.length < 4) return;

  const counts = new Map<string, number>();
  for (const line of eligible) counts.set(line, (counts.get(line) ?? 0) + 1);
  const repeated = [...counts.entries()]
    .filter(([line, count]) => line.length <= 160 && count >= 3 &&
      count / eligible.length >= 0.75)
    .map(([line]) => line);
  if (repeated.length !== 1) return;

  const target = repeated[0];
  for (const lines of pages) {
    const indexes = lines
      .map((line, index) => line ? index : -1)
      .filter((index) => index >= 0);
    if (indexes.length <= 1) continue;
    const targetIndex = edge === "first" ? indexes[0] : indexes.at(-1)!;
    if (lines[targetIndex] === target) lines[targetIndex] = "";
  }
}

export function capUtf16(value: string, limit: number) {
  if (value.length <= limit) return { text: value, truncated: false };
  let end = limit;
  const last = value.charCodeAt(end - 1);
  if (last >= 0xD800 && last <= 0xDBFF) end -= 1;
  return { text: value.slice(0, end), truncated: true };
}

function isEligibleShape(material: MaterialRow, userId: string, materialId: string) {
  const path = material.storage_path?.split("/") ?? [];
  return material.user_id === userId && material.id === materialId &&
    material.kind === "pdf" && material.source_kind === "upload" &&
    material.storage_bucket === "study-materials" &&
    material.mime_type === "application/pdf" &&
    Number.isInteger(material.file_size_bytes) &&
    (material.file_size_bytes ?? 0) >= 1 && (material.file_size_bytes ?? 0) <= maxPdfBytes &&
    path.length === 3 && path[0] === userId && path[1] === materialId && path[2].trim().length > 0;
}

function hasPdfSignature(bytes: Uint8Array) {
  return bytes.length >= 5 && bytes[0] === 0x25 && bytes[1] === 0x50 &&
    bytes[2] === 0x44 && bytes[3] === 0x46 && bytes[4] === 0x2D;
}

function cleanText(value: unknown) {
  return typeof value === "string" ? value.trim() : "";
}

function isRecord(value: unknown): value is Record<string, unknown> {
  return typeof value === "object" && value !== null && !Array.isArray(value);
}

const uuidPattern = /^[0-9a-f]{8}-[0-9a-f]{4}-[1-5][0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$/i;

function json(body: Record<string, unknown>, status = 200) {
  return new Response(JSON.stringify(body), {
    status,
    headers: { ...corsHeaders, "Content-Type": "application/json" },
  });
}
