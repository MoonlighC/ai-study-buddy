import {
  AnalysisDependencies,
  createAdvanceMaterialAnalysisHandler,
  createMaterialAnalysisDiagnosticHandler,
  createMaterialAnalysisDispatchHandler,
  createPrepareMaterialAnalysisHandler,
  createRetryMaterialAnalysisHandler,
  InternalWorkUnit,
} from "./handlers.ts";
import { analysisValidatorVersion, SafeAnalysisError } from "./engine.ts";
import { TrustedOpenAiAdapter } from "./openai_adapter.ts";
import { buildSyntheticPdf } from "./synthetic_pdf_fixtures.ts";

const owner = crypto.randomUUID();
const materialId = crypto.randomUUID();
const otherOwner = crypto.randomUUID();
const jobId = crypto.randomUUID();
const batchId = crypto.randomUUID();
const leaseId = crypto.randomUUID();
const artifactId = crypto.randomUUID();
const retryAuthorizationId = crypto.randomUUID();
const runtimeAuthFixture = ["fixture", crypto.randomUUID()].join("_");
const runtimeApiFixture = ["safe", "mock", crypto.randomUUID()].join("_");
const runtimeServiceFixture = ["service", crypto.randomUUID()].join("_");

Deno.test("C2 prepare owner succeeds with exact 1..P manifest", async () => {
  const pdf = await buildSyntheticPdf(["text", "text"]);
  const fake = fakeDependencies(pdf);
  const response = await createPrepareMaterialAnalysisHandler(fake.deps)(
    request({
      material_id: materialId,
      processing_mode: "recommended",
      confirm_large_document: false,
    }),
  );
  equal(response.status, 200);
  equal(fake.preparations.length, 1);
  equal(fake.preparations[0].page_count, 2);
  equal(
    (fake.preparations[0].page_plans as Array<Record<string, unknown>>).map(
      (page) => page.page_number,
    ),
    [1, 2],
  );
  equal(fake.providerRequests, 0);
});

Deno.test("50-page Analyze again requires confirmation before any POST", async () => {
  const pdf = await buildSyntheticPdf(Array(50).fill("text"));
  const fake = fakeDependencies(pdf);
  fake.status.state = "awaiting_confirmation";
  fake.status.confirmation_required = true;
  const response = await createPrepareMaterialAnalysisHandler(fake.deps)(
    request({
      material_id: materialId,
      processing_mode: "recommended",
      confirm_large_document: false,
      analyze_again: true,
    }),
  );
  equal(response.status, 200);
  equal(fake.preparations.length, 1);
  equal(fake.preparations[0].analyze_again, true);
  equal(fake.preparations[0].page_count, 50);
  equal(fake.preparations[0].confirm_large_document, false);
  equal((await response.json()).confirmation_required, true);
  equal(fake.providerRequests, 0);
});

Deno.test("C2 prepare denies cross-user and malformed requests", async () => {
  const pdf = await buildSyntheticPdf(["text"]);
  const fake = fakeDependencies(pdf);
  fake.source.user_id = otherOwner;
  const denied = await createPrepareMaterialAnalysisHandler(fake.deps)(request({
    material_id: materialId,
    processing_mode: "recommended",
    confirm_large_document: false,
  }));
  equal(denied.status, 404);
  equal((await denied.json()).code, "material_unavailable");
  const malformed = await createPrepareMaterialAnalysisHandler(fake.deps)(
    request({
      material_id: materialId,
      processing_mode: "recommended",
      confirm_large_document: false,
      model: "attacker-model",
    }),
  );
  equal(malformed.status, 400);
  equal((await malformed.json()).code, "invalid_request");
  equal(fake.preparations.length, 0);
});

Deno.test("C2 21 through 100 pages require confirmation without paid activity", async () => {
  const pdf = await buildSyntheticPdf(Array(21).fill("text"));
  const fake = fakeDependencies(pdf);
  fake.status.state = "awaiting_confirmation";
  fake.status.confirmation_required = true;
  const response = await createPrepareMaterialAnalysisHandler(fake.deps)(
    request({
      material_id: materialId,
      processing_mode: "economy",
      confirm_large_document: false,
    }),
  );
  equal(response.status, 200);
  equal((await response.json()).confirmation_required, true);
  equal(fake.preparations.length, 1);
  equal(fake.providerRequests, 0);
});

Deno.test("C2 page 101 rejects before job budget upload or OpenAI", async () => {
  const pdf = await buildSyntheticPdf(Array(101).fill("text"));
  const fake = fakeDependencies(pdf);
  const response = await createPrepareMaterialAnalysisHandler(fake.deps)(
    request({
      material_id: materialId,
      processing_mode: "recommended",
      confirm_large_document: true,
    }),
  );
  equal(response.status, 422);
  equal((await response.json()).code, "document_too_large");
  equal(fake.preparations.length, 0);
  equal(fake.providerRequests, 0);
});

Deno.test("diagnostic handler retrieves once without POST, upload, attempt, budget, or public diagnostic", async () => {
  const pdf = await buildSyntheticPdf(["text"]);
  const fake = fakeDependencies(pdf);
  const response = await createMaterialAnalysisDiagnosticHandler(fake.deps)(
    diagnosticRequest(batchId),
  );
  equal(response.status, 200);
  equal(await response.json(), { status: "recorded" });
  equal(fake.providerRequests, 1);
  equal(fake.providerMethods, ["GET"]);
  equal(fake.uploadRequests, 0);
  equal(fake.submissions, 0);
  equal(fake.completions, 0);
  equal(fake.failures.length, 0);
  equal(fake.diagnostics.length, 1);
  equal(fake.diagnostics[0].diagnostic_code, "page_persistence_failed");
});

