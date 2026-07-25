import {
  canonicalizeFinalSummaryEquations,
  canonicalizePageBatchResult,
  ProviderRequest,
  validateProviderOutput,
  validateProviderOutputWithMetadata,
} from "./openai_adapter.ts";
import {
  validateDownstreamPageBatchResult,
  validatePageBatchResult,
  validateReductionResult,
  validateSummarySemantics,
} from "./schemas.ts";
import {
  grumciAuthoritativeEquation,
  grumciFinalSummary,
  grumciReduction,
  gti6Pages11To15Provider,
  gti6Pages11To15Raw,
  gti7Pages21To25,
  gti7Pages26To30,
} from "./phase_c_real_failure_fixtures.ts";

Deno.test("gti6 raw page warning fails at the exact provider contract", () => {
  const validation = validatePageBatchResult(
    gti6Pages11To15Raw,
    [11, 12, 13, 14, 15],
    50,
  );
  equal(validation.valid, false);
  includes(validation.errors, "page_12:page_warning_code_not_allowed");
});

Deno.test("gti6 Boolean expression canonicalizes without unrelated changes", () => {
  const original = clone(gti6Pages11To15Provider);
  const canonical = canonicalizePageBatchResult(
    original,
    [11, 12, 13, 14, 15],
    50,
  );
  equal(canonical.valid, true);
  const result = canonical.result as any;
  equal(
    result.pages[1].equations[0].latex,
    String.raw`A = (E_1 \times S) \vee (E_2 \times \bar{S})`,
  );
  equal(result.pages[0], original.pages[0]);
  equal(canonical.degradedEquationIds, []);
});

Deno.test("gti7 positive pages 21-25 remain valid", () => {
  equal(
    validatePageBatchResult(gti7Pages21To25, [21, 22, 23, 24, 25], 50)
      .valid,
    true,
  );
});

Deno.test("gti7 pages 26-30 canonicalize spacing and dots", () => {
  const canonical = canonicalizePageBatchResult(
    gti7Pages26To30,
    [26, 27, 28, 29, 30],
    50,
  );
  equal(canonical.valid, true);
  const result = canonical.result as any;
  equal(
    result.pages[3].equations[0].latex,
    String.raw`x_1,\ldots,x_n`,
  );
  equal(result.pages[4].equations[0].latex, "x + y");
  equal(result.pages.slice(0, 3), gti7Pages26To30.pages.slice(0, 3));
});

Deno.test("invalid equation degrades only its page and preserves its batch", () => {
  const fixture = clone(gti7Pages21To25);
  fixture.pages[2].equations = [{
    ...grumciAuthoritativeEquation,
    id: "eq_page23_bad",
    source_page: 23,
    latex: String.raw`\href{unsafe}{x}`,
  }];
  const canonical = canonicalizePageBatchResult(
    fixture,
    [21, 22, 23, 24, 25],
    50,
  );
  equal(canonical.valid, true);
  const result = canonical.result as any;
  equal(result.pages[2].content_status, "partial");
  equal(result.pages[2].confidence, 0.5);
  equal(result.pages[2].equations, []);
  equal(
    result.pages[2].warnings.map((warning: any) => warning.code),
    ["invalid_equation_latex", "page_content_partial"],
  );
  equal(
    validateDownstreamPageBatchResult(
      result,
      [21, 22, 23, 24, 25],
      50,
    ).valid,
    true,
  );
  equal(canonical.degradedEquationIds, ["eq_page23_bad"]);
  equal(
    [result.pages[0], result.pages[1], result.pages[3], result.pages[4]],
    [fixture.pages[0], fixture.pages[1], fixture.pages[3], fixture.pages[4]],
  );
});

Deno.test("GruMCI reduction remains valid", () => {
  equal(
    validateReductionResult(
      grumciReduction,
      [1, 2, 3, 4],
      ["eq_page1_1"],
    ).valid,
    true,
  );
});

