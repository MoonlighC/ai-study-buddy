import {
  canonicalizeFinalSummaryEquations,
  canonicalizePageBatchResult,
  canonicalizeReductionResult,
  ProviderRequest,
  validateProviderOutput,
  validateProviderOutputWithMetadata,
  validateProviderRequest,
} from "./openai_adapter.ts";
import {
  validateDownstreamPageBatchResult,
  validatePageBatchResult,
  validatePageResult,
  validateReductionResult,
  validateSummarySemantics,
} from "./schemas.ts";
import {
  grumciAuthoritativeEquation,
  grumciFinalSummary,
  grumciReduction,
  gti6FinalReductionRaw,
  gti6Pages11To15Provider,
  gti6Pages11To15Raw,
  gti7Pages21To25,
  gti7Pages26To30,
  gti9AuthoritativeEquationIds,
  gti9GlobalReductionRaw,
  ss24Pages11To13WithStray10,
  ss24Pages1To5MissingUntrustworthy,
  ss24Pages6To10MissingUntrustworthy,
  ss24Pages6To9,
} from "./phase_c_real_failure_fixtures.ts";

Deno.test("gti6 raw page warning fails at the exact provider contract", () => {
  const validation = validatePageBatchResult(
    gti6Pages11To15Raw,
    [11, 12, 13, 14, 15],
    50,
  );
  equal(validation.valid, false);
  includes(validation.errors, "page_12:page_warning_code_not_allowed");
});

Deno.test("gti6 Boolean expression canonicalizes without unrelated changes", () => {
  const original = clone(gti6Pages11To15Provider);
  const canonical = canonicalizePageBatchResult(
    original,
    [11, 12, 13, 14, 15],
    50,
  );
  equal(canonical.valid, true);
  const result = canonical.result as any;
  equal(
    result.pages[1].equations[0].latex,
    String.raw`A = (E_1 \times S) \vee (E_2 \times \bar{S})`,
  );
  equal(result.pages[0], original.pages[0]);
  equal(canonical.degradedEquationIds, []);
});

Deno.test("gti7 positive pages 21-25 remain valid", () => {
  equal(
    validatePageBatchResult(gti7Pages21To25, [21, 22, 23, 24, 25], 50)
      .valid,
    true,
  );
});

Deno.test("gti7 pages 26-30 repair partial warning status and LaTeX", () => {
  const rawPage29 = gti7Pages26To30.pages[3];
  equal(
    rawPage29.content_status === "completed" &&
      rawPage29.warnings.some((warning: any) =>
        warning.code === "page_content_partial"
      )
      ? "page_29:completed_status_warning_conflict"
      : null,
    "page_29:completed_status_warning_conflict",
  );

  const canonical = canonicalizePageBatchResult(
    gti7Pages26To30,
    [26, 27, 28, 29, 30],
    50,
  );
  equal(canonical.valid, true);
  const result = canonical.result as any;
  equal(result.pages[3].content_status, "partial");
  equal(result.pages[3].warnings[0].code, "page_content_partial");
  equal(
    result.pages[3].equations[0].latex,
    String.raw`x_1,\ldots,x_n`,
  );
  equal(result.pages[4].equations[0].latex, "x + y");
  equal(result.pages.slice(0, 3), gti7Pages26To30.pages.slice(0, 3));
});

Deno.test("invalid equation degrades only its page and preserves its batch", () => {
  const fixture = clone(gti7Pages21To25);
  fixture.pages[2].equations = [{
    ...grumciAuthoritativeEquation,
    id: "eq_page23_bad",
    source_page: 23,
    latex: String.raw`\href{unsafe}{x}`,
  }];
  const canonical = canonicalizePageBatchResult(
    fixture,
    [21, 22, 23, 24, 25],
    50,
  );
  equal(canonical.valid, true);
  const result = canonical.result as any;
  equal(result.pages[2].content_status, "partial");
  equal(result.pages[2].confidence, 0.5);
  equal(result.pages[2].equations, []);
  equal(
    result.pages[2].warnings.map((warning: any) => warning.code),
    ["invalid_equation_latex", "page_content_partial"],
  );
  equal(
    validateDownstreamPageBatchResult(
      result,
      [21, 22, 23, 24, 25],
      50,
    ).valid,
    true,
  );
  equal(canonical.degradedEquationIds, ["eq_page23_bad"]);
  equal(
    [result.pages[0], result.pages[1], result.pages[3], result.pages[4]],
    [fixture.pages[0], fixture.pages[1], fixture.pages[3], fixture.pages[4]],
  );
});

