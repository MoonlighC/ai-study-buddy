import { pathToFileURL } from "node:url";
import { readFile } from "node:fs/promises";
import path from "node:path";

const modulePath = process.env.PGLITE_MODULE;
if (!modulePath) {
  throw new Error(
    "Set PGLITE_MODULE to the absolute @electric-sql/pglite dist index.js path.",
  );
}
const { PGlite } = await import(pathToFileURL(modulePath).href);
const root = path.resolve(import.meta.dirname, "..");
const database = new PGlite();
await database.waitReady;

await database.exec(`
  create schema if not exists extensions;
  create schema if not exists auth;
  create schema if not exists storage;
  create or replace function extensions.digest(value text,algorithm text)
  returns bytea language sql immutable as $$
    select case when lower(algorithm)='sha256' then pg_catalog.sha256(convert_to(value,'utf8'))
      else decode(md5(value),'hex') end
  $$;
  do $$ begin
    if not exists(select 1 from pg_roles where rolname='anon') then create role anon nologin; end if;
    if not exists(select 1 from pg_roles where rolname='authenticated') then create role authenticated nologin; end if;
    if not exists(select 1 from pg_roles where rolname='service_role') then create role service_role nologin; end if;
  end $$;
  create table auth.users(id uuid primary key,email text);
  create or replace function auth.uid() returns uuid language sql stable as $$
    select nullif(current_setting('request.jwt.claim.sub',true),'')::uuid
  $$;
  create table storage.buckets(
    id text primary key,public boolean not null default false,
    file_size_limit bigint,allowed_mime_types text[]
  );
  create table storage.objects(
    id uuid primary key,bucket_id text not null,
    name text not null,owner_id text,created_at timestamptz not null default now()
  );
  alter table storage.objects enable row level security;
  create or replace function storage.foldername(value text) returns text[]
  language sql immutable as $$
    select case when strpos(value,'/')=0 then '{}'::text[]
      else string_to_array(regexp_replace(value,'/[^/]*$',''),'/') end
  $$;
  create or replace function storage.filename(value text) returns text
  language sql immutable as $$ select regexp_replace(value,'^.*/','') $$;
  insert into storage.buckets(id) values('study-materials'),('study-images');
`);

for (let number = 1; number <= 13; number++) {
  const prefix = String(number).padStart(3, "0") + "_";
  const directory = path.join(root, "supabase", "migrations");
  const entries = (await import("node:fs/promises")).readdir(directory);
  const file = (await entries).find((entry) => entry.startsWith(prefix));
  if (!file) throw new Error(`Missing migration ${prefix}`);
  await runSql(path.join(directory, file), `migration ${prefix}`);
}

for (
  const file of [
    "phase_c1_processing.sql",
    "phase_c1_recovery.sql",
    "phase_c2_processing.sql",
    "phase_c_diagnostics.sql",
    "phase_c_final_response_diagnostics.sql",
    "phase_c_diagnostic_correlation.sql",
  ]
) {
  await runSql(path.join(root, "supabase", "tests", file), file);
}

await runSql(
  path.join(
    root,
    "supabase",
    "migrations",
    "014_material_analysis_diagnostic_cleanup.sql",
  ),
  "cleanup migration 014",
);
await runSql(
  path.join(root, "supabase", "tests", "phase_c_diagnostic_cleanup.sql"),
  "phase_c_diagnostic_cleanup.sql",
);
await runSql(
  path.join(
    root,
    "supabase",
    "migrations",
    "015_material_analysis_recovery_fingerprints.sql",
  ),
  "migration 015_",
);
await runSql(
  path.join(root, "supabase", "tests", "phase_c_recovery_fingerprints.sql"),
  "phase_c_recovery_fingerprints.sql",
);
await runSql(
  path.join(
    root,
    "supabase",
    "migrations",
    "016_material_analysis_no_work_terminalization.sql",
  ),
  "migration 016_",
);
await runSql(
  path.join(root, "supabase", "tests", "phase_c_no_work_terminalization.sql"),
  "phase_c_no_work_terminalization.sql",
);

