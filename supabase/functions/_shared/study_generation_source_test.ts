import {
  canonicalStudySource,
  StudySourceError,
} from "./study_generation_source.ts";

Deno.test("canonical source preserves the existing extracted-text path", () => {
  const source = canonicalStudySource({
    kind: "pdf",
    source_kind: "upload",
    processing_status: "ready",
    content_text: "  authoritative extracted text  ",
  });
  equal(source, {
    kind: "extracted_text",
    text: "authoritative extracted text",
  });
});

Deno.test("completed validated structured summary is study-ready with empty text", () => {
  const source = canonicalStudySource(validSummaryRow());
  equal(source.kind, "structured_summary");
  assert(source.text.includes("Section: Foundations"));
  assert(source.text.includes("Equation (eq_1, page 1): x^2"));
  assert(!source.text.includes("raw_provider"));
});

Deno.test("pending legacy processing status does not block a valid summary", () => {
  const row = validSummaryRow();
  row.processing_status = "pending";
  equal(canonicalStudySource(row).kind, "structured_summary");
});

Deno.test("invalid version, provenance, markdown, or latex is rejected", () => {
  for (
    const mutate of [
      (row: Record<string, unknown>) => row.summary_schema_version = 2,
      (row: Record<string, unknown>) => row.analysis_status = "processing",
      (row: Record<string, unknown>) => {
        (row.summary_payload as any).sections[0].source_pages = [2];
      },
      (row: Record<string, unknown>) => {
        (row.summary_payload as any).sections[0].blocks[0].markdown =
          "[unsafe](https://example.test)";
      },
      (row: Record<string, unknown>) => {
        (row.summary_payload as any).equations[0].latex = "\\href{x}{y}";
      },
    ]
  ) {
    const row = validSummaryRow();
    mutate(row);
    throwsStudySource(() => canonicalStudySource(row));
  }
});

function validSummaryRow(): Record<string, unknown> {
  return {
    kind: "pdf",
    source_kind: "upload",
    processing_status: "pending",
    content_text: "",
    analysis_status: "completed",
    analysis_page_count: 1,
    summary_schema_version: 1,
    summary_validation_version: "phase-c-validator-v2",
    summary_validation_hash: "a".repeat(64),
    summary_payload: {
      language: "en",
      sections: [{
        id: "s1",
        title: "Foundations",
        blocks: [
          { kind: "prose", markdown: "A safe explanation.", display: "block" },
          { kind: "equation", equation_id: "eq_1", display: "block" },
        ],
        source_pages: [1],
        confidence: 0.9,
      }],
      key_concepts: [{
        title: "Concept",
        explanation_markdown: "Safe concept text.",
        source_pages: [1],
        confidence: 0.9,
      }],
      equations: [{
        id: "eq_1",
        latex: "x^2",
        explanation_markdown: "Safe equation explanation.",
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
        page_modes: [{ page: 1, mode: "visual" }],
      },
    },
  };
}

function throwsStudySource(callback: () => unknown) {
  try {
    callback();
  } catch (error) {
    if (error instanceof StudySourceError) return;
  }
  throw new Error("Expected StudySourceError");
}

function assert(value: boolean) {
  if (!value) throw new Error("Assertion failed");
}

function equal(actual: unknown, expected: unknown) {
  if (JSON.stringify(actual) !== JSON.stringify(expected)) {
    throw new Error(
      `Expected ${JSON.stringify(expected)}, got ${JSON.stringify(actual)}`,
    );
  }
}
