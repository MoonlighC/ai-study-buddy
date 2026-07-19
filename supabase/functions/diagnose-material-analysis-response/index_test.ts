import {
  createDiagnosticHandler,
  DiagnosticRpcClient,
  runPreservedFinalResponseDiagnostic,
} from "./index.ts";

const callerSelectedId = crypto.randomUUID();
const namedKey = `fixture_named_${crypto.randomUUID()}`;
const oldNamedKey = `fixture_legacy_named_${crypto.randomUUID()}`;
const otherNamedKey = `fixture_other_named_${crypto.randomUUID()}`;
const defaultKey = `fixture_default_${crypto.randomUUID()}`;
const publishableKey = `fixture_publishable_${crypto.randomUUID()}`;
const authEnvironment = {
  url: "https://fixture.supabase.co",
  secretKeys: {
    default: defaultKey,
    material_analysis_diagnostic_staging: namedKey,
    "material-analysis-diagnostic-staging": oldNamedKey,
    other_named_key: otherNamedKey,
  },
  publishableKeys: { default: publishableKey },
};

Deno.test("diagnostic authorization accepts only the exact named apikey", async () => {
  let executions = 0;
  const handler = createDiagnosticHandler({
    authEnvironment,
    execute: () => {
      executions++;
      return Promise.resolve(recordedExecution());
    },
    logger: () => {},
  });
  const rejected: Array<HeadersInit | undefined> = [
    undefined,
    { apikey: "fixture_wrong" },
    { apikey: oldNamedKey },
    { apikey: otherNamedKey },
    { apikey: defaultKey },
    { apikey: publishableKey },
    { Authorization: "Bearer fixture.legacy.jwt" },
    { Authorization: namedKey },
    { authorization: `Basic ${namedKey}` },
    { apikey: namedKey, Authorization: "Bearer fixture" },
  ];
  for (const headers of rejected) {
    const response = await handler(request({ headers }));
    equal(response.status, 401);
    rejectsSensitiveResponse(await response.text());
  }
  equal(executions, 0);

  const accepted = await handler(request({ apikey: namedKey }));
  equal(accepted.status, 200);
  equal(await accepted.json(), { diagnostic_recorded: true });
  equal(executions, 1);
  equal(accepted.headers.get("Access-Control-Allow-Origin"), null);
  equal(accepted.headers.get("Access-Control-Allow-Headers"), null);
});

Deno.test("diagnostic request contract is POST application/json with exactly empty object", async () => {
  let executions = 0;
  const handler = createDiagnosticHandler({
    authEnvironment,
    execute: () => {
      executions++;
      return Promise.resolve(recordedExecution());
    },
    logger: () => {},
  });
  const get = await handler(
    new Request("https://fixture.invalid", {
      method: "GET",
      headers: { apikey: namedKey },
    }),
  );
  equal(get.status, 405);
  const invalidBodies: unknown[] = [
    [],
    null,
    { batch_id: callerSelectedId },
    { response_id: "provider_identifier" },
    { material_id: callerSelectedId },
    { user_id: callerSelectedId },
    { correlation_id: callerSelectedId },
    { fingerprint: "a".repeat(64) },
    { fixture: "controlled" },
    { operation: "diagnose" },
    { sql: "select 1" },
  ];
  for (const body of invalidBodies) {
    const response = await handler(request({ apikey: namedKey, body }));
    equal(response.status, 400);
  }
  const wrongContentType = await handler(request({
    apikey: namedKey,
    contentType: "text/plain",
  }));
  equal(wrongContentType.status, 400);
  const emptyBody = await handler(
    new Request("https://fixture.invalid", {
      method: "POST",
      headers: { apikey: namedKey, "Content-Type": "application/json" },
      body: "",
    }),
  );
  equal(emptyBody.status, 400);
  const oversized = await handler(
    new Request("https://fixture.invalid", {
      method: "POST",
      headers: { apikey: namedKey, "Content-Type": "application/json" },
      body: JSON.stringify({ padding: "x".repeat(1024) }),
    }),
  );
  equal(oversized.status, 400);
  equal(executions, 0);

  const accepted = await handler(request({ apikey: namedKey, body: {} }));
  equal(accepted.status, 200);
  equal(executions, 1);
});

