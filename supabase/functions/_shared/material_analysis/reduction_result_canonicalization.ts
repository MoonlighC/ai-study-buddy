import { ReductionResult } from "./contracts.ts";
import { validateReductionResult } from "./schemas.ts";
import { validateSafeMarkdown } from "./validators.ts";

const maximumReductionKeyConcepts = 100;
const maximumReductionKeyConceptLength = 500;
const controlCharacterPattern = /[\p{Cc}\p{Cf}]/u;
const structureDelimiterPattern = /[\[\]{}]/u;
const quoteCommaQuotePattern = /["']\s*,\s*["']/u;
const jsonPropertyPattern = /["']\s*:\s*/u;
const jsonEscapePattern = /\\(?:["\\/bfnrt]|u[0-9a-f]{4})/iu;
const htmlPattern = /<\/?[a-z][^>]*>/iu;
const markdownPattern = /[`*_~]|(?:^|\s)(?:#{1,6}|>)\s|^(?:[-+*]|\d+\.)\s|!\[/u;
const domainPattern =
  /\b(?:[a-z][a-z0-9+.-]*:\/\/|www\.|[a-z0-9](?:[a-z0-9-]{0,62}\.)+[a-z]{2,63}(?:\b|\/))/iu;

export type ReductionKeyConceptComparison = {
  providerKeyConceptCount: number;
  acceptedKeyConceptCount: number;
  droppedKeyConceptCount: number;
  duplicateKeyConceptCount: number;
  cappedKeyConceptCount: number;
};

export function canonicalizeReductionResult(
  result: unknown,
  allowedPages: number[],
  authoritativeEquationIds: string[] = [],
): {
  valid: boolean;
  result: unknown;
  comparison: ReductionKeyConceptComparison;
} {
  const comparison = {
    providerKeyConceptCount: isRecord(result) &&
        Array.isArray(result.key_concepts)
      ? result.key_concepts.length
      : 0,
    acceptedKeyConceptCount: 0,
    droppedKeyConceptCount: 0,
    duplicateKeyConceptCount: 0,
    cappedKeyConceptCount: 0,
  };
  if (!isRecord(result) || !Array.isArray(result.key_concepts)) {
    return { valid: false, result, comparison };
  }
  const withoutConcepts = { ...result, key_concepts: [] };
  if (
    !validateReductionResult(
      withoutConcepts,
      allowedPages,
      authoritativeEquationIds,
    ).valid
  ) {
    return { valid: false, result, comparison };
  }

  const keyConcepts: string[] = [];
  const seen = new Set<string>();
  for (const item of result.key_concepts) {
    const normalized = canonicalizeReductionKeyConcept(item);
    if (normalized === null) {
      comparison.droppedKeyConceptCount++;
      continue;
    }
    if (seen.has(normalized)) {
      comparison.duplicateKeyConceptCount++;
      continue;
    }
    seen.add(normalized);
    if (keyConcepts.length >= maximumReductionKeyConcepts) {
      comparison.cappedKeyConceptCount++;
      continue;
    }
    keyConcepts.push(normalized);
  }
  comparison.acceptedKeyConceptCount = keyConcepts.length;
  const canonical: ReductionResult = {
    ...(result as unknown as ReductionResult),
    key_concepts: keyConcepts,
  };
  return {
    valid: validateReductionResult(
      canonical,
      allowedPages,
      authoritativeEquationIds,
    ).valid,
    result: canonical,
    comparison,
  };
}

function canonicalizeReductionKeyConcept(value: unknown): string | null {
  if (
    typeof value !== "string" || value.length === 0 ||
    value.length > maximumReductionKeyConceptLength ||
    controlCharacterPattern.test(value)
  ) {
    return null;
  }
  const normalized = value.trim().replace(/(?:\p{Zs}| )+/gu, " ");
  if (
    normalized.length === 0 ||
    structureDelimiterPattern.test(normalized) ||
    quoteCommaQuotePattern.test(normalized) ||
    jsonPropertyPattern.test(normalized) ||
    jsonEscapePattern.test(normalized) ||
    htmlPattern.test(normalized) ||
    markdownPattern.test(normalized) ||
    domainPattern.test(normalized) ||
    !validateSafeMarkdown(normalized, maximumReductionKeyConceptLength).valid
  ) {
    return null;
  }
  return normalized;
}

function isRecord(value: unknown): value is Record<string, unknown> {
  return typeof value === "object" && value !== null && !Array.isArray(value);
}