Deno.test("ss24 pages 6-10 synthesize only the omitted missing page", () => {
  const expectedPages = [6, 7, 8, 9, 10];
  const raw = validatePageBatchResult(ss24Pages6To9, expectedPages, 13);
  equal(raw.valid, false);
  includes(raw.errors, "page_batch_provenance");

  const canonical = canonicalizePageBatchResult(
    ss24Pages6To9,
    expectedPages,
    13,
  );
  equal(canonical.valid, true);
  equal(canonical.comparison, {
    expectedPageCount: 5,
    returnedPageCount: 4,
    normalizedMissingTrustworthyCount: 0,
    discardedStrayPageCount: 0,
    synthesizedMissingPageCount: 1,
    missingPageNumbersCount: 1,
  });
  const result = canonical.result as any;
  equal(
    result.pages.slice(0, 4),
    ss24Pages6To9.pages,
  );
  equal(
    result.pages.map((page: any) => page.page_number),
    expectedPages,
  );
  equal(result.pages[4], {
    page_number: 10,
    content_status: "missing",
    summary_markdown: "",
    key_concepts: [],
    equations: [],
    confidence: 0,
    warnings: [{
      code: "page_missing",
      detail: "This page could not be analyzed.",
      source_pages: [10],
    }, {
      code: "page_content_missing",
      detail: "No usable grounded content was available.",
      source_pages: [10],
    }],
    trustworthy: true,
  });
  equal(
    validateDownstreamPageBatchResult(result, expectedPages, 13).valid,
    true,
  );
});

Deno.test("ss24 page 5 normalizes only missing trustworthy", () => {
  const fixture = clone(ss24Pages1To5MissingUntrustworthy);
  const raw = validatePageBatchResult(fixture, [1, 2, 3, 4, 5], 13);
  equal(raw.valid, false);
  includes(raw.errors, "page_5:trustworthy_content_required");

  const canonical = canonicalizePageBatchResult(
    fixture,
    [1, 2, 3, 4, 5],
    13,
  );
  equal(canonical.valid, true);
  const expected = clone(fixture);
  expected.pages[4].trustworthy = true;
  equal(canonical.result, expected);
  equal(canonical.comparison, {
    expectedPageCount: 5,
    returnedPageCount: 5,
    normalizedMissingTrustworthyCount: 1,
    discardedStrayPageCount: 0,
    synthesizedMissingPageCount: 0,
    missingPageNumbersCount: 0,
  });
  equal(
    validateDownstreamPageBatchResult(
      canonical.result,
      [1, 2, 3, 4, 5],
      13,
    ).valid,
    true,
  );
});

Deno.test("ss24 page 10 normalizes only missing trustworthy", () => {
  const fixture = clone(ss24Pages6To10MissingUntrustworthy);
  const raw = validatePageBatchResult(fixture, [6, 7, 8, 9, 10], 13);
  equal(raw.valid, false);
  includes(raw.errors, "page_10:trustworthy_content_required");

  const canonical = canonicalizePageBatchResult(
    fixture,
    [6, 7, 8, 9, 10],
    13,
  );
  equal(canonical.valid, true);
  const expected = clone(fixture);
  expected.pages[4].trustworthy = true;
  equal(canonical.result, expected);
  equal(canonical.comparison.normalizedMissingTrustworthyCount, 1);
  equal(canonical.comparison.discardedStrayPageCount, 0);
  equal(canonical.comparison.synthesizedMissingPageCount, 0);
  equal(
    validateDownstreamPageBatchResult(
      canonical.result,
      [6, 7, 8, 9, 10],
      13,
    ).valid,
    true,
  );
});