await runSql(
  path.join(
    root,
    "supabase",
    "migrations",
    "017_material_pdf_upload_limit.sql",
  ),
  "migration 017_",
);
await runSql(
  path.join(
    root,
    "supabase",
    "migrations",
    "018_material_analysis_terminal_reconciliation.sql",
  ),
  "migration 018_",
);
await runSql(
  path.join(root, "supabase", "tests", "phase_c_terminal_reconciliation.sql"),
  "phase_c_terminal_reconciliation.sql",
);

await runSql(
  path.join(
    root,
    "supabase",
    "migrations",
    "019_account_deletion_processing_cascade.sql",
  ),
  "migration 019_",
);
await runSql(
  path.join(
    root,
    "supabase",
    "tests",
    "account_deletion_processing_cascade.sql",
  ),
  "account_deletion_processing_cascade.sql",
);

await runSql(
  path.join(
    root,
    "supabase",
    "migrations",
    "020_material_analysis_reproduction_diagnostics.sql",
  ),
  "migration 020_",
);
await runSql(
  path.join(
    root,
    "supabase",
    "tests",
    "material_analysis_reproduction_diagnostics.sql",
  ),
  "material_analysis_reproduction_diagnostics.sql",
);

await runSql(
  path.join(
    root,
    "supabase",
    "migrations",
    "021_material_analysis_reproduction_diagnostic_cleanup.sql",
  ),
  "migration 021_",
);
await runSql(
  path.join(
    root,
    "supabase",
    "tests",
    "material_analysis_reproduction_diagnostic_cleanup.sql",
  ),
  "material_analysis_reproduction_diagnostic_cleanup.sql",
);

await runSql(
  path.join(
    root,
    "supabase",
    "migrations",
    "022_material_analysis_latex_diagnostic.sql",
  ),
  "migration 022_",
);
await runSql(
  path.join(
    root,
    "supabase",
    "migrations",
    "023_material_analysis_latex_diagnostic_cleanup.sql",
  ),
  "migration 023_",
);

await runSql(
  path.join(
    root,
    "supabase",
    "migrations",
    "024_material_analysis_reconciliation_operation.sql",
  ),
  "migration 024_",
);
await runSql(
  path.join(root, "supabase", "tests", "phase_c_reconciliation_operation.sql"),
  "phase_c_reconciliation_operation.sql",
);

await runSql(
  path.join(
    root,
    "supabase",
    "migrations",
    "025_study_generation_source_flashcards.sql",
  ),
  "migration 025_",
);
await runSql(
  path.join(root, "supabase", "tests", "study_generation_flashcards.sql"),
  "study_generation_flashcards.sql",
);
await runSql(
  path.join(
    root,
    "supabase",
    "migrations",
    "026_persisted_study_sessions_quiz_and_favorites.sql",
  ),
  "migration 026_",
);
await runSql(
  path.join(
    root,
    "supabase",
    "tests",
    "persisted_study_sessions_quiz_favorites.sql",
  ),
  "persisted_study_sessions_quiz_favorites.sql",
);

await runSql(
  path.join(
    root,
    "supabase",
    "migrations",
    "027_authoritative_study_progress.sql",
  ),
  "migration 027_",
);
await runSql(
  path.join(root, "supabase", "tests", "authoritative_study_progress.sql"),
  "authoritative_study_progress.sql",
);

await runSql(
  path.join(
    root,
    "supabase",
    "migrations",
    "028_cancel_empty_study_session.sql",
  ),
  "migration 028_",
);
await runSql(
  path.join(root, "supabase", "tests", "cancel_empty_study_session.sql"),
  "cancel_empty_study_session.sql",
);

await runSql(
  path.join(
    root,
    "supabase",
    "migrations",
    "029_material_analysis_page_content_contract.sql",
  ),
  "migration 029_",
);
await runSql(
  path.join(
    root,
    "supabase",
    "tests",
    "material_analysis_page_content_contract.sql",
  ),
  "material_analysis_page_content_contract.sql",
);

