import { diagnosePageBatchResult } from "./response_diagnostics.ts";
import { gti6Pages11To15Raw } from "./phase_c_real_failure_fixtures.ts";
import { gti7Pages26To30 } from "./phase_c_real_failure_fixtures.ts";

Deno.test("five-page diagnostic exposes the first safe warning failure", () => {
  const diagnostic = diagnosePageBatchResult(
    gti6Pages11To15Raw,
    [11, 12, 13, 14, 15],
    50,
  );
  equal(diagnostic, {
    expected_page_numbers: [11, 12, 13, 14, 15],
    batch_result_count: 5,
    first_failing_page_number: 12,
    field_path: "pages.1.warnings.0.code",
    validator_stage: "validatePageSemantics",
    validator_code: "page_warning_code_not_allowed",
    warning_code: "invalid_equation_latex",
  });
  const serialized = JSON.stringify(diagnostic);
  equal(serialized.includes("Sanitized grounded"), false);
  equal(serialized.includes("\\bar"), false);
});

Deno.test("repairable unsafe equation leaves no fatal diagnostic", () => {
  const fixture = structuredClone(gti6Pages11To15Raw) as any;
  fixture.pages[1].warnings = [];
  fixture.pages[1].equations[0].latex = String.raw`\href{secret}{x}`;
  const diagnostic = diagnosePageBatchResult(
    fixture,
    [11, 12, 13, 14, 15],
    50,
  );
  equal(diagnostic, null);
  equal(JSON.stringify(diagnostic).includes("secret"), false);
});

Deno.test("batch diagnostics repair earlier LaTeX before fatal structure", () => {
  const fixture = structuredClone(gti7Pages26To30) as any;
  fixture.pages[0].equations = [{
    id: "eq_page26_repairable",
    latex: String.raw`x_1,\dots,x_n`,
    explanation_markdown: "",
    source_page: 26,
    display: "inline",
    confidence: 0.9,
    uncertainty: false,
  }];
  fixture.pages[1].unknown_provider_field = "content must not be logged";
  const diagnostic = diagnosePageBatchResult(
    fixture,
    [26, 27, 28, 29, 30],
    50,
  );
  equal(diagnostic?.first_failing_page_number, 27);
  equal(diagnostic?.field_path, "pages.1");
  equal(diagnostic?.validator_stage, "validatePageSchema");
  equal(diagnostic?.validator_code, "page_unknown_field");
  equal(JSON.stringify(diagnostic).includes("content must not be logged"), false);
});

function equal(actual: unknown, expected: unknown) {
  if (JSON.stringify(actual) !== JSON.stringify(expected)) {
    throw new Error(
      `Expected ${JSON.stringify(expected)}, got ${JSON.stringify(actual)}`,
    );
  }
}
