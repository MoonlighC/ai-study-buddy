import { diagnoseFinalSummaryLatex } from "./latex_diagnostic.ts";

Deno.test("LaTeX diagnostic returns only bounded syntax metadata", () => {
  const result = diagnoseFinalSummaryLatex([
    { latex: String.raw`\frac{}{}` },
    { latex: String.raw`\operatorname{}` },
  ]);
  equal(result.equation_index, 1);
  equal(result.validator_rule_code, "latex_command_unsupported");
  equal(result.category, "unsupported_command");
  equal(result.offending_syntax, "operatorname");
  equal(result.equations_passing_before_failure, 1);
  equal(JSON.stringify(result).includes("\\operatorname"), false);
  equal(JSON.stringify(result).includes("\\operatorname"), false);
});

Deno.test("LaTeX diagnostic all-pass result contains no failure", () => {
  const result = diagnoseFinalSummaryLatex([
    { latex: String.raw`\frac{}{}` },
    { latex: String.raw`\cdot` },
  ]);
  equal(result.equation_index, null);
  equal(result.validator_rule_code, null);
  equal(result.equations_passing_before_failure, 2);
});

Deno.test("LaTeX diagnostic first failure is deterministic and malformed input fails", () => {
  const equations = [
    { latex: String.raw`\href{}{}` },
    { latex: String.raw`\operatorname{}` },
  ];
  const first = diagnoseFinalSummaryLatex(equations);
  const second = diagnoseFinalSummaryLatex(equations);
  equal(first, second);
  equal(first.equation_index, 0);
  equal(first.category, "forbidden_url_link_command");
  equal(first.offending_syntax, "href");
});

function equal(actual: unknown, expected: unknown) {
  if (JSON.stringify(actual) !== JSON.stringify(expected)) {
    throw new Error(
      `Expected ${JSON.stringify(expected)}, got ${JSON.stringify(actual)}`,
    );
  }
}
