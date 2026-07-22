import {
  createGenerateQuizHandler,
  parseQuiz,
  SafeQuizGenerationError,
} from "./handler.ts";

const userId = "11111111-1111-4111-8111-111111111111";
const materialId = "22222222-2222-4222-8222-222222222222";
const operationId = "33333333-3333-4333-8333-333333333333";
const questions = [{
  question: "Q?",
  options: ["A", "B"],
  correct_answer: "A",
  explanation: "Because.",
  topic: "T",
  difficulty: "medium" as const,
}];
const source = {
  kind: "structured_summary",
  text: "A validated structured summary long enough for generation.",
};

function check(value: unknown, message: string) {
  if (!value) throw new Error(message);
}
function request(id = operationId) {
  return new Request("http://local", {
    method: "POST",
    headers: {
      Authorization: "Bearer jwt",
      "Content-Type": "application/json",
    },
    body: JSON.stringify({
      material_id: materialId,
      count: 1,
      operation_id: id,
    }),
  });
}
function dependencies(overrides: Record<string, unknown> = {}) {
  let providerPosts = 0;
  const deps = {
    verifyJwt: async () => userId,
    loadOwnedMaterial: async () => ({ id: materialId }),
    loadExistingQuiz: async () => null,
    canonicalSource: () => source,
    reserveOperation: async () => ({ status: "reserved" as const }),
    claimProvider: async () => true,
    awaitOperation: async () => ({
      quiz_id: "q",
      material_id: materialId,
      title: "Quiz",
      questions: [],
    }),
    generate: async () => {
      providerPosts++;
      return {
        text: JSON.stringify({ title: "Quiz", questions }),
        inputTokens: 10,
        outputTokens: 20,
      };
    },
    complete: async () => ({
      quiz_id: "q",
      material_id: materialId,
      title: "Quiz",
      questions,
    }),
    fail: async () => {},
    ...overrides,
  };
  return { deps, posts: () => providerPosts };
}

Deno.test("structured summary quiz generation uses one provider POST", async () => {
  const setup = dependencies();
  const response = await createGenerateQuizHandler(setup.deps)(request());
  check(response.status === 200, "status");
  check(setup.posts() === 1, "one POST");
});

Deno.test("authoritative extracted text regression", async () => {
  const setup = dependencies({
    canonicalSource: () => ({ kind: "extracted_text", text: "x".repeat(100) }),
  });
  check(
    (await createGenerateQuizHandler(setup.deps)(request())).status === 200,
    "status",
  );
});

Deno.test("existing matching quiz uses zero provider POST", async () => {
  const setup = dependencies({
    loadExistingQuiz: async () => ({
      quiz_id: "q",
      material_id: materialId,
      title: "Existing",
      questions,
    }),
  });
  check(
    (await createGenerateQuizHandler(setup.deps)(request())).status === 200,
    "status",
  );
  check(setup.posts() === 0, "zero POST");
});

Deno.test("concurrent joiner does not submit provider request", async () => {
  const setup = dependencies({
    claimProvider: async () => false,
    awaitOperation: async () => ({
      quiz_id: "q",
      material_id: materialId,
      title: "Joined",
      questions,
    }),
  });
  check(
    (await createGenerateQuizHandler(setup.deps)(request())).status === 200,
    "status",
  );
  check(setup.posts() === 0, "zero POST");
});

Deno.test("malformed provider output persists nothing", async () => {
  let completions = 0;
  const setup = dependencies({
    generate: async () => ({
      text: '{"title":"Quiz","questions":[]}',
      inputTokens: 1,
      outputTokens: 1,
    }),
    complete: async () => {
      completions++;
      throw new Error("should not complete");
    },
  });
  check(
    (await createGenerateQuizHandler(setup.deps)(request())).status === 500,
    "status",
  );
  check(completions === 0, "no persistence");
});

