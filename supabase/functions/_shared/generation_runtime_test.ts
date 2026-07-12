import {
  generationLog,
  providerSafeCode,
  resolveProjectKeys,
  SafeConfigurationError,
  safeDatabaseFailure,
} from "./generation_runtime.ts";

Deno.test("project keys prefer hosted dictionaries and retain legacy fallback", () => {
  const serviceJwt = jwt({ role: "service_role" });
  const hosted = resolveProjectKeys((name) =>
    ({
      SUPABASE_PUBLISHABLE_KEYS: '{"default":"publishable"}',
      SUPABASE_SECRET_KEYS: '{"default":"sb_secret_hosted"}',
      SUPABASE_ANON_KEY: "legacy-public",
      SUPABASE_SERVICE_ROLE_KEY: "legacy-secret",
    })[name]
  );
  assertEquals(hosted, {
    publicKey: "publishable",
    trustedKey: "sb_secret_hosted",
    trustedSource: "secret_keys_default",
  });
  const legacy = resolveProjectKeys((name) =>
    ({ SUPABASE_ANON_KEY: "anon", SUPABASE_SERVICE_ROLE_KEY: serviceJwt })[name]
  );
  assertEquals(legacy, {
    publicKey: "anon",
    trustedKey: serviceJwt,
    trustedSource: "legacy_service_role",
  });
});

Deno.test("database diagnostics retain only bounded PostgREST code and status", () => {
  assertEquals(
    safeDatabaseFailure({
      code: "42501",
      message: "permission denied for table flashcards",
      details: "secret",
    }),
    { code: "42501", status: 403 },
  );
  assertEquals(
    safeDatabaseFailure({ code: "unsafe code with spaces", message: "raw" }),
    { code: "database_write_failed" },
  );
});

Deno.test("missing or malformed key dictionaries fail safely", () => {
  for (
    const values of [{}, { SUPABASE_PUBLISHABLE_KEYS: "{" }, {
      SUPABASE_PUBLISHABLE_KEYS: "{}",
    }, {
      SUPABASE_ANON_KEY: "anon",
      SUPABASE_SERVICE_ROLE_KEY: jwt({ role: "authenticated" }),
    }]
  ) {
    let error: unknown;
    try {
      resolveProjectKeys((name) => (values as Record<string, string>)[name]);
    } catch (caught) {
      error = caught;
    }
    if (!(error instanceof SafeConfigurationError)) {
      throw new Error("expected safe configuration error");
    }
  }
});

function jwt(payload: Record<string, unknown>) {
  return `header.${
    btoa(JSON.stringify(payload)).replaceAll("=", "")
  }.signature`;
}

Deno.test("provider statuses map to stable safe codes", () => {
  assertEquals([401, 403, 429, 400, 500].map(providerSafeCode), [
    "openai_auth_failed",
    "openai_access_denied",
    "openai_rate_or_quota",
    "openai_request_invalid",
    "openai_unavailable",
  ]);
});

Deno.test("generation logs discard identifiers, content, paths, tokens, and keys", () => {
  let line = "";
  generationLog("generate-summary", "known_failure", {
    code: "openai_auth_failed",
    status: 401,
    user_id: "user-1",
    material_id: "material-1",
    content: "secret text",
    path: "user/file",
    token: "jwt",
    key: "secret",
  }, (value) => line = value);
  if (
    line.includes("user-1") || line.includes("material-1") ||
    line.includes("secret text") || line.includes("user/file") ||
    line.includes("jwt") || line.includes('"key"')
  ) throw new Error(`unsafe log: ${line}`);
});

function assertEquals(actual: unknown, expected: unknown) {
  if (JSON.stringify(actual) !== JSON.stringify(expected)) {
    throw new Error(
      `Expected ${JSON.stringify(expected)}, got ${JSON.stringify(actual)}`,
    );
  }
}
