import {
  executeStudyGeneration,
  reconcileStudyGeneration,
  StudyGenerationProviderResponse,
  StudyGenerationReconciliationDependencies,
} from "./study_generation_reconciliation.ts";

for (const feature of ["flashcards", "quiz"] as const) {
  Deno.test(
    `${feature}: crash after response identity resumes with one GET and zero POST`,
    async () => {
      const fixture = reconciliationFixture({ crashed: true });
      const result = await reconcileStudyGeneration(fixture.deps);
      check(result === "result-1", "recovered result");
      check(fixture.posts() === 0, "zero POST");
      check(fixture.gets() === 1, "one GET");
      check(fixture.persists() === 1, "persisted once");
    },
  );

  Deno.test(
    `${feature}: accepted operation uses one POST and completed replay uses zero POST`,
    async () => {
      const fixture = reconciliationFixture();
      const first = await executeStudyGeneration(fixture.deps);
      const replay = await reconcileStudyGeneration(fixture.deps);
      check(first === replay, "exact replay");
      check(fixture.posts() === 1, "one POST");
      check(fixture.gets() === 0, "no GET needed for completed POST envelope");
      check(fixture.persists() === 1, "persisted once");
    },
  );
}

Deno.test("concurrent reconcilers acquire one persistence lease", async () => {
  const fixture = reconciliationFixture({ crashed: true });
  const [first, second] = await Promise.all([
    reconcileStudyGeneration(fixture.deps),
    reconcileStudyGeneration(fixture.deps),
  ]);
  check(first === "result-1" && second === "result-1", "same replay");
  check(fixture.persists() === 1, "one persistence");
  check(fixture.gets() === 1, "one retrieval");
});

Deno.test("provider terminal failure is accounted once", async () => {
  const fixture = reconciliationFixture({
    crashed: true,
    providerStatus: "failed",
  });
  let failed = false;
  try {
    await reconcileStudyGeneration(fixture.deps);
  } catch (_) {
    failed = true;
  }
  check(failed, "terminal failure");
  check(fixture.failures() === 1, "accounted once");
  check(fixture.posts() === 0, "zero POST");
});

Deno.test("submission failure before identity requires a new operation", async () => {
  const fixture = reconciliationFixture({ submitFailure: true });
  let failed = false;
  try {
    await executeStudyGeneration(fixture.deps);
  } catch (_) {
    failed = true;
  }
  check(failed, "failed");
  check(fixture.posts() === 1, "one attempted POST");
  check(fixture.failures() === 1, "one terminal accounting");
  check(fixture.gets() === 0, "no identity means no GET");
});

function reconciliationFixture(options: {
  crashed?: boolean;
  providerStatus?: "completed" | "failed";
  submitFailure?: boolean;
} = {}) {
  const response: StudyGenerationProviderResponse = {
    identity: "resp_fixture_1",
    status: options.providerStatus ?? "completed",
    envelope: { safe: true },
  };
  let state:
    | "reserved"
    | "reconciliation_required"
    | "persisting"
    | "succeeded"
    | "failed" = options.crashed ? "reconciliation_required" : "reserved";
  let activeToken: string | null = null;
  let postCount = 0;
  let getCount = 0;
  let persistCount = 0;
  let failureCount = 0;
  let tokenCounter = 0;

  const deps: StudyGenerationReconciliationDependencies<string> = {
    async claimProvider() {
      if (state !== "reserved") return false;
      return true;
    },
    async submitProvider() {
      postCount++;
      if (options.submitFailure) throw new Error("network_failed");
      return response;
    },
    async recordProviderResponse() {
      state = "reconciliation_required";
    },
    async claimReconciliation(token) {
      if (state === "succeeded") {
        return { kind: "completed", resultIds: ["result-1"] };
      }
      if (state === "failed") {
        return { kind: "failed", safeCode: "provider_terminal_failed" };
      }
      if (
        state === "reconciliation_required" ||
        state === "persisting" && activeToken === null
      ) {
        state = "persisting";
        activeToken = token;
        return {
          kind: "claimed",
          token,
          responseIdentity: response.identity,
        };
      }
      return { kind: "active", status: "reconciling" };
    },
    async retrieveProvider() {
      getCount++;
      return response;
    },
    async updateProviderStatus(token) {
      check(activeToken === token, "lease");
    },
    async persist(_provider, token) {
      check(activeToken === token, "lease");
      await Promise.resolve();
      persistCount++;
      state = "succeeded";
      activeToken = null;
      return "result-1";
    },
    async replay(ids) {
      check(ids.length === 1 && ids[0] === "result-1", "result ids");
      return "result-1";
    },
    async fail() {
      if (state === "failed") return;
      failureCount++;
      state = "failed";
      activeToken = null;
    },
    createToken() {
      tokenCounter++;
      return `00000000-0000-4000-8000-${
        tokenCounter.toString().padStart(12, "0")
      }`;
    },
    async wait() {
      await Promise.resolve();
    },
  };
  return {
    deps,
    posts: () => postCount,
    gets: () => getCount,
    persists: () => persistCount,
    failures: () => failureCount,
  };
}

function check(value: unknown, message: string) {
  if (!value) throw new Error(message);
}
