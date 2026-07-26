import {
  analysisLog,
  analysisValidatorVersion,
  buildPagePlans,
  buildProcessingVersionContract,
  confirmationRequired,
  inspectSourceBytes,
  parseMaterialOnlyRequest,
  parsePrepareRequest,
  projectSummaryToSafeMarkdown,
  SafeAnalysisError,
  sanitizePublicStatus,
  SourceMaterial,
  validateSourceMaterial,
  validationHash,
} from "./engine.ts";
import {
  classifyFailure,
  persistedBackoffSeconds,
} from "./fingerprints_retry.ts";
import { createMiniPdf } from "./mini_pdf.ts";
import {
  ProviderBoundaryError,
  ProviderRequest,
  TrustedOpenAiAdapter,
} from "./openai_adapter.ts";
import { Equation, StructuredSummary } from "./contracts.ts";
import {
  DiagnosticCode,
  DiagnosticMetadata,
  diagnosticVersion,
} from "./response_diagnostics.ts";

type AnalysisOperation =
  | "page_text"
  | "page_visual"
  | "page_recovery"
  | "reduction"
  | "final_summary";

const analysisOperations: readonly AnalysisOperation[] = [
  "page_text",
  "page_visual",
  "page_recovery",
  "reduction",
  "final_summary",
];

export type InternalWorkUnit = {
  kind:
    | "none"
    | "page_text"
    | "page_visual"
    | "page_recovery"
    | "reduction"
    | "final_summary"
    | "reconciliation"
    | "cleanup";
  operation?: AnalysisOperation;
  material_id: string;
  job_id?: string;
  batch_id?: string;
  lease_token?: string;
  idempotency_key?: string;
  page_count?: number;
  page_numbers?: number[];
  input_payload?: unknown;
  response_id?: string;
  temporary_file_id?: string;
  artifact_id?: string;
  mime_type?: string;
  validation_version?: string;
};

export type AnalysisDependencies = {
  verifyJwt(jwt: string): Promise<string | null>;
  verifyServiceJwt?(jwt: string): Promise<boolean>;
  loadSource(principalId: string, materialId: string): Promise<unknown>;
  downloadPrivate(material: SourceMaterial): Promise<Uint8Array>;
  prepareInternal(input: {
    principal_id: string;
    material_id: string;
    processing_mode: string;
    confirm_large_document: boolean;
    analyze_again: boolean;
    page_count: number;
    source_hash: string;
    version_contract: Record<string, unknown>;
    version_fingerprint: string;
    page_plans: unknown[];
  }): Promise<unknown>;
  claimNext(
    input: { principal_id: string; material_id: string },
  ): Promise<InternalWorkUnit>;
  markSubmitted(input: {
    batch_id: string;
    lease_token: string;
  }): Promise<{ idempotency_key: string }>;
  createFileIntent(input: {
    batch_id: string;
    lease_token: string;
  }): Promise<{ artifact_id: string }>;
  recordFileUploaded(input: {
    artifact_id: string;
    lease_token: string;
    temporary_file_id: string;
  }): Promise<void>;
  recordFileRecovery(input: {
    artifact_id: string;
    lease_token: string;
    temporary_file_id: string;
    deleted: boolean;
  }): Promise<void>;
  markResponseKnown(input: {
    batch_id: string;
    lease_token: string;
    response_id: string;
    temporary_file_id?: string;
  }): Promise<void>;
  markDispatchUnknown(input: {
    batch_id: string;
    lease_token: string;
  }): Promise<void>;
  completeOperation(input: {
    batch_id: string;
    lease_token: string;
    result: unknown;
    validation_version: string;
    validation_hash: string;
    summary_markdown?: string;
    cleanup_complete: boolean;
  }): Promise<void>;
  failOperation(input: {
    batch_id: string;
    lease_token: string;
    failure_class: string;
    retry_after_seconds?: number;
    temporary_file_id?: string;
    cleanup_complete?: boolean;
  }): Promise<void>;
  reconcileOperation(input: {
    batch_id: string;
    lease_token: string;
    result: unknown;
    validation_version: string;
    validation_hash: string;
  }): Promise<void>;
  persistCleanup(input: {
    artifact_id: string;
    lease_token: string;
    temporary_file_id: string;
    complete: boolean;
  }): Promise<void>;
  authorizeRetry(principalId: string, materialId: string): Promise<string>;
  consumeRetry(materialId: string, authorizationId: string): Promise<void>;
  getStatus(principalId: string, materialId: string): Promise<unknown>;
  loadDiagnosticTarget?(batchId: string): Promise<DiagnosticTarget>;
  recordDiagnostic?(input: {
    batch_id: string;
    diagnostic_code: DiagnosticCode;
    diagnostic_metadata: DiagnosticMetadata;
    diagnostic_version: number;
  }): Promise<void>;
  provider: TrustedOpenAiAdapter;
  jitter(): number;
};

