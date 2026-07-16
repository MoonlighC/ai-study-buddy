import {
  buildSummaryRequestBody,
  conciseSummaryInstructions,
  conciseSummaryOutputTokens,
  isPastedSummaryMaterial,
  isPhaseCUpload,
  pdfStudySummaryInstructions,
  pdfStudySummaryOutputTokens,
} from "./summary_prompt.ts";
import {
  createGenerateSummaryHandler,
  SummaryHandlerDependencies,
} from "./index.ts";

Deno.test("manual pasted text keeps concise summary behavior", () => {
  const request = buildSummaryRequestBody("model", "manual text", false);

  assertEquals(request.instructions, conciseSummaryInstructions);
  assertEquals(request.max_output_tokens, conciseSummaryOutputTokens);
  assert(request.instructions.includes("4 to 6 sentences"));
  assert(!request.instructions.includes("Important formulas or relationships"));
});

Deno.test("legacy ready PDF prompt builder remains available", () => {
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

Deno.test("uploaded PDF and image regeneration routes only through Phase C", () => {
  assert(isPhaseCUpload({ kind: "pdf", source_kind: "upload" }));
  assert(isPhaseCUpload({ kind: "image", source_kind: "upload" }));
  assert(
    !isPastedSummaryMaterial(
      { kind: "pdf", source_kind: "upload", processing_status: "ready" },
      "flattened uploaded text",
    ),
  );
  assert(isPastedSummaryMaterial(
    { kind: "pasted_text", source_kind: "manual" },
    "manual study text",
  ));
});

Deno.test("full generate-summary handler preserves pasted-text compatibility", async () => {
  let generated = 0;
  let saved = "";
  const deps = summaryDependencies({
    id: "22222222-2222-4222-8222-222222222222",
    user_id: "11111111-1111-4111-8111-111111111111",
    kind: "pasted_text",
    source_kind: "manual",
    content_text: "A sufficiently long lecture passage. ".repeat(5),
    processing_status: "ready",
  });
  deps.generate = async (_apiKey, model, text) => {
    generated++;
    assertEquals(model, "test-model");
    assert(text.startsWith("A sufficiently long"));
    return await Promise.resolve("Concise compatible summary.");
  };
  deps.saveSummary = (input) => {
    saved = input.summary;
    return Promise.resolve(true);
  };
  const response = await createGenerateSummaryHandler(deps)(
    new Request(
      "https://local.test/generate-summary",
      {
        method: "POST",
        headers: {
          Authorization: "Bearer valid-jwt",
          "Content-Type": "application/json",
        },
        body: JSON.stringify({
          material_id: "22222222-2222-4222-8222-222222222222",
        }),
      },
    ),
  );
  assertEquals(response.status, 200);
  assertEquals(generated, 1);
  assertEquals(saved, "Concise compatible summary.");
});

Deno.test("full generate-summary handler rejects uploads before paid generation", async () => {
  let generated = 0;
  const deps = summaryDependencies({
    id: "22222222-2222-4222-8222-222222222222",
    user_id: "11111111-1111-4111-8111-111111111111",
    kind: "pdf",
    source_kind: "upload",
    content_text: "Flattened text must not use the legacy path. ".repeat(3),
    processing_status: "ready",
  });
  deps.generate = () => {
    generated++;
    return Promise.resolve("must not happen");
  };
  const response = await createGenerateSummaryHandler(deps)(
    new Request(
      "https://local.test/generate-summary",
      {
        method: "POST",
        headers: {
          Authorization: "Bearer valid-jwt",
          "Content-Type": "application/json",
        },
        body: JSON.stringify({
          material_id: "22222222-2222-4222-8222-222222222222",
        }),
      },
    ),
  );
  assertEquals(response.status, 409);
  assertEquals(generated, 0);
});

function summaryDependencies(
  material: Record<string, unknown>,
): SummaryHandlerDependencies {
  const env = new Map([
    ["SUPABASE_URL", "https://project.test"],
    ["SUPABASE_PUBLISHABLE_KEYS", '{"default":"sb_publishable_test"}'],
    ["SUPABASE_SECRET_KEYS", '{"default":"sb_secret_test"}'],
    ["OPENAI_API_KEY", "openai-test-key"],
    ["OPENAI_MODEL", "test-model"],
  ]);
  return {
    env: (name) => env.get(name) ?? "",
    verifyUser: () => Promise.resolve("11111111-1111-4111-8111-111111111111"),
    loadMaterial: () => Promise.resolve(material),
    saveSummary: () => Promise.resolve(true),
    generate: () => Promise.resolve("summary"),
  };
}

function assert(condition: boolean, message = "Assertion failed") {
  if (!condition) throw new Error(message);
}

function assertEquals(actual: unknown, expected: unknown) {
  if (actual !== expected) {
    throw new Error(`Expected ${expected}, got ${actual}`);
  }
}
