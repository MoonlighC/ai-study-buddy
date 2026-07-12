export type EnvironmentReader = (name: string) => string | undefined;

export class SafeConfigurationError extends Error {
  constructor() {
    super("configuration_unavailable");
  }
}

export function resolveProjectKeys(read: EnvironmentReader): {
  publicKey: string;
  trustedKey: string;
  trustedSource: "secret_keys_default" | "legacy_service_role";
} {
  const secretDictionary = read("SUPABASE_SECRET_KEYS")?.trim();
  const trustedKey = secretDictionary
    ? resolveDictionaryKey(secretDictionary)
    : requiredFallback(read, "SUPABASE_SERVICE_ROLE_KEY");
  if (!isTrustedCredential(trustedKey, Boolean(secretDictionary))) {
    throw new SafeConfigurationError();
  }
  return {
    publicKey: resolveKey(
      read,
      "SUPABASE_PUBLISHABLE_KEYS",
      "SUPABASE_ANON_KEY",
    ),
    trustedKey,
    trustedSource: secretDictionary
      ? "secret_keys_default"
      : "legacy_service_role",
  };
}

function resolveKey(
  read: EnvironmentReader,
  dictionaryName: string,
  fallbackName: string,
) {
  const dictionary = read(dictionaryName)?.trim();
  if (dictionary) {
    return resolveDictionaryKey(dictionary);
  }
  return requiredFallback(read, fallbackName);
}

function resolveDictionaryKey(dictionary: string) {
  let parsed: unknown;
  try {
    parsed = JSON.parse(dictionary);
  } catch (_) {
    throw new SafeConfigurationError();
  }
  if (
    !isRecord(parsed) || typeof parsed.default !== "string" ||
    !parsed.default.trim()
  ) {
    throw new SafeConfigurationError();
  }
  return parsed.default.trim();
}

function requiredFallback(read: EnvironmentReader, name: string) {
  const value = read(name)?.trim();
  if (!value) throw new SafeConfigurationError();
  return value;
}

function isTrustedCredential(value: string, hostedSecret: boolean) {
  if (hostedSecret && value.startsWith("sb_secret_")) return true;
  const parts = value.split(".");
  if (parts.length !== 3) return false;
  try {
    const payload = JSON.parse(decodeBase64Url(parts[1]));
    return isRecord(payload) && payload.role === "service_role";
  } catch (_) {
    return false;
  }
}

function decodeBase64Url(value: string) {
  const normalized = value.replaceAll("-", "+").replaceAll("_", "/");
  const padded = normalized.padEnd(Math.ceil(normalized.length / 4) * 4, "=");
  return atob(padded);
}

export type GenerationSafeCode =
  | "openai_auth_failed"
  | "openai_access_denied"
  | "openai_rate_or_quota"
  | "openai_request_invalid"
  | "openai_unavailable"
  | "response_parse_failed"
  | "generation_failed";

export function providerSafeCode(status: number): GenerationSafeCode {
  if (status === 401) return "openai_auth_failed";
  if (status === 403) return "openai_access_denied";
  if (status === 429) return "openai_rate_or_quota";
  if (status === 400) return "openai_request_invalid";
  if (status >= 500) return "openai_unavailable";
  return "generation_failed";
}

export function safeProviderToken(value: unknown): string | undefined {
  if (typeof value !== "string") return undefined;
  const token = value.trim().slice(0, 64);
  return /^[A-Za-z0-9_.-]+$/.test(token) ? token : undefined;
}

export function safeDatabaseFailure(value: unknown): {
  code: string;
  status?: number;
} {
  const rawCode = isRecord(value) ? safeProviderToken(value.code) : undefined;
  return {
    code: rawCode ?? "database_write_failed",
    status: rawCode === "42501" ? 403 : undefined,
  };
}

export function generationLog(
  operation: string,
  stage: string,
  details: Record<string, unknown> = {},
  write: (line: string) => void = console.log,
) {
  const allowed = [
    "code",
    "reason",
    "status",
    "model",
    "content_length",
    "requested_count",
    "created_count",
  ];
  const safe: Record<string, unknown> = { operation, stage };
  for (const key of allowed) {
    const value = details[key];
    if (typeof value === "number" && Number.isFinite(value)) {
      safe[key] = Math.max(0, Math.min(value, 1_000_000));
    }
    if (typeof value === "string" && /^[A-Za-z0-9_.-]{1,64}$/.test(value)) {
      safe[key] = value;
    }
  }
  write(JSON.stringify(safe));
}

function isRecord(value: unknown): value is Record<string, unknown> {
  return typeof value === "object" && value !== null && !Array.isArray(value);
}
