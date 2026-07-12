import {
  buildSummaryRequestBody,
  conciseSummaryInstructions,
  conciseSummaryOutputTokens,
  pdfStudySummaryInstructions,
  pdfStudySummaryOutputTokens,
} from "./summary_prompt.ts";

Deno.test("manual pasted text keeps concise summary behavior", () => {
  const request = buildSummaryRequestBody("model", "manual text", false);

  assertEquals(request.instructions, conciseSummaryInstructions);
  assertEquals(request.max_output_tokens, conciseSummaryOutputTokens);
  assert(request.instructions.includes("4 to 6 sentences"));
  assert(!request.instructions.includes("Important formulas or relationships"));
});

Deno.test("ready PDF uses expanded structured study summary behavior", () => {
  const request = buildSummaryRequestBody("model", "pdf text", true);

  assertEquals(request.instructions, pdfStudySummaryInstructions);
  assertEquals(request.max_output_tokens, pdfStudySummaryOutputTokens);
  assert(request.max_output_tokens > conciseSummaryOutputTokens);
  for (
    const heading of [
      "Overview",
      "Key concepts",
      "Important formulas or relationships",
      "Main examples/applications",
      "What to remember",
    ]
  ) {
    assert(request.instructions.includes(heading));
  }
  assert(request.instructions.includes("Preserve the language"));
  assert(
    request.instructions.includes("Do not reconstruct unreadable formulas"),
  );
  assert(request.instructions.includes("Do not ask for more input"));
  assert(request.instructions.includes("supplied portion"));
});

function assert(condition: boolean, message = "Assertion failed") {
  if (!condition) throw new Error(message);
}

function assertEquals(actual: unknown, expected: unknown) {
  if (actual !== expected) {
    throw new Error(`Expected ${expected}, got ${actual}`);
  }
}
