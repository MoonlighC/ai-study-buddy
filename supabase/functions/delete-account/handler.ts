export interface AccountPrincipal {
  userId: string;
  lastSignInAt: string | null;
}
export interface AccountDependencies {
  verifyJwt(jwt: string): Promise<AccountPrincipal | null>;
  begin(userId: string): Promise<Record<string, unknown> | null>;
  list(
    bucket: string,
    prefix: string,
    offset: number,
    limit: number,
  ): Promise<{ names: string[]; error: boolean }>;
  remove(bucket: string, paths: string[]): Promise<{ error: boolean }>;
  mark(
    userId: string,
    stage: string,
    code: string | null,
    found: number,
    removed: number,
  ): Promise<boolean>;
  deleteAuthUser(
    userId: string,
  ): Promise<{ error: boolean; notFound?: boolean }>;
  nowMilliseconds(): number;
  operationId(): string;
  log(event: Record<string, unknown>): void;
}
const buckets = ["study-materials", "study-images"] as const;
const pageSize = 100;
const recentAuthWindowMs = 10 * 60 * 1000;
const allowedFutureSkewMs = 60 * 1000;
const uuid =
  /^[0-9a-f]{8}-[0-9a-f]{4}-[1-5][0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$/i;
export function createDeleteAccountHandler(deps: AccountDependencies) {
  return async (request: Request): Promise<Response> => {
    const operationId = deps.operationId();
    if (request.method === "OPTIONS") return reply({ ok: true }, 200);
    if (request.method !== "POST") return reply({ code: "unknown" }, 405);
    const jwt = bearer(request);
    let principal: AccountPrincipal | null = null;
    try {
      principal = jwt ? await deps.verifyJwt(jwt) : null;
    } catch {
      return reply({ code: "unauthorized" }, 401);
    }
    if (!principal) return reply({ code: "unauthorized" }, 401);
    const freshness = recentAuthFreshness(
      principal.lastSignInAt,
      deps.nowMilliseconds(),
    );
    try {
      deps.log({
        operation: "delete-account",
        stage: "recent_auth_checked",
        code: freshness === "fresh"
          ? "recent_auth_accepted"
          : "recent_auth_required",
        timestamp_present: principal.lastSignInAt != null,
        age_bucket: freshness,
        timestamp: new Date(deps.nowMilliseconds()).toISOString(),
      });
    } catch {
      // Diagnostics must never change deletion authorization or ordering.
    }
    if (freshness !== "fresh") {
      return reply({ code: "recent_auth_required" }, 403);
    }
    let body: unknown;
    try {
      body = await request.json();
    } catch {
      return reply({ code: "unknown" }, 400);
    }
    if (
      !record(body) || Object.keys(body).length !== 1 ||
      body.confirmation !== "DELETE"
    ) return reply({ code: "unknown" }, 400);
    let found = 0, removed = 0;
    try {
      const begun = await deps.begin(principal.userId);
      if (!begun) throw new Error("begin");
      if (begun.outcome === "in_progress") {
        return reply(
          { code: "deletion_in_progress", status: "in_progress" },
          409,
        );
      }
      for (const bucket of buckets) {
        for (;;) {
          const folders = await deps.list(
            bucket,
            principal.userId,
            0,
            pageSize,
          );
          if (folders.error) {
            return await storageFailure(
              deps,
              principal.userId,
              operationId,
              found,
              removed,
            );
          }
          if (folders.names.length === 0) break;
          if (folders.names.length > pageSize) {
            return await terminalFailure(
              deps,
              principal.userId,
              operationId,
              found,
              removed,
            );
          }
          for (const materialId of folders.names) {
            if (!uuid.test(materialId)) {
              return await terminalFailure(
                deps,
                principal.userId,
                operationId,
                found,
                removed,
              );
            }
            const prefix = `${principal.userId}/${materialId}`;
            for (;;) {
              const files = await deps.list(bucket, prefix, 0, pageSize);
              if (files.error) {
                return await storageFailure(
                  deps,
                  principal.userId,
                  operationId,
                  found,
                  removed,
                );
              }
              if (files.names.length === 0) break;
              if (
                files.names.length > pageSize ||
                found + files.names.length > 1000000
              ) {
                return await terminalFailure(
                  deps,
                  principal.userId,
                  operationId,
                  found,
                  removed,
                );
              }
              const paths = files.names.map((name) => `${prefix}/${name}`);
              if (
                paths.some((path) =>
                  !validPath(path, principal.userId, materialId)
                )
              ) {
                return await terminalFailure(
                  deps,
                  principal.userId,
                  operationId,
                  found,
                  removed,
                );
              }
              found += paths.length;
              if ((await deps.remove(bucket, paths)).error) {
                return await storageFailure(
                  deps,
                  principal.userId,
                  operationId,
                  found,
                  removed,
                );
              }
              removed += paths.length;
              if (
                !await deps.mark(
                  principal.userId,
                  "pending_storage",
                  null,
                  found,
                  removed,
                )
              ) throw new Error("mark");
              if (files.names.length < pageSize) break;
            }
          }
          const verify = await deps.list(bucket, principal.userId, 0, 1);
          if (verify.error || verify.names.length !== 0) {
            return await storageFailure(
              deps,
              principal.userId,
              operationId,
              found,
              removed,
            );
          }
        }
      }
      if (
        !await deps.mark(
          principal.userId,
          "storage_verified",
          null,
          found,
          removed,
        ) ||
        !await deps.mark(
          principal.userId,
          "database_ready",
          null,
          found,
          removed,
        )
      ) throw new Error("mark");
      const deleted = await deps.deleteAuthUser(principal.userId);
      if (deleted.error && !deleted.notFound) {
        await deps.mark(
          principal.userId,
          "auth_failed",
          "auth_cleanup_failed",
          found,
          removed,
        );
        deps.log({
          operation_id: operationId,
          stage: "auth",
          code: "auth_cleanup_failed",
          status: 503,
          objects_found: found,
          objects_removed: removed,
          timestamp: new Date().toISOString(),
        });
        return reply({ code: "auth_cleanup_failed", status: "retryable" }, 503);
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
        code: "database_cleanup_failed",
        status: 503,
        timestamp: new Date().toISOString(),
      });
      return reply(
        { code: "database_cleanup_failed", status: "retryable" },
        503,
      );
    }
  };
}