type DiagnosticTargetBase = {
  batch_id: string;
  status: "failed";
  response_id: string;
  page_numbers: number[];
  page_count: number;
  cleanup_state: "not_required" | "pending" | "completed";
};
export type DiagnosticTarget =
  & DiagnosticTargetBase
  & ({ operation: "page_visual" } | { operation: "final_summary" });

const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers":
    "authorization, x-client-info, apikey, content-type",
  "Access-Control-Allow-Methods": "POST, OPTIONS",
};

export function createPrepareMaterialAnalysisHandler(
  deps: AnalysisDependencies,
) {
  return createPublicHandler("prepare", deps, async (request, principalId) => {
    const body = parsePrepareRequest(await safeJson(request));
    const rawMaterial = await deps.loadSource(principalId, body.material_id);
    const material = validateSourceMaterial(
      rawMaterial,
      principalId,
      body.material_id,
    );
    const bytes = await deps.downloadPrivate(material);
    const inspected = await inspectSourceBytes(material, bytes);
    const version = await buildProcessingVersionContract({
      material,
      sourceHash: inspected.sourceHash,
      processingMode: body.processing_mode,
      pageCount: inspected.pageCount,
    });
    if (
      confirmationRequired(inspected.pageCount) && !body.confirm_large_document
    ) {
      const plans = await buildPagePlans({
        material,
        pageCount: inspected.pageCount,
        mode: body.processing_mode,
        selectablePages: selectablePages(material.metadata),
      });
      await deps.prepareInternal({
        principal_id: principalId,
        material_id: material.id,
        processing_mode: body.processing_mode,
        confirm_large_document: false,
        analyze_again: body.analyze_again,
        page_count: inspected.pageCount,
        source_hash: inspected.sourceHash,
        version_contract: version.contract,
        version_fingerprint: version.fingerprint,
        page_plans: plans,
      });
      return await deps.getStatus(principalId, material.id);
    }
    const plans = await buildPagePlans({
      material,
      pageCount: inspected.pageCount,
      mode: body.processing_mode,
      selectablePages: selectablePages(material.metadata),
    });
    await deps.prepareInternal({
      principal_id: principalId,
      material_id: material.id,
      processing_mode: body.processing_mode,
      confirm_large_document: body.confirm_large_document,
      analyze_again: body.analyze_again,
      page_count: inspected.pageCount,
      source_hash: inspected.sourceHash,
      version_contract: version.contract,
      version_fingerprint: version.fingerprint,
      page_plans: plans,
    });
    return await deps.getStatus(principalId, material.id);
  });
}

export function createAdvanceMaterialAnalysisHandler(
  deps: AnalysisDependencies,
) {
  return createPublicHandler("advance", deps, async (request, principalId) => {
    const body = parseMaterialOnlyRequest(await safeJson(request));
    const material = validateSourceMaterial(
      await deps.loadSource(principalId, body.material_id),
      principalId,
      body.material_id,
    );
    const work = await deps.claimNext({
      principal_id: principalId,
      material_id: body.material_id,
    });
    if (work.kind !== "none") await executeOneWorkUnit(deps, work, material);
    return await deps.getStatus(principalId, body.material_id);
  });
}

