export type EnvironmentReader = (name: string) => string | undefined;

export class SafeConfigurationError extends Error {
  constructor() {
    super("configuration_unavailable");
  }
}

export function resolveProjectKeys(read: EnvironmentReader): {
  publicKey: string;
  trustedKey: string;
} {
  return {
    publicKey: resolveKey(
      read,
      "SUPABASE_PUBLISHABLE_KEYS",
      "SUPABASE_ANON_KEY",
    ),
    trustedKey: resolveKey(
      read,
      "SUPABASE_SECRET_KEYS",
      "SUPABASE_SERVICE_ROLE_KEY",
    ),
  };
}

function resolveKey(
  read: EnvironmentReader,
  dictionaryName: string,
  fallbackName: string,
) {
  const dictionary = read(dictionaryName)?.trim();
  if (dictionary) {
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
  const fallback = read(fallbackName)?.trim();
  if (!fallback) throw new SafeConfigurationError();
  return fallback;
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