Deno.test("diagnostic handler persists a specific code without provider content", async () => {
  const pdf = await buildSyntheticPdf(["text"]);
  const fake = fakeDependencies(pdf, "pdf", "diagnostic_latex_failure");
  const response = await createMaterialAnalysisDiagnosticHandler(fake.deps)(
    diagnosticRequest(batchId),
  );
  equal(response.status, 200);
  equal(fake.providerMethods, ["GET"]);
  equal(fake.diagnostics[0].diagnostic_code, "page_latex_failed");
  equal(
    JSON.stringify(fake.diagnostics[0]).includes("private provider content"),
    false,
  );
});

Deno.test("final-summary diagnostic retrieves once and records persistence eligibility without mutations", async () => {
  const pdf = await buildSyntheticPdf(["text"]);
  const fake = fakeDependencies(pdf, "pdf", "diagnostic_final_success");
  fake.deps.loadDiagnosticTarget = (requestedBatchId) =>
    Promise.resolve({
      batch_id: requestedBatchId,
      operation: "final_summary",
      status: "failed",
      response_id: "resp_12345678",
      page_numbers: [1],
      page_count: 1,
      cleanup_state: "not_required",
    });
  const before = {
    submissions: fake.submissions,
    completions: fake.completions,
    failures: fake.failures.length,
    uploads: fake.uploadRequests,
  };
  const response = await createMaterialAnalysisDiagnosticHandler(fake.deps)(
    diagnosticRequest(batchId),
  );
  equal(response.status, 200);
  equal(fake.providerMethods, ["GET"]);
  equal(fake.providerRequests, 1);
  equal(fake.uploadRequests, before.uploads);
  equal(fake.submissions, before.submissions);
  equal(fake.completions, before.completions);
  equal(fake.failures.length, before.failures);
  equal(fake.diagnostics.length, 1);
  equal(
    fake.diagnostics[0].diagnostic_code,
    "final_summary_persistence_failed",
  );
  equal(
    (fake.diagnostics[0].diagnostic_metadata as Record<string, unknown>)
      .validator_stage,
    "persistFinalSummaryEligibility",
  );
});

Deno.test("final-summary diagnostic write failure performs no provider fallback", async () => {
  const pdf = await buildSyntheticPdf(["text"]);
  const fake = fakeDependencies(pdf, "pdf", "diagnostic_final_success");
  fake.deps.loadDiagnosticTarget = (requestedBatchId) =>
    Promise.resolve({
      batch_id: requestedBatchId,
      operation: "final_summary",
      status: "failed",
      response_id: "resp_12345678",
      page_numbers: [1],
      page_count: 1,
      cleanup_state: "not_required",
    });
  fake.deps.recordDiagnostic = () =>
    Promise.reject(new Error("private database detail"));
  const response = await createMaterialAnalysisDiagnosticHandler(fake.deps)(
    diagnosticRequest(batchId),
  );
  equal(response.status, 500);
  equal(fake.providerMethods, ["GET"]);
  equal(fake.providerRequests, 1);
  equal(fake.uploadRequests, 0);
  equal(fake.submissions, 0);
  equal(fake.completions, 0);
  equal(fake.failures.length, 0);
});

Deno.test("diagnostic database write failure stays generic and never retries provider", async () => {
  const pdf = await buildSyntheticPdf(["text"]);
  const fake = fakeDependencies(pdf);
  fake.deps.recordDiagnostic = () =>
    Promise.reject(new Error("private database detail"));
  const response = await createMaterialAnalysisDiagnosticHandler(fake.deps)(
    diagnosticRequest(batchId),
  );
  equal(response.status, 500);
  equal(await response.json(), {
    error: "Material analysis is temporarily unavailable.",
  });
  equal(fake.providerMethods, ["GET"]);
  equal(fake.providerRequests, 1);
  equal(fake.uploadRequests, 0);
  equal(fake.submissions, 0);
  equal(fake.diagnostics.length, 0);
});

Deno.test("diagnostic handler rejects non-service callers before provider access", async () => {
  const pdf = await buildSyntheticPdf(["text"]);
  const fake = fakeDependencies(pdf);
  const response = await createMaterialAnalysisDiagnosticHandler(fake.deps)(
    request({ batch_id: batchId }),
  );
  equal(response.status, 401);
  equal(fake.providerRequests, 0);
  equal(fake.diagnostics.length, 0);
});

Deno.test("forged diagnostic header is inert for a normal authenticated user", async () => {
  const pdf = await buildSyntheticPdf(["text"]);
  const fake = fakeDependencies(pdf);
  const withHeader = await createMaterialAnalysisDispatchHandler(fake.deps)(
    normalDiagnosticShapedRequest(true),
  );
  const withoutHeader = await createMaterialAnalysisDispatchHandler(fake.deps)(
    normalDiagnosticShapedRequest(false),
  );
  equal(withHeader.status, withoutHeader.status);
  equal(await withHeader.json(), await withoutHeader.json());
  equal(fake.providerRequests, 0);
  equal(fake.uploadRequests, 0);
  equal(fake.diagnostics.length, 0);
});

Deno.test("C2 image above 8 MiB rejects before budget upload or response", async () => {
  const fake = fakeDependencies(pngBytes(), "image");
  fake.source.file_size_bytes = 8 * 1024 * 1024 + 1;
  const response = await createPrepareMaterialAnalysisHandler(fake.deps)(
    request({
      material_id: materialId,
      processing_mode: "recommended",
      confirm_large_document: false,
    }),
  );
  equal(response.status, 422);
  equal((await response.json()).code, "corrupt_document");
  equal(fake.preparations.length, 0);
  equal(fake.fileIntents, 0);
  equal(fake.uploadRequests, 0);
  equal(fake.providerRequests, 0);
  equal(fake.submissions, 0);
});

Deno.test("C2 duplicate preparation delegates idempotency without provider work", async () => {
  const pdf = await buildSyntheticPdf(["text"]);
  const fake = fakeDependencies(pdf);
  const handler = createPrepareMaterialAnalysisHandler(fake.deps);
  for (let index = 0; index < 2; index++) {
    const response = await handler(request({
      material_id: materialId,
      processing_mode: "recommended",
      confirm_large_document: false,
    }));
    equal(response.status, 200);
  }
  equal(fake.preparations.length, 2);
  equal(fake.providerRequests, 0);
});