export function createMaterialAnalysisDispatchHandler(
  deps: AnalysisDependencies,
) {
  const advance = createAdvanceMaterialAnalysisHandler(deps);
  const diagnostic = createMaterialAnalysisDiagnosticHandler(deps);
  return async (request: Request): Promise<Response> => {
    if (
      request.headers.get("x-material-analysis-operation") !==
        "diagnose-preserved-response-v1"
    ) return advance(request);
    const jwt = bearerToken(request);
    let authorized = false;
    try {
      authorized = !!jwt && !!deps.verifyServiceJwt &&
        await deps.verifyServiceJwt(jwt);
    } catch (_) {
      authorized = false;
    }
    return authorized ? diagnostic(request) : advance(request);
  };
}

export function createMaterialAnalysisDiagnosticHandler(
  deps: AnalysisDependencies,
) {
  return async (request: Request): Promise<Response> => {
    if (request.method !== "POST") {
      return json({ error: "Method not allowed." }, 405);
    }
    const jwt = bearerToken(request);
    if (
      !jwt || !deps.verifyServiceJwt || !deps.loadDiagnosticTarget ||
      !deps.recordDiagnostic || !(await deps.verifyServiceJwt(jwt))
    ) return json({ error: "Authentication required." }, 401);
    try {
      const batchId = parseDiagnosticRequest(await safeJson(request));
      const target = validateDiagnosticTarget(
        await deps.loadDiagnosticTarget(batchId),
        batchId,
      );
      const result = target.operation === "page_visual"
        ? await deps.provider.diagnoseRetrieved({
          responseId: target.response_id,
          request: {
            operation: "page_visual",
            input: {
              kind: "pdf",
              bytes: new Uint8Array(),
              pageNumbers: target.page_numbers,
            },
            expectedPages: target.page_numbers,
            pageCount: target.page_count,
            idempotencyKey: "0".repeat(64),
          },
        })
        : await deps.provider.diagnoseFinalSummaryRetrieved({
          responseId: target.response_id,
          pageCount: target.page_count,
        });
      const diagnostic = result.ok
        ? target.operation === "page_visual"
          ? {
            code: "page_persistence_failed" as const,
            metadata: {
              ...result.metadata,
              validator_stage: "persistValidatedPage" as const,
            },
          }
          : {
            code: "final_summary_persistence_failed" as const,
            metadata: {
              ...result.metadata,
              validator_stage: "persistFinalSummaryEligibility" as const,
            },
          }
        : { code: result.code, metadata: result.metadata };
      await deps.recordDiagnostic({
        batch_id: target.batch_id,
        diagnostic_code: diagnostic.code,
        diagnostic_metadata: diagnostic.metadata,
        diagnostic_version: diagnosticVersion,
      });
      analysisLog("diagnostic", "recorded", {
        reason: diagnostic.code,
        ...diagnostic.metadata,
      });
      return json({ status: "recorded" });
    } catch (_) {
      analysisLog("diagnostic", "failed", { reason: "validation_unknown" });
      return json(
        { error: "Material analysis is temporarily unavailable." },
        500,
      );
    }
  };
}

export function createRetryMaterialAnalysisHandler(deps: AnalysisDependencies) {
  return createPublicHandler("retry", deps, async (request, principalId) => {
    const body = parseMaterialOnlyRequest(await safeJson(request));
    validateSourceMaterial(
      await deps.loadSource(principalId, body.material_id),
      principalId,
      body.material_id,
    );
    const authorization = await deps.authorizeRetry(
      principalId,
      body.material_id,
    );
    await deps.consumeRetry(body.material_id, authorization);
    return await deps.getStatus(principalId, body.material_id);
  });
}

