import { createDeleteAccountHandler } from "./handler.ts";
import type { AccountDependencies } from "./handler.ts";

const materialId = "123e4567-e89b-42d3-a456-426614174000";
function assert(value: unknown, message = "assertion failed"): asserts value {
  if (!value) throw new Error(message);
}
function equal(a: unknown, e: unknown) {
  const x = JSON.stringify(a), y = JSON.stringify(e);
  if (x !== y) throw new Error(`expected ${y}, got ${x}`);
}
function deps(
  overrides: Partial<AccountDependencies> = {},
): AccountDependencies {
  return {
    verifyJwt: async () => ({ userId: "user", authTime: 950 }),
    begin: async () => ({ outcome: "pending", operation_id: "stable" }),
    list: async () => ({ names: [], error: false }),
    remove: async () => ({ error: false }),
    mark: async () => true,
    deleteAuthUser: async () => ({ error: false }),
    nowSeconds: () => 1000,
    operationId: () => "operation",
    log: () => {},
    ...overrides,
  };
}
function request(
  body: unknown = { confirmation: "DELETE" },
  authorization = "Bearer jwt",
) {
  return new Request("http://local", {
    method: "POST",
    headers: {
      ...(authorization ? { Authorization: authorization } : {}),
      "Content-Type": "application/json",
    },
    body: JSON.stringify(body),
  });
}
async function json(r: Response) {
  return await r.json();
}
function inventory(first: string[] = [], second: string[] = []) {
  const files = new Map<string, string[]>();
  files.set(`study-materials/user/${materialId}`, [...first]);
  files.set(`study-images/user/${materialId}`, [...second]);
  return {
    list: async (bucket: string, prefix: string) => {
      if (prefix === "user") {
        return {
          names: (files.get(`${bucket}/user/${materialId}`)?.length ?? 0) > 0
            ? [materialId]
            : [],
          error: false,
        };
      }
      return {
        names: [...(files.get(`${bucket}/${prefix}`) ?? [])],
        error: false,
      };
    },
    remove: async (bucket: string, paths: string[]) => {
      for (const path of paths) {
        files.set(`${bucket}/${path.substring(0, path.lastIndexOf("/"))}`, []);
      }
      return { error: false };
    },
  };
}

Deno.test("account: no bearer token is rejected without verification", async () => {
  let verified = false;
  const r = await createDeleteAccountHandler(deps({
    verifyJwt: async () => {
      verified = true;
      return null;
    },
  }))(request(undefined, ""));
  equal(r.status, 401);
  assert(!verified);
});
Deno.test("account: invalid token is rejected", async () =>
  equal(
    await json(
      await createDeleteAccountHandler(deps({ verifyJwt: async () => null }))(
        request(),
      ),
    ),
    { code: "unauthorized" },
  ));
Deno.test("account: verifier errors are sanitized", async () =>
  equal(
    (await createDeleteAccountHandler(deps({
      verifyJwt: async () => {
        throw new Error("raw provider");
      },
    }))(request())).status,
    401,
  ));
Deno.test("account: client user ID is rejected", async () => {
  let begun = false;
  const r = await createDeleteAccountHandler(deps({
    begin: async () => {
      begun = true;
      return null;
    },
  }))(request({ confirmation: "DELETE", user_id: "other" }));
  equal(r.status, 400);
  assert(!begun);
});
Deno.test("account: missing auth_time requires recent auth", async () =>
  equal(
    await json(
      await createDeleteAccountHandler(
        deps({ verifyJwt: async () => ({ userId: "user", authTime: null }) }),
      )(request()),
    ),
    { code: "recent_auth_required" },
  ));
Deno.test("account: stale auth_time requires recent auth", async () =>
  equal(
    (await createDeleteAccountHandler(
      deps({ verifyJwt: async () => ({ userId: "user", authTime: 399 }) }),
    )(request())).status,
    403,
  ));
