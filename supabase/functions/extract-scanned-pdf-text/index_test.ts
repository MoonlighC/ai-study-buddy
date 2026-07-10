import { assert, assertEquals } from "https://deno.land/std@0.224.0/assert/mod.ts";
import { buildPdfOcrRequestBody, parsePdfOcrResult } from "./pdf_ocr_adapter.ts";

Deno.test("provider body uses high-detail PDF and trusted candidates", () => {
  const body = buildPdfOcrRequestBody("pinned", new Uint8Array([1, 2]), [2, 5]);
  assertEquals(body.store, false);
  assert(String(body.instructions).includes("pages 2, 5"));
  const file = body.input[0].content[0];
  assertEquals(file.type, "input_file");
  assertEquals(file.detail, "high");
  assert(String(file.file_data).startsWith("data:application/pdf;base64,"));
});

Deno.test("structured result contains pages only and sanitizes warnings", () => {
  const pages = parsePdfOcrResult({ pages: [{
    page_number: 2, text: "text", detected_language: null,
    handwriting_present: false,
    warning_codes: ["unknown", "blur_detected", "blur_detected"],
    truncated: false,
  }] });
  assertEquals(pages[0].warning_codes, ["blur_detected"]);
});