async function executeOneWorkUnit(
  deps: AnalysisDependencies,
  work: InternalWorkUnit,
  material: SourceMaterial,
) {
  if (work.kind === "cleanup") {
    if (!work.artifact_id || !work.lease_token || !work.temporary_file_id) {
      throw new SafeAnalysisError("work_unavailable", 500);
    }
    const complete = await deps.provider.deleteFile(work.temporary_file_id);
    await deps.persistCleanup({
      artifact_id: work.artifact_id,
      lease_token: work.lease_token,
      temporary_file_id: work.temporary_file_id,
      complete,
    });
    return;
  }
  const required = requireWorkIds(work);
  if (work.validation_version !== analysisValidatorVersion) {
    analysisLog("advance", "structured_output_invalid", {
      reason: "legacy_validator_version",
      validator_stage: "validateVersionContract",
      validator_code: "validator_version_mismatch",
    });
    await deps.failOperation({
      batch_id: required.batchId,
      lease_token: required.leaseToken,
      failure_class: "terminal_structured_output_invalid",
    });
    return;
  }
  if (work.kind === "reconciliation") {
    if (!work.response_id) throw new SafeAnalysisError("work_unavailable", 500);
    const request = await providerRequestOrTerminalize(
      deps,
      work,
      material,
      required.idempotencyKey,
    );
    if (!request) return;
    const retrieved = await deps.provider.retrieve({
      responseId: work.response_id,
      request,
    });
    if (retrieved.status === "pending") {
      await deps.failOperation({
        batch_id: required.batchId,
        lease_token: required.leaseToken,
        failure_class: "reconcile_only",
      });
      return;
    }
    if (retrieved.status === "incomplete") {
      await deps.failOperation({
        batch_id: required.batchId,
        lease_token: required.leaseToken,
        failure_class: "terminal_provider_incomplete",
      });
      return;
    }
    if (retrieved.status === "failed") {
      await deps.failOperation({
        batch_id: required.batchId,
        lease_token: required.leaseToken,
        failure_class: "terminal_provider_failed",
      });
      return;
    }
    if (retrieved.status === "invalid" || retrieved.result === undefined) {
      if (retrieved.diagnostic) {
        analysisLog("advance", "structured_output_invalid", {
          reason: "structured_output_invalid",
          ...retrieved.diagnostic,
        });
      }
      await deps.failOperation({
        batch_id: required.batchId,
        lease_token: required.leaseToken,
        failure_class: "terminal_structured_output_invalid",
      });
      return;
    }
    logPageBatchComparison(retrieved.pageBatchComparison);
    logReductionKeyConceptComparison(
      retrieved.reductionKeyConceptComparison,
    );
    logEquationComparison(retrieved.equationComparison);
    await deps.completeOperation({
      batch_id: required.batchId,
      lease_token: required.leaseToken,
      result: retrieved.result,
      validation_version: analysisValidatorVersion,
      validation_hash: await validationHash(retrieved.result),
      summary_markdown: request.operation === "final_summary"
        ? projectSummaryToSafeMarkdown(retrieved.result as StructuredSummary)
        : undefined,
      cleanup_complete: !work.temporary_file_id,
    });
    return;
  }

  const request = await providerRequestOrTerminalize(
    deps,
    work,
    material,
    "0".repeat(64),
  );
  if (!request) return;
  let temporaryFileId: string | undefined;
  let artifactId: string | undefined;
  try {
    if (request.input.kind === "pdf") {
      const intent = await deps.createFileIntent({
        batch_id: required.batchId,
        lease_token: required.leaseToken,
      });
      artifactId = intent.artifact_id;
      temporaryFileId = await deps.provider.uploadPdf(
        request.input.bytes,
        artifactId,
      );
      try {
        await deps.recordFileUploaded({
          artifact_id: artifactId,
          lease_token: required.leaseToken,
          temporary_file_id: temporaryFileId,
        });
      } catch (_) {
        const deleted = await deps.provider.deleteFile(temporaryFileId);
        try {
          await deps.recordFileRecovery({
            artifact_id: artifactId,
            lease_token: required.leaseToken,
            temporary_file_id: temporaryFileId,
            deleted,
          });
        } catch (_) {
          // The durable intent and provider filename preserve manual recovery identity.
        }
        await deps.failOperation({
          batch_id: required.batchId,
          lease_token: required.leaseToken,
          failure_class: "pre_dispatch_retryable",
          temporary_file_id: temporaryFileId,
          cleanup_complete: deleted,
        });
        return;
      }
    }
    const provider = await deps.provider.execute(request, async () => {
      const submitted = await deps.markSubmitted({
        batch_id: required.batchId,
        lease_token: required.leaseToken,
      });
      return submitted.idempotency_key;
    }, temporaryFileId);
    await persistResponseKnown(deps, {
      batch_id: required.batchId,
      lease_token: required.leaseToken,
      response_id: provider.responseId,
      temporary_file_id: temporaryFileId,
    });
    logPageBatchComparison(provider.pageBatchComparison);
    logReductionKeyConceptComparison(
      provider.reductionKeyConceptComparison,
    );
    logEquationComparison(provider.equationComparison);
    const summaryMarkdown = work.kind === "final_summary"
      ? projectSummaryToSafeMarkdown(provider.result as StructuredSummary)
      : undefined;
    await deps.completeOperation({
      batch_id: required.batchId,
      lease_token: required.leaseToken,
      result: provider.result,
      validation_version: analysisValidatorVersion,
      validation_hash: await validationHash(provider.result),
      summary_markdown: summaryMarkdown,
      cleanup_complete: !temporaryFileId,
    });
  } catch (error) {
    if (!(error instanceof ProviderBoundaryError)) throw error;
    if (error.diagnostic) {
      analysisLog("advance", "structured_output_invalid", {
        reason: "structured_output_invalid",
        ...error.diagnostic,
      });
    }
    if (error.responseId) {
      await persistResponseKnown(deps, {
        batch_id: required.batchId,
        lease_token: required.leaseToken,
        response_id: error.responseId,
        temporary_file_id: temporaryFileId,
      });
    }
    const classified = classifyFailure({
      dispatched: error.dispatched,
      responseId: error.responseId,
      status: error.status,
      errorKind: error.kind === "timeout" || error.kind === "network"
        ? error.kind
        : error.kind === "http"
        ? "unknown"
        : "validation",
    });
    let failureClass:
      | "pre_dispatch_retryable"
      | "retryable_response"
      | "non_retryable"
      | "reconcile_only"
      | "user_retry_required" = classified.kind;
    if (failureClass === "user_retry_required") {
      await deps.markDispatchUnknown({
        batch_id: required.batchId,
        lease_token: required.leaseToken,
      });
    }
    await deps.failOperation({
      batch_id: required.batchId,
      lease_token: required.leaseToken,
      failure_class: failureClass,
      retry_after_seconds: failureClass === "pre_dispatch_retryable"
        ? persistedBackoffSeconds({
          attempt: 1,
          retryAfterSeconds: error.retryAfterSeconds,
          jitter: deps.jitter,
        })
        : undefined,
      temporary_file_id: temporaryFileId,
      cleanup_complete: !temporaryFileId,
    });
  }
}

