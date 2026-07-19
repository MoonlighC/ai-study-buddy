import {
  createDiagnosticHandler,
  DiagnosticRpcClient,
  runPreservedFinalResponseDiagnostic,
} from "./index.ts";

const batchId = crypto.randomUUID();
const namedKey = `fixture_named_${crypto.randomUUID()}`;
const defaultKey = `fixture_default_${crypto.randomUUID()}`;
const publishableKey = `fixture_publishable_${crypto.randomUUID()}`;
const authEnvironment = {
  url: "https://fixture.supabase.co",
  secretKeys: {
    default: defaultKey,
    "material-analysis-diagnostic-staging": namedKey,
  },
  publishableKeys: { default: publishableKey },
};

Deno.test("diagnostic authorization matrix rejects every untrusted credential shape", async () => {
  const executeCalls: string[] = [];
  const handler = createDiagnosticHandler({
    authEnvironment,
    execute: (_admin, id) => {
      executeCalls.push(id);
      return Promise.resolve(recordedExecution());
    },
    logger: () => {},
  });
  const cases: Array<{ name: string; headers?: HeadersInit }> = [
    { name: "no apikey" },
    { name: "wrong named secret", headers: { apikey: "fixture_wrong" } },
    { name: "default secret", headers: { apikey: defaultKey } },
    { name: "publishable key", headers: { apikey: publishableKey } },
    {
      name: "legacy service role in Authorization",
      headers: { Authorization: "Bearer fixture.legacy.jwt" },
    },
    {
      name: "named key in Authorization",
      headers: { Authorization: `Bearer ${namedKey}` },
    },
    {
      name: "valid apikey plus Authorization",
      headers: { apikey: namedKey, Authorization: "Bearer fixture" },
    },
  ];
  for (const fixture of cases) {
    const response = await handler(request({ headers: fixture.headers }));
    equal(response.status, 401, fixture.name);
    const body = await response.text();
    rejectsSensitiveResponse(body);
  }
  equal(executeCalls.length, 0);
});

Deno.test("valid named apikey reaches the handler without CORS or diagnostic data", async () => {
  const executeCalls: string[] = [];
  const logs: unknown[] = [];
  const handler = createDiagnosticHandler({
    authEnvironment,
    execute: (_admin, id) => {
      executeCalls.push(id);
      return Promise.resolve(recordedExecution());
    },
    logger: (entry) => logs.push(entry),
    now: sequentialClock(10, 17),
  });
  const response = await handler(request({ apikey: namedKey }));
  equal(response.status, 200);
  equal(await response.json(), { diagnostic_recorded: true });
  equal(response.headers.get("Access-Control-Allow-Origin"), null);
  equal(response.headers.get("Access-Control-Allow-Headers"), null);
  equal(executeCalls, [batchId]);
  equal(logs, [{
    operation: "final_response_diagnostic",
    outcome: "recorded",
    diagnostic_code: "response_status_not_completed",
    elapsed_milliseconds: 7,
    get_count: 1,
  }]);
});

Deno.test("valid named apikey still requires POST and application/json", async () => {
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
  const wrongContentType = await handler(request({
    apikey: namedKey,
    contentType: "text/plain",
  }));
  equal(wrongContentType.status, 400);
  equal(executions, 0);
});

Deno.test("closed request decoder rejects malformed, additional, and oversized bodies", async () => {
  let executions = 0;
  const handler = createDiagnosticHandler({
    authEnvironment,
    execute: () => {
      executions++;
      return Promise.resolve(recordedExecution());
    },
    logger: () => {},
  });
  const invalidBodies: unknown[] = [
    {},
    [],
    { batch_id: "not-a-uuid" },
    { batch_id: batchId, operation: "final_summary" },
    { user_id: batchId },
    { response_id: "provider_identifier" },
  ];
  for (const body of invalidBodies) {
    const response = await handler(request({ apikey: namedKey, body }));
    equal(response.status, 400);
  }
  const oversized = await handler(
    new Request("https://fixture.invalid", {
      method: "POST",
      headers: {
        apikey: namedKey,
        "Content-Type": "application/json",
      },
      body: JSON.stringify({ batch_id: batchId, padding: "x".repeat(1024) }),
    }),
  );
  equal(oversized.status, 400);
  equal(executions, 0);
});

