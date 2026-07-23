import {
  diagnoseFinalSummaryResponse,
  diagnosePageResponse,
  DiagnosticCode,
} from "./response_diagnostics.ts";

Deno.test("diagnostic staged parser accepts one completed visual page", () => {
  const result = diagnosePageResponse(response(pageBatch()), 1, 1);
  equal(result.ok, true);
  if (result.ok) {
    equal(result.result, pageBatch());
    equal(result.metadata.response_status, "completed");
    equal(result.metadata.structured_candidate_count, 1);
  }
});

for (
  const fixture of diagnosticFixtures()
) {
  Deno.test(`diagnostic code ${fixture.code} is specific and content-free`, () => {
    const result = diagnosePageResponse(fixture.response, 1, 1);
    equal(result.ok, false);
    if (!result.ok) {
      equal(result.code, fixture.code);
      const persisted = JSON.stringify(result.metadata);
      equal(persisted.includes("private provider content"), false);
      equal(persisted.includes("\\frac"), false);
      equal(Object.keys(result.metadata).length <= 15, true);
    }
  });
}

function equal(actual: unknown, expected: unknown) {
  if (JSON.stringify(actual) !== JSON.stringify(expected)) {
    throw new Error(
      `Expected ${JSON.stringify(expected)}, got ${JSON.stringify(actual)}`,
    );
  }
}

Deno.test("diagnostic unknown exception maps to validation_unknown", () => {
  const hostile = new Proxy({}, {
    get() {
      throw new Error("private provider content");
    },
  });
  const result = diagnosePageResponse(hostile, 1, 1);
  equal(result.ok, false);
  if (!result.ok) equal(result.code, "validation_unknown");
});

Deno.test("final-summary diagnostic accepts a valid completed response", () => {
  const result = diagnoseFinalSummaryResponse(response(finalSummary()), 1);
  equal(result.ok, true);
  if (result.ok) {
    equal(result.metadata.section_count, 1);
    equal(result.metadata.concept_count, 1);
    equal(result.metadata.equation_count, 1);
    equal(result.metadata.source_page_count, 1);
  }
});

for (const fixture of finalDiagnosticFixtures()) {
  Deno.test(`final-summary diagnostic ${fixture.name}`, () => {
    const result = diagnoseFinalSummaryResponse(fixture.response, 1);
    equal(result.ok, false);
    if (!result.ok) {
      equal(result.code, fixture.code);
      const persisted = JSON.stringify(result.metadata);
      equal(persisted.includes("private provider content"), false);
      equal(persisted.includes("\\frac"), false);
      equal(Object.keys(result.metadata).length <= 15, true);
    }
  });
}

Deno.test("final-summary unknown exception is content-free", () => {
  const hostile = new Proxy({}, {
    get() {
      throw new Error("private provider content");
    },
  });
  const result = diagnoseFinalSummaryResponse(hostile, 1);
  equal(result.ok, false);
  if (!result.ok) equal(result.code, "final_validation_unknown");
});

function diagnosticFixtures(): Array<{
  code: DiagnosticCode;
  response: Record<string, unknown>;
}> {
  const mutate = (
    update: (payload: Record<string, any>) => void,
  ) => {
    const payload = pageBatch();
    update(payload);
    return response(payload);
  };
  return [
    {
      code: "response_status_not_completed",
      response: { ...response(pageBatch()), status: "failed" },
    },
    {
      code: "response_error_present",
      response: {
        ...response(pageBatch()),
        status: "failed",
        error: { message: "private provider content" },
      },
    },
    {
      code: "response_incomplete",
      response: {
        ...response(pageBatch()),
        status: "incomplete",
        incomplete_details: { reason: "private provider content" },
      },
    },
    {
      code: "response_refusal",
      response: responseWithContent([{
        type: "refusal",
        refusal: "private provider content",
      }]),
    },
    {
      code: "response_output_missing",
      response: { ...response(pageBatch()), output: [] },
    },
    {
      code: "response_output_multiple",
      response: responseWithContent([
        outputText(pageBatch()),
        outputText(pageBatch()),
      ]),
    },
    {
      code: "response_structured_text_missing",
      response: responseWithContent([{ type: "output_text", text: "" }]),
    },
    {
      code: "response_json_parse_failed",
      response: responseWithContent([{ type: "output_text", text: "{" }]),
    },
    {
      code: "page_schema_failed",
      response: response({ pages: [{ page_number: 1 }] }),
    },
    {
      code: "page_unknown_field",
      response: mutate((payload) => payload.pages[0].provider_secret = true),
    },
    {
      code: "page_number_mismatch",
      response: mutate((payload) => payload.pages[0].page_number = 2),
    },
    {
      code: "page_provenance_failed",
      response: mutate((payload) =>
        payload.pages[0].equations[0].source_page = 2
      ),
    },
    {
      code: "page_confidence_failed",
      response: mutate((payload) => payload.pages[0].confidence = 1.1),
    },
    {
      code: "page_warning_failed",
      response: mutate((payload) => {
        payload.pages[0].warnings = [{
          code: "bad",
          detail: "ok",
          source_pages: [1, 1],
        }];
      }),
    },
    {
      code: "page_equation_reference_failed",
      response: mutate((payload) =>
        payload.pages[0].equations.push({ ...payload.pages[0].equations[0] })
      ),
    },
    {
      code: "page_markdown_failed",
      response: mutate((payload) =>
        payload.pages[0].summary_markdown = "[unsafe](https://example.test)"
      ),
    },
    {
      code: "page_latex_failed",
      response: mutate((payload) =>
        payload.pages[0].equations[0].latex = String.raw`\href{x}{y}`
      ),
    },
    {
      code: "page_payload_too_large",
      response: responseWithContent([{
        type: "output_text",
        text: `{"private":"${"x".repeat(262_145)}"}`,
      }]),
    },
  ];
}