function logPageBatchComparison(
  comparison:
    | {
      expectedPageCount: number;
      returnedPageCount: number;
      synthesizedMissingPageCount: number;
      missingPageNumbersCount: number;
    }
    | undefined,
) {
  if (!comparison) return;
  analysisLog("advance", "page_batch_canonicalization", {
    validator_stage: "canonicalizePageBatchResult",
    validator_code: comparison.synthesizedMissingPageCount > 0
      ? "missing_pages_synthesized"
      : "page_batch_unchanged",
    expected_page_count: comparison.expectedPageCount,
    returned_page_count: comparison.returnedPageCount,
    synthesized_missing_page_count: comparison.synthesizedMissingPageCount,
    missing_page_numbers_count: comparison.missingPageNumbersCount,
  });
}

function logReductionKeyConceptComparison(
  comparison:
    | {
      providerKeyConceptCount: number;
      acceptedKeyConceptCount: number;
      droppedKeyConceptCount: number;
      duplicateKeyConceptCount: number;
      cappedKeyConceptCount: number;
    }
    | undefined,
) {
  if (!comparison) return;
  analysisLog("advance", "reduction_key_concept_canonicalization", {
    validator_stage: "canonicalizeReductionKeyConcepts",
    validator_code: comparison.droppedKeyConceptCount > 0 ||
        comparison.duplicateKeyConceptCount > 0 ||
        comparison.cappedKeyConceptCount > 0
      ? "reduction_key_concepts_canonicalized"
      : "reduction_key_concepts_unchanged",
    provider_key_concept_count: comparison.providerKeyConceptCount,
    accepted_key_concept_count: comparison.acceptedKeyConceptCount,
    dropped_key_concept_count: comparison.droppedKeyConceptCount,
    duplicate_key_concept_count: comparison.duplicateKeyConceptCount,
    capped_key_concept_count: comparison.cappedKeyConceptCount,
  });
}

