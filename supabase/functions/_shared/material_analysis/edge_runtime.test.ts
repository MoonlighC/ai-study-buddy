import { SafeAnalysisError } from "./engine.ts";
import { requireOwnedMaterial } from "./edge_runtime.ts";

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

function captured(action: () => unknown): Error {
  try {
    action();
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
