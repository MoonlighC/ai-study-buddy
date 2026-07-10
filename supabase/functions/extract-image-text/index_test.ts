import { capUtf16, createExtractImageTextHandler, inspectImage, isUseful, MaterialRow, normalizeText } from "./handler.ts";
import { buildOcrRequestBody, imageOcrMaxOutputTokens, parseOcrResult, sanitizeWarningCodes } from "./ocr_adapter.ts";

Deno.test("OCR request uses high detail, no storage and bounded output", () => {
  const body = buildOcrRequestBody("model", "image/png", "AAAA");
  assertEquals(body.store, false);
  assertEquals(body.max_output_tokens, 6_000);
  assertEquals(imageOcrMaxOutputTokens, 6_000);
  assertEquals(body.input[0].content[0].detail, "high");
  assert(String(body.input[0].content[0].image_url).startsWith("data:image/png;base64,"));
});

Deno.test("strict result discards unknown warnings, deduplicates and caps", () => {
  const value = parseOcrResult({
    text: "Useful text", detected_language: "en",
    warning_codes: ["blur_detected", "provider prose", "blur_detected", "low_contrast", "layout_uncertain", "formula_uncertain", "partial_text", "rotated_content"],
    handwriting_present: false, truncated: false,
  });
  assertEquals(value.warning_codes.length, 5);
  assertEquals(value.warning_codes.filter((v) => v === "blur_detected").length, 1);
  assert(!value.warning_codes.includes("provider prose"));
  assertEquals(sanitizeWarningCodes(["unknown"]).length, 0);
});

Deno.test("strict result rejects extra or malformed fields", () => {
  assertThrows(() => parseOcrResult({ text: "x", detected_language: null, warning_codes: [], handwriting_present: false, truncated: false, prose: "no" }));
  assertThrows(() => parseOcrResult({ text: "x", detected_language: null, warning_codes: "bad", handwriting_present: false, truncated: false }));
});

Deno.test("normalization, quality guard and surrogate-safe cap", () => {
  const useful = normalizeText("  " + "Readable study content ".repeat(6) + "\u0000");
  assert(isUseful(useful));
  assert(!isUseful("Only a few labels"));
  assertEquals(capUtf16("abc😀", 4).text, "abc");
});

Deno.test("PNG dimensions parse and malformed header fails", () => {
  const bytes = new Uint8Array(24);
  bytes.set([0x89,0x50,0x4E,0x47,0x0D,0x0A,0x1A,0x0A]);
  bytes.set([0,0,0,13], 8); bytes.set([0x49,0x48,0x44,0x52], 12);
  bytes.set([0,0,0,100], 16); bytes.set([0,0,0,50], 20);
  const image = inspectImage(bytes);
  assertEquals(image?.mime, "image/png"); assertEquals(image?.width, 100); assertEquals(image?.height, 50);
  assertEquals(inspectImage(bytes.subarray(0, 12)), null);
});

Deno.test("a claimed request invokes OCR exactly once", async () => {
  const userId = "11111111-1111-4111-8111-111111111111";
  const materialId = "22222222-2222-4222-8222-222222222222";
  const bytes = new Uint8Array(100);
  bytes.set([0x89,0x50,0x4E,0x47,0x0D,0x0A,0x1A,0x0A]);
  bytes.set([0,0,0,13], 8); bytes.set([0x49,0x48,0x44,0x52], 12);
  bytes.set([0,0,0,100], 16); bytes.set([0,0,0,100], 20);
  let calls = 0;
  let row: MaterialRow = {
    id: materialId, user_id: userId, kind: "image", source_kind: "upload",
    content_text: null, summary: "preserved", storage_bucket: "study-images",
    storage_path: `${userId}/${materialId}/note.png`, mime_type: "image/png",
    file_size_bytes: bytes.length, processing_status: "pending", metadata: {},
  };
  const handler = createExtractImageTextHandler({
    verifyJwt: async () => userId, loadOwnedMaterial: async () => row,
    claim: async (_, token) => row = { ...row, processing_status: "processing", metadata: { image_ocr_claim: token } },
    restoreReady: async () => null, download: async () => bytes,
    ocr: async () => { calls++; return { text: "Reliable study text ".repeat(8), detected_language: "en", warning_codes: [], handwriting_present: false, truncated: false }; },
    succeed: async ({ text, metadata }) => row = { ...row, content_text: text, processing_status: "ready", metadata: { image_ocr: metadata } },
    fail: async () => null, token: () => "claim", now: () => "2026-01-01T00:00:00Z", provider: "openai", model: "model",
  });
  const response = await handler(new Request("http://local", {
    method: "POST", headers: { Authorization: "Bearer jwt", "Content-Type": "application/json" },
    body: JSON.stringify({ material_id: materialId }),
  }));
  assertEquals(response.status, 200); assertEquals(calls, 1); assertEquals(row.summary, "preserved");
});

function assert(value: boolean, message = "Assertion failed") { if (!value) throw new Error(message); }
function assertEquals(actual: unknown, expected: unknown) { if (actual !== expected) throw new Error(`Expected ${expected}, got ${actual}`); }
function assertThrows(callback: () => unknown) { try { callback(); } catch (_) { return; } throw new Error("Expected throw"); }
