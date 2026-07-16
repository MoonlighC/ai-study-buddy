import {
  assertTransition,
  batchStates,
  batchTransitions,
  consumePageAttempt,
  jobStates,
  jobTransitions,
  pageStates,
  pageTransitions,
  transitionRule,
} from "./state_machines.ts";
import { PageRoutingInput, routePage } from "./router.ts";
import {
  pageAnalysisResultSchema,
  publicStatusSchema,
  reductionResultSchema,
  structuredSummarySchema,
  validatePageResult,
  validateReductionResult,
  validateStructuredOutputSubset,
  validateSummarySemantics,
} from "./schemas.ts";
import {
  safeEquationFallback,
  validateLatex,
  validateSafeMarkdown,
} from "./validators.ts";
import {
  batchFingerprint,
  classifyFailure,
  mayReuseCompletedFingerprint,
  persistedBackoffSeconds,
  stableJson,
} from "./fingerprints_retry.ts";
import {
  FakeOpenAiBoundary,
  FakeSupabaseBoundary,
  StructuredSummary,
} from "./contracts.ts";
import { InMemoryFakeOpenAi, InMemoryFakeSupabase } from "./fakes.ts";

Deno.test("all declared allowed transitions satisfy their requirements", () => {
  for (const table of [jobTransitions, pageTransitions, batchTransitions]) {
    for (const entry of table) {
      const result = assertTransition({
        table: table as typeof batchTransitions,
        from: entry.from as never,
        to: entry.to as never,
        leaseToken: entry.leaseRequired ? "lease" : undefined,
        responseId: entry.responseIdRequired ? "resp_12345678" : undefined,
        explicitUserAction: entry.explicitUserAction,
      });
      equal(result.to, entry.to);
    }
  }
});

Deno.test("every undeclared transition is forbidden", () => {
  for (
    const [states, table] of [
      [jobStates, jobTransitions],
      [pageStates, pageTransitions],
      [batchStates, batchTransitions],
    ] as const
  ) {
    for (const from of states) {
      for (const to of states) {
        if (transitionRule(table as never, from as never, to as never)) {
          continue;
        }
        throws(() =>
          assertTransition({
            table: table as never,
            from: from as never,
            to: to as never,
          }), "transition_forbidden");
      }
    }
  }
});

Deno.test("terminal states have no outgoing transitions", () => {
  for (const terminal of ["completed", "completed_with_warnings"]) {
    equal(jobTransitions.some((rule) => rule.from === terminal), false);
  }
  for (const terminal of ["completed", "partial", "missing"]) {
    equal(pageTransitions.some((rule) => rule.from === terminal), false);
  }
  for (const terminal of ["completed", "failed"]) {
    equal(batchTransitions.some((rule) => rule.from === terminal), false);
  }
});

Deno.test("dispatch ambiguity cannot auto-resubmit and retains consumed cost", () => {
  equal(transitionRule(batchTransitions, "dispatch_unknown", "prepared"), null);
  const toUser = transitionRule(
    batchTransitions,
    "dispatch_unknown",
    "user_retry_required",
  )!;
  equal(toUser.budgetEffect, "retain");
  equal(toUser.automaticRetry, false);
  const retry = transitionRule(
    batchTransitions,
    "user_retry_required",
    "prepared",
  )!;
  equal(retry.explicitUserAction, true);
  throws(
    () =>
      assertTransition({
        table: batchTransitions,
        from: "user_retry_required",
        to: "prepared",
      }),
    "explicit_user_action_required",
  );
});

Deno.test("page attempt ceilings are exact", () => {
  let attempts = { grouped: 0, recovery: 0, total: 0 };
  attempts = consumePageAttempt(attempts, "grouped");
  attempts = consumePageAttempt(attempts, "grouped");
  attempts = consumePageAttempt(attempts, "recovery");
  equal(attempts, { grouped: 2, recovery: 1, total: 3 });
  throws(
    () => consumePageAttempt(attempts, "grouped"),
    "page_attempt_budget_exhausted",
  );
  throws(
    () => consumePageAttempt(attempts, "recovery"),
    "page_attempt_budget_exhausted",
  );
});

Deno.test("router is deterministic and images always route visual", async () => {
  const input = routingInput({ sourceKind: "image" });
  const first = await routePage(input);
  const second = await routePage(structuredClone(input));
  equal(first, second);
  equal(first.route, "visual");
  equal(first.reasons.includes("original_image"), true);
});