Deno.test("runtime performs one persisted-response GET and only two diagnostic RPCs", async () => {
  const state = immutableState();
  const before = structuredClone(state);
  const admin = fakeAdmin(state);
  const providerCalls: Array<{ method: string; url: string }> = [];
  const result = await runPreservedFinalResponseDiagnostic(
    admin,
    batchId,
    {
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
    },
  );
  equal(providerCalls.length, 1);
  equal(providerCalls[0].method, "GET");
  equal(providerCalls[0].url.includes(state.persistedResponseIdentity), true);
  equal(admin.calls.map((call) => call.name), [
    "load_material_analysis_diagnostic_target_internal",
    "record_material_analysis_diagnostic_internal",
  ]);
  equal(result.getCount, 1);
  equal(result.diagnosticCode, "response_status_not_completed");
  equal(
    JSON.stringify(result.diagnosticMetadata).includes(
      "private provider content",
    ),
    false,
  );
  equal(state.protected, before.protected);
  equal(state.recorded?.p_batch_id, batchId);
  equal(state.recorded?.p_diagnostic_code, "response_status_not_completed");
  equal(state.recorded?.p_diagnostic_version, 1);
  equal(
    JSON.stringify(state.recorded).includes(state.persistedResponseIdentity),
    false,
  );
});

for (const ineligible of ["completed", "text", "page", "reduction"]) {
  Deno.test(`RPC-rejected ${ineligible} target causes no provider request or write`, async () => {
    const calls: string[] = [];
    const admin: DiagnosticRpcClient = {
      rpc(name) {
        calls.push(name);
        return Promise.resolve({ data: null, error: { safe: true } });
      },
    };
    let providerCalls = 0;
    await rejects(() =>
      runPreservedFinalResponseDiagnostic(admin, batchId, {
        openAiKey: "fixture-provider-key",
        model: "fixture-model",
        fetcher: () => {
          providerCalls++;
          return Promise.reject(new Error("must_not_run"));
        },
      })
    );
    equal(calls, ["load_material_analysis_diagnostic_target_internal"]);
    equal(providerCalls, 0);
  });
}

Deno.test("unknown failures stay generic and content-free", async () => {
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
  const body = await response.text();
  equal(body.includes(privateDetail), false);
  equal(JSON.stringify(logs).includes(privateDetail), false);
  equal(logs, [{
    operation: "final_response_diagnostic",
    outcome: "failed",
    diagnostic_code: "final_validation_unknown",
    elapsed_milliseconds: 5,
    get_count: 0,
  }]);
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
    body: JSON.stringify(options.body ?? { batch_id: batchId }),
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
      idempotency_key: "fixture-idempotency",
      budget_state: "released",
      lease_token: null,
      job_status: "failed",
      summary_payload: null,
      cleanup_state: "not_required",
      page_status: "completed",
    },
    recorded: null as Record<string, unknown> | null,
  };
}

function fakeAdmin(state: ReturnType<typeof immutableState>) {
  const calls: Array<{ name: string; args: Record<string, unknown> }> = [];
  return {
    calls,
    rpc(name: string, args: Record<string, unknown>) {
      calls.push({ name, args: structuredClone(args) });
      if (name === "load_material_analysis_diagnostic_target_internal") {
        return Promise.resolve({
          data: {
            batch_id: batchId,
            operation: "final_summary",
            status: "failed",
            response_id: state.persistedResponseIdentity,
            page_numbers: [1],
            page_count: 1,
            cleanup_state: state.protected.cleanup_state,
          },
          error: null,
        });
      }
      if (name === "record_material_analysis_diagnostic_internal") {
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
  equal(value.includes("material-analysis-diagnostic-staging"), false);
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