Deno.test("runtime performs one persisted-response GET and two service-only RPCs", async () => {
  const state = immutableState();
  const before = structuredClone(state.protected);
  const admin = fakeAdmin(state);
  const providerCalls: Array<{ method: string; url: string }> = [];
  const result = await runPreservedFinalResponseDiagnostic(admin, {
    openAiKey: "fixture-provider-key",
    model: "fixture-model",
    fetcher: (input, init) => {
      providerCalls.push({
        method: (init?.method ?? "GET").toUpperCase(),
        url: String(input),
      });
      return Promise.resolve(
        new Response(
          JSON.stringify({
            status: "failed",
            error: null,
            incomplete_details: null,
            output: [],
            ignored_private_content: "private provider content",
          }),
          { status: 200, headers: { "Content-Type": "application/json" } },
        ),
      );
    },
  });
  equal(providerCalls.length, 1);
  equal(providerCalls[0].method, "GET");
  equal(providerCalls[0].url.includes(state.persistedResponseIdentity), true);
  equal(admin.calls.map((call) => call.name), [
    "select_material_analysis_diagnostic_target_internal",
    "record_correlated_material_analysis_diagnostic_internal",
  ]);
  equal(admin.calls[0].args, {});
  equal(result.getCount, 1);
  equal(result.diagnosticCode, "response_status_not_completed");
  equal(JSON.stringify(result).includes("private provider content"), false);
  equal(state.protected, before);
  equal(Object.hasOwn(state.recorded ?? {}, "p_batch_id"), false);
  equal(state.recorded?.p_diagnostic_code, "response_status_not_completed");
  equal(state.recorded?.p_diagnostic_version, 1);
  equal(
    JSON.stringify(state.recorded).includes(state.persistedResponseIdentity),
    false,
  );
});

for (const targetCount of [0, 2]) {
  Deno.test(`${targetCount} authoritative targets fail closed before provider access`, async () => {
    const calls: string[] = [];
    const admin: DiagnosticRpcClient = {
      rpc(name) {
        calls.push(name);
        return Promise.resolve({
          data: targetCount === 0 ? [] : [eligibleTarget(), eligibleTarget()],
          error: null,
        });
      },
    };
    let providerCalls = 0;
    await rejects(() =>
      runPreservedFinalResponseDiagnostic(admin, {
        openAiKey: "fixture-provider-key",
        fetcher: () => {
          providerCalls++;
          return Promise.reject(new Error("must_not_run"));
        },
      })
    );
    equal(calls, ["select_material_analysis_diagnostic_target_internal"]);
    equal(providerCalls, 0);
  });
}

Deno.test("one malformed or weakened target stops before provider access", async () => {
  const weakened = {
    ...eligibleTarget(),
    page_count: 2,
    page_numbers: [1, 2],
    cleanup_state: "completed",
  };
  let providerCalls = 0;
  await rejects(() =>
    runPreservedFinalResponseDiagnostic({
      rpc: () => Promise.resolve({ data: weakened, error: null }),
    }, {
      openAiKey: "fixture-provider-key",
      fetcher: () => {
        providerCalls++;
        return Promise.reject(new Error("must_not_run"));
      },
    })
  );
  equal(providerCalls, 0);
});

Deno.test("exactly one authoritative target proceeds and cannot cause a retry", async () => {
  const state = immutableState();
  const admin = fakeAdmin(state);
  let getCount = 0;
  await runPreservedFinalResponseDiagnostic(admin, {
    openAiKey: "fixture-provider-key",
    fetcher: () => {
      getCount++;
      return Promise.resolve(new Response("not-json", { status: 503 }));
    },
  });
  equal(getCount, 1);
  equal(
    admin.calls.filter((call) =>
      call.name === "record_correlated_material_analysis_diagnostic_internal"
    ).length,
    1,
  );
});

Deno.test("selector unavailable is returned without identifiers or content", async () => {
  const handler = createDiagnosticHandler({
    authEnvironment,
    execute: () =>
      runPreservedFinalResponseDiagnostic({
        rpc: () =>
          Promise.resolve({
            data: null,
            error: { message: "diagnostic_target_unavailable" },
          }),
      }, { openAiKey: "fixture-provider-key" }),
    logger: () => {},
  });
  const response = await handler(request({ apikey: namedKey }));
  equal(response.status, 409);
  equal(await response.json(), { error: "diagnostic_target_unavailable" });
});