Deno.test("C2 advance performs one bounded operation with exact original image bytes", async () => {
  const bytes = pngBytes();
  const fake = fakeDependencies(bytes, "image");
  fake.work = {
    kind: "page_visual",
    material_id: materialId,
    job_id: jobId,
    batch_id: batchId,
    lease_token: leaseId,
    page_count: 1,
    page_numbers: [1],
    validation_version: analysisValidatorVersion,
  };
  const response = await createAdvanceMaterialAnalysisHandler(fake.deps)(
    request({ material_id: materialId }),
  );
  equal(response.status, 200);
  equal(fake.claims, 1);
  equal(fake.providerRequests, 1);
  equal(fake.observedImageBytes, bytes);
  equal(fake.submissions, 1);
  equal(fake.completions, 1);
});

Deno.test("one-page visual PDF uses one mini-PDF upload and one Responses create", async () => {
  const pdf = await buildSyntheticPdf(["text"]);
  const fake = fakeDependencies(pdf, "pdf");
  fake.work = workUnit();
  const response = await createAdvanceMaterialAnalysisHandler(fake.deps)(
    request({ material_id: materialId }),
  );
  equal(response.status, 200);
  equal(fake.claims, 1);
  equal(fake.fileIntents, 1);
  equal(fake.uploadRequests, 1);
  equal(fake.submissions, 1);
  equal(fake.providerRequests, 1);
  equal(fake.responsePersistenceAttempts, 1);
  equal(fake.completions, 1);
  equal(fake.deleteRequests, 0);
});

Deno.test("C2 another worker lease returns status without provider request", async () => {
  const pdf = await buildSyntheticPdf(["text"]);
  const fake = fakeDependencies(pdf);
  fake.work = { kind: "none", material_id: materialId };
  const response = await createAdvanceMaterialAnalysisHandler(fake.deps)(
    request({ material_id: materialId }),
  );
  equal(response.status, 200);
  equal(fake.claims, 1);
  equal(fake.providerRequests, 0);
});

Deno.test("claimed v2 work terminalizes before any provider request", async () => {
  const fake = fakeDependencies(pngBytes(), "image");
  fake.work = { ...workUnit(), validation_version: "phase-c-validator-v2" };
  const response = await createAdvanceMaterialAnalysisHandler(fake.deps)(
    request({ material_id: materialId }),
  );
  equal(response.status, 200);
  equal(fake.providerRequests, 0);
  equal(fake.submissions, 0);
  equal(fake.failures[0].failure_class, "terminal_structured_output_invalid");
});

Deno.test("cross-page duplicate equation IDs fail before provider POST", async () => {
  const fake = fakeDependencies(pngBytes(), "image");
  const work = finalSummaryWorkUnit();
  const equation = {
    id: "eq_duplicate",
    latex: "x",
    explanation_markdown: "",
    source_page: 1,
    display: "block",
    confidence: 0.9,
    uncertainty: false,
  };
  (work.input_payload as Record<string, unknown>).authoritative_equations = [
    equation,
    { ...equation, source_page: 2 },
  ];
  fake.work = work;
  const response = await createAdvanceMaterialAnalysisHandler(fake.deps)(
    request({ material_id: materialId }),
  );
  equal(response.status, 200);
  equal(fake.providerRequests, 0);
  equal(fake.submissions, 0);
  equal(fake.failures[0].failure_class, "terminal_structured_output_invalid");
});

Deno.test("duplicate equation IDs fail before reduction persistence", async () => {
  const fake = fakeDependencies(pngBytes(), "image");
  fake.work = {
    ...workUnit(),
    kind: "reduction",
    input_payload: {
      inputs: [pageBatch().pages[0]],
      equation_ids: ["eq_duplicate", "eq_duplicate"],
    },
  };
  const response = await createAdvanceMaterialAnalysisHandler(fake.deps)(
    request({ material_id: materialId }),
  );
  equal(response.status, 200);
  equal(fake.providerRequests, 0);
  equal(fake.submissions, 0);
  equal(fake.completions, 0);
  equal(fake.failures[0].failure_class, "terminal_structured_output_invalid");
});

Deno.test("C2 after-dispatch failure without response ID requires explicit user retry", async () => {
  const bytes = pngBytes();
  const fake = fakeDependencies(bytes, "image", "network_failure");
  fake.work = workUnit();
  const response = await createAdvanceMaterialAnalysisHandler(fake.deps)(
    request({ material_id: materialId }),
  );
  equal(response.status, 200);
  equal(fake.failures[0].failure_class, "user_retry_required");
  equal(fake.submissions, 1);
  equal(fake.completions, 0);
});

Deno.test("C2 proven pre-dispatch upload failure backs off without consuming an attempt", async () => {
  const pdf = await buildSyntheticPdf(["text"]);
  const fake = fakeDependencies(pdf, "pdf", "upload_failure");
  fake.work = workUnit();
  const response = await createAdvanceMaterialAnalysisHandler(fake.deps)(
    request({ material_id: materialId }),
  );
  equal(response.status, 200);
  equal(fake.failures[0].failure_class, "pre_dispatch_retryable");
  equal(fake.failures[0].retry_after_seconds, 5);
  equal(fake.submissions, 0);
  equal(fake.providerRequests, 0);
});

Deno.test("C2 file-ID persistence failure deletes immediately without paid response", async () => {
  const pdf = await buildSyntheticPdf(["text"]);
  const fake = fakeDependencies(pdf, "pdf", "file_persistence_failure");
  fake.work = workUnit();
  const response = await createAdvanceMaterialAnalysisHandler(fake.deps)(
    request({ material_id: materialId }),
  );
  equal(response.status, 200);
  equal(fake.fileIntents, 1);
  equal(fake.uploadRequests, 1);
  equal(fake.deleteRequests, 1);
  equal(fake.fileRecoveries, 1);
  equal(fake.providerRequests, 0);
  equal(fake.submissions, 0);
  equal(fake.failures[0].failure_class, "pre_dispatch_retryable");
});

