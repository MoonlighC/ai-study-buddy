export type SafeCode =
  | "deletion_in_progress"
  | "storage_cleanup_failed"
  | "database_cleanup_failed"
  | "unauthorized"
  | "retry_later"
  | "unknown";
export interface SubjectDependencies {
  verifyJwt(jwt: string): Promise<string | null>;
  begin(
    userId: string,
    subjectId: string,
  ): Promise<Record<string, unknown> | null>;
  list(
    bucket: string,
    prefix: string,
    offset: number,
    limit: number,
  ): Promise<{ names: string[]; error: boolean }>;
  remove(bucket: string, paths: string[]): Promise<{ error: boolean }>;
  mark(
    userId: string,
    subjectId: string,
    stage: string,
    code: string | null,
    found: number,
    removed: number,
  ): Promise<boolean>;
  finalize(userId: string, subjectId: string): Promise<boolean>;
  operationId(): string;
  log(event: Record<string, unknown>): void;
}
const buckets = ["study-materials", "study-images"] as const;
const uuid =
  /^[0-9a-f]{8}-[0-9a-f]{4}-[1-5][0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$/i;
const pageSize = 100;
export function createDeleteSubjectHandler(deps: SubjectDependencies) {
  return async (request: Request): Promise<Response> => {
    const operationId = deps.operationId();
    if (request.method === "OPTIONS") return reply({ ok: true }, 200);
    if (request.method !== "POST") return reply({ code: "unknown" }, 405);
    const jwt = bearer(request);
    let userId: string | null = null;
    try {
      userId = jwt ? await deps.verifyJwt(jwt) : null;
    } catch {
      return reply({ code: "unauthorized" }, 401);
    }
    if (!userId) return reply({ code: "unauthorized" }, 401);
    let body: unknown;
    try {
      body = await request.json();
    } catch {
      return reply({ code: "unknown" }, 400);
    }
    if (
      !isRecord(body) || Object.keys(body).length !== 1 ||
      typeof body.subject_id !== "string" || !uuid.test(body.subject_id)
    ) return reply({ code: "unknown" }, 400);
    const subjectId = body.subject_id;
    let found = 0;
    let removed = 0;
    try {
      const begun = await deps.begin(userId, subjectId);
      if (!begun) throw new Error("begin");
      if (begun.outcome === "not_found") {
        return reply({ ok: true, idempotent: true, status: "completed" }, 200);
      }
      if (begun.outcome === "in_progress") {
        return reply(
          { code: "deletion_in_progress", status: "in_progress" },
          409,
        );
      }
      const materialIds = Array.isArray(begun.material_ids)
        ? begun.material_ids
        : null;
      if (
        !materialIds ||
        materialIds.some((id) => typeof id !== "string" || !uuid.test(id))
      ) throw new Error("begin");
      for (const materialId of materialIds as string[]) {
        for (const bucket of buckets) {
          const prefix = `${userId}/${materialId}`;
          for (;;) {
            const listed = await deps.list(bucket, prefix, 0, pageSize);
            if (listed.error) {
              return await storageFailure(
                deps,
                userId,
                subjectId,
                operationId,
                found,
                removed,
              );
            }
            if (listed.names.length === 0) {
              break;
            }
            if (
              listed.names.length > pageSize ||
              found + listed.names.length > 1000000
            ) {
              return await terminalFailure(
                deps,
                userId,
                subjectId,
                operationId,
                found,
                removed,
              );
            }
            const paths = listed.names.map((name) => `${prefix}/${name}`);
            if (
              paths.some((path) => !validSubjectPath(path, userId, materialId))
            ) {
              return await terminalFailure(
                deps,
                userId,
                subjectId,
                operationId,
                found,
                removed,
              );
            }
            found += paths.length;
            if ((await deps.remove(bucket, paths)).error) {
              return await storageFailure(
                deps,
                userId,
                subjectId,
                operationId,
                found,
                removed,
              );
            }
            removed += paths.length;
            if (
              !await deps.mark(
                userId,
                subjectId,
                "pending_storage",
                null,
                found,
                removed,
              )
            ) throw new Error("mark");
            if (listed.names.length < pageSize) break;
          }
          const verify = await deps.list(bucket, prefix, 0, 1);
          if (verify.error || verify.names.length !== 0) {
            return await storageFailure(
              deps,
              userId,
              subjectId,
              operationId,
              found,
              removed,
            );
          }
        }
      }
      if (
        !await deps.mark(
          userId,
          subjectId,
          "storage_verified",
          null,
          found,
          removed,
        )
      ) throw new Error("mark");
      if (!await deps.finalize(userId, subjectId)) {
        await deps.mark(
          userId,
          subjectId,
          "database_failed",
          "database_cleanup_failed",
          found,
          removed,
        );
        deps.log({
          operation_id: operationId,
          stage: "database",
          code: "database_cleanup_failed",
          status: 503,
          objects_found: found,
          objects_removed: removed,
          timestamp: new Date().toISOString(),
        });
        return reply(
          { code: "database_cleanup_failed", status: "retryable" },
          503,
        );
      }
      deps.log({
        operation_id: operationId,
        stage: "complete",
        status: 200,
        objects_found: found,
        objects_removed: removed,
        timestamp: new Date().toISOString(),
      });
      return reply({ ok: true, status: "completed" }, 200);
    } catch {
      deps.log({
        operation_id: operationId,
        stage: "database",
        code: "unknown",
        status: 500,
        timestamp: new Date().toISOString(),
      });
      return reply({ code: "unknown" }, 500);
    }
  };
}
async function storageFailure(
  deps: SubjectDependencies,
  userId: string,
  subjectId: string,
  operationId: string,
  found: number,
  removed: number,
) {
  await deps.mark(
    userId,
    subjectId,
    "storage_failed",
    "storage_cleanup_failed",
    found,
    removed,
  );
  deps.log({
    operation_id: operationId,
    stage: "storage",
    code: "storage_cleanup_failed",
    status: 503,
    objects_found: found,
    objects_removed: removed,
    timestamp: new Date().toISOString(),
  });
  return reply({ code: "storage_cleanup_failed", status: "retryable" }, 503);
}
async function terminalFailure(
  deps: SubjectDependencies,
  userId: string,
  subjectId: string,
  operationId: string,
  found: number,
  removed: number,
) {
  await deps.mark(
    userId,
    subjectId,
    "storage_failed",
    "unknown",
    found,
    removed,
  );
  deps.log({
    operation_id: operationId,
    stage: "storage",
    code: "unknown",
    status: 409,
    objects_found: found,
    objects_removed: removed,
    timestamp: new Date().toISOString(),
  });
  return reply({ code: "unknown", status: "operator_review" }, 409);
}
function validSubjectPath(path: string, userId: string, materialId: string) {
  const parts = path.split("/");
  return parts.length === 3 && parts[0] === userId && parts[1] === materialId &&
    parts[2].trim() !== "";
}
function bearer(request: Request) {
  const value = request.headers.get("Authorization") ?? "";
  return value.startsWith("Bearer ") ? value.slice(7).trim() : "";
}
function isRecord(value: unknown): value is Record<string, unknown> {
  return typeof value === "object" && value !== null && !Array.isArray(value);
}
const cors = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers":
    "authorization, x-client-info, apikey, content-type",
  "Access-Control-Allow-Methods": "POST, OPTIONS",
};
function reply(body: Record<string, unknown>, status: number) {
  return new Response(JSON.stringify(body), {
    status,
    headers: { ...cors, "Content-Type": "application/json" },
  });
}
