import {
  capUtf16,
  createExtractPdfTextHandler,
  extractionVersion,
  ExtractPdfDependencies,
  MaterialRow,
  noSelectableTextMessage,
  normalizePdfPages,
  classifyPdfPages,
} from "./handler.ts";

const userId = "11111111-1111-4111-8111-111111111111";
const materialId = "22222222-2222-4222-8222-222222222222";
const pdfBytes = new TextEncoder().encode("%PDF-test");

Deno.test("requires authentication and exact request shape", async () => {
  const fixture = createFixture();
  let response = await fixture.handler(new Request("http://local", { method: "POST" }));
  assertEquals(response.status, 401);
  response = await fixture.handler(request({ material_id: materialId, path: "forged" }));
  assertEquals(response.status, 400);
});

Deno.test("claims, validates, normalizes and completes extraction", async () => {
  const first = `First page\n\n${"Useful selectable study text ".repeat(4)}`.trim();
  const second = `Second page\n${"More reliable selectable text ".repeat(4)}`.trim();
  const fixture = createFixture({ pages: [first, second] });
  const response = await fixture.handler(request({ material_id: materialId }));
  const body = await response.json();
  assertEquals(response.status, 200);
  assertEquals(body.ok, true);
  assertEquals(body.material.processing_status, "ready");
  assertEquals(body.material.content_text, `${first}\n\n${second}`);
  assertEquals(fixture.parseCalls(), 1);
});

Deno.test("ready material returns idempotently without parsing", async () => {
  const fixture = createFixture({ status: "ready", content: "Existing valid text" });
  const body = await (await fixture.handler(request({ material_id: materialId }))).json();
  assertEquals(body.idempotent, true);
  assertEquals(fixture.parseCalls(), 0);
});

Deno.test("processing duplicate returns 409", async () => {
  const fixture = createFixture({ status: "processing" });
  const response = await fixture.handler(request({ material_id: materialId }));
  assertEquals(response.status, 409);
});

Deno.test("bad signature and empty extraction become safe failed rows", async () => {
  const invalid = createFixture({ bytes: new TextEncoder().encode("not-pdf!!") });
  let body = await (await invalid.handler(request({ material_id: materialId }))).json();
  assertEquals(body.ok, false);
  assertEquals(body.error.message, "The uploaded file is not a valid PDF.");

  const empty = createFixture({ pages: [" \t\r\n "] });
  body = await (await empty.handler(request({ material_id: materialId }))).json();
  assertEquals(body.error.message, noSelectableTextMessage);
  assertEquals(body.material.summary, "Preserved summary");
});

Deno.test("actual byte size must match the stored size", async () => {
  const fixture = createFixture({ declaredSize: pdfBytes.length + 1 });
  const body = await (await fixture.handler(request({ material_id: materialId }))).json();
  assertEquals(body.ok, false);
  assertEquals(body.error.code, "invalid_pdf");
  assertEquals(fixture.parseCalls(), 0);
});

Deno.test("wrong material shape is rejected before download", async () => {
  for (const mutate of [
    (row: MaterialRow) => row.kind = "image",
    (row: MaterialRow) => row.source_kind = "manual",
    (row: MaterialRow) => row.storage_bucket = "study-images",
    (row: MaterialRow) => row.mime_type = "image/png",
    (row: MaterialRow) => row.storage_path = `${userId}/other/file.pdf`,
    (row: MaterialRow) => row.file_size_bytes = 0,
  ]) {
    const fixture = createFixture({ mutate });
    const response = await fixture.handler(request({ material_id: materialId }));
    assertEquals(response.status, 422);
    assertEquals(fixture.parseCalls(), 0);
  }
});

Deno.test("claim token mismatch cannot finalize", async () => {
  const fixture = createFixture({ rejectFinalToken: true });
  const response = await fixture.handler(request({ material_id: materialId }));
  assertEquals(response.status, 500);
});

Deno.test("normalization and UTF-16 cap are deterministic", () => {
  assertEquals(normalizePdfPages([" A\t B\r\n\r\n\r\nC ", " D "]), "A B\n\nC\n\nD");
  const capped = capUtf16(`1234😀x`, 5);
  assertEquals(capped.text, "1234");
  assertEquals(capped.truncated, true);
});

Deno.test("zero text is an OCR candidate and mixed pages retain selectable text", () => {
  const useful = "Reliable selectable study text with letters and numbers 123. ".repeat(2);
  const classified = classifyPdfPages([useful, ""], 2);
  assertEquals(classified.classification, "mixed_ocr_available");
  assertEquals(classified.usefulPages, [1]);
  assertEquals(classified.candidatePages, [2]);
});

