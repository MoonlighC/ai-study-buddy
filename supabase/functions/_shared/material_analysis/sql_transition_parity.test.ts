import {
  batchTransitions,
  jobTransitions,
  pageTransitions,
  TransitionRule,
} from "./state_machines.ts";

const migration = await Deno.readTextFile(
  new URL(
    "../../../migrations/010_material_analysis_processing.sql",
    import.meta.url,
  ),
);

Deno.test("SQL is the authoritative transition pair source and TypeScript matches it", () => {
  assertParity("job", jobTransitions);
  assertParity("page", pageTransitions);
  assertParity("batch", batchTransitions);
});

Deno.test("SQL and TypeScript both reject status self-transitions", () => {
  includes(functionBody("job"), "old.status = new.status");
  includes(functionBody("page"), "old.status = new.status");
  includes(functionBody("batch"), "old.status = new.status");
  for (const table of [jobTransitions, pageTransitions, batchTransitions]) {
    if (table.some((rule) => rule.from === rule.to)) {
      throw new Error("typescript_self_transition");
    }
  }
});

function assertParity(
  kind: "job" | "page" | "batch",
  rules: TransitionRule<string>[],
) {
  const body = functionBody(kind);
  const start = body.indexOf("if not ((old.status,new.status) in (");
  const end = body.indexOf(")) then", start);
  if (start < 0 || end < 0) {
    throw new Error(`sql_transition_list_missing:${kind}`);
  }
  const sqlPairs = [
    ...body.slice(start, end).matchAll(/\('([^']+)','([^']+)'\)/g),
  ]
    .map((match) => `${match[1]}->${match[2]}`)
    .sort();
  const tsPairs = rules.map((rule) => `${rule.from}->${rule.to}`).sort();
  equal(sqlPairs, tsPairs);
}

function functionBody(kind: "job" | "page" | "batch") {
  const start = migration.indexOf(
    `function public.enforce_material_processing_${kind}_row()`,
  );
  if (start < 0) throw new Error(`sql_function_missing:${kind}`);
  const end = migration.indexOf("$$;", start);
  if (end < 0) throw new Error(`sql_function_unterminated:${kind}`);
  return migration.slice(start, end);
}

function includes(actual: string, expected: string) {
  if (!actual.includes(expected)) {
    throw new Error(`Expected SQL to include ${expected}`);
  }
}
function equal(actual: unknown, expected: unknown) {
  if (JSON.stringify(actual) !== JSON.stringify(expected)) {
    throw new Error(
      `Expected ${JSON.stringify(expected)}, got ${JSON.stringify(actual)}`,
    );
  }
}
