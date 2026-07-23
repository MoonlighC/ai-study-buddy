import { validatePageBatchResult, validateReductionResult } from "./schemas.ts";
import { validateSafeMarkdown } from "./validators.ts";
import { realOutputFixtures } from "./real_output_fixtures.ts";

for (const fixture of realOutputFixtures) {
  Deno.test(`real output fixture: ${fixture.name}`, () => {
    const validation = fixture.operation === "page"
      ? validatePageBatchResult(
        fixture.payload,
        fixture.expectedPages,
        Math.max(...fixture.expectedPages),
      )
      : validateReductionResult(
        fixture.payload,
        fixture.expectedPages,
        fixture.allowedEquationIds,
      );
    equal(validation.valid, fixture.expectedValid);
    if (fixture.expectedCode) {
      equal(
        validation.errors.some((error) =>
          error.includes(fixture.expectedCode!)
        ),
        true,
      );
    }
  });
}

Deno.test("dollars in fenced and inline code are not math delimiters", () => {
  equal(
    validateSafeMarkdown("```dart\nprint('$value');\n```\nUse `$value`.").valid,
    true,
  );
});

Deno.test("dollar-delimited math outside code remains forbidden", () => {
  const validation = validateSafeMarkdown("Use $x + y$ here.");
  equal(validation.valid, false);
  equal(validation.errors.includes("markdown_latex_delimiter"), true);
});

function equal(actual: unknown, expected: unknown) {
  if (JSON.stringify(actual) !== JSON.stringify(expected)) {
    throw new Error(
      `Expected ${JSON.stringify(expected)}, got ${JSON.stringify(actual)}`,
    );
  }
}