Deno.test("pdf-text-v2 removes only confident repeated edge lines", () => {
  assertEquals(extractionVersion, "pdf-text-v2");
  const normalized = normalizePdfPages([
    "Course header\nFirst body\nShared footer",
    "Course header\nSecond body\nShared footer",
    "Course header\nThird body\nShared footer",
    "Different header\nFourth body\nShared footer",
  ]);
  assertEquals(
    normalized,
    "First body\n\nSecond body\n\nThird body\n\nDifferent header\nFourth body",
  );
});

Deno.test("cleanup preserves repeated body text and low-confidence edges", () => {
  const normalized = normalizePdfPages([
    "Occasional header\nRepeated body\nFormula x = 2",
    "Different header\nRepeated body\nFormula y = 3",
    "Occasional header\nRepeated body\nFormula z = 4",
  ]);
  assertEquals(
    normalized,
    "Occasional header\nRepeated body\nFormula x = 2\n\n" +
      "Different header\nRepeated body\nFormula y = 3\n\n" +
      "Occasional header\nRepeated body\nFormula z = 4",
  );
});

Deno.test("cleanup removes clear edge page numbers but preserves numeric content", () => {
  const normalized = normalizePdfPages([
    "Page 1\nValue 42\nFormula 1 + 1 = 2",
    "2 / 3\nValue 2\nFormula 2 + 2 = 4",
    "Value 3\nFormula 3 + 3 = 6\nPage 3",
  ]);
  assertEquals(
    normalized,
    "Value 42\nFormula 1 + 1 = 2\n\n" +
      "Value 2\nFormula 2 + 2 = 4\n\n" +
      "Value 3\nFormula 3 + 3 = 6",
  );
});

function request(body: Record<string, unknown>) {
  return new Request("http://local", {
    method: "POST",
    headers: { Authorization: "Bearer valid", "Content-Type": "application/json" },
    body: JSON.stringify(body),
  });
}

function createFixture(options: {
  status?: string;
  content?: string | null;
  bytes?: Uint8Array;
  pages?: string[];
  mutate?: (row: MaterialRow) => void;
  rejectFinalToken?: boolean;
  declaredSize?: number;
} = {}) {
  let row = baseMaterial(
    options.declaredSize ?? options.bytes?.length ?? pdfBytes.length,
  );
  row.processing_status = options.status ?? "pending";
  row.content_text = options.content ?? null;
  options.mutate?.(row);
  let parses = 0;
  const deps: ExtractPdfDependencies = {
    verifyJwt: async (jwt) => jwt === "valid" ? userId : null,
    loadOwnedMaterial: async (owner, id) => owner === userId && id === materialId ? row : null,
    claim: async (material, token) => {
      if (!["pending", "failed"].includes(material.processing_status)) return null;
      row = { ...material, processing_status: "processing", metadata: { ...material.metadata, pdf_extraction_claim: token } };
      return row;
    },
    restoreReady: async (material) => row = { ...material, processing_status: "ready" },
    download: async () => options.bytes ?? pdfBytes,
    parse: async () => {
      parses += 1;
      return { pages: options.pages ?? ["Selectable PDF study text with enough reliable letters and numbers for useful extraction. ".repeat(2)], pageCount: 1 };
    },
    succeed: async ({ material, token, text, metadata }) => {
      if (options.rejectFinalToken || material.metadata.pdf_extraction_claim !== token) return null;
      row = { ...material, content_text: text, processing_status: "ready", metadata: { pdf_extraction: metadata } };
      return row;
    },
    fail: async ({ material, token, code, message, metadata }) => {
      if (material.metadata.pdf_extraction_claim !== token) return null;
      row = { ...material, processing_status: "failed", metadata: { pdf_extraction: metadata, pdf_extraction_error: { code, message } } };
      return row;
    },
    token: () => "claim-token",
    now: () => "2026-07-10T12:00:00.000Z",
  };
  return {
    handler: createExtractPdfTextHandler(deps),
    parseCalls: () => parses,
  };
}

function baseMaterial(size: number): MaterialRow {
  return {
    id: materialId,
    user_id: userId,
    subject_id: "33333333-3333-4333-8333-333333333333",
    title: "lecture.pdf",
    kind: "pdf",
    source_kind: "upload",
    content_text: null,
    summary: "Preserved summary",
    storage_bucket: "study-materials",
    storage_path: `${userId}/${materialId}/lecture.pdf`,
    mime_type: "application/pdf",
    file_size_bytes: size,
    processing_status: "pending",
    metadata: {},
    created_at: "2026-07-10T12:00:00.000Z",
  };
}

function assertEquals(actual: unknown, expected: unknown) {
  if (JSON.stringify(actual) !== JSON.stringify(expected)) {
    throw new Error(`Expected ${JSON.stringify(expected)}, got ${JSON.stringify(actual)}`);
  }
}
