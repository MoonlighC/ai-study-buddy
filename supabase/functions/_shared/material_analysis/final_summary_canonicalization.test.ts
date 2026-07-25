import {
  canonicalizeFinalSummaryPartition,
  ProviderBoundaryError,
  ProviderRequest,
  validateProviderOutput,
} from "./openai_adapter.ts";
import { finalSummaryPartitionOverlapFixture } from "./final_summary_canonicalization_fixture.ts";

Deno.test("authoritative manifest canonicalizes overlapping partial page", () => {
  const request = fixtureRequest();
  const providerResult = clone(
    finalSummaryPartitionOverlapFixture.providerResult,
  );
  const canonical = canonicalizeFinalSummaryPartition(request, providerResult);

  equal(canonical.comparison, {
    changed: true,
    duplicateMembership: true,
    classificationChanged: true,
    orderingChanged: false,
    providerCounts: { analyzed: 1, partial: 1, missing: 0 },
    canonicalCounts: { analyzed: 0, partial: 1, missing: 0 },
  });
  equal(
    (canonical.result as Record<string, any>).partial_extraction,
    {
      is_partial: true,
      analyzed_pages: [],
      partial_pages: [1],
      missing_pages: [],
      page_modes: [{ page: 1, mode: "visual" }],
    },
  );
  equal(validateProviderOutput(request, providerResult), canonical.result);
});

Deno.test("provider partition with an out-of-range page remains invalid", () => {
  const result = clone(finalSummaryPartitionOverlapFixture.providerResult);
  result.partial_extraction.analyzed_pages = [2];
  rejectsProviderOutput(fixtureRequest(), result);
});

Deno.test("authoritative manifest with a duplicate page is rejected", () => {
  const request = requestForManifest([
    manifestPage(1, "partial"),
    manifestPage(1, "completed"),
  ], 2);
  rejectsRequest(() =>
    canonicalizeFinalSummaryPartition(
      request,
      clone(finalSummaryPartitionOverlapFixture.providerResult),
    )
  );
});

Deno.test("authoritative manifest must cover page_count", () => {
  const request = requestForManifest([manifestPage(1, "partial")], 2);
  rejectsRequest(() =>
    canonicalizeFinalSummaryPartition(
      request,
      clone(finalSummaryPartitionOverlapFixture.providerResult),
    )
  );
});

Deno.test("malformed partial_extraction type remains invalid", () => {
  const result = clone(
    finalSummaryPartitionOverlapFixture.providerResult,
  ) as Record<string, unknown>;
  result.partial_extraction = [];
  rejectsProviderOutput(fixtureRequest(), result);
});

Deno.test("unrelated semantic error still fails after canonicalization", () => {
  const result = clone(finalSummaryPartitionOverlapFixture.providerResult);
  result.sections[0].source_pages = [2];
  rejectsProviderOutput(fixtureRequest(), result);
});

function fixtureRequest(): ProviderRequest {
  return requestForManifest(
    clone(finalSummaryPartitionOverlapFixture.manifest),
    finalSummaryPartitionOverlapFixture.pageCount,
  );
}

function requestForManifest(
  manifest: unknown[],
  pageCount: number,
): ProviderRequest {
  const expectedPages = Array.from(
    { length: pageCount },
    (_, index) => index + 1,
  );
  return {
    operation: "final_summary",
    input: {
      kind: "text",
      text: JSON.stringify({
        operation: "final_summary",
        authoritative_equations: [],
        validated_reduction: {
          source_pages: expectedPages,
          summary_markdown: "Sanitized grounded reduction.",
          key_concepts: [],
          equation_ids: [],
          warnings: [],
          confidence: 0.8,
        },
        manifest,
      }),
    },
    expectedPages,
    allowedEquationIds: [],
    authoritativeEquations: [],
    pageCount,
    idempotencyKey: "c".repeat(64),
  };
}

function manifestPage(
  pageNumber: number,
  status: "completed" | "partial" | "missing",
) {
  return {
    page_number: pageNumber,
    status,
    route: "visual",
    warnings: status === "partial"
      ? [{
        code: "page_content_partial",
        detail: "Only grounded included content is retained.",
        source_pages: [pageNumber],
      }]
      : [],
  };
}

function rejectsProviderOutput(request: ProviderRequest, result: unknown) {
  let error: unknown;
  try {
    validateProviderOutput(request, result);
  } catch (caught) {
    error = caught;
  }
  equal(error instanceof ProviderBoundaryError, true);
}

function rejectsRequest(action: () => unknown) {
  let error: unknown;
  try {
    action();
  } catch (caught) {
    error = caught;
  }
  equal((error as Error | undefined)?.message, "invalid_final_summary_request");
}

function clone<T>(value: T): T {
  return JSON.parse(JSON.stringify(value));
}

function equal(actual: unknown, expected: unknown) {
  if (JSON.stringify(actual) !== JSON.stringify(expected)) {
    throw new Error(
      `Expected ${JSON.stringify(expected)}, got ${JSON.stringify(actual)}`,
    );
  }
}