Deno.test("C2 transient DB failure after response retries without another paid call", async () => {
  const fake = fakeDependencies(
    pngBytes(),
    "image",
    "response_persistence_transient",
  );
  fake.work = workUnit();
  const response = await createAdvanceMaterialAnalysisHandler(fake.deps)(
    request({ material_id: materialId }),
  );
  equal(response.status, 200);
  equal(fake.providerRequests, 1);
  equal(fake.responsePersistenceAttempts, 2);
  equal(fake.completions, 1);
});

Deno.test("valid final summary persists exactly once with one provider POST", async () => {
  const fake = fakeDependencies(pngBytes(), "image");
  fake.work = finalSummaryWorkUnit();
  const handler = createAdvanceMaterialAnalysisHandler(fake.deps);
  equal((await handler(request({ material_id: materialId }))).status, 200);
  equal((await handler(request({ material_id: materialId }))).status, 200);
  equal(fake.providerMethods, ["POST"]);
  equal(fake.submissions, 1);
  equal(fake.completions, 1);
});

Deno.test("runtime logs safe equation comparison metadata", async () => {
  const cases = [
    ["final_equation_replaced", true, 0],
    ["final_equation_orphan", false, 1],
    ["final_equation_unchanged", false, 0],
  ] as const;
  for (const [mode, replaced, orphanCount] of cases) {
    const fake = fakeDependencies(pngBytes(), "image", mode);
    fake.work = finalSummaryEquationWorkUnit();
    const lines: string[] = [];
    const original = console.log;
    console.log = (line: unknown) => lines.push(String(line));
    try {
      const response = await createAdvanceMaterialAnalysisHandler(fake.deps)(
        request({ material_id: materialId }),
      );
      equal(response.status, 200);
    } finally {
      console.log = original;
    }
    const metadata = lines.map((line) => JSON.parse(line)).find((line) =>
      line.stage === "equation_canonicalization"
    );
    equal(metadata.authoritative_equation_count, 1);
    equal(metadata.provider_equation_count, 1);
    equal(metadata.referenced_equation_objects_added, 0);
    equal(metadata.orphan_references_added, orphanCount);
    equal(metadata.equation_fields_replaced, replaced);
    equal(JSON.stringify(metadata).includes("eq_runtime"), false);
    equal(JSON.stringify(metadata).includes("x+y"), false);
  }
});

Deno.test("runtime logs referenced authoritative equation object recovery", async () => {
  const fake = fakeDependencies(
    pngBytes(),
    "image",
    "final_equation_referenced_only",
  );
  fake.work = finalSummaryEquationWorkUnit();
  const lines: string[] = [];
  const original = console.log;
  console.log = (line: unknown) => lines.push(String(line));
  try {
    const response = await createAdvanceMaterialAnalysisHandler(fake.deps)(
      request({ material_id: materialId }),
    );
    equal(response.status, 200);
  } finally {
    console.log = original;
  }
  const metadata = lines.map((line) => JSON.parse(line)).find((line) =>
    line.stage === "equation_canonicalization"
  );
  equal(metadata.referenced_equation_objects_added, 1);
  equal(metadata.orphan_references_added, 0);
  equal(metadata.equation_fields_replaced, false);
  equal(JSON.stringify(metadata).includes("eq_runtime"), false);
  equal(JSON.stringify(metadata).includes("x+y"), false);
});

Deno.test("repeated final-summary reconciliation persists once with zero POSTs", async () => {
  const fake = fakeDependencies(
    pngBytes(),
    "image",
    "retrieval_final_success",
  );
  fake.work = finalSummaryReconciliationWorkUnit();
  const handler = createAdvanceMaterialAnalysisHandler(fake.deps);
  equal((await handler(request({ material_id: materialId }))).status, 200);
  equal((await handler(request({ material_id: materialId }))).status, 200);
  equal(fake.providerMethods, ["GET"]);
  equal(fake.submissions, 0);
  equal(fake.completions, 1);
});

Deno.test("reduction reconciliation retrieves once and persists without POST", async () => {
  const fake = fakeDependencies(
    pngBytes(),
    "image",
    "retrieval_reduction_success",
  );
  fake.work = reductionReconciliationWorkUnit();
  const handler = createAdvanceMaterialAnalysisHandler(fake.deps);
  equal((await handler(request({ material_id: materialId }))).status, 200);
  equal((await handler(request({ material_id: materialId }))).status, 200);
  equal(fake.providerMethods, ["GET"]);
  equal(fake.submissions, 0);
  equal(fake.completions, 1);
});

Deno.test("page-text reconciliation retrieves once and persists without POST", async () => {
  const fake = fakeDependencies(pngBytes(), "image");
  fake.work = pageTextReconciliationWorkUnit();
  const response = await createAdvanceMaterialAnalysisHandler(fake.deps)(
    request({ material_id: materialId }),
  );
  equal(response.status, 200);
  equal(fake.providerMethods, ["GET"]);
  equal(fake.submissions, 0);
  equal(fake.completions, 1);
});

for (
  const [name, work] of [
    ["missing trusted operation", {
      ...reconciliationWorkUnit(),
      operation: undefined,
    }],
    ["conflicting nested operation", {
      ...reconciliationWorkUnit(),
      input_payload: { operation: "final_summary" },
    }],
    ["conflicting normal operation", {
      ...workUnit(),
      operation: "reduction",
    }],
    ["conflicting normal nested operation", {
      ...workUnit(),
      operation: "page_visual",
      input_payload: { operation: "reduction" },
    }],
  ] as const
) {
  Deno.test(`${name} fails before provider access`, async () => {
    const fake = fakeDependencies(pngBytes(), "image");
    fake.work = work as InternalWorkUnit;
    const response = await createAdvanceMaterialAnalysisHandler(fake.deps)(
      request({ material_id: materialId }),
    );
    equal(response.status, 500);
    equal((await response.json()).code, "request_failed");
    equal(fake.providerRequests, 0);
    equal(fake.submissions, 0);
    equal(fake.completions, 0);
  });
}