Deno.test("recommended routes complex STEM visual while economy keeps usable text", async () => {
  const stem = routingInput({ domainProfile: "stem", mathDensity: 0.02 });
  equal((await routePage(stem)).route, "visual");
  equal((await routePage({ ...stem, mode: "economy" })).route, "text");
});

Deno.test("uncertain and unusable pages route visual", async () => {
  equal(
    (await routePage(routingInput({ layoutUncertainty: 0.2 }))).route,
    "visual",
  );
  equal(
    (await routePage(routingInput({ normalizedText: "", textCoverage: 0 })))
      .route,
    "visual",
  );
});

Deno.test("all JSON schemas are closed and recursively bound core objects", () => {
  for (
    const schema of [
      pageAnalysisResultSchema,
      reductionResultSchema,
      structuredSummarySchema,
      publicStatusSchema,
    ]
  ) {
    equal(schema.additionalProperties, false);
    equal(Array.isArray(schema.required), true);
    equal(schema.required.length, Object.keys(schema.properties).length);
  }
});

Deno.test("OpenAI schemas use only the documented strict Structured Outputs subset", () => {
  for (
    const schema of [
      pageAnalysisResultSchema,
      reductionResultSchema,
      structuredSummarySchema,
    ]
  ) {
    const validation = validateStructuredOutputSubset(schema);
    equal(validation.valid, true);
    equal(JSON.stringify(schema).includes('"oneOf"'), false);
  }
});

Deno.test("summary semantics enforce manifest and equation integrity", () => {
  const summary = validSummary();
  equal(validateSummarySemantics(summary, 2).valid, true);
  const broken = structuredClone(summary);
  broken.partial_extraction.page_modes = [{ page: 1, mode: "text" }];
  broken.sections[0].blocks.push({
    kind: "equation",
    equation_id: "eq_missing",
    display: "block",
  });
  const result = validateSummarySemantics(broken, 2);
  equal(result.valid, false);
  equal(result.errors.includes("manifest_coverage"), true);
  equal(result.errors.includes("equation_reference"), true);
});

Deno.test("summary semantics reject claims sourced only from missing pages", () => {
  const summary = validSummary();
  summary.partial_extraction.is_partial = true;
  summary.partial_extraction.missing_pages = [2];
  summary.partial_extraction.analyzed_pages = [1];
  summary.sections[0].source_pages = [2];
  equal(
    validateSummarySemantics(summary, 2).errors.includes("section_sources"),
    true,
  );
});

Deno.test("summary partitions every page into sorted analyzed partial or missing sets", () => {
  const summary = validSummary();
  summary.partial_extraction.analyzed_pages = [1];
  summary.partial_extraction.partial_pages = [2];
  summary.partial_extraction.is_partial = true;
  equal(validateSummarySemantics(summary, 2).valid, true);
  summary.partial_extraction.partial_pages = [];
  equal(
    validateSummarySemantics(summary, 2).errors.includes("page_partition"),
    true,
  );
  summary.partial_extraction.partial_pages = [2, 1];
  equal(
    validateSummarySemantics(summary, 2).errors.includes("page_set_invalid"),
    true,
  );
});

Deno.test("Markdown permits study structure and rejects active/embedded content", () => {
  equal(
    validateSafeMarkdown("# Heading\n\n**Bold**\n\n- item\n\n> quote\n\n`code`")
      .valid,
    true,
  );
  for (
    const unsafe of [
      "<b>html</b>",
      "![image](x)",
      "[link](https://example.com)",
      "<https://example.com>",
      "https://example.com",
      "[reference][id]\n\n[id]: https://example.com",
      "[shortcut]\n\n[shortcut]: /relative",
      "<mailto:user@example.com>",
      "<user@example.com>",
      "www.example.com",
      "<!-- hidden -->",
      "[![nested](image.png)](https://example.com)",
      "$x+y$",
      "$$x+y$$",
    ]
  ) equal(validateSafeMarkdown(unsafe).valid, false);
  equal(
    validateSafeMarkdown(String.raw`\[literal\]\(not-a-link\)`).valid,
    true,
  );
});