Deno.test("unknown failures stay generic and provider content is never returned or logged", async () => {
  const privateDetail = "private provider body";
  const logs: unknown[] = [];
  const handler = createDiagnosticHandler({
    authEnvironment,
    execute: () => Promise.reject(new Error(privateDetail)),
    logger: (entry) => logs.push(entry),
    now: sequentialClock(50, 55),
  });
  const response = await handler(request({ apikey: namedKey }));
  equal(response.status, 500);
  equal((await response.text()).includes(privateDetail), false);
  equal(JSON.stringify(logs).includes(privateDetail), false);
  equal(logs, [{
    operation: "final_response_diagnostic",
    outcome: "failed",
    diagnostic_code: "final_validation_unknown",
    elapsed_milliseconds: 5,
    get_count: 0,
  }]);
});

Deno.test("diagnostic recording boundary is idempotently compatible", async () => {
  const state = immutableState();
  const admin = fakeAdmin(state);
  const first = {
    p_diagnostic_code: "response_status_not_completed",
    p_diagnostic_metadata: { response_status: "failed" },
    p_diagnostic_version: 1,
  };
  await admin.rpc(
    "record_correlated_material_analysis_diagnostic_internal",
    first,
  );
  const snapshot = structuredClone(state.recorded);
  await admin.rpc(
    "record_correlated_material_analysis_diagnostic_internal",
    first,
  );
  equal(state.recorded, snapshot);
  equal(state.protected.attempt_count, 1);
  equal(state.protected.budget_state, "released");
  equal(state.protected.batch_status, "failed");
});

function request(options: {
  apikey?: string;
  headers?: HeadersInit;
  body?: unknown;
  contentType?: string;
} = {}) {
  const headers = new Headers(options.headers);
  if (options.apikey) headers.set("apikey", options.apikey);
  headers.set("Content-Type", options.contentType ?? "application/json");
  return new Request("https://fixture.invalid", {
    method: "POST",
    headers,
    body: JSON.stringify(
      Object.hasOwn(options, "body") ? options.body : {},
    ),
  });
}

function recordedExecution() {
  return {
    diagnosticCode: "response_status_not_completed" as const,
    diagnosticMetadata: {
      response_status: "failed" as const,
      validator_stage: "validateResponseEnvelope" as const,
    },
    getCount: 1 as const,
  };
}

function immutableState() {
  return {
    persistedResponseIdentity: "resp_fixture_persisted_1234",
    protected: {
      batch_status: "failed",
      failure_code: "non_retryable",
      attempt_count: 1,
      budget_state: "released",
      job_budget_state: "released",
      public_status: "failed",
      summary_payload: null,
      cleanup_state: "not_required",
      page_status: "completed",
    },
    recorded: null as Record<string, unknown> | null,
  };
}

function eligibleTarget(responseId = "resp_fixture_persisted_1234") {
  return {
    operation: "final_summary",
    status: "failed",
    response_id: responseId,
    page_numbers: [1],
    page_count: 1,
    cleanup_state: "not_required",
  };
}

function fakeAdmin(state: ReturnType<typeof immutableState>) {
  const calls: Array<{ name: string; args: Record<string, unknown> }> = [];
  return {
    calls,
    rpc(name: string, args: Record<string, unknown>) {
      calls.push({ name, args: structuredClone(args) });
      if (name === "select_material_analysis_diagnostic_target_internal") {
        return Promise.resolve({
          data: eligibleTarget(state.persistedResponseIdentity),
          error: null,
        });
      }
      if (name === "record_correlated_material_analysis_diagnostic_internal") {
        if (
          state.recorded &&
          JSON.stringify(state.recorded) !== JSON.stringify(args)
        ) {
          return Promise.resolve({ data: null, error: { safe: true } });
        }
        state.recorded = structuredClone(args);
        return Promise.resolve({ data: null, error: null });
      }
      return Promise.resolve({ data: null, error: { unexpected: true } });
    },
  };
}

function sequentialClock(...values: number[]) {
  let index = 0;
  return () => values[Math.min(index++, values.length - 1)];
}

function rejectsSensitiveResponse(value: string) {
  equal(value.includes("material_analysis_diagnostic_staging"), false);
  equal(value.includes("fixture_named"), false);
}

async function rejects(callback: () => Promise<unknown>) {
  try {
    await callback();
  } catch (_) {
    return;
  }
  throw new Error("expected rejection");
}

function equal(actual: unknown, expected: unknown, label = "values") {
  if (JSON.stringify(actual) !== JSON.stringify(expected)) {
    throw new Error(
      `${label} differ: ${JSON.stringify(actual)} != ${
        JSON.stringify(expected)
      }`,
    );
  }
}
