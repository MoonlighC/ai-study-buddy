import {
  createLatexDiagnosticHandler,
  retrieveLatexDiagnostic,
} from "./handler.ts";

Deno.test("preserved response diagnostic performs one GET and zero POST", async () => {
  const methods: string[] = [];
  const result = await retrieveLatexDiagnostic({
    responseId: "resp_12345678",
    openAiKey: "test-key",
    fetcher: ((_: string | URL | Request, init?: RequestInit) => {
      methods.push(init?.method ?? "GET");
      return Promise.resolve(responseEnvelope(String.raw`\operatorname{}`));
    }) as typeof fetch,
  });
  equal(methods, ["GET"]);
  equal(result.validator_rule_code, "latex_command_unsupported");
  equal(result.offending_syntax, "operatorname");
  equal(JSON.stringify(result).includes("\\operatorname"), false);
});

Deno.test("operator rejects Authorization body and wrong apikey before claim", async () => {
  const fake = fakeDatabase();
  const handler = createLatexDiagnosticHandler({
    operatorKey: "k".repeat(48),
    openAiKey: "test-key",
    database: fake.database,
  });
  equal(
    (await handler(
      new Request("https://local", {
        method: "POST",
        headers: { authorization: "Bearer anything", apikey: "k".repeat(48) },
      }),
    )).status,
    401,
  );
  equal(
    (await handler(
      new Request("https://local", {
        method: "POST",
        headers: { apikey: "wrong".repeat(10) },
      }),
    )).status,
    401,
  );
  equal(fake.calls.length, 0);
});

Deno.test("one-shot repeat is rejected before a second provider GET", async () => {
  const fake = fakeDatabase();
  let gets = 0;
  const handler = createLatexDiagnosticHandler({
    operatorKey: "k".repeat(48),
    openAiKey: "test-key",
    database: fake.database,
    fetcher: ((_: string | URL | Request, init?: RequestInit) => {
      if (init?.method === "GET") gets++;
      return Promise.resolve(responseEnvelope(String.raw`\operatorname{}`));
    }) as typeof fetch,
  });
  const request = () =>
    new Request("https://local", {
      method: "POST",
      headers: { apikey: "k".repeat(48) },
    });
  equal((await handler(request())).status, 200);
  equal((await handler(request())).status, 500);
  equal(gets, 1);
  equal(fake.records.length, 1);
});

function responseEnvelope(latex: string) {
  return new Response(
    JSON.stringify({
      status: "completed",
      output: [{
        content: [{
          type: "output_text",
          text: JSON.stringify({
            equations: [{ latex }],
          }),
        }],
      }],
    }),
    { status: 200, headers: { "content-type": "application/json" } },
  );
}

function fakeDatabase() {
  let claimed = false;
  const calls: string[] = [];
  const records: unknown[] = [];
  return {
    calls,
    records,
    database: {
      rpc(name: string, args?: Record<string, unknown>) {
        calls.push(name);
        if (name === "claim_material_analysis_latex_diagnostic_internal") {
          if (claimed) {
            return Promise.resolve({
              data: null,
              error: { message: "claimed" },
            });
          }
          claimed = true;
          return Promise.resolve({
            data: { response_id: "resp_12345678", page_count: 1 },
            error: null,
          });
        }
        if (name === "record_material_analysis_latex_diagnostic_internal") {
          records.push(args?.p_metadata);
          return Promise.resolve({ data: null, error: null });
        }
        return Promise.resolve({ data: null, error: { message: "unknown" } });
      },
    },
  };
}

function equal(actual: unknown, expected: unknown) {
  if (JSON.stringify(actual) !== JSON.stringify(expected)) {
    throw new Error(
      `Expected ${JSON.stringify(expected)}, got ${JSON.stringify(actual)}`,
    );
  }
}