function logEquationComparison(
  comparison:
    | {
      authoritativeEquationCount: number;
      providerEquationCount: number;
      referencedEquationObjectsAdded: number;
      orphanReferencesAdded: number;
      equationFieldsReplaced: boolean;
    }
    | undefined,
) {
  if (!comparison) return;
  analysisLog("advance", "equation_canonicalization", {
    validator_stage: "canonicalizeFinalSummaryEquations",
    validator_code: comparison.referencedEquationObjectsAdded > 0 ||
        comparison.orphanReferencesAdded > 0 ||
        comparison.equationFieldsReplaced
      ? "equation_canonicalized"
      : "equation_unchanged",
    authoritative_equation_count: comparison.authoritativeEquationCount,
    provider_equation_count: comparison.providerEquationCount,
    referenced_equation_objects_added:
      comparison.referencedEquationObjectsAdded,
    orphan_references_added: comparison.orphanReferencesAdded,
    equation_fields_replaced: comparison.equationFieldsReplaced,
  });
}

async function persistResponseKnown(
  deps: AnalysisDependencies,
  input: Parameters<AnalysisDependencies["markResponseKnown"]>[0],
) {
  try {
    await deps.markResponseKnown(input);
  } catch (_) {
    // A single immediate retry closes transient database disconnects without
    // issuing another paid provider request. Durable lease recovery handles
    // longer outages from the already-submitted attempt.
    await deps.markResponseKnown(input);
  }
}

async function providerRequest(
  deps: AnalysisDependencies,
  work: InternalWorkUnit,
  material: SourceMaterial,
  idempotencyKey: string,
): Promise<ProviderRequest> {
  const operation = resolveWorkOperation(work);
  const pages = work.page_numbers ?? [];
  let input: ProviderRequest["input"];
  if (
    (operation === "page_visual" || operation === "page_recovery") &&
    material.kind === "pdf"
  ) {
    const original = await deps.downloadPrivate(material);
    await inspectSourceBytes(material, original);
    const mini = await createMiniPdf(original, pages);
    if (mini.originalPageNumbers.join() !== pages.join()) {
      throw new Error("mini_pdf_mapping_failed");
    }
    input = { kind: "pdf", bytes: mini.bytes, pageNumbers: pages };
  } else if (
    (operation === "page_visual" || operation === "page_recovery") &&
    material.kind === "image"
  ) {
    const bytes = await deps.downloadPrivate(material);
    await inspectSourceBytes(material, bytes);
    input = { kind: "image", bytes, mimeType: material.mime_type };
  } else {
    input = { kind: "text", text: JSON.stringify(work.input_payload ?? {}) };
  }
  const authoritative = authoritativeEquations(work.input_payload);
  return {
    operation: operation as ProviderRequest["operation"],
    input,
    expectedPages: pages,
    allowedEquationIds: authoritative?.map((equation) => equation.id) ??
      equationIds(work.input_payload),
    authoritativeEquations: authoritative,
    pageCount: work.page_count ?? Math.max(...pages),
    idempotencyKey,
  };
}

async function providerRequestOrTerminalize(
  deps: AnalysisDependencies,
  work: InternalWorkUnit,
  material: SourceMaterial,
  idempotencyKey: string,
): Promise<ProviderRequest | null> {
  try {
    return await providerRequest(deps, work, material, idempotencyKey);
  } catch (error) {
    if (!(error instanceof DuplicateEquationIdError)) throw error;
    const required = requireWorkIds(work);
    analysisLog("advance", "structured_output_invalid", {
      reason: "duplicate_authoritative_equation_id",
      validator_stage: "validateAuthoritativeEquations",
      validator_code: "duplicate_authoritative_equation_id",
      equation_id_present: true,
    });
    await deps.failOperation({
      batch_id: required.batchId,
      lease_token: required.leaseToken,
      failure_class: "terminal_structured_output_invalid",
    });
    return null;
  }
}