Deno.test("C2 DB failure after known PDF response retains file for reconciliation", async () => {
  const pdf = await buildSyntheticPdf(["text"]);
  const fake = fakeDependencies(pdf, "pdf", "completion_failure");
  fake.work = workUnit();
  const response = await createAdvanceMaterialAnalysisHandler(fake.deps)(
    request({ material_id: materialId }),
  );
  equal(response.status, 500);
  equal(fake.providerRequests, 1);
  equal(fake.responsePersistenceAttempts, 1);
  equal(fake.deleteRequests, 0);
  equal(fake.completions, 1);
});

for (
  const [providerMode, expectedFailure] of [
    ["retrieval_incomplete", "terminal_provider_incomplete"],
    ["retrieval_failed", "terminal_provider_failed"],
    ["retrieval_invalid", "terminal_structured_output_invalid"],
  ] as const
) {
  Deno.test(`C2 ${providerMode} terminalizes reconciliation without POST`, async () => {
    const fake = fakeDependencies(pngBytes(), "image", providerMode);
    fake.work = reconciliationWorkUnit();
    const handler = createAdvanceMaterialAnalysisHandler(fake.deps);
    equal((await handler(request({ material_id: materialId }))).status, 200);
    equal((await handler(request({ material_id: materialId }))).status, 200);
    equal(fake.providerMethods, ["GET"]);
    equal(fake.submissions, 0);
    equal(fake.completions, 0);
    equal(fake.failures.length, 1);
    equal(fake.failures[0].failure_class, expectedFailure);
  });
}

Deno.test("C2 explicit 429 uses persisted retry policy", async () => {
  const bytes = pngBytes();
  const fake = fakeDependencies(bytes, "image", "http_429");
  fake.work = workUnit();
  const response = await createAdvanceMaterialAnalysisHandler(fake.deps)(
    request({ material_id: materialId }),
  );
  equal(response.status, 200);
  equal(fake.failures[0].failure_class, "user_retry_required");
  equal(fake.failures[0].retry_after_seconds, undefined);
  equal(fake.submissions, 1);
});

Deno.test("C2 explicit retry authorizes then consumes without accepting attempt IDs", async () => {
  const pdf = await buildSyntheticPdf(["text"]);
  const fake = fakeDependencies(pdf);
  fake.status.state = "user_retry_required";
  fake.status.can_retry = true;
  const response = await createRetryMaterialAnalysisHandler(fake.deps)(
    request({ material_id: materialId }),
  );
  equal(response.status, 200);
  equal(fake.retryAuthorizations, 1);
  equal(fake.retryConsumptions, 1);
  const rejected = await createRetryMaterialAnalysisHandler(fake.deps)(request({
    material_id: materialId,
    attempt_id: "attacker",
  }));
  equal(rejected.status, 400);
});

Deno.test("ownership misses are identical and safe for all public handlers", async () => {
  const pdf = await buildSyntheticPdf(["text"]);
  for (const scenario of publicHandlerScenarios()) {
    const crossUser = fakeDependencies(pdf);
    crossUser.deps.loadSource = () =>
      Promise.reject(new SafeAnalysisError("material_unavailable", 404));
    const crossResponse = await scenario.handler(crossUser.deps)(
      request(scenario.body),
    );
    const crossBody = await crossResponse.text();

    const nonexistent = fakeDependencies(pdf);
    nonexistent.deps.loadSource = () =>
      Promise.reject(new SafeAnalysisError("material_unavailable", 404));
    const nonexistentResponse = await scenario.handler(nonexistent.deps)(
      request(scenario.body),
    );
    const nonexistentBody = await nonexistentResponse.text();

    equal(crossResponse.status, 404);
    equal(nonexistentResponse.status, 404);
    equal(crossBody, nonexistentBody);
    equal(
      crossBody,
      JSON.stringify({
        error: "Material unavailable.",
        code: "material_unavailable",
      }),
    );
  }
});

Deno.test("authentication and strict requests remain closed for all public handlers", async () => {
  const pdf = await buildSyntheticPdf(["text"]);
  for (const scenario of publicHandlerScenarios()) {
    const fake = fakeDependencies(pdf);
    const missingJwt = await scenario.handler(fake.deps)(
      request(scenario.body, false),
    );
    equal(missingJwt.status, 401);
    equal(
      await missingJwt.text(),
      JSON.stringify({
        error: "Authentication required.",
      }),
    );

    const malformed = await scenario.handler(fake.deps)(request({
      ...scenario.body,
      unexpected: "private",
    }));
    equal(malformed.status, 400);
    equal((await malformed.json()).code, "invalid_request");
  }
});

Deno.test("internal and network failures remain safe 500 responses", async () => {
  const pdf = await buildSyntheticPdf(["text"]);
  for (const scenario of publicHandlerScenarios()) {
    for (
      const rawDetail of [
        "relation public.materials denied for user secret-user-id",
        "network request exposed private.internal.example",
      ]
    ) {
      const fake = fakeDependencies(pdf);
      fake.deps.loadSource = () => Promise.reject(new Error(rawDetail));
      const lines: string[] = [];
      const original = console.log;
      console.log = (line: unknown) => lines.push(String(line));
      try {
        const response = await scenario.handler(fake.deps)(
          request(scenario.body),
        );
        const body = await response.text();
        equal(response.status, 500);
        equal(
          body,
          JSON.stringify({
            error: "Material analysis is temporarily unavailable.",
            code: "request_failed",
          }),
        );
        equal(body.includes(rawDetail), false);
      } finally {
        console.log = original;
      }
      equal(lines.some((line) => line.includes(rawDetail)), false);
    }
  }
});