Deno.test("GruMCI orphan equation attaches to its unique sourced section", () => {
  const request = finalRequest();
  const canonical = canonicalizeFinalSummaryEquations(
    request,
    clone(grumciFinalSummary),
  );
  equal(canonical.valid, true);
  const result = canonical.result as any;
  equal(canonical.comparison.orphanReferencesAdded, 1);
  equal(
    result.sections[0].blocks[1],
    { kind: "equation", equation_id: "eq_page1_1", display: "block" },
  );
  const validated = validateProviderOutput(
    request,
    clone(grumciFinalSummary),
  );
  equal(validateSummarySemantics(validated, 4).valid, true);
});

Deno.test("final provider cannot alter or invent authoritative equations", () => {
  const altered = clone(grumciFinalSummary);
  altered.equations[0].latex = "provider_changed";
  const canonical = canonicalizeFinalSummaryEquations(finalRequest(), altered);
  equal(canonical.valid, true);
  const result = canonical.result as any;
  equal(
    result.equations[0],
    grumciAuthoritativeEquation,
  );
  equal(canonical.comparison.equationFieldsReplaced, true);

  const invented = clone(grumciFinalSummary);
  invented.equations[0].id = "eq_invented";
  equal(
    canonicalizeFinalSummaryEquations(finalRequest(), invented).valid,
    false,
  );
});

Deno.test("safe equation comparison metadata survives validation", () => {
  const request = finalRequest();
  const orphan = validateProviderOutputWithMetadata(
    request,
    clone(grumciFinalSummary),
  );
  equal(orphan.equationComparison, {
    authoritativeEquationCount: 1,
    providerEquationCount: 1,
    orphanReferencesAdded: 1,
    equationFieldsReplaced: false,
  });

  const altered = clone(grumciFinalSummary);
  altered.equations[0].latex = "provider_changed";
  const replaced = validateProviderOutputWithMetadata(request, altered);
  equal(replaced.equationComparison?.equationFieldsReplaced, true);

  const unchanged = validateProviderOutputWithMetadata(
    request,
    replaced.result,
  );
  equal(unchanged.equationComparison, {
    authoritativeEquationCount: 1,
    providerEquationCount: 1,
    orphanReferencesAdded: 0,
    equationFieldsReplaced: false,
  });
});

Deno.test("orphan recovery stays strict when section provenance is ambiguous", () => {
  const ambiguous = clone(grumciFinalSummary);
  ambiguous.sections.push({
    ...clone(ambiguous.sections[0]),
    id: "section_page_1_duplicate",
  });
  equal(
    canonicalizeFinalSummaryEquations(finalRequest(), ambiguous).valid,
    false,
  );
});

function finalRequest(): ProviderRequest {
  return {
    operation: "final_summary",
    input: {
      kind: "text",
      text: JSON.stringify({
        operation: "final_summary",
        authoritative_equations: [grumciAuthoritativeEquation],
        validated_reduction: grumciReduction,
        manifest: [1, 2, 3, 4].map((page) => ({
          page_number: page,
          status: "completed",
          route: "visual",
          warnings: [],
        })),
      }),
    },
    expectedPages: [1, 2, 3, 4],
    allowedEquationIds: ["eq_page1_1"],
    authoritativeEquations: [grumciAuthoritativeEquation],
    pageCount: 4,
    idempotencyKey: "d".repeat(64),
  };
}

function includes(values: string[], expected: string) {
  if (!values.includes(expected)) {
    throw new Error(`Expected ${expected}, got ${JSON.stringify(values)}`);
  }
}

function clone<T>(value: T): T {
  return JSON.parse(JSON.stringify(value));
}

function equal(actual: unknown, expected: unknown) {
  if (JSON.stringify(actual) !== JSON.stringify(expected)) {
    throw new Error(
      `Expected ${JSON.stringify(expected)}, got ${JSON.stringify(actual)}`,
    );
  }
}
