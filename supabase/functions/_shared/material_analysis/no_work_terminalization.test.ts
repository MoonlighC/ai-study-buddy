function assert(value: unknown): asserts value {
  if (!value) throw new Error("assertion_failed");
}

function assertEquals(actual: unknown, expected: unknown): void {
  if (actual !== expected) throw new Error("assertion_failed");
}

const migration = await Deno.readTextFile(
  new URL(
    "../../../migrations/016_material_analysis_no_work_terminalization.sql",
    import.meta.url,
  ),
);
const recoveryMigration = await Deno.readTextFile(
  new URL(
    "../../../migrations/015_material_analysis_recovery_fingerprints.sql",
    import.meta.url,
  ),
);

Deno.test("no-work terminalization uses the existing bounded failure contract", () => {
  for (
    const fragment of [
      "status='failed'",
      "safe_error_code='unable_to_extract_content'",
      "budget_state='released'",
      "processing_status='failed'",
    ]
  ) assert(migration.includes(fragment));
  assert(
    migration.includes(
      "status not in ('completed','partial','missing')",
    ),
  );
  assert(
    migration.includes("status in ('completed','partial')"),
  );
});

Deno.test("terminalization branch creates no downstream operation", () => {
  const terminalStart = migration.indexOf(
    "if not exists(select 1 from public.material_processing_pages",
  );
  const terminalEnd = migration.indexOf(
    "elsif cardinality(v_pages)>0 then",
    terminalStart,
  );
  assert(terminalStart >= 0 && terminalEnd > terminalStart);
  const branch = migration.slice(terminalStart, terminalEnd);
  for (
    const forbidden of [
      "create_material_processing_batch_internal",
      "submit_material_analysis_operation_internal",
      "material_processing_attempts",
      "summary_payload=",
    ]
  ) assertEquals(branch.includes(forbidden), false);
});

Deno.test("recovery and downstream fingerprint contracts remain unchanged", () => {
  for (
    const formula of [
      "page_number::text||'='||grouped_attempts::text||'/'||recovery_attempts::text",
      "v_job.version_fingerprint||':reduction:1:'||v_job.id::text",
      "v_job.version_fingerprint||':reduction:'||(v_level+1)::text",
      "v_job.version_fingerprint||':final:'||v_job.id::text",
    ]
  ) {
    assert(migration.includes(formula));
    assert(recoveryMigration.includes(formula));
  }
});

Deno.test("replacement claim keeps fixed authority and search path", () => {
  assert(migration.includes("security definer"));
  assert(migration.includes("set search_path = pg_catalog, public"));
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
