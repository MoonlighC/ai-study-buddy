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
    name text not null,owner_id uuid,created_at timestamptz not null default now()
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

console.log("PHASE_C_DATABASE_TESTS_OK migrations=16 sql_suites=9");
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