function publicHandlerScenarios() {
  return [
    {
      handler: createPrepareMaterialAnalysisHandler,
      body: {
        material_id: materialId,
        processing_mode: "recommended",
        confirm_large_document: false,
      },
    },
    {
      handler: createAdvanceMaterialAnalysisHandler,
      body: { material_id: materialId },
    },
    {
      handler: createRetryMaterialAnalysisHandler,
      body: { material_id: materialId },
    },
  ] as const;
}

function fakeDependencies(
  bytes: Uint8Array,
  kind: "pdf" | "image" = "pdf",
  providerMode:
    | "success"
    | "network_failure"
    | "upload_failure"
    | "file_persistence_failure"
    | "response_persistence_transient"
    | "completion_failure"
    | "diagnostic_latex_failure"
    | "diagnostic_final_success"
    | "retrieval_incomplete"
    | "retrieval_failed"
    | "retrieval_invalid"
    | "retrieval_final_success"
    | "retrieval_reduction_success"
    | "final_equation_replaced"
    | "final_equation_orphan"
    | "final_equation_referenced_only"
    | "final_equation_unchanged"
    | "http_429" = "success",
) {
  const state = {
    source: source(bytes, kind) as Record<string, unknown>,
    preparations: [] as Array<{
      page_count: number;
      page_plans: unknown[];
      [key: string]: unknown;
    }>,
    status: publicStatus() as Record<string, unknown>,
    work: { kind: "none", material_id: materialId } as InternalWorkUnit,
    claims: 0,
    submissions: 0,
    completions: 0,
    failures: [] as Array<Record<string, unknown>>,
    retryAuthorizations: 0,
    retryConsumptions: 0,
    providerRequests: 0,
    providerMethods: [] as string[],
    uploadRequests: 0,
    deleteRequests: 0,
    fileIntents: 0,
    fileRecoveries: 0,
    responsePersistenceAttempts: 0,
    diagnostics: [] as Array<Record<string, unknown>>,
    observedImageBytes: new Uint8Array(),
  };
  const provider = new TrustedOpenAiAdapter({
    apiKey: runtimeApiFixture,
    model: "server-model",
    fetcher: async (input, init) => {
      await Promise.resolve();
      if (String(input).endsWith("/files")) {
        state.uploadRequests++;
        if (providerMode === "upload_failure") throw new TypeError("network");
        return new Response(JSON.stringify({ id: "file_12345678" }), {
          status: 200,
          headers: { "Content-Type": "application/json" },
        });
      }
      if (String(input).includes("/files/")) {
        state.deleteRequests++;
        return new Response(JSON.stringify({ deleted: true }), { status: 200 });
      }
      if (!String(input).includes("/responses")) {
        throw new Error("unexpected provider endpoint");
      }
      state.providerRequests++;
      state.providerMethods.push(init?.method ?? "GET");
      if ((init?.method ?? "GET") === "GET") {
        if (providerMode === "retrieval_incomplete") {
          return new Response(
            JSON.stringify({
              id: "resp_12345678",
              object: "response",
              status: "incomplete",
              incomplete_details: { reason: "max_output_tokens" },
            }),
            { status: 200, headers: { "Content-Type": "application/json" } },
          );
        }
        if (providerMode === "retrieval_failed") {
          return new Response(
            JSON.stringify({
              id: "resp_12345678",
              object: "response",
              status: "failed",
            }),
            { status: 200, headers: { "Content-Type": "application/json" } },
          );
        }
        if (providerMode === "retrieval_invalid") {
          return new Response(
            JSON.stringify(completedResponse({
              ...pageBatch(),
              unexpected: true,
            })),
            { status: 200, headers: { "Content-Type": "application/json" } },
          );
        }
        if (providerMode === "diagnostic_final_success") {
          return new Response(
            JSON.stringify(completedResponse(finalSummary())),
            { status: 200, headers: { "Content-Type": "application/json" } },
          );
        }
        if (providerMode === "retrieval_final_success") {
          return new Response(
            JSON.stringify(completedResponse(finalSummary())),
            { status: 200, headers: { "Content-Type": "application/json" } },
          );
        }
        if (providerMode === "retrieval_reduction_success") {
          return new Response(
            JSON.stringify(completedResponse(reductionResult())),
            { status: 200, headers: { "Content-Type": "application/json" } },
          );
        }
        const payload = pageBatch();
        if (providerMode === "diagnostic_latex_failure") {
          (payload.pages[0] as Record<string, unknown>).equations = [{
            id: "eq_bad",
            latex: String.raw`\href{private provider content}{x}`,
            explanation_markdown: "",
            source_page: 1,
            display: "block",
            confidence: 0.9,
            uncertainty: false,
          }];
        }
        return new Response(JSON.stringify(completedResponse(payload)), {
          status: 200,
          headers: { "Content-Type": "application/json" },
        });
      }
      const body = JSON.parse(String(init?.body));
      const dataUrl = body.input[0].content.find((
        item: Record<string, unknown>,
      ) => item.type === "input_image")?.image_url;
      if (typeof dataUrl === "string") {
        state.observedImageBytes = fromBase64(dataUrl.split(",")[1]);
      }
      if (providerMode === "network_failure") throw new TypeError("network");
      if (providerMode === "http_429") {
        return new Response(JSON.stringify({ error: "private" }), {
          status: 429,
          headers: { "Content-Type": "application/json", "Retry-After": "17" },
        });
      }
      const finalOperation =
        body.text?.format?.name === "phase_c_final_summary_v3";
      const equationMode = providerMode === "final_equation_replaced" ||
          providerMode === "final_equation_orphan" ||
          providerMode === "final_equation_referenced_only" ||
          providerMode === "final_equation_unchanged"
        ? providerMode
        : null;
      return new Response(
        JSON.stringify(completedResponse(
          finalOperation
            ? equationMode
              ? finalSummaryWithEquation(equationMode)
              : finalSummary()
            : pageBatch(),
        )),
        { status: 200, headers: { "Content-Type": "application/json" } },
      );
    },
  });
  const deps: AnalysisDependencies = {
    verifyJwt: (jwt) =>
      Promise.resolve(jwt === runtimeAuthFixture ? owner : null),
    verifyServiceJwt: (jwt) => Promise.resolve(jwt === runtimeServiceFixture),
    loadSource: () => Promise.resolve(state.source),
    downloadPrivate: () => Promise.resolve(Uint8Array.from(bytes)),
    prepareInternal: (input) => {
      state.preparations.push(structuredClone(input));
      return Promise.resolve("job");
    },
    claimNext: () => {
      state.claims++;
      return Promise.resolve(state.work);
    },
    markSubmitted: () => {
      state.submissions++;
      return Promise.resolve({ idempotency_key: "a".repeat(64) });
    },
    createFileIntent: () => {
      state.fileIntents++;
      return Promise.resolve({
        artifact_id: artifactId,
      });
    },
    recordFileUploaded: () =>
      providerMode === "file_persistence_failure"
        ? Promise.reject(new Error("trusted_rpc_failed"))
        : Promise.resolve(),
    recordFileRecovery: () => {
      state.fileRecoveries++;
      return Promise.resolve();
    },
    markResponseKnown: () => {
      state.responsePersistenceAttempts++;
      if (
        providerMode === "response_persistence_transient" &&
        state.responsePersistenceAttempts === 1
      ) return Promise.reject(new Error("trusted_rpc_failed"));
      return Promise.resolve();
    },
    markDispatchUnknown: () => Promise.resolve(),
    completeOperation: () => {
      state.completions++;
      if (providerMode === "completion_failure") {
        return Promise.reject(new Error("trusted_rpc_failed"));
      }
      state.work = { kind: "none", material_id: materialId };
      return Promise.resolve();
    },
    failOperation: (input) => {
      state.failures.push(structuredClone(input));
      if (String(input.failure_class).startsWith("terminal_")) {
        state.work = { kind: "none", material_id: materialId };
      }
      return Promise.resolve();
    },
    reconcileOperation: () => Promise.resolve(),
    persistCleanup: () => Promise.resolve(),
    authorizeRetry: () => {
      state.retryAuthorizations++;
      return Promise.resolve(retryAuthorizationId);
    },
    consumeRetry: () => {
      state.retryConsumptions++;
      return Promise.resolve();
    },
    getStatus: () => Promise.resolve(state.status),
    loadDiagnosticTarget: (requestedBatchId) =>
      Promise.resolve({
        batch_id: requestedBatchId,
        operation: "page_visual",
        status: "failed",
        response_id: "resp_12345678",
        page_numbers: [1],
        page_count: 1,
        cleanup_state: "pending",
      }),
    recordDiagnostic: (input) => {
      state.diagnostics.push(structuredClone(input));
      return Promise.resolve();
    },
    provider,
    jitter: () => 0,
  };
  return Object.assign(state, { deps });
}