Deno.test("account: exact ten-minute auth boundary is accepted", async () =>
  equal(
    (await createDeleteAccountHandler(
      deps({ verifyJwt: async () => ({ userId: "user", authTime: 400 }) }),
    )(request())).status,
    200,
  ));
Deno.test("account: recent authentication is accepted", async () =>
  equal((await createDeleteAccountHandler(deps())(request())).status, 200));
Deno.test("account: first request starts stable operation", async () => {
  let count = 0;
  await createDeleteAccountHandler(deps({
    begin: async () => {
      count++;
      return { outcome: "pending", operation_id: "stable" };
    },
  }))(request());
  equal(count, 1);
});
Deno.test("account: duplicate active request returns deletion_in_progress", async () =>
  equal(
    await json(
      await createDeleteAccountHandler(
        deps({ begin: async () => ({ outcome: "in_progress" }) }),
      )(request()),
    ),
    { code: "deletion_in_progress", status: "in_progress" },
  ));
Deno.test("account: stale pending operation resumes", async () => {
  let deleted = false;
  await createDeleteAccountHandler(
    deps({
      begin: async () => ({ outcome: "pending", stage: "pending_storage" }),
      deleteAuthUser: async () => {
        deleted = true;
        return { error: false };
      },
    }),
  )(request());
  assert(deleted);
});
Deno.test("account: invalidated session after interrupted success is safe", async () => {
  let begun = false;
  const r = await createDeleteAccountHandler(
    deps({
      verifyJwt: async () => null,
      begin: async () => {
        begun = true;
        return null;
      },
    }),
  )(request());
  equal(r.status, 401);
  assert(!begun);
});
Deno.test("account: stable operation derives identity only from principal", async () => {
  const users: string[] = [];
  const h = createDeleteAccountHandler(deps({
    begin: async (u) => {
      users.push(u);
      return { outcome: "pending", operation_id: "same" };
    },
  }));
  await h(request());
  await h(request());
  equal(users, ["user", "user"]);
});
Deno.test("account: both empty buckets verify then delete Auth", async () => {
  let deleted = false;
  await createDeleteAccountHandler(deps({
    deleteAuthUser: async () => {
      deleted = true;
      return { error: false };
    },
  }))(request());
  assert(deleted);
});
Deno.test("account: object only in first bucket is removed", async () => {
  const i = inventory(["a.pdf"], []);
  const removed: string[] = [];
  const r = await createDeleteAccountHandler(
    deps({
      ...i,
      remove: async (b, p) => {
        removed.push(`${b}:${p[0]}`);
        return i.remove(b, p);
      },
    }),
  )(request());
  equal(r.status, 200);
  equal(removed, [`study-materials:user/${materialId}/a.pdf`]);
});
Deno.test("account: object only in second bucket is removed", async () => {
  const i = inventory([], ["a.png"]);
  const removed: string[] = [];
  await createDeleteAccountHandler(deps({
    ...i,
    remove: async (b, p) => {
      removed.push(`${b}:${p[0]}`);
      return i.remove(b, p);
    },
  }))(request());
  equal(removed, [`study-images:user/${materialId}/a.png`]);
});
Deno.test("account: many objects use bounded removal pages", async () => {
  let page = 0;
  const sizes: number[] = [];
  const r = await createDeleteAccountHandler(deps({
    list: async (b, p) =>
      b === "study-materials" && p === "user" && page < 3
        ? ({ names: [materialId], error: false })
        : b === "study-materials" && p.endsWith(materialId) && page < 3
        ? ({
          names: Array.from({ length: [100, 100, 5][page++] }, (_, i) =>
            `f${page}-${i}`),
          error: false,
        })
        : ({ names: [], error: false }),
    remove: async (_b, p) => {
      sizes.push(p.length);
      return { error: false };
    },
  }))(request());
  equal(r.status, 200);
  equal(sizes, [100, 100, 5]);
});
Deno.test("account: partial failure in first bucket blocks Auth", async () => {
  let deleted = false;
  const r = await createDeleteAccountHandler(deps({
    list: async (b, p) =>
      b === "study-materials" && p === "user"
        ? ({ names: [materialId], error: false })
        : b === "study-materials"
        ? ({ names: ["f"], error: false })
        : ({ names: [], error: false }),
    remove: async () => ({ error: true }),
    deleteAuthUser: async () => {
      deleted = true;
      return { error: false };
    },
  }))(request());
  equal(r.status, 503);
  assert(!deleted);
});
Deno.test("account: partial failure in second bucket blocks Auth", async () => {
  let deleted = false;
  const r = await createDeleteAccountHandler(deps({
    list: async (b, p) =>
      b === "study-images" && p === "user"
        ? ({ names: [materialId], error: false })
        : b === "study-images"
        ? ({ names: ["f"], error: false })
        : ({ names: [], error: false }),
    remove: async () => ({ error: true }),
    deleteAuthUser: async () => {
      deleted = true;
      return { error: false };
    },
  }))(request());
  equal(r.status, 503);
  assert(!deleted);
});
Deno.test("account: retry resumes recorded storage_failed stage", async () => {
  let deleted = false;
  await createDeleteAccountHandler(
    deps({
      begin: async () => ({ outcome: "pending", stage: "storage_failed" }),
      deleteAuthUser: async () => {
        deleted = true;
        return { error: false };
      },
    }),
  )(request());
  assert(deleted);
});
Deno.test("account: already missing objects are tolerated", async () =>
  equal((await createDeleteAccountHandler(deps())(request())).status, 200));