Deno.test("LaTeX allowlist accepts study math and rejects dangerous primitives", () => {
  for (
    const safe of [
      "\\frac{a}{b}",
      "\\sqrt{x^2+y^2}",
      "\\sum_{i=1}^{n} i",
      "\\begin{pmatrix}a&b\\\\c&d\\end{pmatrix}",
      "\\begin {matrix}a&b\\\\c&d\\end {matrix}",
      "\\begin{cases}x&\\begin{matrix}a&b\\\\c&d\\end{matrix}\\\\y&z\\end{cases}",
      "\\alpha + \\Omega",
    ]
  ) equal(validateLatex(safe).valid, true);
  for (
    const unsafe of [
      "\\newcommand{\\x}{bad}",
      "\\href{https://x}{x}",
      "\\input{secret}",
      "\\usepackage{x}",
      "\\htmlStyle{x}{y}",
      "$x$",
      "\\unknown{x}",
      "\\dfrac{a}{b}",
      "\\begin{matrix}a\\end{aligned}",
      "\\be%comment\ngin{matrix}a\\end{matrix}",
      "＼input{x}",
      "\\csname input\\endcsname",
    ]
  ) equal(validateLatex(unsafe).valid, false);
  equal(validateLatex(String.raw`\\input`).valid, false);
  equal(validateLatex(String.raw`\\\input{x}`).valid, false);
});

Deno.test("LaTeX depth, matrix, and balance limits fail safely", () => {
  equal(validateLatex("{".repeat(17) + "x" + "}".repeat(17)).valid, false);
  equal(validateLatex("\\frac{a}{b").valid, false);
  const row = Array.from({ length: 13 }, () => "x").join("&");
  equal(validateLatex(`\\begin{matrix}${row}\\end{matrix}`).valid, false);
  equal(
    validateLatex(
      "\\begin{matrix}a&b\\\\c&d\\end{matrix}+\\begin{matrix}" + row +
        "\\end{matrix}",
    ).valid,
    false,
  );
  const fallback = safeEquationFallback(validSummary().equations[0]);
  equal(fallback.warning, null);
  const bad = safeEquationFallback({
    ...validSummary().equations[0],
    latex: "\\input{x}",
  });
  equal(bad.equation.uncertainty, true);
  equal(bad.warning?.code, "invalid_equation_latex");
});

Deno.test("page and reduction validators reject unknown fields and invented provenance", () => {
  const pageResult = {
    page_number: 1,
    summary_markdown: "Safe summary.",
    key_concepts: ["Concept"],
    equations: validSummary().equations,
    confidence: 0.9,
    warnings: [],
    trustworthy: true,
  };
  equal(validatePageResult(pageResult, 1, 2).valid, true);
  equal(validatePageResult({ ...pageResult, extra: true }, 1, 2).valid, false);
  equal(
    validatePageResult({ ...pageResult, trustworthy: false }, 1, 2, "partial")
      .valid,
    false,
  );
  equal(validatePageResult(null, 1, 2, "missing").valid, true);
  equal(validatePageResult(pageResult, 1, 2, "missing").valid, false);
  const reduction = {
    source_pages: [1, 2],
    summary_markdown: "Safe reduction.",
    key_concepts: ["Concept"],
    equation_ids: ["eq_voltage"],
    warnings: [],
    confidence: 0.8,
  };
  equal(validateReductionResult(reduction, [1, 2], ["eq_voltage"]).valid, true);
  equal(validateReductionResult(reduction, [1, 2], []).valid, false);
});

Deno.test("fingerprints are canonical and completed results are reusable", async () => {
  equal(stableJson({ b: 2, a: 1 }), stableJson({ a: 1, b: 2 }));
  const input = {
    operation: "page_text",
    mode: "recommended",
    pageNumbers: [1, 2],
    inputHashes: ["a", "b"],
    routerVersion: "r1",
    promptVersion: "p1",
    schemaVersion: 1,
    reductionLevel: 0,
    configurationVersion: "c1",
  };
  const first = await batchFingerprint(input);
  const second = await batchFingerprint({ ...input });
  equal(first, second);
  equal(
    mayReuseCompletedFingerprint({
      fingerprint: first,
      completedFingerprint: second,
      completedResultValid: true,
    }),
    true,
  );
});

Deno.test("retry classifier distinguishes pre-dispatch, reconciliation, and user retry", () => {
  equal(
    classifyFailure({ dispatched: false, status: 429 }).kind,
    "pre_dispatch_retryable",
  );
  equal(
    classifyFailure({ dispatched: false, status: 503 }).kind,
    "pre_dispatch_retryable",
  );
  equal(
    classifyFailure({ dispatched: false, errorKind: "validation" }).kind,
    "non_retryable",
  );
  equal(
    classifyFailure({ dispatched: true, responseId: "resp_12345678" }).kind,
    "reconcile_only",
  );
  equal(classifyFailure({ dispatched: true }).kind, "user_retry_required");
});

