function assert(value: unknown): asserts value {
  if (!value) throw new Error("assertion_failed");
}

function assertEquals(actual: unknown, expected: unknown): void {
  if (actual !== expected) throw new Error("assertion_failed");
}

const migration = await Deno.readTextFile(
  new URL(
    "../../../migrations/015_material_analysis_recovery_fingerprints.sql",
    import.meta.url,
  ),
);
const originalMigration = await Deno.readTextFile(
  new URL(
    "../../../migrations/010_material_analysis_processing.sql",
    import.meta.url,
  ),
);

Deno.test("first page generation preserves the original fingerprint contract", () => {
  assert(
    migration.includes(
      "case when max(grouped_attempts+recovery_attempts)=0 then '' else",
    ),
  );
});

Deno.test("page recovery generation binds both immutable attempt counters", () => {
  assert(
    migration.includes(
      "page_number::text||'='||grouped_attempts::text||'/'||recovery_attempts::text",
    ),
  );
  assert(migration.includes("':logical_generation:'"));
  for (const unstableInput of ["clock_timestamp", "random()", "created_at::text"]) {
    assertEquals(migration.includes(unstableInput), false);
  }
});

Deno.test("reduction and final summary fingerprint formulas are unchanged", () => {
  for (const formula of [
    "v_job.version_fingerprint||':reduction:1:'||v_job.id::text",
    "v_job.version_fingerprint||':reduction:'||(v_level+1)::text",
    "v_job.version_fingerprint||':final:'||v_job.id::text",
  ]) {
    assert(migration.includes(formula));
    assert(originalMigration.includes(formula));
  }
});

Deno.test("job fingerprint uniqueness and service-only claim authority remain enforced", () => {
  assert(originalMigration.includes("unique (job_id, fingerprint)"));
  assert(
    migration.includes(
      "revoke all on function public.claim_next_material_analysis_operation_internal(uuid)",
    ),
  );
  assert(
    migration.includes(
      "grant execute on function public.claim_next_material_analysis_operation_internal(uuid)",
    ),
  );
});
