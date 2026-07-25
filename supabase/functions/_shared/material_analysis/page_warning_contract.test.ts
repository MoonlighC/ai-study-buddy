import {
  downstreamAnalysisWarningCodes,
  pageAnalysisResultSchema,
  providerPageWarningCodes,
  reductionResultSchema,
  structuredSummarySchema,
} from "./schemas.ts";

Deno.test("provider page warning schema is narrow and exact", () => {
  const codes = (pageAnalysisResultSchema as any).properties.warnings.items
    .properties.code.enum;
  equal(codes, [...providerPageWarningCodes]);
  equal(codes.includes("invalid_equation_latex"), false);
});

Deno.test("reduction and final schemas preserve downstream warnings", () => {
  for (const schema of [reductionResultSchema, structuredSummarySchema]) {
    const codes =
      (schema as any).properties.warnings.items.properties.code.enum;
    equal(codes, [...downstreamAnalysisWarningCodes]);
  }
});

function equal(actual: unknown, expected: unknown) {
  if (JSON.stringify(actual) !== JSON.stringify(expected)) {
    throw new Error(
      `Expected ${JSON.stringify(expected)}, got ${JSON.stringify(actual)}`,
    );
  }
}
