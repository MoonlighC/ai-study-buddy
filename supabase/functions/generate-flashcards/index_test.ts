import {
  buildOpenAiRequestBody,
  createGenerateFlashcardsHandler,
  FlashcardInsert,
  GenerateFlashcardsDependencies,
} from "./handler.ts";

const materialId = "22222222-2222-4222-8222-222222222222";

Deno.test("requires authentication and exact count request shape", async () => {
  const fixture = createFixture();
  let response = await fixture.handler(new Request("http://local", {
    method: "POST",
  }));
  assertEquals(response.status, 401);

  for (const body of [
    {},
    { material_id: materialId },
    { material_id: materialId, count: 5, extra: true },
    { material_id: materialId, count: "5" },
    { material_id: materialId, count: null },
    { material_id: materialId, count: true },
    { material_id: materialId, count: 1.5 },
    { material_id: materialId, count: 0 },
    { material_id: materialId, count: -1 },
    { material_id: materialId, count: 31 },
  ]) {
    response = await fixture.handler(request(JSON.stringify(body)));
    assertEquals(response.status, 400);
  }
  response = await fixture.handler(request(
    `{"material_id":"${materialId}","count":1e999}`,
  ));
  assertEquals(response.status, 400);
  assertEquals(fixture.generationCalls(), 0);
});

Deno.test("one request creates additive cards and returns authoritative counts", async () => {
  const fixture = createFixture({
    generated: cardsJson([card("One"), card("Two")]),
  });
  const response = await fixture.handler(request(JSON.stringify({
    material_id: materialId,
    count: 2,
  })));
  const body = await response.json();

  assertEquals(response.status, 200);
  assertEquals(fixture.generationCalls(), 1);
  assertEquals(fixture.requestedCounts(), [2]);
  assertEquals(body.requested_count, 2);
  assertEquals(body.created_count, 2);
  assertEquals(body.flashcards.length, 2);
  assertEquals(fixture.insertedRows().length, 2);
});

Deno.test("only requested candidates are inspected and inserted", async () => {
  const fixture = createFixture({
    generated: JSON.stringify({
      flashcards: [
        card("One"),
        { front: "", back: "Invalid", topic: "Topic", difficulty: "easy" },
        card("Must not be inspected"),
      ],
    }),
  });
  const body = await (await fixture.handler(request(JSON.stringify({
    material_id: materialId,
    count: 2,
  })))).json();

  assertEquals(body.created_count, 1);
  assertEquals(fixture.insertedRows().map((row) => row.front), ["One"]);
});

Deno.test("existing and within-response duplicates are removed", async () => {
  const fixture = createFixture({
    existing: [card("Existing", "Shared answer")],
    generated: cardsJson([
      card("  EXISTING  ", "shared   answer"),
      card("Unique", "Answer"),
      card("unique", " answer "),
      card("Second unique", "Answer two"),
    ]),
  });
  const body = await (await fixture.handler(request(JSON.stringify({
    material_id: materialId,
    count: 4,
  })))).json();

  assertEquals(body.created_count, 2);
  assertEquals(
    fixture.insertedRows().map((row) => row.front),
    ["Unique", "Second unique"],
  );
  assertEquals(fixture.existingRows().length, 1);
});

Deno.test("zero unique cards is a successful result", async () => {
  const fixture = createFixture({
    existing: [card("Existing")],
    generated: cardsJson([card("existing")]),
  });
  const response = await fixture.handler(request(JSON.stringify({
    material_id: materialId,
    count: 1,
  })));
  const body = await response.json();

  assertEquals(response.status, 200);
  assertEquals(body.requested_count, 1);
  assertEquals(body.created_count, 0);
  assertEquals(body.flashcards, []);
  assertEquals(fixture.insertCalls(), 0);
});

Deno.test("existing-card load failure stops before OpenAI", async () => {
  const fixture = createFixture({ throwOnExistingLoad: true });
  const response = await fixture.handler(request(JSON.stringify({
    material_id: materialId,
    count: 5,
  })));

  assertEquals(response.status, 500);
  assertEquals(fixture.generationCalls(), 0);
  assertEquals(fixture.insertCalls(), 0);
});

Deno.test("OpenAI request uses exact structured count and bounded tokens", () => {
  const small = buildOpenAiRequestBody("model", "text", 5);
  const large = buildOpenAiRequestBody("model", "text", 30);
  const smallFormat = small.text.format;
  const largeFormat = large.text.format;

  assertEquals(smallFormat.type, "json_schema");
  assertEquals(smallFormat.strict, true);
  assertEquals(smallFormat.schema.properties.flashcards.minItems, 5);
  assertEquals(smallFormat.schema.properties.flashcards.maxItems, 5);
  assertEquals(largeFormat.schema.properties.flashcards.minItems, 30);
  assert(large.max_output_tokens > small.max_output_tokens);
  assert(large.max_output_tokens <= 6_000);
});

function createFixture(options: {
  existing?: Record<string, unknown>[];
  generated?: string;
  throwOnExistingLoad?: boolean;
} = {}) {
  const existing = [...(options.existing ?? [])];
  const inserted: FlashcardInsert[] = [];
  const counts: number[] = [];
  let generationCalls = 0;
  let insertCalls = 0;

  const deps: GenerateFlashcardsDependencies = {
    model: "test-model",
    async verifyJwt(jwt) {
      return jwt === "valid" ? "user-1" : null;
    },
    async loadOwnedMaterial() {
      return {
        id: materialId,
        user_id: "user-1",
        subject_id: "subject-1",
        kind: "pasted_text",
        source_kind: "manual",
        content_text:
          "Sufficient source material with enough detailed content to generate useful flashcards safely.",
        processing_status: "ready",
      };
    },
    async loadExistingCards() {
      if (options.throwOnExistingLoad) throw new Error("load failed");
      return existing;
    },
    async generateCandidates(input) {
      generationCalls += 1;
      counts.push(input.count);
      return options.generated ?? cardsJson([card("Default")]);
    },
    async insertCards(rows) {
      insertCalls += 1;
      inserted.push(...rows);
      return rows.map((row, index) => ({ id: `new-${index}`, ...row }));
    },
  };

  return {
    handler: createGenerateFlashcardsHandler(deps),
    generationCalls: () => generationCalls,
    requestedCounts: () => counts,
    insertCalls: () => insertCalls,
    insertedRows: () => inserted,
    existingRows: () => existing,
  };
}

function request(body: string) {
  return new Request("http://local", {
    method: "POST",
    headers: {
      Authorization: "Bearer valid",
      "Content-Type": "application/json",
    },
    body,
  });
}

function card(front: string, back = `${front} answer`) {
  return { front, back, topic: "Topic", difficulty: "medium" };
}

function cardsJson(cards: Record<string, unknown>[]) {
  return JSON.stringify({ flashcards: cards });
}

function assert(condition: boolean, message = "Assertion failed") {
  if (!condition) throw new Error(message);
}

function assertEquals(actual: unknown, expected: unknown) {
  const actualJson = JSON.stringify(actual);
  const expectedJson = JSON.stringify(expected);
  if (actualJson !== expectedJson) {
    throw new Error(`Expected ${expectedJson}, got ${actualJson}`);
  }
}
