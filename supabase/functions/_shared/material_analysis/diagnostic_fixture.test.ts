import { sha256Hex } from "./fingerprints_retry.ts";
import { buildSyntheticPdf } from "./synthetic_pdf_fixtures.ts";

Deno.test("pre-committed diagnostic fixture fingerprint is deterministic", async () => {
  const first = await buildSyntheticPdf(["vector"]);
  const second = await buildSyntheticPdf(["vector"]);
  assertEquals(first, second);
  assertEquals(first.byteLength, 1946);
  const fingerprint = await sha256Hex(first);
  assertEquals(
    fingerprint,
    "9c4df300f7bff18e8522322f3973b36bdc3186122af01ffdbc5852669b40f46a",
  );
  const migration = await Deno.readTextFile(
    new URL(
      "../../../migrations/013_material_analysis_diagnostic_target_selection.sql",
      import.meta.url,
    ),
  );
  assertEquals(migration.includes(fingerprint), true);
  assertEquals(migration.includes("m.title"), false);
  assertEquals(migration.includes("domain_profile"), false);
});

function assertEquals(actual: unknown, expected: unknown) {
  if (JSON.stringify(actual) !== JSON.stringify(expected)) {
    throw new Error("diagnostic fixture assertion failed");
  }
}