Deno.test("backoff uses Retry-After and deterministic bounded jitter", () => {
  equal(persistedBackoffSeconds({ attempt: 1, jitter: () => 0 }), 5);
  equal(persistedBackoffSeconds({ attempt: 2, jitter: () => 1 }), 13);
  equal(
    persistedBackoffSeconds({
      attempt: 2,
      retryAfterSeconds: 60,
      jitter: () => 0.5,
    }),
    60,
  );
  equal(persistedBackoffSeconds({ attempt: 20, jitter: () => 1 }), 900);
});

Deno.test("fake provider and database boundaries carry no real side effects", async () => {
  const openAi: FakeOpenAiBoundary = {
    submit: async () => ({ responseId: "fake_response", result: { ok: true } }),
    retrieve: async () => ({ status: "completed", result: { ok: true } }),
    deleteFile: async () => true,
  };
  const supabase: FakeSupabaseBoundary = {
    loadOwnedMaterial: async (principalId, materialId) => ({
      principalId,
      materialId,
    }),
    callTrustedRpc: async (name, args) => ({ name, args }),
  };
  equal(
    (await openAi.submit({ fingerprint: "x", operation: "fake", payload: {} }))
      .responseId,
    "fake_response",
  );
  equal(await supabase.loadOwnedMaterial("user", "material"), {
    principalId: "user",
    materialId: "material",
  });
});

Deno.test("reusable in-memory fakes record only explicit local calls", async () => {
  const materials = new Map<string, unknown>([["owner:material", {
    id: "material",
  }]]);
  const openAi = new InMemoryFakeOpenAi({ pages: [1] }, "fake_response");
  const supabase = new InMemoryFakeSupabase(materials);
  await openAi.submit({
    fingerprint: "fingerprint",
    operation: "page_text",
    payload: { page: 1 },
  });
  await openAi.retrieve("fake_response");
  await openAi.deleteFile("fake_file");
  await supabase.callTrustedRpc("fake_rpc", { material_id: "material" });
  equal(openAi.submissions.length, 1);
  equal(openAi.retrieved, ["fake_response"]);
  equal(openAi.deletedFiles, ["fake_file"]);
  equal(await supabase.loadOwnedMaterial("owner", "material"), {
    id: "material",
  });
  equal(supabase.rpcCalls.length, 1);
});

function routingInput(
  overrides: Partial<PageRoutingInput> = {},
): PageRoutingInput {
  return {
    pageNumber: 1,
    sourceKind: "pdf",
    normalizedText:
      "Reliable selectable study text with enough letters and numbers for deterministic analysis. "
        .repeat(2),
    textCoordinates: [{ x: 20, y: 20, width: 300, height: 20 }],
    pageWidth: 612,
    pageHeight: 792,
    textCoverage: 0.2,
    damagedCharacterRatio: 0,
    mathDensity: 0,
    columnAlignment: 0,
    tableAlignment: 0,
    rasterCoverage: 0,
    vectorPathComplexity: 0,
    handwritingOrInk: false,
    diagramOrGraph: false,
    readingOrderUncertainty: 0,
    layoutUncertainty: 0,
    domainProfile: "general",
    mode: "recommended",
    ...overrides,
  };
}

function validSummary(): StructuredSummary {
  return {
    language: "en",
    sections: [{
      id: "overview",
      title: "Overview",
      blocks: [{
        kind: "equation",
        equation_id: "eq_voltage",
        display: "block",
      }],
      source_pages: [1],
      confidence: 0.9,
    }],
    key_concepts: [{
      title: "Voltage",
      explanation_markdown: "A safe explanation.",
      source_pages: [1],
      confidence: 0.9,
    }],
    equations: [{
      id: "eq_voltage",
      latex: "V = I \\cdot R",
      explanation_markdown: "Ohm's law.",
      source_page: 1,
      display: "block",
      confidence: 0.9,
      uncertainty: false,
    }],
    warnings: [],
    partial_extraction: {
      is_partial: false,
      analyzed_pages: [1, 2],
      partial_pages: [],
      missing_pages: [],
      page_modes: [{ page: 1, mode: "text" }, { page: 2, mode: "visual" }],
    },
  };
}

function equal(actual: unknown, expected: unknown) {
  if (JSON.stringify(actual) !== JSON.stringify(expected)) {
    throw new Error(
      `Expected ${JSON.stringify(expected)}, got ${JSON.stringify(actual)}`,
    );
  }
}
function throws(action: () => unknown, message: string) {
  try {
    action();
  } catch (error) {
    if (error instanceof Error && error.message === message) return;
    throw error;
  }
  throw new Error(`Expected ${message}`);
}