function source(bytes: Uint8Array, kind: "pdf" | "image") {
  return {
    id: materialId,
    user_id: owner,
    kind,
    source_kind: "upload",
    storage_bucket: kind === "pdf" ? "study-materials" : "study-images",
    storage_path: `${owner}/${materialId}/notes.${
      kind === "pdf" ? "pdf" : "png"
    }`,
    mime_type: kind === "pdf" ? "application/pdf" : "image/png",
    file_size_bytes: bytes.length,
    processing_status: "ready",
    deleted_at: null,
    metadata: {},
  };
}

function workUnit(): InternalWorkUnit {
  return {
    kind: "page_visual",
    material_id: materialId,
    job_id: jobId,
    batch_id: batchId,
    lease_token: leaseId,
    page_count: 1,
    page_numbers: [1],
    validation_version: analysisValidatorVersion,
  };
}

function reconciliationWorkUnit(): InternalWorkUnit {
  return {
    ...workUnit(),
    kind: "reconciliation",
    operation: "page_visual",
    response_id: "resp_12345678",
    idempotency_key: "a".repeat(64),
    input_payload: { operation: "page_visual" },
  };
}

function finalSummaryWorkUnit(): InternalWorkUnit {
  return {
    kind: "final_summary",
    material_id: materialId,
    job_id: jobId,
    batch_id: batchId,
    lease_token: leaseId,
    page_count: 1,
    page_numbers: [1],
    validation_version: analysisValidatorVersion,
    input_payload: finalSummaryInputPayload(),
  };
}

function finalSummaryEquationWorkUnit(): InternalWorkUnit {
  const equation = runtimeEquation();
  return {
    ...finalSummaryWorkUnit(),
    input_payload: {
      ...finalSummaryInputPayload(),
      authoritative_equations: [equation],
      validated_reduction: {
        ...finalSummaryInputPayload().validated_reduction,
        equation_ids: [equation.id],
      },
    },
  };
}

function finalSummaryReconciliationWorkUnit(): InternalWorkUnit {
  return {
    ...finalSummaryWorkUnit(),
    kind: "reconciliation",
    operation: "final_summary",
    response_id: "resp_12345678",
    idempotency_key: "a".repeat(64),
  };
}

function reductionReconciliationWorkUnit(): InternalWorkUnit {
  return {
    kind: "reconciliation",
    operation: "reduction",
    material_id: materialId,
    job_id: jobId,
    batch_id: batchId,
    lease_token: leaseId,
    response_id: "resp_12345678",
    idempotency_key: "a".repeat(64),
    page_count: 1,
    page_numbers: [1],
    validation_version: analysisValidatorVersion,
    input_payload: {
      inputs: [pageBatch().pages[0]],
      equation_ids: [],
    },
  };
}

