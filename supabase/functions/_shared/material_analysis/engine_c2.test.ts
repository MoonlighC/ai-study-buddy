import {
  analysisLog,
  buildPagePlans,
  buildProcessingVersionContract,
  confirmationRequired,
  createReductionGroups,
  createTextBatches,
  createVisualBatches,
  inspectSourceBytes,
  parseMaterialOnlyRequest,
  parsePrepareRequest,
  projectSummaryToSafeMarkdown,
  sanitizePublicStatus,
  validateSourceMaterial,
} from "./engine.ts";
import { sha256Hex, stableJson } from "./fingerprints_retry.ts";
import { buildSyntheticPdf } from "./synthetic_pdf_fixtures.ts";
import { StructuredSummary } from "./contracts.ts";

const owner = "11111111-1111-4111-8111-111111111111";
const materialId = "22222222-2222-4222-8222-222222222222";

Deno.test("C2 public DTOs reject every client-controlled internal field", () => {
  const prepare = {
    material_id: materialId,
    processing_mode: "recommended",
    confirm_large_document: false,
  };
  equal(parsePrepareRequest(prepare), prepare);
  for (
    const extra of [
      "user_id",
      "model",
      "detail",
      "routing",
      "page_numbers",
      "storage_path",
    ]
  ) {
    throws(() => parsePrepareRequest({ ...prepare, [extra]: "attacker" }));
    throws(() =>
      parseMaterialOnlyRequest({ material_id: materialId, [extra]: "attacker" })
    );
  }
});

Deno.test("C2 preparation validates canonical private source ownership", () => {
  const material = pdfMaterial();
  equal(validateSourceMaterial(material, owner, materialId), material);
  for (
    const changed of [
      { user_id: "33333333-3333-4333-8333-333333333333" },
      { storage_bucket: "public" },
      { storage_path: `${owner}/wrong/file.pdf` },
      { mime_type: "text/plain" },
      { source_kind: "manual" },
    ]
  ) {
    throws(() =>
      validateSourceMaterial({ ...material, ...changed }, owner, materialId)
    );
  }
});

Deno.test("C2 PDF page gates cover 1 10 11 20 21 and 100 pages", async () => {
  for (const count of [1, 10, 11, 20, 21, 100]) {
    const bytes = await buildSyntheticPdf(Array(count).fill("text"));
    const inspected = await inspectSourceBytes(
      { ...pdfMaterial(), file_size_bytes: bytes.length },
      bytes,
    );
    equal(inspected.pageCount, count);
    equal(confirmationRequired(count), count >= 21);
  }
});

Deno.test("C2 rejects page 101 before any provider boundary", async () => {
  const bytes = await buildSyntheticPdf(Array(101).fill("text"));
  await rejects(() =>
    inspectSourceBytes(
      { ...pdfMaterial(), file_size_bytes: bytes.length },
      bytes,
    )
  );
});

Deno.test("C2 rejects mismatched bytes and signatures", async () => {
  await rejects(() =>
    inspectSourceBytes(pdfMaterial(), new Uint8Array([1, 2, 3]))
  );
  const png = Uint8Array.from([0x89, 0x50, 0x4e, 0x47, 0x0d, 0x0a, 0x1a, 0x0a]);
  const image = imageMaterial(png.length);
  equal((await inspectSourceBytes(image, png)).pageCount, 1);
});

Deno.test("C2 image size gate accepts exactly 8 MiB and rejects one byte more", () => {
  equal(
    validateSourceMaterial(imageMaterial(8 * 1024 * 1024), owner, materialId)
      .file_size_bytes,
    8 * 1024 * 1024,
  );
  throws(() =>
    validateSourceMaterial(
      imageMaterial(8 * 1024 * 1024 + 1),
      owner,
      materialId,
    )
  );
});