function createPublicHandler(
  operation: "prepare" | "advance" | "retry",
  deps: AnalysisDependencies,
  action: (request: Request, principalId: string) => Promise<unknown>,
) {
  return async (request: Request): Promise<Response> => {
    if (request.method === "OPTIONS") {
      return new Response("ok", { headers: corsHeaders });
    }
    if (request.method !== "POST") {
      return json({ error: "Method not allowed." }, 405);
    }
    const authorization = request.headers.get("Authorization") ?? "";
    const jwt = authorization.startsWith("Bearer ")
      ? authorization.slice("Bearer ".length).trim()
      : "";
    if (!jwt) return json({ error: "Authentication required." }, 401);
    const principalId = await deps.verifyJwt(jwt);
    if (!principalId) return json({ error: "Authentication required." }, 401);
    try {
      const status = sanitizePublicStatus(await action(request, principalId));
      analysisLog(operation, "completed", {
        state: status.state,
        public_stage: status.public_stage,
        page_count: status.page_count,
        completed_pages: status.completed_pages,
      });
      return json(status as unknown as Record<string, unknown>);
    } catch (error) {
      const safe = error instanceof SafeAnalysisError
        ? error
        : new SafeAnalysisError("analysis_unavailable", 500);
      analysisLog(operation, "failed", {
        reason: safe.code,
        status: safe.status,
      });
      return json({
        error: publicMessage(safe.status),
        code: publicErrorCode(safe),
      }, safe.status);
    }
  };
}

function requireWorkIds(work: InternalWorkUnit) {
  if (!work.batch_id || !work.lease_token) {
    throw new SafeAnalysisError("work_unavailable", 500);
  }
  return {
    batchId: work.batch_id,
    leaseToken: work.lease_token,
    idempotencyKey: work.idempotency_key ?? "0".repeat(64),
  };
}

function selectablePages(metadata: Record<string, unknown> | undefined) {
  const extraction = isRecord(metadata?.pdf_extraction)
    ? metadata?.pdf_extraction
    : undefined;
  const pages = extraction && Array.isArray(extraction.selectable_pages)
    ? extraction.selectable_pages
    : [];
  return pages.filter(isRecord).flatMap((page) =>
    Number.isInteger(page.page_number) && typeof page.text === "string"
      ? [{ page_number: page.page_number as number, text: page.text }]
      : []
  );
}

function equationIds(value: unknown) {
  if (!isRecord(value) || !Array.isArray(value.equation_ids)) return [];
  const ids = new Set<string>();
  let duplicate = false;
  const visit = (item: unknown) => {
    if (Array.isArray(item)) {
      item.forEach(visit);
      return;
    }
    if (typeof item === "string" && /^eq_[a-z0-9_-]{1,60}$/.test(item)) {
      if (ids.has(item)) duplicate = true;
      ids.add(item);
      return;
    }
    if (!isRecord(item)) return;
    if (
      typeof item.id === "string" &&
      /^eq_[a-z0-9_-]{1,60}$/.test(item.id)
    ) {
      if (ids.has(item.id)) duplicate = true;
      ids.add(item.id);
    }
  };
  visit(value.equation_ids);
  if (duplicate) throw new DuplicateEquationIdError();
  return [...ids].sort();
}

function authoritativeEquations(value: unknown): Equation[] | undefined {
  if (!isRecord(value) || !Array.isArray(value.authoritative_equations)) {
    return undefined;
  }
  const equations = value.authoritative_equations.map((equation) => ({
    ...(equation as Equation),
  }));
  const ids = equations.map((equation) => equation.id);
  if (new Set(ids).size !== ids.length) throw new DuplicateEquationIdError();
  return equations;
}

class DuplicateEquationIdError extends Error {}