function pageTextReconciliationWorkUnit(): InternalWorkUnit {
  return {
    kind: "reconciliation",
    operation: "page_text",
    material_id: materialId,
    job_id: jobId,
    batch_id: batchId,
    lease_token: leaseId,
    response_id: "resp_12345678",
    idempotency_key: "a".repeat(64),
    page_count: 1,
    page_numbers: [1],
    validation_version: analysisValidatorVersion,
    input_payload: {
      pages: [{ page_number: 1, normalized_text: "Selectable text." }],
    },
  };
}

function finalSummaryInputPayload() {
  return {
    operation: "final_summary",
    authoritative_equations: [],
    validated_reduction: {
      source_pages: [1],
      summary_markdown: "Validated reduction.",
      key_concepts: [],
      equation_ids: [],
      warnings: [],
      confidence: 0.9,
    },
    manifest: [{
      page_number: 1,
      status: "completed",
      route: "visual",
      warnings: [],
    }],
  };
}

function pageBatch() {
  return {
    pages: [{
      page_number: 1,
      content_status: "completed",
      summary_markdown: "Safe summary.",
      key_concepts: [],
      equations: [],
      confidence: 0.9,
      warnings: [],
      trustworthy: true,
    }],
  };
}

function reductionResult() {
  return {
    source_pages: [1],
    summary_markdown: "Safe reduction.",
    key_concepts: [],
    equation_ids: [],
    warnings: [],
    confidence: 0.9,
  };
}

function finalSummary() {
  return {
    language: "en",
    sections: [{
      id: "section_1",
      title: "Summary",
      blocks: [{
        kind: "prose",
        markdown: "Safe summary.",
        display: "block",
      }],
      source_pages: [1],
      confidence: 0.9,
    }],
    key_concepts: [],
    equations: [],
    warnings: [],
    partial_extraction: {
      is_partial: false,
      analyzed_pages: [1],
      partial_pages: [],
      missing_pages: [],
      page_modes: [{ page: 1, mode: "visual" }],
    },
  };
}

function runtimeEquation() {
  return {
    id: "eq_runtime",
    latex: "x+y",
    explanation_markdown: "Canonical equation.",
    source_page: 1,
    display: "block" as const,
    confidence: 0.9,
    uncertainty: false,
  };
}

function finalSummaryWithEquation(
  mode:
    | "final_equation_replaced"
    | "final_equation_orphan"
    | "final_equation_referenced_only"
    | "final_equation_unchanged",
) {
  const authoritative = runtimeEquation();
  const providerEquation = mode === "final_equation_replaced"
    ? {
      ...authoritative,
      latex: "z",
      explanation_markdown: "Provider replacement.",
      display: "inline" as const,
      confidence: 0.4,
      uncertainty: true,
    }
    : authoritative;
  const summary = finalSummary();
  return {
    ...summary,
    sections: [{
      ...summary.sections[0],
      blocks: mode === "final_equation_orphan" ? summary.sections[0].blocks : [{
        kind: "equation" as const,
        equation_id: authoritative.id,
        display: "block" as const,
      }],
    }],
    equations: mode === "final_equation_referenced_only"
      ? []
      : [providerEquation],
  };
}

function completedResponse(value: unknown) {
  return {
    id: "resp_12345678",
    object: "response",
    status: "completed",
    error: null,
    incomplete_details: null,
    output: [{
      type: "message",
      content: [{ type: "output_text", text: JSON.stringify(value) }],
    }],
  };
}

function publicStatus() {
  return {
    material_id: materialId,
    processing_mode: "recommended",
    state: "processing",
    public_stage: "analyzing_pages",
    page_count: 1,
    completed_pages: 0,
    confirmation_required: false,
    can_retry: false,
    can_analyze_again: false,
    retry_after_seconds: null,
    warnings: [],
    summary_schema_version: null,
    summary_payload: null,
  };
}

function request(body: Record<string, unknown>, authenticated = true) {
  return new Request("https://example.test", {
    method: "POST",
    headers: authenticated
      ? {
        Authorization: ["Bearer", runtimeAuthFixture].join(" "),
        "Content-Type": "application/json",
      }
      : { "Content-Type": "application/json" },
    body: JSON.stringify(body),
  });
}

function diagnosticRequest(requestedBatchId: string) {
  return new Request("https://example.test", {
    method: "POST",
    headers: {
      Authorization: ["Bearer", runtimeServiceFixture].join(" "),
      "Content-Type": "application/json",
      "x-material-analysis-operation": "diagnose-preserved-response-v1",
    },
    body: JSON.stringify({ batch_id: requestedBatchId }),
  });
}

function normalDiagnosticShapedRequest(withHeader: boolean) {
  const headers: Record<string, string> = {
    Authorization: ["Bearer", runtimeAuthFixture].join(" "),
    "Content-Type": "application/json",
  };
  if (withHeader) {
    headers["x-material-analysis-operation"] = "diagnose-preserved-response-v1";
  }
  return new Request("https://example.test", {
    method: "POST",
    headers,
    body: JSON.stringify({ batch_id: batchId }),
  });
}

function pngBytes() {
  return Uint8Array.from([
    0x89,
    0x50,
    0x4e,
    0x47,
    0x0d,
    0x0a,
    0x1a,
    0x0a,
    1,
    2,
    3,
  ]);
}

function fromBase64(value: string) {
  return Uint8Array.from(atob(value), (character) => character.charCodeAt(0));
}

function equal(actual: unknown, expected: unknown) {
  if (actual instanceof Uint8Array && expected instanceof Uint8Array) {
    if (
      actual.length === expected.length &&
      actual.every((value, index) => value === expected[index])
    ) return;
  } else if (JSON.stringify(actual) === JSON.stringify(expected)) return;
  throw new Error(
    `Expected ${JSON.stringify(expected)}, got ${JSON.stringify(actual)}`,
  );
}
