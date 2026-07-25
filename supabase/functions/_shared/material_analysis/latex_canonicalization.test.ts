import { canonicalizeLatex, validateLatex } from "./validators.ts";

Deno.test("canonicalizes only the proven safe LaTeX tokens", () => {
  equal(
    canonicalizeLatex(
      String.raw`A \dots B \, C \: D \; E \! F times G vee H wedge I`,
    ),
    String.raw`A \ldots B   C   D   E   F \times G \vee H \wedge I`,
  );
});

Deno.test("operator words remain unchanged in protected text and prose", () => {
  equal(
    canonicalizeLatex(
      String.raw`\text{A times B vee C}+\mathrm{times wedge}+x times y`,
    ),
    String.raw`\text{A times B vee C}+\mathrm{times wedge}+x \times y`,
  );
  equal(canonicalizeLatex("delivery times vary"), "delivery times vary");
});

Deno.test("natural language counterexamples never become operators", () => {
  for (
    const value of [
      "delivery times vary (x)",
      "travel times vary = often",
      "documentation URL times example",
      "timeseries + beehivee + wedged",
      "return x times y;",
    ]
  ) {
    equal(canonicalizeLatex(value), value);
    equal(validateLatex(value).valid, false);
  }
});

Deno.test("protected groups allow whitespace and nested braces", () => {
  for (
    const value of [
      String.raw`\text {A times B} + x \times y`,
      String.raw`\mathrm {vee} + x \vee y`,
      String.raw`\text {A {times \; B}} + x`,
    ]
  ) {
    equal(canonicalizeLatex(value), value);
    equal(validateLatex(value).valid, true);
  }
});

Deno.test("malformed protected groups and URLs fail closed", () => {
  for (
    const value of [
      String.raw`\text A times B + x`,
      String.raw`\mathrm {vee + x`,
      String.raw`x + \text{https://example.com}`,
    ]
  ) {
    equal(canonicalizeLatex(value), value);
    equal(validateLatex(value).valid, false);
  }
});

Deno.test("unknown commands and malformed environments are never repaired", () => {
  for (
    const value of [
      String.raw`\href{x}{y}`,
      String.raw`\begin{matrix}x`,
      String.raw`\input{file}`,
    ]
  ) {
    const canonical = canonicalizeLatex(value);
    equal(canonical, value);
    equal(validateLatex(canonical).valid, false);
  }
});

Deno.test("safe Boolean commands share the strict backend subset", () => {
  for (const command of ["vee", "wedge", "land", "lor", "neg", "oplus"]) {
    equal(validateLatex(`A \\${command} B`).valid, true);
  }
});

function equal(actual: unknown, expected: unknown) {
  if (JSON.stringify(actual) !== JSON.stringify(expected)) {
    throw new Error(
      `Expected ${JSON.stringify(expected)}, got ${JSON.stringify(actual)}`,
    );
  }
}
