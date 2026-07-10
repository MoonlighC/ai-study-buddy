export const defaultImageOcrModel = "gpt-4.1-mini-2025-04-14";
export const imageOcrMaxOutputTokens = 6_000;
export const imageOcrTimeoutMs = 45_000;

export const allowedWarningCodes = new Set([
  "handwriting_low_confidence",
  "blur_detected",
  "low_contrast",
  "layout_uncertain",
  "formula_uncertain",
  "partial_text",
  "rotated_content",
]);

export type OcrResult = {
  text: string;
  detected_language: string | null;
  warning_codes: string[];
  handwriting_present: boolean;
  truncated: boolean;
};

export function buildOcrRequestBody(
  model: string,
  mime: string,
  base64: string,
) {
  return {
    model,
    store: false,
    instructions: ocrInstructions,
    input: [{
      role: "user",
      content: [{
        type: "input_image",
        image_url: `data:${mime};base64,${base64}`,
        detail: "high",
      }],
    }],
    text: {
      format: {
        type: "json_schema",
        name: "image_ocr_result",
        strict: true,
        schema: {
          type: "object",
          additionalProperties: false,
          properties: {
            text: { type: "string" },
            detected_language: { type: ["string", "null"] },
            warning_codes: { type: "array", items: { type: "string" } },
            handwriting_present: { type: "boolean" },
            truncated: { type: "boolean" },
          },
          required: [
            "text",
            "detected_language",
            "warning_codes",
            "handwriting_present",
            "truncated",
          ],
        },
      },
    },
    max_output_tokens: imageOcrMaxOutputTokens,
  };
}

export async function requestImageOcr(input: {
  apiKey: string;
  model: string;
  mime: string;
  bytes: Uint8Array;
  fetcher?: typeof fetch;
}): Promise<OcrResult> {
  const fetcher = input.fetcher ?? fetch;
  const controller = new AbortController();
  const timer = setTimeout(() => controller.abort(), imageOcrTimeoutMs);
  try {
    const response = await fetcher("https://api.openai.com/v1/responses", {
      method: "POST",
      headers: {
        Authorization: `Bearer ${input.apiKey}`,
        "Content-Type": "application/json",
      },
      body: JSON.stringify(buildOcrRequestBody(
        input.model,
        input.mime,
        bytesToBase64(input.bytes),
      )),
      signal: controller.signal,
    });
    if (!response.ok) throw new Error("provider_failed");
    const data: unknown = await response.json();
    const raw = responseOutputText(data);
    if (!raw) throw new Error("provider_response_invalid");
    return parseOcrResult(JSON.parse(raw));
  } catch (_) {
    throw new Error("provider_failed");
  } finally {
    clearTimeout(timer);
  }
}

export function parseOcrResult(value: unknown): OcrResult {
  if (!isRecord(value) || Object.keys(value).length !== 5 ||
    typeof value.text !== "string" ||
    !(typeof value.detected_language === "string" || value.detected_language === null) ||
    !Array.isArray(value.warning_codes) ||
    !value.warning_codes.every((item) => typeof item === "string") ||
    typeof value.handwriting_present !== "boolean" ||
    typeof value.truncated !== "boolean") {
    throw new Error("provider_response_invalid");
  }
  return {
    text: value.text,
    detected_language: value.detected_language,
    warning_codes: sanitizeWarningCodes(value.warning_codes),
    handwriting_present: value.handwriting_present,
    truncated: value.truncated,
  };
}

export function sanitizeWarningCodes(values: string[]) {
  return [...new Set(values.filter((value) => allowedWarningCodes.has(value)))].slice(0, 5);
}

function responseOutputText(value: unknown) {
  if (!isRecord(value)) return "";
  if (typeof value.output_text === "string") return value.output_text.trim();
  const parts: string[] = [];
  if (Array.isArray(value.output)) collectText(value.output, parts);
  return parts.join("").trim();
}

function collectText(value: unknown, parts: string[]) {
  if (Array.isArray(value)) {
    for (const item of value) collectText(item, parts);
  } else if (isRecord(value)) {
    if (typeof value.text === "string") parts.push(value.text);
    if ("content" in value) collectText(value.content, parts);
  }
}

function bytesToBase64(bytes: Uint8Array) {
  let result = "";
  const chunk = 0x8000;
  for (let index = 0; index < bytes.length; index += chunk) {
    result += String.fromCharCode(...bytes.subarray(index, index + chunk));
  }
  return btoa(result);
}

function isRecord(value: unknown): value is Record<string, unknown> {
  return typeof value === "object" && value !== null && !Array.isArray(value);
}

const ocrInstructions = `Faithfully transcribe visible study text from the image.
Preserve the source language, reliable headings, paragraph breaks, and reading order.
Do not summarize, explain, answer displayed questions, or use outside knowledge.
Do not guess missing words or fabricate formulas. Omit unreadable content rather than inventing it.
Attempt handwriting conservatively. Ignore clearly decorative chrome and background content.
Return only the requested structured result. Use warning codes only when applicable.`;