Deno.test("account: malformed material folder is rejected", async () =>
  equal(
    (await createDeleteAccountHandler(deps({
      list: async (b, p) =>
        b === "study-materials" && p === "user"
          ? ({ names: ["not-a-uuid"], error: false })
          : ({ names: [], error: false }),
    }))(request())).status,
    409,
  ));
Deno.test("account: foreign traversal prefix is rejected", async () =>
  equal(
    (await createDeleteAccountHandler(deps({
      list: async (b, p) =>
        b === "study-materials" && p === "user"
          ? ({ names: ["../other"], error: false })
          : ({ names: [], error: false }),
    }))(request())).status,
    409,
  ));
Deno.test("account: nested filename path is rejected", async () => {
  let root = true;
  const r = await createDeleteAccountHandler(deps({
    list: async (_b, p) =>
      p === "user" && root
        ? (root = false, { names: [materialId], error: false })
        : p.endsWith(materialId)
        ? ({ names: ["nested/file"], error: false })
        : ({ names: [], error: false }),
  }))(request());
  equal(r.status, 409);
});
Deno.test("account: only allowlisted buckets are queried", async () => {
  const seen = new Set<string>();
  await createDeleteAccountHandler(deps({
    list: async (b) => {
      seen.add(b);
      return { names: [], error: false };
    },
  }))(request());
  equal([...seen], ["study-materials", "study-images"]);
});
Deno.test("account: oversized provider page cannot overflow counters", async () => {
  const r = await createDeleteAccountHandler(
    deps({
      list: async (b, p) =>
        b === "study-materials" && p === "user"
          ? ({
            names: Array.from({ length: 101 }, () => materialId),
            error: false,
          })
          : ({ names: [], error: false }),
    }),
  )(request());
  equal(r.status, 409);
});
Deno.test("account: listing proves both initially empty namespaces", async () => {
  const roots: Record<string, number> = {};
  await createDeleteAccountHandler(deps({
    list: async (b, p) => {
      if (p === "user") roots[b] = (roots[b] ?? 0) + 1;
      return { names: [], error: false };
    },
  }))(request());
  equal(roots, { "study-materials": 1, "study-images": 1 });
});
Deno.test("account: unexpected object during post-removal verification blocks Auth", async () => {
  let roots = 0, deleted = false;
  const r = await createDeleteAccountHandler(deps({
    list: async (b, p) => {
      if (b !== "study-materials") return { names: [], error: false };
      if (p === "user") return { names: [materialId], error: false };
      if (p.endsWith(materialId) && roots++ === 0) {
        return { names: ["file"], error: false };
      }
      return { names: [], error: false };
    },
    remove: async () => ({ error: false }),
    deleteAuthUser: async () => {
      deleted = true;
      return { error: false };
    },
  }))(request());
  equal(r.status, 503);
  assert(!deleted);
});
Deno.test("account: Auth delete never precedes Storage verification", async () => {
  const calls: string[] = [];
  await createDeleteAccountHandler(deps({
    mark: async (_u, s) => {
      calls.push(s);
      return true;
    },
    deleteAuthUser: async () => {
      calls.push("auth");
      return { error: false };
    },
  }))(request());
  equal(calls, ["storage_verified", "database_ready", "auth"]);
});
Deno.test("account: database-stage failure never calls Auth admin", async () => {
  let auth = false;
  const r = await createDeleteAccountHandler(
    deps({
      mark: async (_u, s) => s !== "database_ready",
      deleteAuthUser: async () => {
        auth = true;
        return { error: false };
      },
    }),
  )(request());
  equal(r.status, 503);
  assert(!auth);
});
Deno.test("account: Auth deletion is final destructive call", async () => {
  const calls: string[] = [];
  await createDeleteAccountHandler(deps({
    mark: async (_u, s) => {
      calls.push(`mark:${s}`);
      return true;
    },
    deleteAuthUser: async () => {
      calls.push("auth");
      return { error: false };
    },
    log: () => calls.push("log"),
  }))(request());
  equal(calls.slice(-2), ["auth", "log"]);
});
Deno.test("account: Auth deletion failure maps safely", async () =>
  equal(
    await json(
      await createDeleteAccountHandler(
        deps({ deleteAuthUser: async () => ({ error: true }) }),
      )(request()),
    ),
    { code: "auth_cleanup_failed", status: "retryable" },
  ));
