export const defaultScannedPdfOcrModel = "gpt-4.1-2025-04-14";
export const scannedPdfOcrTimeoutMs = 90_000;
export const scannedPdfMaxOutputTokens = 20_000;

export const allowedWarningCodes = new Set([
  "handwriting_low_confidence", "blur_detected", "low_contrast",
  "layout_uncertain", "formula_uncertain", "partial_text",
  "rotated_content", "page_unreadable",
]);

export type PdfOcrPage = {
  page_number: number; text: string; detected_language: string | null;
  handwriting_present: boolean; warning_codes: string[]; truncated: boolean;
};
export type PdfOcrResult = {
  pages: PdfOcrPage[];
  usage: { inputTokens: number | null; outputTokens: number | null };
};

export function buildPdfOcrRequestBody(model: string, bytes: Uint8Array, candidates: number[]) {
  return {
    model,
    store: false,
    instructions: `Faithfully transcribe visible study text only from PDF pages ${candidates.join(", ")}.
Transcribe only those pages and do not return pages that are not listed. Page numbering is one-based.
Preserve the source language, reliable headings, paragraphs, and reading order.
Do not summarize, answer questions, use outside knowledge, guess unreadable words, invent formulas,
or interpret diagrams beyond their visible labels and text. Omit unreadable content rather than fabricate it.
Return only the requested structured result and use warning codes only when applicable.`,
    input: [{ role: "user", content: [{
      type: "input_file", filename: "material.pdf",
      file_data: `data:application/pdf;base64,${bytesToBase64(bytes)}`, detail: "high",
    }] }],
    text: { format: { type: "json_schema", name: "scanned_pdf_ocr_result", strict: true,
      schema: { type: "object", additionalProperties: false, properties: {
        pages: { type: "array", maxItems: 10, items: { type: "object", additionalProperties: false,
          properties: {
            page_number: { type: "integer" }, text: { type: "string" },
            detected_language: { type: ["string", "null"] },
            handwriting_present: { type: "boolean" },
            warning_codes: { type: "array", items: { type: "string" }, maxItems: 8 },
            truncated: { type: "boolean" },
          }, required: ["page_number", "text", "detected_language", "handwriting_present", "warning_codes", "truncated"] } },
      }, required: ["pages"] },
    } },
    max_output_tokens: scannedPdfMaxOutputTokens,
  };
}

export async function requestPdfOcr(input: { apiKey: string; model: string; bytes: Uint8Array; candidates: number[]; fetcher?: typeof fetch }): Promise<PdfOcrResult> {
  const controller = new AbortController();
  const timer = setTimeout(() => controller.abort(), scannedPdfOcrTimeoutMs);
  try {
    const response = await (input.fetcher ?? fetch)("https://api.openai.com/v1/responses", {
      method: "POST", headers: { Authorization: `Bearer ${input.apiKey}`, "Content-Type": "application/json" },
      body: JSON.stringify(buildPdfOcrRequestBody(input.model, input.bytes, input.candidates)), signal: controller.signal,
    });
    if (!response.ok) throw new Error("provider_failed");
    const data: unknown = await response.json();
    if (!isRecord(data)) throw new Error("provider_response_invalid");
    const raw = responseOutputText(data);
    if (!raw) throw new Error("provider_response_invalid");
    const parsed = parsePdfOcrResult(JSON.parse(raw));
    const usage = isRecord(data.usage) ? data.usage : {};
    return { pages: parsed, usage: {
      inputTokens: integerOrNull(usage.input_tokens), outputTokens: integerOrNull(usage.output_tokens),
    } };
  } catch (_) { throw new Error("provider_failed"); }
  finally { clearTimeout(timer); }
}

export function parsePdfOcrResult(value: unknown): PdfOcrPage[] {
  if (!isRecord(value) || Object.keys(value).length !== 1 || !Array.isArray(value.pages)) throw new Error("provider_response_invalid");
  return value.pages.map((item) => {
    if (!isRecord(item) || !Number.isInteger(item.page_number) || typeof item.text !== "string" ||
      !(typeof item.detected_language === "string" || item.detected_language === null) ||
      typeof item.handwriting_present !== "boolean" || !Array.isArray(item.warning_codes) ||
      !item.warning_codes.every((code) => typeof code === "string") || typeof item.truncated !== "boolean") {
      throw new Error("provider_response_invalid");
    }
    return { page_number: item.page_number as number, text: item.text,
      detected_language: item.detected_language as string | null,
      handwriting_present: item.handwriting_present, warning_codes: sanitizeWarnings(item.warning_codes as string[]),
      truncated: item.truncated };
  });
}

export function sanitizeWarnings(values: string[]) {
  return [...new Set(values.filter((value) => allowedWarningCodes.has(value)))].slice(0, 8);
}
function responseOutputText(value: Record<string, unknown>) {
  if (typeof value.output_text === "string") return value.output_text.trim();
  const parts: string[] = []; collect(value.output, parts); return parts.join("").trim();
}
function collect(value: unknown, parts: string[]) {
  if (Array.isArray(value)) for (const item of value) collect(item, parts);
  else if (isRecord(value)) { if (typeof value.text === "string") parts.push(value.text); if ("content" in value) collect(value.content, parts); }
}
function bytesToBase64(bytes: Uint8Array) { let result = ""; for (let i = 0; i < bytes.length; i += 0x8000) result += String.fromCharCode(...bytes.subarray(i, i + 0x8000)); return btoa(result); }
function integerOrNull(value: unknown) { return Number.isInteger(value) && (value as number) >= 0 ? value as number : null; }
function isRecord(value: unknown): value is Record<string, unknown> { return typeof value === "object" && value !== null && !Array.isArray(value); }