Deno.test("ss24 stray page 10 is discarded and page 13 is synthesized", () => {
  const fixture = clone(ss24Pages11To13WithStray10);
  equal(validatePageResult(fixture.pages[2], 10, 13).valid, true);
  const raw = validatePageBatchResult(fixture, [11, 12, 13], 13);
  equal(raw.valid, false);
  includes(raw.errors, "page_batch_provenance");

  const canonical = canonicalizePageBatchResult(
    fixture,
    [11, 12, 13],
    13,
  );
  equal(canonical.valid, true);
  equal(canonical.comparison, {
    expectedPageCount: 3,
    returnedPageCount: 3,
    normalizedMissingTrustworthyCount: 0,
    discardedStrayPageCount: 1,
    synthesizedMissingPageCount: 1,
    missingPageNumbersCount: 1,
  });
  const result = canonical.result as any;
  equal(
    result.pages.map((page: any) => page.page_number),
    [11, 12, 13],
  );
  equal(result.pages.slice(0, 2), fixture.pages.slice(0, 2));
  equal(result.pages[2], {
    page_number: 13,
    content_status: "missing",
    summary_markdown: "",
    key_concepts: [],
    equations: [],
    confidence: 0,
    warnings: [{
      code: "page_missing",
      detail: "This page could not be analyzed.",
      source_pages: [13],
    }, {
      code: "page_content_missing",
      detail: "No usable grounded content was available.",
      source_pages: [13],
    }],
    trustworthy: true,
  });
  equal(JSON.stringify(result).includes("Stray page 10"), false);
  equal(
    validateDownstreamPageBatchResult(result, [11, 12, 13], 13).valid,
    true,
  );
});

Deno.test("missing trustworthy normalization remains fail closed", () => {
  const nonEmpty = clone(ss24Pages1To5MissingUntrustworthy);
  nonEmpty.pages[4].summary_markdown = "Must not be retained.";
  equal(
    canonicalizePageBatchResult(nonEmpty, [1, 2, 3, 4, 5], 13).valid,
    false,
  );

  const noWarning = clone(ss24Pages1To5MissingUntrustworthy);
  noWarning.pages[4].warnings = [];
  equal(
    canonicalizePageBatchResult(noWarning, [1, 2, 3, 4, 5], 13).valid,
    false,
  );

  const wrongProvenance = clone(
    ss24Pages1To5MissingUntrustworthy,
  ) as any;
  wrongProvenance.pages[4].warnings[0].source_pages = [4];
  equal(
    canonicalizePageBatchResult(
      wrongProvenance,
      [1, 2, 3, 4, 5],
      13,
    ).valid,
    false,
  );

  const completed = clone(ss24Pages1To5MissingUntrustworthy);
  completed.pages[4] = {
    ...completed.pages[3],
    page_number: 5,
    trustworthy: false,
  };
  equal(
    canonicalizePageBatchResult(completed, [1, 2, 3, 4, 5], 13).valid,
    false,
  );
});

Deno.test("stray page discard remains fail closed", () => {
  const twoStrays = clone(ss24Pages11To13WithStray10) as any;
  twoStrays.pages.push({
    ...clone(twoStrays.pages[2]),
    page_number: 9,
    warnings: [{
      ...clone(twoStrays.pages[2].warnings[0]),
      source_pages: [9],
    }],
  });
  equal(
    canonicalizePageBatchResult(twoStrays, [11, 12, 13], 13).valid,
    false,
  );

  const twoMissing = clone(ss24Pages11To13WithStray10);
  twoMissing.pages.splice(1, 1);
  equal(
    canonicalizePageBatchResult(twoMissing, [11, 12, 13], 13).valid,
    false,
  );

  const duplicateExpected = clone(ss24Pages11To13WithStray10);
  duplicateExpected.pages[1] = clone(duplicateExpected.pages[0]);
  equal(
    canonicalizePageBatchResult(
      duplicateExpected,
      [11, 12, 13],
      13,
    ).valid,
    false,
  );

  const mixedProvenance = clone(ss24Pages11To13WithStray10) as any;
  mixedProvenance.pages[2].warnings[0].source_pages = [10, 11];
  equal(
    canonicalizePageBatchResult(
      mixedProvenance,
      [11, 12, 13],
      13,
    ).valid,
    false,
  );

  const expectedEquation = clone(ss24Pages11To13WithStray10) as any;
  expectedEquation.pages[2].equations = [{
    id: "eq_stray_expected",
    latex: "x + y",
    explanation_markdown: "Sanitized equation.",
    source_page: 11,
    display: "block",
    confidence: 0.9,
    uncertainty: false,
  }];
  equal(
    canonicalizePageBatchResult(
      expectedEquation,
      [11, 12, 13],
      13,
    ).valid,
    false,
  );
});

