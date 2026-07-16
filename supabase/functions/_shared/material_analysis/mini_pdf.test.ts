import { PDFDocument } from "pdf-lib";
import { extractText, getDocumentProxy } from "unpdf";
import { createMiniPdf } from "./mini_pdf.ts";
import {
  buildSyntheticPdf,
  SyntheticPageKind,
} from "./synthetic_pdf_fixtures.ts";

Deno.test("mini-PDF proof covers one and five selectable pages", async () => {
  await verifyCase("one_text", ["text"], [1]);
  await verifyCase("five_text", ["text", "text", "text", "text", "text"], [
    1,
    2,
    3,
    4,
    5,
  ]);
});

Deno.test("mini-PDF proof covers vector and raster pages", async () => {
  await verifyCase("vector", ["vector"], [1]);
  await verifyCase("raster", ["raster"], [1]);
});

Deno.test("mixed five-page extraction preserves exact original-page mapping", async () => {
  const kinds: SyntheticPageKind[] = [
    "text",
    "vector",
    "raster",
    "text",
    "vector",
  ];
  const source = await buildSyntheticPdf(kinds);
  const result = await createMiniPdf(source, [5, 2, 4]);
  equal(result.originalPageNumbers, [5, 2, 4]);
  const parsed = await independentParse(result.bytes);
  equal(parsed.pageCount, 3);
  includes(parsed.text[0], "original page 5");
  includes(parsed.text[1], "original page 2");
  includes(parsed.text[2], "original page 4");
});

Deno.test("mini-PDF output fingerprint and repeated execution are deterministic", async () => {
  const source = await buildSyntheticPdf([
    "text",
    "vector",
    "raster",
    "text",
    "vector",
  ]);
  const fingerprints: string[] = [];
  const timings: number[] = [];
  const heapBefore = Deno.memoryUsage().heapUsed;
  let observedHeap = heapBefore;
  let outputBytes = 0;
  for (let iteration = 0; iteration < 5; iteration++) {
    const started = performance.now();
    const result = await createMiniPdf(source, [1, 2, 3, 4, 5]);
    timings.push(performance.now() - started);
    fingerprints.push(result.normalizedFingerprint);
    outputBytes = result.bytes.length;
    observedHeap = Math.max(observedHeap, Deno.memoryUsage().heapUsed);
    equal((await PDFDocument.load(result.bytes)).getPageCount(), 5);
  }
  equal(new Set(fingerprints).size, 1);
  const measurement = {
    case: "mixed_five_page_repeated",
    iterations: 5,
    min_ms: round(Math.min(...timings)),
    median_ms: round([...timings].sort((a, b) => a - b)[2]),
    max_ms: round(Math.max(...timings)),
    heap_delta_bytes_observed: Math.max(0, observedHeap - heapBefore),
    output_bytes: outputBytes,
    fingerprint: fingerprints[0],
  };
  console.log(`C1_MINI_PDF_MEASUREMENT ${JSON.stringify(measurement)}`);
});

Deno.test("mini-PDF rejects duplicate, excessive, and out-of-range mappings", async () => {
  const source = await buildSyntheticPdf([
    "text",
    "text",
    "text",
    "text",
    "text",
  ]);
  await rejects(
    () => createMiniPdf(source, [1, 1]),
    "mini_pdf_page_mapping_invalid",
  );
  await rejects(
    () => createMiniPdf(source, [1, 2, 3, 4, 5, 6]),
    "mini_pdf_page_limit",
  );
  await rejects(() => createMiniPdf(source, [6]), "mini_pdf_page_out_of_range");
});

async function verifyCase(
  name: string,
  kinds: SyntheticPageKind[],
  pages: number[],
) {
  const source = await buildSyntheticPdf(kinds);
  const started = performance.now();
  const result = await createMiniPdf(source, pages);
  const elapsed = performance.now() - started;
  const outputBytes = result.bytes.length;
  const parsed = await independentParse(result.bytes);
  equal(parsed.pageCount, pages.length);
  for (let index = 0; index < pages.length; index++) {
    includes(parsed.text[index], `original page ${pages[index]}`);
  }
  console.log(
    `C1_MINI_PDF_MEASUREMENT ${
      JSON.stringify({
        case: name,
        elapsed_ms: round(elapsed),
        source_bytes: source.length,
        output_bytes: outputBytes,
        fingerprint: result.normalizedFingerprint,
      })
    }`,
  );
}

async function independentParse(bytes: Uint8Array) {
  const proxy = await getDocumentProxy(bytes);
  const parsed = await extractText(proxy, { mergePages: false });
  return { pageCount: parsed.totalPages, text: parsed.text };
}
function equal(actual: unknown, expected: unknown) {
  if (JSON.stringify(actual) !== JSON.stringify(expected)) {
    throw new Error(
      `Expected ${JSON.stringify(expected)}, got ${JSON.stringify(actual)}`,
    );
  }
}
function includes(actual: string, expected: string) {
  if (!actual.toLowerCase().includes(expected.toLowerCase())) {
    throw new Error(`Expected ${actual} to include ${expected}`);
  }
}
async function rejects(action: () => Promise<unknown>, message: string) {
  try {
    await action();
  } catch (error) {
    if (error instanceof Error && error.message === message) return;
    throw error;
  }
  throw new Error(`Expected ${message}`);
}
function round(value: number) {
  return Math.round(value * 100) / 100;
}