function finalDiagnosticFixtures(): Array<{
  name: string;
  code: DiagnosticCode;
  response: Record<string, unknown>;
}> {
  const mutate = (update: (payload: Record<string, any>) => void) => {
    const payload = finalSummary();
    update(payload);
    return response(payload);
  };
  return [
    {
      name: "failed response with error is rejected at the envelope",
      code: "response_error_present",
      response: {
        ...response(finalSummary()),
        status: "failed",
        error: { message: "private provider content" },
      },
    },
    {
      name: "failed response without output is never accepted",
      code: "response_status_not_completed",
      response: { ...response(finalSummary()), status: "failed", output: [] },
    },
    {
      name: "incomplete response is rejected",
      code: "response_incomplete",
      response: {
        ...response(finalSummary()),
        status: "incomplete",
        incomplete_details: { reason: "private provider content" },
      },
    },
    {
      name: "refusal is rejected",
      code: "response_refusal",
      response: responseWithContent([{
        type: "refusal",
        refusal: "private provider content",
      }]),
    },
    {
      name: "multiple candidates are rejected",
      code: "response_output_multiple",
      response: responseWithContent([
        outputText(finalSummary()),
        outputText(finalSummary()),
      ]),
    },
    {
      name: "malformed JSON is rejected",
      code: "response_json_parse_failed",
      response: responseWithContent([{ type: "output_text", text: "{" }]),
    },
    {
      name: "invalid schema is rejected",
      code: "final_summary_schema_failed",
      response: response({ language: "en" }),
    },
    {
      name: "invalid partition and provenance are rejected",
      code: "final_summary_semantics_failed",
      response: mutate((payload) => {
        payload.partial_extraction.analyzed_pages = [];
        payload.partial_extraction.missing_pages = [];
      }),
    },
    {
      name: "unsafe Markdown is rejected",
      code: "final_summary_markdown_failed",
      response: mutate((payload) =>
        payload.sections[0].blocks[0].markdown =
          "[unsafe](https://example.test)"
      ),
    },
    {
      name: "unsafe LaTeX is rejected",
      code: "final_summary_latex_failed",
      response: mutate((payload) =>
        payload.equations[0].latex = String.raw`\href{x}{y}`
      ),
    },
    {
      name: "oversized payload is rejected",
      code: "final_summary_payload_too_large",
      response: responseWithContent([{
        type: "output_text",
        text: `{"private":"${"x".repeat(262_145)}"}`,
      }]),
    },
    {
      name: "completed-looking payload on failed envelope is never success",
      code: "response_status_not_completed",
      response: { ...response(finalSummary()), status: "failed" },
    },
  ];
}

function response(payload: unknown) {
  return responseWithContent([outputText(payload)]);
}

function responseWithContent(content: unknown[]) {
  return {
    id: "resp_12345678",
    object: "response",
    status: "completed",
    error: null,
    incomplete_details: null,
    output: [{ type: "message", content }],
  };
}

function outputText(payload: unknown) {
  return { type: "output_text", text: JSON.stringify(payload) };
}

function pageBatch(): Record<string, any> {
  return {
    pages: [{
      page_number: 1,
      content_status: "completed",
      summary_markdown: "A grounded STEM summary.",
      key_concepts: ["Quadratic formula"],
      equations: [{
        id: "eq_quadratic",
        latex: String.raw`\frac{-b \pm \sqrt{b^2-4ac}}{2a}`,
        explanation_markdown: "A standard equation.",
        source_page: 1,
        display: "block",
        confidence: 0.95,
        uncertainty: false,
      }],
      confidence: 0.95,
      warnings: [],
      trustworthy: true,
    }],
  };
}

function finalSummary(): Record<string, any> {
  return {
    language: "en",
    sections: [{
      id: "section_1",
      title: "Summary",
      blocks: [
        { kind: "prose", markdown: "Safe summary.", display: "block" },
        { kind: "equation", equation_id: "eq_one", display: "block" },
      ],
      source_pages: [1],
      confidence: 0.9,
    }],
    key_concepts: [{
      title: "Concept",
      explanation_markdown: "Safe explanation.",
      source_pages: [1],
      confidence: 0.9,
    }],
    equations: [{
      id: "eq_one",
      latex: String.raw`\frac{1}{2}`,
      explanation_markdown: "Safe equation.",
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
  };
}
