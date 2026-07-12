import { createDeleteSubjectHandler } from "./handler.ts";
import type { SubjectDependencies } from "./handler.ts";

const subjectId = "123e4567-e89b-42d3-a456-426614174000";
const materialId = "123e4567-e89b-42d3-a456-426614174001";
function assert(value: unknown, message = "assertion failed"): asserts value {
  if (!value) throw new Error(message);
}
function equal(actual: unknown, expected: unknown) {
  const a = JSON.stringify(actual), e = JSON.stringify(expected);
  if (a !== e) throw new Error(`expected ${e}, got ${a}`);
}
function deps(
  overrides: Partial<SubjectDependencies> = {},
): SubjectDependencies {
  return {
    verifyJwt: async () => "user",
    begin: async () => ({ outcome: "pending", material_ids: [materialId] }),
    list: async () => ({ names: [], error: false }),
    remove: async () => ({ error: false }),
    mark: async () => true,
    finalize: async () => true,
    operationId: () => "operation",
    log: () => {},
    ...overrides,
  };
}
function request(
  body: unknown = { subject_id: subjectId },
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
async function json(response: Response) {
  return await response.json();
}

Deno.test("subject: missing Authorization is rejected without verification", async () => {
  let verified = false;
  const r = await createDeleteSubjectHandler(deps({
    verifyJwt: async () => {
      verified = true;
      return null;
    },
  }))(request(undefined, ""));
  equal(r.status, 401);
  assert(!verified);
});
Deno.test("subject: malformed bearer scheme is rejected", async () =>
  equal(
    (await createDeleteSubjectHandler(deps())(
      request(undefined, "Basic token"),
    )).status,
    401,
  ));
Deno.test("subject: unauthenticated caller is rejected", async () =>
  equal(
    await json(
      await createDeleteSubjectHandler(deps({ verifyJwt: async () => null }))(
        request(),
      ),
    ),
    { code: "unauthorized" },
  ));
Deno.test("subject: verifier errors are sanitized", async () =>
  equal(
    await json(
      await createDeleteSubjectHandler(deps({
        verifyJwt: async () => {
          throw new Error("provider secret");
        },
      }))(request()),
    ),
    { code: "unauthorized" },
  ));
Deno.test("subject: invalid JSON is rejected", async () => {
  const r = new Request("http://local", {
    method: "POST",
    headers: { Authorization: "Bearer jwt" },
    body: "{",
  });
  equal((await createDeleteSubjectHandler(deps())(r)).status, 400);
});
Deno.test("subject: missing subject_id is rejected", async () =>
  equal((await createDeleteSubjectHandler(deps())(request({}))).status, 400));
Deno.test("subject: malformed subject UUID is rejected", async () =>
  equal(
    (await createDeleteSubjectHandler(deps())(request({ subject_id: "bad" })))
      .status,
    400,
  ));
Deno.test("subject: client user ID is rejected", async () => {
  let begun = false;
  const r = await createDeleteSubjectHandler(deps({
    begin: async () => {
      begun = true;
      return null;
    },
  }))(request({ subject_id: subjectId, user_id: "other" }));
  equal(r.status, 400);
  assert(!begun);
});
Deno.test("subject: owned first operation starts and completes", async () =>
  equal((await createDeleteSubjectHandler(deps())(request())).status, 200));
Deno.test("subject: foreign subject is non-enumerating idempotent success", async () =>
  equal(
    await json(
      await createDeleteSubjectHandler(
        deps({ begin: async () => ({ outcome: "not_found" }) }),
      )(request()),
    ),
    { ok: true, idempotent: true, status: "completed" },
  ));
Deno.test("subject: already absent is idempotent success", async () =>
  equal(
    (await createDeleteSubjectHandler(
      deps({ begin: async () => ({ outcome: "not_found" }) }),
    )(request())).status,
    200,
  ));
Deno.test("subject: duplicate active operation returns deletion_in_progress", async () =>
  equal(
    await json(
      await createDeleteSubjectHandler(
        deps({ begin: async () => ({ outcome: "in_progress" }) }),
      )(request()),
    ),
    { code: "deletion_in_progress", status: "in_progress" },
  ));
Deno.test("subject: stale operation returned as pending resumes", async () => {
  let finalized = false;
  await createDeleteSubjectHandler(
    deps({
      begin: async () => ({
        outcome: "pending",
        stage: "pending_storage",
        material_ids: [materialId],
      }),
      finalize: async () => {
        finalized = true;
        return true;
      },
    }),
  )(request());
  assert(finalized);
});
Deno.test("subject: completed operation behaves idempotently", async () => {
  let removed = false;
  await createDeleteSubjectHandler(
    deps({
      begin: async () => ({ outcome: "not_found" }),
      remove: async () => {
        removed = true;
        return { error: false };
      },
    }),
  )(request());
  assert(!removed);
});
Deno.test("subject: zero objects finalizes", async () => {
  let finalized = 0;
  await createDeleteSubjectHandler(deps({
    finalize: async () => {
      finalized++;
      return true;
    },
  }))(request());
  equal(finalized, 1);
});
Deno.test("subject: one object is removed exactly", async () => {
  let first = true;
  const paths: string[] = [];
  await createDeleteSubjectHandler(
    deps({
      list: async () =>
        first
          ? (first = false, { names: ["file.pdf"], error: false })
          : ({ names: [], error: false }),
      remove: async (_b, p) => {
        paths.push(...p);
        return { error: false };
      },
    }),
  )(request());
  equal(paths, [`user/${materialId}/file.pdf`]);
});
Deno.test("subject: multiple pages are drained with bounded calls", async () => {
  let page = 0;
  const sizes: number[] = [];
  await createDeleteSubjectHandler(deps({
    list: async (_b, p) =>
      p.endsWith(materialId) && page < 2
        ? ({
          names: Array.from({ length: page++ === 0 ? 100 : 1 }, (_, i) =>
            `f${i}`),
          error: false,
        })
        : ({ names: [], error: false }),
    remove: async (_b, p) => {
      sizes.push(p.length);
      return { error: false };
    },
  }))(request());
  equal(sizes, [100, 1]);
});
Deno.test("subject: more than one removal batch stays bounded", async () => {
  let page = 0;
  const sizes: number[] = [];
  await createDeleteSubjectHandler(deps({
    list: async (_b, p) =>
      p.endsWith(materialId) && page < 3
        ? ({
          names: Array.from(
            { length: [100, 100, 5][page++] },
            (_, i) => `p${page}-${i}`,
          ),
          error: false,
        })
        : ({ names: [], error: false }),
    remove: async (_b, p) => {
      sizes.push(p.length);
      return { error: false };
    },
  }))(request());
  equal(sizes, [100, 100, 5]);
});
Deno.test("subject: already missing objects are tolerated", async () =>
  equal((await createDeleteSubjectHandler(deps())(request())).status, 200));
Deno.test("subject: partial remove failure is retryable", async () => {
  let first = true;
  const r = await createDeleteSubjectHandler(
    deps({
      list: async () =>
        first
          ? (first = false, { names: ["file"], error: false })
          : ({ names: [], error: false }),
      remove: async () => ({ error: true }),
    }),
  )(request());
  equal(await json(r), { code: "storage_cleanup_failed", status: "retryable" });
});
Deno.test("subject: retry resumes after a recorded storage failure", async () => {
  let fail = true;
  const d = deps({
    begin: async () => ({
      outcome: "pending",
      stage: "storage_failed",
      material_ids: [materialId],
    }),
    list: async () => ({ names: fail ? ["file"] : [], error: false }),
    remove: async () => {
      fail = false;
      return { error: true };
    },
  });
  equal((await createDeleteSubjectHandler(d)(request())).status, 503);
  d.remove = async () => ({ error: false });
  equal((await createDeleteSubjectHandler(d)(request())).status, 200);
});
Deno.test("subject: re-list verification error blocks finalization", async () => {
  let calls = 0, finalized = false;
  const r = await createDeleteSubjectHandler(
    deps({
      list: async () =>
        ++calls === 2
          ? ({ names: [], error: true })
          : ({ names: [], error: false }),
      finalize: async () => {
        finalized = true;
        return true;
      },
    }),
  )(request());
  equal(r.status, 503);
  assert(!finalized);
});
Deno.test("subject: unexpected remaining object blocks finalization", async () => {
  let calls = 0;
  const r = await createDeleteSubjectHandler(
    deps({
      list: async () =>
        ++calls === 2
          ? ({ names: ["remaining"], error: false })
          : ({ names: [], error: false }),
    }),
  )(request());
  equal(r.status, 503);
});
Deno.test("subject: malformed nested object path is rejected", async () => {
  let first = true;
  const r = await createDeleteSubjectHandler(
    deps({
      list: async () =>
        first
          ? (first = false, { names: ["nested/file"], error: false })
          : ({ names: [], error: false }),
    }),
  )(request());
  equal(r.status, 409);
});
Deno.test("subject: another-user traversal path is rejected", async () => {
  let first = true;
  const r = await createDeleteSubjectHandler(
    deps({
      list: async () =>
        first
          ? (first = false, { names: ["../../other/file"], error: false })
          : ({ names: [], error: false }),
    }),
  )(request());
  equal(r.status, 409);
});
Deno.test("subject: prefix-confusion filename is rejected", async () => {
  let first = true;
  const r = await createDeleteSubjectHandler(
    deps({
      list: async () =>
        first
          ? (first = false, { names: ["file/../../user2"], error: false })
          : ({ names: [], error: false }),
    }),
  )(request());
  equal(r.status, 409);
});
Deno.test("subject: only allowlisted buckets are queried", async () => {
  const seen = new Set<string>();
  await createDeleteSubjectHandler(deps({
    list: async (b) => {
      seen.add(b);
      return { names: [], error: false };
    },
  }))(request());
  equal([...seen], ["study-materials", "study-images"]);
});
Deno.test("subject: only trusted material UUIDs are accepted", async () => {
  let listed = false;
  const r = await createDeleteSubjectHandler(
    deps({
      begin: async () => ({ outcome: "pending", material_ids: ["foreign"] }),
      list: async () => {
        listed = true;
        return { names: [], error: false };
      },
    }),
  )(request());
  equal(r.status, 500);
  assert(!listed);
});
Deno.test("subject: finalization occurs after storage verification", async () => {
  const calls: string[] = [];
  await createDeleteSubjectHandler(deps({
    mark: async (_u, _s, stage) => {
      calls.push(stage);
      return true;
    },
    finalize: async () => {
      calls.push("finalize");
      return true;
    },
  }))(request());
  equal(calls.slice(-2), ["storage_verified", "finalize"]);
});
Deno.test("subject: finalization failure maps to database_cleanup_failed", async () =>
  equal(
    await json(
      await createDeleteSubjectHandler(deps({ finalize: async () => false }))(
        request(),
      ),
    ),
    { code: "database_cleanup_failed", status: "retryable" },
  ));
Deno.test("subject: storage failure never finalizes", async () => {
  let finalized = false;
  await createDeleteSubjectHandler(
    deps({
      list: async () => ({ names: [], error: true }),
      finalize: async () => {
        finalized = true;
        return true;
      },
    }),
  )(request());
  assert(!finalized);
});
Deno.test("subject: oversized provider page cannot overflow counters", async () => {
  const r = await createDeleteSubjectHandler(
    deps({
      list: async () => ({
        names: Array.from({ length: 101 }, (_, i) => `f${i}`),
        error: false,
      }),
    }),
  )(request());
  equal(r.status, 409);
});
Deno.test("subject: provider details never appear in response", async () => {
  const r = await createDeleteSubjectHandler(
    deps({ list: async () => ({ names: [], error: true }) }),
  )(request());
  assert(!(await r.text()).includes("provider-secret"));
});
Deno.test("subject: logs contain only safe fields", async () => {
  let event: Record<string, unknown> = {};
  await createDeleteSubjectHandler(deps({ log: (e) => event = e }))(request());
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
Deno.test("subject: unsupported methods and OPTIONS are handled consistently", async () => {
  const h = createDeleteSubjectHandler(deps());
  equal((await h(new Request("http://local", { method: "GET" }))).status, 405);
  const o = await h(new Request("http://local", { method: "OPTIONS" }));
  equal(o.status, 200);
  assert(o.headers.has("access-control-allow-origin"));
});