Deno.test("account: interrupted response after Auth success remains safely retryable", async () => {
  let auth = false, firstLog = true;
  const h = createDeleteAccountHandler(deps({
    deleteAuthUser: async () => {
      auth = true;
      return { error: false };
    },
    log: () => {
      if (firstLog) {
        firstLog = false;
        throw new Error("disconnect");
      }
    },
  }));
  const r = await h(request());
  assert(auth);
  equal(await json(r), {
    code: "database_cleanup_failed",
    status: "retryable",
  });
});
Deno.test("account: stable codes do not leak provider payloads", async () => {
  const r = await createDeleteAccountHandler(
    deps({ deleteAuthUser: async () => ({ error: true }) }),
  )(request());
  const text = await r.text();
  assert(
    !text.includes("provider") && !text.includes("user") &&
      !text.includes("token"),
  );
});
Deno.test("account: logs contain only safe completion fields", async () => {
  let event: Record<string, unknown> = {};
  await createDeleteAccountHandler(deps({ log: (e) => event = e }))(request());
  equal(Object.keys(event).sort(), [
    "objects_found",
    "objects_removed",
    "operation_id",
    "stage",
    "status",
    "timestamp",
  ]);
  assert(!JSON.stringify(event).includes("user"));
});
Deno.test("account: invalid JSON and unsupported methods are sanitized", async () => {
  const h = createDeleteAccountHandler(deps());
  const bad = new Request("http://local", {
    method: "POST",
    headers: { Authorization: "Bearer jwt" },
    body: "{",
  });
  equal((await h(bad)).status, 400);
  equal(
    (await h(new Request("http://local", { method: "DELETE" }))).status,
    405,
  );
});
Deno.test("account: OPTIONS includes CORS without authentication", async () => {
  const r = await createDeleteAccountHandler(deps())(
    new Request("http://local", { method: "OPTIONS" }),
  );
  equal(r.status, 200);
  assert(r.headers.has("access-control-allow-origin"));
});