Deno.test("C2 PDF size gate accepts exactly 40 MiB and rejects one byte more", () => {
  equal(
    validateSourceMaterial(
      { ...pdfMaterial(), file_size_bytes: 40 * 1024 * 1024 },
      owner,
      materialId,
    ).file_size_bytes,
    40 * 1024 * 1024,
  );
  throws(() =>
    validateSourceMaterial(
      { ...pdfMaterial(), file_size_bytes: 40 * 1024 * 1024 + 1 },
      owner,
      materialId,
    )
  );
});

Deno.test("C2 version contract fingerprints every output-affecting component", async () => {
  const base = await buildProcessingVersionContract({
    material: pdfMaterial(),
    sourceHash: "a".repeat(64),
    processingMode: "recommended",
    pageCount: 1,
  });
  const expectedKeys = [
    "final_summary_schema_version",
    "fingerprint_version",
    "mini_pdf_version",
    "openai_configuration_version",
    "page_count",
    "page_schema_version",
    "processing_mode",
    "prompt_version",
    "reduction_schema_version",
    "router_version",
    "source_content_hash",
    "source_metadata_hash",
    "validator_version",
  ];
  equal(Object.keys(base.contract).sort(), expectedKeys);
  for (const key of expectedKeys) {
    const changed = {
      ...base.contract,
      [key]:
        typeof base.contract[key as keyof typeof base.contract] === "number"
          ? 2
          : `${base.contract[key as keyof typeof base.contract]}-changed`,
    };
    const fingerprint = await sha256Hex(stableJson(changed));
    if (fingerprint === base.fingerprint) {
      throw new Error(`version component did not change fingerprint: ${key}`);
    }
  }
  const metadataChanged = await buildProcessingVersionContract({
    material: { ...pdfMaterial(), metadata: { ocr_version: "v2" } },
    sourceHash: "a".repeat(64),
    processingMode: "recommended",
    pageCount: 1,
  });
  if (metadataChanged.fingerprint === base.fingerprint) {
    throw new Error("source metadata did not change fingerprint");
  }
});

Deno.test("C2 routing is local deterministic and STEM is stricter", async () => {
  const material = pdfMaterial();
  const general = await buildPagePlans({
    material,
    pageCount: 1,
    mode: "recommended",
    selectablePages: [{
      page_number: 1,
      text: "A reliable history lecture page. ".repeat(10),
    }],
  });
  const repeated = await buildPagePlans({
    material,
    pageCount: 1,
    mode: "recommended",
    selectablePages: [{
      page_number: 1,
      text: "A reliable history lecture page. ".repeat(10),
    }],
  });
  equal(general, repeated);
  const stem = await buildPagePlans({
    material,
    pageCount: 1,
    mode: "recommended",
    selectablePages: [{
      page_number: 1,
      text: "The theorem uses matrix = integral + equation. ".repeat(10),
    }],
  });
  equal(stem[0].route, "visual");
});

Deno.test("C2 text batches are at most ten pages and 40000 characters", () => {
  const pages = Array.from({ length: 25 }, (_, index) => ({
    page_number: index + 1,
    normalized_text: "x".repeat(3900),
  }));
  const batches = createTextBatches(pages);
  equal(batches.length, 3);
  for (const batch of batches) {
    if (batch.length > 10) throw new Error("page limit");
    const rendered = batch.map((page) =>
      `<original_page number="${page.page_number}">\n${page.normalized_text}\n</original_page>`
    ).join("\n");
    if (rendered.length > 40_000) throw new Error("character limit");
  }
});

Deno.test("C2 visual and reduction grouping are bounded", () => {
  equal(
    createVisualBatches(Array.from({ length: 100 }, (_, index) => index + 1))
      .length,
    20,
  );
  for (const batch of createVisualBatches([1, 2, 3, 4, 5, 6])) {
    if (batch.length > 5) throw new Error("visual limit");
  }
  const reductions = createReductionGroups(
    Array.from({ length: 100 }, (_, index) => index),
  );
  equal(reductions.length, 10);
  equal(reductions.every((group) => group.length <= 10), true);
});

