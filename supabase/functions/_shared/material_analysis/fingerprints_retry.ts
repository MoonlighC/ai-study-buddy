export function stableJson(value: unknown): string {
  if (value === null || typeof value !== "object") return JSON.stringify(value);
  if (Array.isArray(value)) return `[${value.map(stableJson).join(",")}]`;
  const record = value as Record<string, unknown>;
  return `{${
    Object.keys(record).sort().map((key) =>
      `${JSON.stringify(key)}:${stableJson(record[key])}`
    ).join(",")
  }}`;
}

export async function sha256Hex(value: string | Uint8Array): Promise<string> {
  const bytes = typeof value === "string"
    ? new TextEncoder().encode(value)
    : value;
  const owned = Uint8Array.from(bytes);
  const digest = await crypto.subtle.digest("SHA-256", owned.buffer);
  return [...new Uint8Array(digest)].map((byte) =>
    byte.toString(16).padStart(2, "0")
  ).join("");
}

export async function batchFingerprint(input: {
  operation: string;
  mode: string;
  pageNumbers: number[];
  inputHashes: string[];
  routerVersion: string;
  promptVersion: string;
  schemaVersion: number;
  reductionLevel: number;
  configurationVersion: string;
}): Promise<string> {
  return await sha256Hex(stableJson(input));
}

export type FailureClassification =
  | { kind: "pre_dispatch_retryable"; automaticRetry: true }
  | { kind: "non_retryable"; automaticRetry: false }
  | { kind: "reconcile_only"; automaticRetry: false; responseId: string }
  | { kind: "user_retry_required"; automaticRetry: false };

export function classifyFailure(input: {
  dispatched: boolean;
  status?: number;
  responseId?: string;
  errorKind?:
    | "network"
    | "timeout"
    | "auth"
    | "ownership"
    | "validation"
    | "file"
    | "schema"
    | "unknown";
}): FailureClassification {
  if (input.dispatched) {
    return input.responseId
      ? {
        kind: "reconcile_only",
        automaticRetry: false,
        responseId: input.responseId,
      }
      : { kind: "user_retry_required", automaticRetry: false };
  }
  const retryableStatus = input.status === 408 || input.status === 429 ||
    (input.status !== undefined && input.status >= 500 && input.status <= 599);
  const retryableKind = input.errorKind === "network" ||
    input.errorKind === "timeout";
  return retryableStatus || retryableKind
    ? { kind: "pre_dispatch_retryable", automaticRetry: true }
    : { kind: "non_retryable", automaticRetry: false };
}

export function persistedBackoffSeconds(input: {
  attempt: number;
  retryAfterSeconds?: number;
  jitter: () => number;
}): number {
  if (!Number.isInteger(input.attempt) || input.attempt < 1) {
    throw new Error("invalid_attempt");
  }
  const random = input.jitter();
  if (!Number.isFinite(random) || random < 0 || random > 1) {
    throw new Error("invalid_jitter");
  }
  const base = Math.min(900, 5 * 2 ** (input.attempt - 1));
  const jittered = Math.ceil(base * (1 + random * 0.25));
  return Math.min(900, Math.max(jittered, input.retryAfterSeconds ?? 0));
}

export function mayReuseCompletedFingerprint(input: {
  fingerprint: string;
  completedFingerprint?: string;
  completedResultValid: boolean;
}): boolean {
  return input.completedResultValid && input.fingerprint.length === 64 &&
    input.fingerprint === input.completedFingerprint;
}