Deno.test("page omission repair remains strict for provider output", () => {
  const expectedPages = [6, 7, 8, 9, 10];
  const duplicate = clone(ss24Pages6To9);
  duplicate.pages[3].page_number = 8;
  equal(
    canonicalizePageBatchResult(duplicate, expectedPages, 13).valid,
    false,
  );

  const unexpected = clone(ss24Pages6To9);
  unexpected.pages[3].page_number = 11;
  equal(
    canonicalizePageBatchResult(unexpected, expectedPages, 13).valid,
    false,
  );

  const substitution = clone(ss24Pages6To9);
  substitution.pages[3].page_number = 10;
  equal(
    canonicalizePageBatchResult(substitution, expectedPages, 13).valid,
    false,
  );

  const malformed = clone(ss24Pages6To9) as any;
  malformed.pages[2].unexpected = true;
  equal(
    canonicalizePageBatchResult(malformed, expectedPages, 13).valid,
    false,
  );

  const providerMissingWarning = clone(ss24Pages6To9) as any;
  providerMissingWarning.pages[0].warnings = [{
    code: "page_missing",
    detail: "Provider must not emit this downstream warning.",
    source_pages: [6],
  }];
  const forbidden = canonicalizePageBatchResult(
    providerMissingWarning,
    expectedPages,
    13,
  );
  equal(forbidden.valid, false);
  equal(forbidden.providerWarningViolation?.code, "page_missing");
});

Deno.test("page omission repair supports multiple absent expected pages", () => {
  const provider = {
    pages: [ss24Pages6To9.pages[0], ss24Pages6To9.pages[2]],
  };
  const canonical = canonicalizePageBatchResult(
    provider,
    [6, 7, 8, 9, 10],
    13,
  );
  equal(canonical.valid, true);
  const result = canonical.result as any;
  equal(
    result.pages.map((page: any) => page.page_number),
    [6, 7, 8, 9, 10],
  );
  equal(
    result.pages.filter((page: any) => page.content_status === "missing")
      .length,
    3,
  );
  equal(canonical.comparison.synthesizedMissingPageCount, 3);
});

Deno.test("gti6 final reduction drops one serialized-list concept only", () => {
  const allowedPages = gti6FinalReductionRaw.source_pages;
  const allowedEquationIds = ["eq_page41_1"];
  equal(
    validateReductionResult(
      gti6FinalReductionRaw,
      allowedPages,
      allowedEquationIds,
    ).valid,
    false,
  );
  const canonical = canonicalizeReductionResult(
    gti6FinalReductionRaw,
    allowedPages,
    allowedEquationIds,
  );
  equal(canonical.valid, true);
  equal(canonical.comparison, {
    inputConceptCount: 3,
    acceptedConceptCount: 2,
    duplicateConceptCount: 0,
    oversizedConceptCount: 1,
    serializedListConceptCount: 1,
    droppedConceptCount: 1,
  });
  const result = canonical.result as any;
  equal(result.key_concepts, [
    "Nullausgabebedingung",
    "Boolean algebra laws",
  ]);
  equal(
    result.key_concepts.some((concept: string) =>
      concept.includes("switch algebra")
    ),
    false,
  );
  for (
    const field of [
      "summary_markdown",
      "source_pages",
      "equation_ids",
      "warnings",
      "confidence",
    ]
  ) {
    equal(result[field], (gti6FinalReductionRaw as any)[field]);
  }
  equal(
    validateReductionResult(result, allowedPages, allowedEquationIds).valid,
    true,
  );
});

Deno.test("reduction key concepts reject structure without reconstruction", () => {
  const fixture = {
    ...clone(grumciReduction),
    key_concepts: [
      "Sichere deutsche Erklärung",
      "Safe English concept",
      "Safe   English\u00a0concept",
      "https://example.test/private",
      "portal.example.ai/private",
      "**Markdown**",
      "<strong>HTML</strong>",
      "first line\nsecond line",
      "one','two",
      '["one","two"]',
      '{"one":"two"}',
      "control\u0007value",
      " ",
    ],
  };
  const canonical = canonicalizeReductionResult(
    fixture,
    [1, 2, 3, 4],
    ["eq_page1_1"],
  );
  equal(canonical.valid, true);
  const result = canonical.result as any;
  equal(result.key_concepts, [
    "Sichere deutsche Erklärung",
    "Safe English concept",
  ]);
  equal(canonical.comparison, {
    inputConceptCount: 13,
    acceptedConceptCount: 2,
    duplicateConceptCount: 1,
    oversizedConceptCount: 0,
    serializedListConceptCount: 2,
    droppedConceptCount: 11,
  });
  equal(result.summary_markdown, fixture.summary_markdown);
  equal(result.equation_ids, fixture.equation_ids);
});