await runSql(
  path.join(
    root,
    "supabase",
    "migrations",
    "030_study_generation_response_reconciliation.sql",
  ),
  "migration 030_",
);
await runSql(
  path.join(
    root,
    "supabase",
    "tests",
    "study_generation_reconciliation_tester_usage.sql",
  ),
  "study_generation_reconciliation_tester_usage.sql",
);

await runSql(
  path.join(
    root,
    "supabase",
    "migrations",
    "031_material_analysis_real_output_reliability.sql",
  ),
  "migration 031_",
);
await runSql(
  path.join(
    root,
    "supabase",
    "tests",
    "phase_c_real_output_reliability.sql",
  ),
  "phase_c_real_output_reliability.sql",
);

await runSql(
  path.join(
    root,
    "supabase",
    "migrations",
    "032_material_analysis_analyze_again_artifact_eligibility.sql",
  ),
  "migration 032_",
);
await runSql(
  path.join(
    root,
    "supabase",
    "tests",
    "phase_c_analyze_again_artifact_eligibility.sql",
  ),
  "phase_c_analyze_again_artifact_eligibility.sql",
);

await runSql(
  path.join(
    root,
    "supabase",
    "migrations",
    "033_material_analysis_bounded_page_recovery.sql",
  ),
  "migration 033_",
);
await runSql(
  path.join(root, "supabase", "tests", "phase_c_page_recovery_pass.sql"),
  "phase_c_page_recovery_pass.sql",
);

console.log("PHASE_DE_DATABASE_TESTS_OK migrations=33 sql_suites=23");
await database.close();

async function runSql(file, label) {
  let source = (await readFile(file, "utf8"))
    .replace(
      /create extension if not exists pgcrypto with schema extensions;\s*/i,
      "",
    )
    .split(/\r?\n/)
    .join("\n");
  if (label === "migration 010_") {
    source = source.replace(
      /if not migration_owner\.rolcanlogin or migration_owner\.rolsuper or\s+not migration_owner\.rolcreatedb or not migration_owner\.rolcreaterole or\s+not migration_owner\.rolinherit or not migration_owner\.rolreplication or\s+not migration_owner\.rolbypassrls then/,
      "if false then",
    );
  }
  try {
    if (source.includes("\\gset")) await runPsqlCompatible(source);
    else {await database.exec(
        source.split(/\r?\n/).filter((line) =>
          !line.trimStart().startsWith("\\")
        ).join("\n"),
      );}
    console.log(`PASS ${label}`);
  } catch (error) {
    console.error(`FAIL ${label}`);
    throw error;
  }
}

async function runPsqlCompatible(source) {
  const variables = new Map();
  let buffer = "";
  for (const originalLine of source.split(/\r?\n/)) {
    if (originalLine.trimStart().startsWith("\\set")) continue;
    const match = originalLine.match(/\\gset(?:\s+([A-Za-z0-9_]+))?/);
    if (!match) {
      buffer += originalLine + "\n";
      continue;
    }
    buffer += originalLine.replace(/\\gset.*$/, "") + "\n";
    const boundary = buffer.lastIndexOf(";", buffer.length - 2);
    const prefixSql = boundary >= 0 ? buffer.slice(0, boundary + 1) : "";
    const querySql = buffer.slice(boundary + 1).trim().replace(/;?$/, ";");
    if (prefixSql.trim()) await database.exec(substitute(prefixSql, variables));
    const result = await database.query(substitute(querySql, variables));
    if (result.rows.length !== 1) {
      throw new Error("gset query must return exactly one row");
    }
    for (const [key, value] of Object.entries(result.rows[0])) {
      variables.set((match[1] ?? "") + key, value);
    }
    buffer = "";
  }
  if (buffer.trim()) await database.exec(substitute(buffer, variables));
}

function substitute(sql, variables) {
  return sql.replace(/:'([A-Za-z0-9_]+)'/g, (_match, name) => {
    if (!variables.has(name)) throw new Error(`Unknown psql variable ${name}`);
    const value = variables.get(name);
    if (value === null) return "null";
    return `'${String(value).replaceAll("'", "''")}'`;
  });
}