function resolveWorkOperation(work: InternalWorkUnit): AnalysisOperation {
  const nestedOperation = isRecord(work.input_payload) &&
      Object.hasOwn(work.input_payload, "operation")
    ? work.input_payload.operation
    : undefined;
  if (work.kind === "reconciliation") {
    if (!isAnalysisOperation(work.operation)) {
      throw new SafeAnalysisError("work_unavailable", 500);
    }
    if (
      nestedOperation !== undefined && nestedOperation !== work.operation
    ) throw new SafeAnalysisError("work_unavailable", 500);
    return work.operation;
  }
  if (!isAnalysisOperation(work.kind)) {
    throw new SafeAnalysisError("work_unavailable", 500);
  }
  if (work.operation !== undefined && work.operation !== work.kind) {
    throw new SafeAnalysisError("work_unavailable", 500);
  }
  if (nestedOperation !== undefined && nestedOperation !== work.kind) {
    throw new SafeAnalysisError("work_unavailable", 500);
  }
  return work.kind;
}

function isAnalysisOperation(value: unknown): value is AnalysisOperation {
  return typeof value === "string" &&
    analysisOperations.includes(value as AnalysisOperation);
}

function bearerToken(request: Request) {
  const authorization = request.headers.get("Authorization") ?? "";
  return authorization.startsWith("Bearer ")
    ? authorization.slice("Bearer ".length).trim()
    : "";
}

function parseDiagnosticRequest(value: unknown) {
  if (
    !isRecord(value) || Object.keys(value).join() !== "batch_id" ||
    typeof value.batch_id !== "string" ||
    !/^[0-9a-f]{8}-[0-9a-f]{4}-[1-5][0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$/i
      .test(value.batch_id)
  ) throw new SafeAnalysisError("invalid_request", 400);
  return value.batch_id;
}

function validateDiagnosticTarget(value: unknown, batchId: string) {
  const pageCount = isRecord(value) && Number.isInteger(value.page_count)
    ? value.page_count as number
    : -1;
  const pageNumbers = isRecord(value) && Array.isArray(value.page_numbers)
    ? value.page_numbers
    : [];
  if (
    !isRecord(value) ||
    Object.keys(value).sort().join() !==
      "batch_id,cleanup_state,operation,page_count,page_numbers,response_id,status" ||
    value.batch_id !== batchId ||
    !["page_visual", "final_summary"].includes(String(value.operation)) ||
    value.status !== "failed" ||
    typeof value.response_id !== "string" ||
    !/^[A-Za-z0-9_.-]{8,200}$/.test(value.response_id) ||
    pageNumbers.length < 1 || pageNumbers.length > 100 ||
    (value.operation === "page_visual" && pageNumbers.length !== 1) ||
    pageNumbers.some((page, index) =>
      !Number.isInteger(page) || page < 1 || page > pageCount ||
      (index > 0 && page <= pageNumbers[index - 1])
    ) ||
    pageCount > 100 ||
    !["not_required", "pending", "completed"].includes(
      String(value.cleanup_state),
    )
  ) throw new SafeAnalysisError("work_unavailable", 500);
  return value as unknown as DiagnosticTarget;
}

async function safeJson(request: Request) {
  try {
    return await request.json();
  } catch (_) {
    throw new SafeAnalysisError("invalid_request", 400);
  }
}

function publicMessage(status: number) {
  if (status === 400) return "Invalid request.";
  if (status === 401) return "Authentication required.";
  if (status === 404) return "Material unavailable.";
  if (status === 409) return "Material analysis is busy.";
  if (status === 422) return "Material cannot be analyzed.";
  return "Material analysis is temporarily unavailable.";
}

function publicErrorCode(error: SafeAnalysisError) {
  if (error.code === "page_limit_exceeded") return "document_too_large";
  if (error.code === "invalid_source") return "corrupt_document";
  if (error.code === "invalid_request") return "invalid_request";
  if (error.code === "material_unavailable") return "material_unavailable";
  return error.status === 422 ? "invalid_document" : "request_failed";
}

function json(body: Record<string, unknown>, status = 200) {
  return new Response(JSON.stringify(body), {
    status,
    headers: { ...corsHeaders, "Content-Type": "application/json" },
  });
}

function isRecord(value: unknown): value is Record<string, unknown> {
  return typeof value === "object" && value !== null && !Array.isArray(value);
}