Deno.test("reduction canonicalization caps safely and cannot mask bad provenance", () => {
  const many = {
    ...clone(grumciReduction),
    key_concepts: Array.from(
      { length: 102 },
      (_, index) => `Safe concept ${index + 1}`,
    ),
  };
  const capped = canonicalizeReductionResult(
    many,
    [1, 2, 3, 4],
    ["eq_page1_1"],
  );
  equal(capped.valid, true);
  equal((capped.result as any).key_concepts.length, 24);
  equal(capped.comparison.droppedConceptCount, 78);

  const wrongEquation = {
    ...clone(grumciReduction),
    equation_ids: ["eq_unknown"],
    key_concepts: ["Valid concept", "one','two"],
  };
  equal(
    canonicalizeReductionResult(
      wrongEquation,
      [1, 2, 3, 4],
      ["eq_page1_1"],
    ).valid,
    false,
  );

  const wrongProvenance = {
    ...clone(grumciReduction),
    source_pages: [1, 2, 3],
    key_concepts: ["Valid concept", "one','two"],
  };
  equal(
    canonicalizeReductionResult(
      wrongProvenance,
      [1, 2, 3, 4],
      ["eq_page1_1"],
    ).valid,
    false,
  );
});

Deno.test("gti9 global reduction drops the exact bare serialized list and prepares final summary", () => {
  equal(gti9GlobalReductionRaw.key_concepts.length, 100);
  equal([...gti9GlobalReductionRaw.key_concepts[1]].length, 1900);
  const canonical = canonicalizeReductionResult(
    gti9GlobalReductionRaw,
    gti9GlobalReductionRaw.source_pages,
    gti9AuthoritativeEquationIds,
  );
  equal(canonical.valid, true);
  equal(canonical.comparison, {
    inputConceptCount: 100,
    acceptedConceptCount: 24,
    duplicateConceptCount: 0,
    oversizedConceptCount: 1,
    serializedListConceptCount: 1,
    droppedConceptCount: 76,
  });
  const repaired = canonical.result as any;
  equal(repaired.key_concepts.length, 24);
  equal(repaired.key_concepts[0], "Finite-state machines");
  equal(repaired.key_concepts[1], "Mealy and Moore automata");
  equal(
    repaired.key_concepts.some((concept: string) =>
      concept.includes("capture register','parallel loading")
    ),
    false,
  );
  for (
    const field of [
      "summary_markdown",
      "source_pages",
      "equation_ids",
      "warnings",
      "confidence",
    ]
  ) {
    equal(repaired[field], (gti9GlobalReductionRaw as any)[field]);
  }

  const authoritativeEquations = gti9AuthoritativeEquationIds.map(
    (id, index) => ({
      id,
      latex: `x_${index + 1}`,
      explanation_markdown: "Sanitized grounded equation.",
      source_page: index + 1,
      display: "block" as const,
      confidence: 0.9,
      uncertainty: false,
    }),
  );
  validateProviderRequest({
    operation: "final_summary",
    input: {
      kind: "text",
      text: JSON.stringify({
        operation: "final_summary",
        validated_reduction: repaired,
        authoritative_equations: authoritativeEquations,
        manifest: gti9GlobalReductionRaw.source_pages.map((page) => ({
          page_number: page,
          status: "completed",
          route: "visual",
          warnings: page <= 8
            ? [gti9GlobalReductionRaw.warnings[page - 1]]
            : [],
        })),
      }),
    },
    expectedPages: gti9GlobalReductionRaw.source_pages,
    allowedEquationIds: gti9AuthoritativeEquationIds,
    authoritativeEquations,
    pageCount: 55,
    idempotencyKey: "e".repeat(64),
  });
});

Deno.test("GruMCI reduction remains valid", () => {
  equal(
    validateReductionResult(
      grumciReduction,
      [1, 2, 3, 4],
      ["eq_page1_1"],
    ).valid,
    true,
  );
});

Deno.test("GruMCI orphan equation attaches to its unique sourced section", () => {
  const request = finalRequest();
  const canonical = canonicalizeFinalSummaryEquations(
    request,
    clone(grumciFinalSummary),
  );
  equal(canonical.valid, true);
  const result = canonical.result as any;
  equal(canonical.comparison.orphanReferencesAdded, 1);
  equal(
    result.sections[0].blocks[1],
    { kind: "equation", equation_id: "eq_page1_1", display: "block" },
  );
  const validated = validateProviderOutput(
    request,
    clone(grumciFinalSummary),
  );
  equal(validateSummarySemantics(validated, 4).valid, true);
});

