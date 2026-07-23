export type StudyGenerationOperationStatus =
  | "reserved"
  | "provider_claimed"
  | "reconciliation_required"
  | "persisting"
  | "succeeded"
  | "failed"
  | "failed_before_provider"
  | "failed_after_provider";

export type StudyGenerationProviderStatus =
  | "queued"
  | "in_progress"
  | "completed"
  | "failed"
  | "cancelled"
  | "incomplete";

export type StudyGenerationProviderResponse = {
  identity: string;
  status: StudyGenerationProviderStatus;
  envelope: unknown;
};

export type StudyGenerationReconciliationClaim =
  | {
    kind: "claimed";
    token: string;
    responseIdentity: string;
  }
  | {
    kind: "completed";
    resultIds: string[];
  }
  | {
    kind: "failed";
    safeCode: string;
  }
  | {
    kind: "active";
    status: "generating" | "reconciling";
  };

export type StudyGenerationReconciliationDependencies<TResult> = {
  claimProvider(): Promise<boolean>;
  submitProvider(): Promise<StudyGenerationProviderResponse>;
  recordProviderResponse(
    response: StudyGenerationProviderResponse,
  ): Promise<void>;
  claimReconciliation(
    token: string,
  ): Promise<StudyGenerationReconciliationClaim>;
  retrieveProvider(
    responseIdentity: string,
  ): Promise<StudyGenerationProviderResponse>;
  updateProviderStatus(
    token: string,
    status: StudyGenerationProviderStatus,
  ): Promise<void>;
  persist(
    response: StudyGenerationProviderResponse,
    token: string,
  ): Promise<TResult>;
  replay(resultIds: string[]): Promise<TResult>;
  fail(
    safeCode: string,
    phase: "before_provider" | "after_provider",
    token?: string,
  ): Promise<void>;
  createToken(): string;
  wait(milliseconds: number): Promise<void>;
};

export class StudyGenerationReconciliationError extends Error {
  constructor(
    readonly safeCode: string,
    readonly clientStatus: "failed" | "generating" | "reconciling",
  ) {
    super(safeCode);
  }
}

export async function executeStudyGeneration<TResult>(
  deps: StudyGenerationReconciliationDependencies<TResult>,
): Promise<TResult> {
  let submitted: StudyGenerationProviderResponse | undefined;
  let ownsProvider = false;
  let submissionStarted = false;
  try {
    ownsProvider = await deps.claimProvider();
    if (ownsProvider) {
      submissionStarted = true;
      submitted = await deps.submitProvider();
      validateProviderResponse(submitted);
      await deps.recordProviderResponse(submitted);
    }
  } catch (error) {
    if (ownsProvider) {
      await bestEffortFailure(
        deps,
        safeCode(error),
        submissionStarted ? "after_provider" : "before_provider",
      );
    }
    throw error;
  }
  return await reconcileStudyGeneration(deps, submitted);
}

export async function reconcileStudyGeneration<TResult>(
  deps: StudyGenerationReconciliationDependencies<TResult>,
  submitted?: StudyGenerationProviderResponse,
): Promise<TResult> {
  for (let attempt = 0; attempt < 8; attempt += 1) {
    const token = deps.createToken();
    const claim = await deps.claimReconciliation(token);
    if (claim.kind === "completed") {
      return await deps.replay(claim.resultIds);
    }
    if (claim.kind === "failed") {
      throw new StudyGenerationReconciliationError(
        claim.safeCode,
        "failed",
      );
    }
    if (claim.kind === "active") {
      await deps.wait(250);
      continue;
    }

    let response: StudyGenerationProviderResponse;
    try {
      response = submitted?.identity === claim.responseIdentity
        ? submitted
        : await deps.retrieveProvider(claim.responseIdentity);
      submitted = undefined;
      validateProviderResponse(response, claim.responseIdentity);
      await deps.updateProviderStatus(token, response.status);
    } catch (error) {
      await bestEffortFailure(deps, safeCode(error), "after_provider", token);
      throw error;
    }

    if (response.status === "queued" || response.status === "in_progress") {
      await deps.wait(250);
      continue;
    }
    if (response.status !== "completed") {
      await deps.fail("provider_terminal_failed", "after_provider", token);
      throw new StudyGenerationReconciliationError(
        "provider_terminal_failed",
        "failed",
      );
    }
    try {
      return await deps.persist(response, token);
    } catch (error) {
      await bestEffortFailure(deps, safeCode(error), "after_provider", token);
      throw error;
    }
  }
  throw new StudyGenerationReconciliationError(
    "generation_in_progress",
    "reconciling",
  );
}

export function providerResponseFromEnvelope(
  envelope: unknown,
): StudyGenerationProviderResponse {
  if (!isRecord(envelope)) {
    throw new StudyGenerationReconciliationError(
      "provider_envelope_invalid",
      "failed",
    );
  }
  const identity = envelope.id;
  const status = envelope.status;
  if (
    typeof identity !== "string" ||
    identity.length < 6 ||
    identity.length > 255 ||
    !/^[A-Za-z0-9_-]+$/.test(identity) ||
    !isProviderStatus(status)
  ) {
    throw new StudyGenerationReconciliationError(
      "provider_envelope_invalid",
      "failed",
    );
  }
  return { identity, status, envelope };
}

function validateProviderResponse(
  response: StudyGenerationProviderResponse,
  expectedIdentity?: string,
) {
  if (
    response.identity.length < 6 ||
    response.identity.length > 255 ||
    !/^[A-Za-z0-9_-]+$/.test(response.identity) ||
    !isProviderStatus(response.status) ||
    expectedIdentity !== undefined && response.identity !== expectedIdentity
  ) {
    throw new StudyGenerationReconciliationError(
      "provider_envelope_invalid",
      "failed",
    );
  }
}

function isProviderStatus(
  value: unknown,
): value is StudyGenerationProviderStatus {
  return value === "queued" || value === "in_progress" ||
    value === "completed" || value === "failed" ||
    value === "cancelled" || value === "incomplete";
}

async function bestEffortFailure<TResult>(
  deps: StudyGenerationReconciliationDependencies<TResult>,
  code: string,
  phase: "before_provider" | "after_provider",
  token?: string,
) {
  try {
    await deps.fail(code, phase, token);
  } catch (_) {
    // The original safe failure remains authoritative.
  }
}

function safeCode(error: unknown) {
  if (error instanceof StudyGenerationReconciliationError) {
    return error.safeCode;
  }
  if (
    isRecord(error) && typeof error.code === "string" &&
    /^[a-z0-9_]{1,64}$/.test(error.code)
  ) {
    return error.code;
  }
  return "generation_failed";
}

function isRecord(value: unknown): value is Record<string, unknown> {
  return typeof value === "object" && value !== null && !Array.isArray(value);
}
