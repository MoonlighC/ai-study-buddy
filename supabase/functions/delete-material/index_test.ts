import { assertEquals } from "https://deno.land/std@0.224.0/assert/mod.ts";
import { createDeleteMaterialHandler, DeleteDependencies } from "./handler.ts";

function deps(overrides: Partial<DeleteDependencies> = {}) {
  const base: DeleteDependencies = {
    verifyJwt: async () => "user",
    begin: async () => ({ outcome: "pending", material_kind: "pdf", source_kind: "upload", storage_bucket: "study-materials", storage_path: "user/123e4567-e89b-42d3-a456-426614174000/file.pdf", cleanup_status: "pending_storage" }),
    remove: async () => ({ error: false }), mark: async () => true, finalize: async () => true,
    operationId: () => "operation", log: () => {},
  };
  return { ...base, ...overrides };
}
const id = "123e4567-e89b-42d3-a456-426614174000";
function request(body: unknown, auth = true) { return new Request("http://local", { method: "POST", headers: { ...(auth ? { Authorization: "Bearer jwt" } : {}), "Content-Type": "application/json" }, body: JSON.stringify(body) }); }

Deno.test("deletes exact trusted upload and finalizes", async () => {
  const calls: string[] = [];
  let removed = ""; const handler = createDeleteMaterialHandler(deps({
    verifyJwt: async () => { calls.push("verified"); return "user"; },
    begin: async (userId) => { calls.push(`begin:${userId}`); return { outcome: "pending", material_kind: "pdf", source_kind: "upload", storage_bucket: "study-materials", storage_path: `user/${id}/file.pdf`, cleanup_status: "pending_storage" }; },
    remove: async (bucket, path) => { calls.push("removed"); removed = `${bucket}:${path}`; return { error: false }; },
    mark: async (userId, _, outcome) => { calls.push(`mark:${userId}:${outcome}`); return true; },
    finalize: async (userId) => { calls.push(`finalize:${userId}`); return true; },
  }));
  const response = await handler(request({ material_id: id }));
  assertEquals(response.status, 200); assertEquals(removed, `study-materials:user/${id}/file.pdf`);
  assertEquals(calls, ["verified", "begin:user", "removed", "mark:user:removed", "finalize:user"]);
});
Deno.test("not found is non-enumerating idempotent success", async () => {
  const response = await createDeleteMaterialHandler(deps({ begin: async () => ({ outcome: "not_found" }) }))(request({ material_id: id }));
  assertEquals(response.status, 200); assertEquals(await response.json(), { ok: true, idempotent: true });
});
Deno.test("storage failure is recorded and not finalized", async () => {
  let marked = ""; let finalized = false;
  const response = await createDeleteMaterialHandler(deps({ remove: async () => ({ error: true }), mark: async (_, __, outcome) => { marked = outcome; return true; }, finalize: async () => { finalized = true; return true; } }))(request({ material_id: id }));
  assertEquals(response.status, 503); assertEquals(marked, "failed"); assertEquals(finalized, false);
});
Deno.test("rejects malformed and extra input", async () => {
  assertEquals((await createDeleteMaterialHandler(deps())(request({ material_id: id, user_id: "x" }))).status, 400);
  assertEquals((await createDeleteMaterialHandler(deps())(request({ material_id: "bad" }))).status, 400);
});
Deno.test("requires authentication", async () => { assertEquals((await createDeleteMaterialHandler(deps())(request({ material_id: id }, false))).status, 401); });

Deno.test("null cleanup status fails closed", async () => {
  const response = await createDeleteMaterialHandler(deps({ begin: async () => ({ outcome: "pending", material_kind: "pdf", source_kind: "upload", storage_bucket: "study-materials", storage_path: `user/${id}/file.pdf`, cleanup_status: null }) }))(request({ material_id: id }));
  assertEquals(response.status, 500);
});

Deno.test("unknown cleanup status fails closed", async () => {
  const response = await createDeleteMaterialHandler(deps({ begin: async () => ({ outcome: "pending", material_kind: "pdf", source_kind: "upload", storage_bucket: "study-materials", storage_path: `user/${id}/file.pdf`, cleanup_status: "unknown" }) }))(request({ material_id: id }));
  assertEquals(response.status, 500);
});

Deno.test("unexpected begin outcome fails closed", async () => {
  const response = await createDeleteMaterialHandler(deps({ begin: async () => ({ outcome: "complete", material_kind: "pdf", source_kind: "upload", storage_bucket: "study-materials", storage_path: `user/${id}/file.pdf`, cleanup_status: "storage_removed" }) }))(request({ material_id: id }));
  assertEquals(response.status, 500);
});

Deno.test("storage_removed skips remove and finalizes", async () => {
  let removed = false; let finalized = false;
  const response = await createDeleteMaterialHandler(deps({
    begin: async () => ({ outcome: "pending", material_kind: "pdf", source_kind: "upload", storage_bucket: "study-materials", storage_path: `user/${id}/file.pdf`, cleanup_status: "storage_removed" }),
    remove: async () => { removed = true; return { error: false }; },
    finalize: async () => { finalized = true; return true; },
  }))(request({ material_id: id }));
  assertEquals(response.status, 200); assertEquals(removed, false); assertEquals(finalized, true);
});

Deno.test("storage_failed retries remove before finalizing", async () => {
  const calls: string[] = [];
  const response = await createDeleteMaterialHandler(deps({
    begin: async () => ({ outcome: "pending", material_kind: "image", source_kind: "upload", storage_bucket: "study-images", storage_path: `user/${id}/file.png`, cleanup_status: "storage_failed" }),
    remove: async () => { calls.push("remove"); return { error: false }; },
    mark: async (_, __, outcome) => { calls.push(`mark:${outcome}`); return true; },
    finalize: async () => { calls.push("finalize"); return true; },
  }))(request({ material_id: id }));
  assertEquals(response.status, 200); assertEquals(calls, ["remove", "mark:removed", "finalize"]);
});

Deno.test("manual not_required finalizes without storage", async () => {
  let removed = false; let finalized = false;
  const response = await createDeleteMaterialHandler(deps({
    begin: async () => ({ outcome: "pending", material_kind: "pasted_text", source_kind: "manual", storage_bucket: null, storage_path: null, cleanup_status: "not_required" }),
    remove: async () => { removed = true; return { error: false }; },
    finalize: async () => { finalized = true; return true; },
  }))(request({ material_id: id }));
  assertEquals(response.status, 200); assertEquals(removed, false); assertEquals(finalized, true);
});

Deno.test("manual material with storage identity fails closed", async () => {
  let finalized = false;
  const response = await createDeleteMaterialHandler(deps({
    begin: async () => ({ outcome: "pending", material_kind: "pasted_text", source_kind: "manual", storage_bucket: "study-materials", storage_path: `user/${id}/file.pdf`, cleanup_status: "not_required" }),
    finalize: async () => { finalized = true; return true; },
  }))(request({ material_id: id }));
  assertEquals(response.status, 500); assertEquals(finalized, false);
});
