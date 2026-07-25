import { SafeAnalysisError } from "./engine.ts";
import {
  requireOwnedMaterial,
  rpcStatusWithV1Fallback,
} from "./edge_runtime.ts";

Deno.test("owned material lookup returns only an exact owned row", () => {
  const row = { id: crypto.randomUUID() };
  equal(requireOwnedMaterial(row, null), row);
});

Deno.test("cross-user and absent lookup share the typed unavailable contract", () => {
  const crossUser = captured(() => requireOwnedMaterial(null, null));
  const nonexistent = captured(() => requireOwnedMaterial(undefined, null));
  equal(crossUser instanceof SafeAnalysisError, true);
  equal(nonexistent instanceof SafeAnalysisError, true);
  equal(crossUser.message, nonexistent.message);
  equal((crossUser as SafeAnalysisError).code, "material_unavailable");
  equal((crossUser as SafeAnalysisError).status, 404);
});

Deno.test("lookup and network failures are not mapped to not found", () => {
  for (
    const detail of [
      { code: "42501", message: "private SQL detail" },
      new TypeError("private network detail"),
    ]
  ) {
    const error = captured(() => requireOwnedMaterial(null, detail));
    equal(error instanceof SafeAnalysisError, false);
    equal(error.message, "owned_material_lookup_failed");
    equal(error.message.includes("private"), false);
  }
});

Deno.test("status RPC uses v2 without touching v1", async () => {
  const calls: string[] = [];
  const result = await rpcStatusWithV1Fallback({
    rpc(name) {
      calls.push(name);
      return Promise.resolve({ data: [statusV2()], error: null });
    },
  }, crypto.randomUUID());
  equal((result as Record<string, unknown>).can_analyze_again, true);
  equal(calls, ["get_material_analysis_status_v2"]);
});

Deno.test("status RPC falls back only when v2 is exactly missing", async () => {
  const calls: string[] = [];
  const result = await rpcStatusWithV1Fallback({
    rpc(name) {
      calls.push(name);
      return Promise.resolve(name.endsWith("_v2")
        ? {
          data: null,
          error: {
            code: "PGRST202",
            message:
              "Could not find public.get_material_analysis_status_v2 in the schema cache",
          },
        }
        : { data: [statusV1()], error: null });
    },
  }, crypto.randomUUID());
  equal((result as Record<string, unknown>).can_analyze_again, false);
  equal(calls, [
    "get_material_analysis_status_v2",
    "get_material_analysis_status",
  ]);
});

Deno.test("status RPC never falls back for another database error", async () => {
  const calls: string[] = [];
  const error = await captureAsync(() =>
    rpcStatusWithV1Fallback({
      rpc(name) {
        calls.push(name);
        return Promise.resolve({
          data: null,
          error: { code: "42501", message: "denied" },
        });
      },
    }, crypto.randomUUID())
  );
  equal(error.message, "trusted_rpc_failed");
  equal(calls, ["get_material_analysis_status_v2"]);
});

function statusV2() {
  return { ...statusV1(), can_analyze_again: true };
}

function statusV1() {
  return {
    material_id: crypto.randomUUID(),
    processing_mode: "recommended",
    state: "failed",
    public_stage: "creating_summary",
    page_count: 1,
    completed_pages: 0,
    confirmation_required: false,
    can_retry: false,
    retry_after_seconds: null,
    warnings: [],
    summary_schema_version: null,
    summary_payload: null,
    safe_error_code: "structured_output_invalid",
    active_operation: null,
  };
}

function captured(action: () => unknown): Error {
  try {
    action();
  } catch (error) {
    if (error instanceof Error) return error;
  }
  throw new Error("Expected action to throw");
}

async function captureAsync(action: () => Promise<unknown>) {
  try {
    await action();
  } catch (error) {
    if (error instanceof Error) return error;
  }
  throw new Error("Expected action to throw");
}

function equal(actual: unknown, expected: unknown) {
  if (JSON.stringify(actual) === JSON.stringify(expected)) return;
  throw new Error(
    `Expected ${JSON.stringify(expected)}, got ${JSON.stringify(actual)}`,
  );
}