Deno.test("strict count, choices, correct answer and closed keys", () => {
  for (
    const invalid of [
      { title: "Q", questions: [] },
      { title: "Q", questions: [{ ...questions[0], correct_answer: "C" }] },
      { title: "Q", questions: [{ ...questions[0], extra: true }] },
    ]
  ) {
    let failed = false;
    try {
      parseQuiz(JSON.stringify(invalid), 1);
    } catch (e) {
      failed = e instanceof SafeQuizGenerationError;
    }
    check(failed, "must fail");
  }
});

Deno.test("request accepts only material, count and operation UUID", async () => {
  const setup = dependencies();
  const bad = new Request("http://local", {
    method: "POST",
    headers: {
      Authorization: "Bearer jwt",
      "Content-Type": "application/json",
    },
    body: JSON.stringify({
      material_id: materialId,
      count: 1,
      operation_id: operationId,
      user_id: userId,
    }),
  });
  check(
    (await createGenerateQuizHandler(setup.deps)(bad)).status === 400,
    "closed request",
  );
  check(setup.posts() === 0, "zero POST");
});

Deno.test("replayed operation returns the completed quiz without another provider POST", async () => {
  let completed = false;
  const setup = dependencies({
    loadExistingQuiz: async () =>
      completed
        ? { quiz_id: "q", material_id: materialId, title: "Quiz", questions }
        : null,
    complete: async () => {
      completed = true;
      return {
        quiz_id: "q",
        material_id: materialId,
        title: "Quiz",
        questions,
      };
    },
  });
  const handler = createGenerateQuizHandler(setup.deps);
  check((await handler(request())).status === 200, "first status");
  check((await handler(request())).status === 200, "replay status");
  check(setup.posts() === 1, "one POST across replay");
});

Deno.test("foreign or absent material stops before reservation and provider", async () => {
  let reservations = 0;
  const setup = dependencies({
    loadOwnedMaterial: async () => null,
    reserveOperation: async () => {
      reservations++;
      return { status: "reserved" as const };
    },
  });
  check(
    (await createGenerateQuizHandler(setup.deps)(request())).status === 404,
    "ownership status",
  );
  check(reservations === 0, "no reservation");
  check(setup.posts() === 0, "no POST");
});

Deno.test("reservation and finalization carry authoritative usage exactly once", async () => {
  let reservations = 0;
  let completions = 0;
  const setup = dependencies({
    reserveOperation: async (input: { count: number; materialId: string }) => {
      reservations++;
      check(input.count === 1, "reserved count");
      check(input.materialId === materialId, "reserved material");
      return { status: "reserved" as const };
    },
    complete: async (input: { inputTokens: number; outputTokens: number }) => {
      completions++;
      check(input.inputTokens === 10, "input usage");
      check(input.outputTokens === 20, "output usage");
      return {
        quiz_id: "q",
        material_id: materialId,
        title: "Quiz",
        questions,
      };
    },
  });
  check(
    (await createGenerateQuizHandler(setup.deps)(request())).status === 200,
    "status",
  );
  check(reservations === 1, "one reservation");
  check(completions === 1, "one finalization");
});

Deno.test("post-provider persistence failure retains reservation accounting", async () => {
  const failures: { code: string; retain: boolean }[] = [];
  const setup = dependencies({
    complete: async () => {
      throw new SafeQuizGenerationError("database_write_failed");
    },
    fail: async (
      _user: string,
      _operation: string,
      code: string,
      retain: boolean,
    ) => {
      failures.push({ code, retain });
    },
  });
  check(
    (await createGenerateQuizHandler(setup.deps)(request())).status === 500,
    "status",
  );
  check(setup.posts() === 1, "one POST");
  check(failures.length === 1, "one failure finalization");
  check(
    failures[0].code === "database_write_failed" && failures[0].retain,
    "retained cost",
  );
});

Deno.test("pre-provider reservation failure performs no POST or failure rewrite", async () => {
  let failures = 0;
  const setup = dependencies({
    reserveOperation: async () => {
      throw new SafeQuizGenerationError("daily_limit_exceeded", 429);
    },
    fail: async () => {
      failures++;
    },
  });
  check(
    (await createGenerateQuizHandler(setup.deps)(request())).status === 429,
    "status",
  );
  check(setup.posts() === 0, "no POST");
  check(failures === 0, "reservation remains authoritative");
});
