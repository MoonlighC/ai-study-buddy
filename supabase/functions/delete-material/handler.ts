export interface DeleteDependencies {
  verifyJwt(jwt: string): Promise<string | null>;
  begin(userId: string, id: string): Promise<Record<string, unknown> | null>;
  remove(bucket: string, path: string): Promise<{ error: boolean }>;
  mark(userId: string, id: string, outcome: "removed" | "failed", code?: string): Promise<boolean>;
  finalize(userId: string, id: string): Promise<boolean>;
  operationId(): string;
  log(stage: string, operationId: string, status: number, errorClass?: string): void;
}

const uuid = /^[0-9a-f]{8}-[0-9a-f]{4}-[1-5][0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$/i;

export function createDeleteMaterialHandler(deps: DeleteDependencies) {
  return async (request: Request): Promise<Response> => {
    const operationId = deps.operationId();
    if (request.method === "OPTIONS") return new Response("ok", { headers: corsHeaders });
    if (request.method !== "POST") return reply({ error: "Method not allowed." }, 405);
    const authorization = request.headers.get("Authorization") ?? "";
    const jwt = authorization.startsWith("Bearer ") ? authorization.slice(7).trim() : "";
    const userId = jwt ? await deps.verifyJwt(jwt) : null;
    if (!userId) return reply({ error: "Authentication required." }, 401);
    let body: unknown;
    try { body = await request.json(); } catch { return reply({ error: "Invalid request." }, 400); }
    if (!record(body) || Object.keys(body).length !== 1 || typeof body.material_id !== "string" || !uuid.test(body.material_id)) {
      return reply({ error: "Invalid request." }, 400);
    }
    const id = body.material_id;
    try {
      const begun = await deps.begin(userId, id);
      if (!begun) throw new Error("begin_failed");
      if (begun.outcome === "not_found") {
        deps.log("complete", operationId, 200);
        return reply({ ok: true, idempotent: true }, 200);
      }
      if (begun.outcome !== "pending") throw new Error("storage_response_invalid");
      if (!validLifecycleRow(begun, id, userId)) throw new Error("storage_response_invalid");
      const source = begun.source_kind as string;
      let cleanup = begun.cleanup_status as string;
      if (source === "upload" && (cleanup === "pending_storage" || cleanup === "storage_failed")) {
        const result = await deps.remove(begun.storage_bucket as string, begun.storage_path as string);
        if (result.error) {
          await deps.mark(userId, id, "failed", "storage_delete_failed");
          deps.log("storage", operationId, 503, "storage_delete_failed");
          return reply({ error: "Could not remove the uploaded file. Try again." }, 503);
        }
        if (!await deps.mark(userId, id, "removed")) throw new Error("mark_failed");
        cleanup = "storage_removed";
      }
      if (source === "manual" && cleanup !== "not_required") throw new Error("storage_response_invalid");
      if (!await deps.finalize(userId, id)) throw new Error("finalize_failed");
      deps.log("complete", operationId, 200);
      return reply({ ok: true }, 200);
    } catch (error) {
      const kind = error instanceof Error ? error.message : "unexpected";
      deps.log("database", operationId, 500, safeClass(kind));
      return reply({ error: "Could not delete the material. Try again." }, 500);
    }
  };
}

function validLifecycleRow(row: Record<string, unknown>, id: string, userId: string) {
  const source = row.source_kind;
  const kind = row.material_kind;
  const cleanup = row.cleanup_status;
  if (source === "manual") return kind === "pasted_text" && cleanup === "not_required" && row.storage_bucket == null && row.storage_path == null;
  if (source !== "upload" || (kind !== "pdf" && kind !== "image")) return false;
  if (!["pending_storage", "storage_failed", "storage_removed"].includes(cleanup as string)) return false;
  const bucket = row.storage_bucket;
  const path = row.storage_path;
  if (bucket !== (kind === "pdf" ? "study-materials" : "study-images") || typeof path !== "string") return false;
  const parts = path.split("/");
  return parts.length === 3 && parts[0] === userId && parts[1] === id && parts[2].trim().length > 0;
}
function record(value: unknown): value is Record<string, unknown> { return typeof value === "object" && value !== null && !Array.isArray(value); }
function safeClass(value: string) { return ["begin_failed", "storage_response_invalid", "mark_failed", "finalize_failed"].includes(value) ? value : "unexpected"; }
const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type",
  "Access-Control-Allow-Methods": "POST, OPTIONS",
};
function reply(body: Record<string, unknown>, status: number) { return new Response(JSON.stringify(body), { status, headers: { ...corsHeaders, "Content-Type": "application/json" } }); }