Deno.test("gti6 final summary restores an authoritative referenced equation object", () => {
  const request = finalRequest();
  const referencedOnly = clone(grumciFinalSummary);
  referencedOnly.sections[0].blocks.push({
    kind: "equation",
    equation_id: "eq_page1_1",
    display: "block",
  } as any);
  referencedOnly.equations = [];

  const canonical = canonicalizeFinalSummaryEquations(
    request,
    referencedOnly,
  );
  equal(canonical.valid, true);
  const result = canonical.result as any;
  equal(result.equations, [grumciAuthoritativeEquation]);
  equal(result.sections[0].blocks.length, 2);
  equal(canonical.comparison.referencedEquationObjectsAdded, 1);
  equal(canonical.comparison.orphanReferencesAdded, 0);
  equal(validateSummarySemantics(result, 4).valid, true);
});

Deno.test("referenced equation repair rejects unknown and wrong-page references", () => {
  const unknown = clone(grumciFinalSummary);
  unknown.equations = [];
  unknown.sections[0].blocks.push({
    kind: "equation",
    equation_id: "eq_unknown",
    display: "block",
  } as any);
  equal(
    canonicalizeFinalSummaryEquations(finalRequest(), unknown).valid,
    false,
  );

  const wrongPage = clone(grumciFinalSummary);
  wrongPage.equations = [];
  wrongPage.sections[0].source_pages = [2, 3, 4];
  wrongPage.sections[0].blocks.push({
    kind: "equation",
    equation_id: "eq_page1_1",
    display: "block",
  } as any);
  equal(
    canonicalizeFinalSummaryEquations(finalRequest(), wrongPage).valid,
    false,
  );
});

Deno.test("final provider cannot alter or invent authoritative equations", () => {
  const altered = clone(grumciFinalSummary);
  altered.equations[0].latex = "provider_changed";
  const canonical = canonicalizeFinalSummaryEquations(finalRequest(), altered);
  equal(canonical.valid, true);
  const result = canonical.result as any;
  equal(
    result.equations[0],
    grumciAuthoritativeEquation,
  );
  equal(canonical.comparison.equationFieldsReplaced, true);

  const invented = clone(grumciFinalSummary);
  invented.equations[0].id = "eq_invented";
  equal(
    canonicalizeFinalSummaryEquations(finalRequest(), invented).valid,
    false,
  );
});

Deno.test("safe equation comparison metadata survives validation", () => {
  const request = finalRequest();
  const orphan = validateProviderOutputWithMetadata(
    request,
    clone(grumciFinalSummary),
  );
  equal(orphan.equationComparison, {
    authoritativeEquationCount: 1,
    providerEquationCount: 1,
    referencedEquationObjectsAdded: 0,
    orphanReferencesAdded: 1,
    equationFieldsReplaced: false,
  });

  const altered = clone(grumciFinalSummary);
  altered.equations[0].latex = "provider_changed";
  const replaced = validateProviderOutputWithMetadata(request, altered);
  equal(replaced.equationComparison?.equationFieldsReplaced, true);

  const unchanged = validateProviderOutputWithMetadata(
    request,
    replaced.result,
  );
  equal(unchanged.equationComparison, {
    authoritativeEquationCount: 1,
    providerEquationCount: 1,
    referencedEquationObjectsAdded: 0,
    orphanReferencesAdded: 0,
    equationFieldsReplaced: false,
  });
});

Deno.test("orphan recovery stays strict when section provenance is ambiguous", () => {
  const ambiguous = clone(grumciFinalSummary);
  ambiguous.sections.push({
    ...clone(ambiguous.sections[0]),
    id: "section_page_1_duplicate",
  });
  equal(
    canonicalizeFinalSummaryEquations(finalRequest(), ambiguous).valid,
    false,
  );
});

function finalRequest(): ProviderRequest {
  return {
    operation: "final_summary",
    input: {
      kind: "text",
      text: JSON.stringify({
        operation: "final_summary",
        authoritative_equations: [grumciAuthoritativeEquation],
        validated_reduction: grumciReduction,
        manifest: [1, 2, 3, 4].map((page) => ({
          page_number: page,
          status: "completed",
          route: "visual",
          warnings: [],
        })),
      }),
    },
    expectedPages: [1, 2, 3, 4],
    allowedEquationIds: ["eq_page1_1"],
    authoritativeEquations: [grumciAuthoritativeEquation],
    pageCount: 4,
    idempotencyKey: "d".repeat(64),
  };
}

function includes(values: string[], expected: string) {
  if (!values.includes(expected)) {
    throw new Error(`Expected ${expected}, got ${JSON.stringify(values)}`);
  }
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