export function recentAuthFreshness(
  lastSignInAt: string | null,
  nowMilliseconds: number,
): "fresh" | "stale" | "invalid" {
  if (lastSignInAt == null || !Number.isFinite(nowMilliseconds)) {
    return "invalid";
  }
  if (!/(?:z|[+-]\d{2}:\d{2})$/i.test(lastSignInAt)) return "invalid";
  const signedInAt = Date.parse(lastSignInAt);
  if (!Number.isFinite(signedInAt)) return "invalid";
  const age = nowMilliseconds - signedInAt;
  if (age < -allowedFutureSkewMs) return "invalid";
  return age <= recentAuthWindowMs ? "fresh" : "stale";
}
async function storageFailure(
  d: AccountDependencies,
  u: string,
  o: string,
  f: number,
  r: number,
) {
  await d.mark(u, "storage_failed", "storage_cleanup_failed", f, r);
  d.log({
    operation_id: o,
    stage: "storage",
    code: "storage_cleanup_failed",
    status: 503,
    objects_found: f,
    objects_removed: r,
    timestamp: new Date().toISOString(),
  });
  return reply({ code: "storage_cleanup_failed", status: "retryable" }, 503);
}
async function terminalFailure(
  d: AccountDependencies,
  u: string,
  o: string,
  f: number,
  r: number,
) {
  await d.mark(u, "storage_failed", "unknown", f, r);
  d.log({
    operation_id: o,
    stage: "storage",
    code: "unknown",
    status: 409,
    objects_found: f,
    objects_removed: r,
    timestamp: new Date().toISOString(),
  });
  return reply({ code: "unknown", status: "operator_review" }, 409);
}
function validPath(path: string, user: string, material: string) {
  const p = path.split("/");
  return p.length === 3 && p[0] === user && p[1] === material &&
    p[2].trim() !== "";
}
function bearer(r: Request) {
  const v = r.headers.get("Authorization") ?? "";
  return v.startsWith("Bearer ") ? v.slice(7).trim() : "";
}
function record(v: unknown): v is Record<string, unknown> {
  return typeof v === "object" && v !== null && !Array.isArray(v);
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
