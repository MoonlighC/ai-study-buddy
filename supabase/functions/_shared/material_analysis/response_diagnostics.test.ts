import {
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