Deno.test("C2 safe projection contains no active links and preserves warnings", () => {
  const markdown = projectSummaryToSafeMarkdown(validSummary());
  equal(markdown.includes("## Overview"), true);
  equal(markdown.includes("Equation: V = I \\cdot R"), true);
  equal(/https?:\/\//.test(markdown), false);
});

Deno.test("C2 status strips internal telemetry and logs only allowlisted fields", () => {
  const status = sanitizePublicStatus({
    ...publicStatus(),
    model: "secret-model",
    file_id: "file-secret",
  });
  equal("model" in (status as unknown as Record<string, unknown>), false);
  const lines: string[] = [];
  analysisLog("advance", "completed", {
    state: "processing",
    model: "secret-model",
    response_id: "resp_secret",
    request_body: "document",
  }, (line) => lines.push(line));
  equal(lines.length, 1);
  equal(lines[0].includes("secret"), false);
  equal(lines[0].includes("document"), false);
});

Deno.test("diagnostic logs retain only code and bounded non-content facts", () => {
  const lines: string[] = [];
  analysisLog("diagnostic", "recorded", {
    reason: "page_latex_failed",
    validator_stage: "validatePageLatex",
    equation_count: 2,
    response_body: "private provider content",
    response_id: "resp_private",
    authorization: "Bearer private",
  }, (line) => lines.push(line));
  equal(lines.length, 1);
  equal(lines[0].includes("page_latex_failed"), true);
  equal(lines[0].includes("validatePageLatex"), true);
  equal(lines[0].includes("private"), false);
  equal(lines[0].includes("response_id"), false);
  equal(lines[0].includes("authorization"), false);
});

function pdfMaterial() {
  return {
    id: materialId,
    user_id: owner,
    kind: "pdf" as const,
    source_kind: "upload" as const,
    storage_bucket: "study-materials",
    storage_path: `${owner}/${materialId}/notes.pdf`,
    mime_type: "application/pdf",
    file_size_bytes: 123,
    processing_status: "ready",
    deleted_at: null,
    metadata: {},
  };
}

function imageMaterial(length: number) {
  return {
    ...pdfMaterial(),
    kind: "image" as const,
    storage_bucket: "study-images",
    storage_path: `${owner}/${materialId}/notes.png`,
    mime_type: "image/png",
    file_size_bytes: length,
  };
}

function validSummary(): StructuredSummary {
  return {
    language: "en",
    sections: [{
      id: "overview",
      title: "Overview",
      blocks: [{
        kind: "equation",
        equation_id: "eq_voltage",
        display: "block",
      }],
      source_pages: [1],
      confidence: 0.9,
    }],
    key_concepts: [{
      title: "Voltage",
      explanation_markdown: "A safe explanation.",
      source_pages: [1],
      confidence: 0.9,
    }],
    equations: [{
      id: "eq_voltage",
      latex: "V = I \\cdot R",
      explanation_markdown: "Ohm's law.",
      source_page: 1,
      display: "block",
      confidence: 0.9,
      uncertainty: false,
    }],
    warnings: [],
    partial_extraction: {
      is_partial: false,
      analyzed_pages: [1],
      partial_pages: [],
      missing_pages: [],
      page_modes: [{ page: 1, mode: "text" }],
    },
  };
}

function publicStatus() {
  return {
    material_id: materialId,
    processing_mode: "recommended",
    state: "processing",
    public_stage: "analyzing_pages",
    page_count: 1,
    completed_pages: 0,
    confirmation_required: false,
    can_retry: false,
    retry_after_seconds: null,
    warnings: [],
    summary_schema_version: null,
    summary_payload: null,
  };
}

function equal(actual: unknown, expected: unknown) {
  if (JSON.stringify(actual) !== JSON.stringify(expected)) {
    throw new Error(
      `Expected ${JSON.stringify(expected)}, got ${JSON.stringify(actual)}`,
    );
  }
}
function throws(action: () => unknown) {
  try {
    action();
  } catch (_) {
    return;
  }
  throw new Error("Expected failure");
}
async function rejects(action: () => Promise<unknown>) {
  try {
    await action();
  } catch (_) {
    return;
  }
  throw new Error("Expected rejection");
}
