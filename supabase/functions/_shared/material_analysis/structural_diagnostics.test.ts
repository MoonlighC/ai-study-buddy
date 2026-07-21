import { diagnoseStructuralFailure } from "./structural_diagnostics.ts";

Deno.test("structural diagnostic records paths and types but never values", () => {
  const response = completed({
    language: "private-language-value",
    sections: [],
    key_concepts: [],
    equations: [],
    warnings: [],
    partial_extraction: {
      is_partial: false,
      analyzed_pages: [1],
      partial_pages: [],
      missing_pages: [],
      page_modes: { page: 1, mode: "visual", private_field: "secret" },
    },
  });
  const diagnostic = diagnoseStructuralFailure(response, {
    operation: "final_summary",
    expectedPages: [1],
    pageCount: 1,
  });

  equal(diagnostic.provider_status, "completed");
  equal(diagnostic.validator_stage, "validateFinalSummarySchema");
  equal(diagnostic.json_parse_success, true);
  equal(diagnostic.observed_types["$.partial_extraction.page_modes"], "object");
  equal(diagnostic.mismatches, [{
    path: "$.sections",
    code: "count_min",
    expected_type: "array",
    observed_type: "array",
  }, {
    path: "$.partial_extraction.page_modes",
    code: "type_mismatch",
    expected_type: "array",
    observed_type: "object",
  }]);
  const serialized = JSON.stringify(diagnostic);
  equal(serialized.includes("private-language-value"), false);
  equal(serialized.includes("secret"), false);
  equal(serialized.includes("private_field"), false);
});

Deno.test("structural diagnostic identifies missing, unexpected, enum, and nullability failures", () => {
  const diagnostic = diagnoseStructuralFailure(
    completed({
      pages: [{
        page_number: 1,
        summary_markdown: null,
        key_concepts: [],
        equations: [{
          id: "eq_a",
          latex: "value-not-retained",
          explanation_markdown: "",
          source_page: 1,
          display: "wide",
          confidence: 0.5,
          uncertainty: false,
        }],
        confidence: 0.8,
        trustworthy: true,
        private_content: "never-retained",
      }],
    }),
    {
      operation: "page_visual",
      expectedPages: [1],
      pageCount: 1,
    },
  );

  equal(diagnostic.missing_required, ["$.pages[].warnings"]);
  equal(diagnostic.unexpected_fields, ["$.pages[].private_content"]);
  includes(diagnostic.mismatches, {
    path: "$.pages[].summary_markdown",
    code: "nullability_mismatch",
    expected_type: "string",
    observed_type: "null",
  });
  includes(diagnostic.mismatches, {
    path: "$.pages[].equations[].display",
    code: "enum_mismatch",
    expected_type: "enum",
    observed_type: "string",
  });
  const serialized = JSON.stringify(diagnostic);
  equal(serialized.includes("value-not-retained"), false);
  equal(serialized.includes("never-retained"), false);
});

Deno.test("structural diagnostic reports parse failure without provider payload", () => {
  const response = {
    id: "provider-id-not-retained",
    status: "completed",
    output: [{ content: [{ type: "output_text", text: "{private payload" }] }],
  };
  const diagnostic = diagnoseStructuralFailure(response, {
    operation: "reduction",
    expectedPages: [1],
    pageCount: 1,
  });
  equal(diagnostic.validator_stage, "parseStructuredJson");
  equal(diagnostic.json_parse_success, false);
  equal(diagnostic.safe_failure_code, "response_json_parse_failed");
  const serialized = JSON.stringify(diagnostic);
  equal(serialized.includes("private payload"), false);
  equal(serialized.includes("provider-id"), false);
});

function completed(payload: unknown): Record<string, unknown> {
  return {
    id: "provider-id-not-retained",
    status: "completed",
    output: [{
      type: "message",
      content: [{ type: "output_text", text: JSON.stringify(payload) }],
    }],
  };
}

function includes<T>(actual: T[], expected: T) {
  if (
    !actual.some((value) => JSON.stringify(value) === JSON.stringify(expected))
  ) {
    throw new Error(
      `expected ${JSON.stringify(expected)} in ${JSON.stringify(actual)}`,
    );
  }
}

function equal(actual: unknown, expected: unknown) {
  if (JSON.stringify(actual) !== JSON.stringify(expected)) {
    throw new Error(
      `expected ${JSON.stringify(expected)}, got ${JSON.stringify(actual)}`,
    );
  }
}
