import { ReductionResult } from "./contracts.ts";
import { validateReductionResult } from "./schemas.ts";
import { validateSafeMarkdown } from "./validators.ts";

const maximumReductionKeyConcepts = 24;
const maximumReductionKeyConceptScalars = 120;
const controlCharacterPattern = /[\p{Cc}\p{Cf}]/u;
const structureDelimiterPattern = /[\[\]{}]/u;
const quoteCommaQuotePattern = /["']\s*,\s*["']/u;
const repeatedQuoteCommaSeparatorPattern =
  /(?:["']\s*,\s*){2,}|(?:,\s*["']\s*){2,}/u;
const jsonPropertyPattern = /["']\s*:\s*/u;
const jsonEscapePattern = /\\(?:["\\/bfnrt]|u[0-9a-f]{4})/iu;
const htmlPattern = /<\/?[a-z][^>]*>/iu;
const markdownPattern = /[`*_~]|(?:^|\s)(?:#{1,6}|>)\s|^(?:[-+*]|\d+\.)\s|!\[/u;
const domainPattern =
  /\b(?:[a-z][a-z0-9+.-]*:\/\/|www\.|[a-z0-9](?:[a-z0-9-]{0,62}\.)+[a-z]{2,63}(?:\b|\/))/iu;

export type ReductionKeyConceptComparison = {
  inputConceptCount: number;
  acceptedConceptCount: number;
  duplicateConceptCount: number;
  oversizedConceptCount: number;
  serializedListConceptCount: number;
  droppedConceptCount: number;
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
    inputConceptCount: isRecord(result) &&
        Array.isArray(result.key_concepts)
      ? result.key_concepts.length
      : 0,
    acceptedConceptCount: 0,
    duplicateConceptCount: 0,
    oversizedConceptCount: 0,
    serializedListConceptCount: 0,
    droppedConceptCount: 0,
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
    const candidate = classifyReductionKeyConcept(item);
    if (candidate.oversized) comparison.oversizedConceptCount++;
    if (candidate.serializedList) comparison.serializedListConceptCount++;
    if (candidate.normalized === null) {
      continue;
    }
    const dedupeKey = candidate.normalized.toLocaleLowerCase();
    if (seen.has(dedupeKey)) {
      comparison.duplicateConceptCount++;
      continue;
    }
    seen.add(dedupeKey);
    if (keyConcepts.length >= maximumReductionKeyConcepts) {
      continue;
    }
    keyConcepts.push(candidate.normalized);
  }
  comparison.acceptedConceptCount = keyConcepts.length;
  comparison.droppedConceptCount = comparison.inputConceptCount -
    comparison.acceptedConceptCount;
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

function classifyReductionKeyConcept(value: unknown): {
  normalized: string | null;
  oversized: boolean;
  serializedList: boolean;
} {
  if (
    typeof value !== "string" || value.length === 0
  ) {
    return { normalized: null, oversized: false, serializedList: false };
  }
  const normalized = value.trim().replace(/(?:\p{Zs}| )+/gu, " ");
  const oversized = [...normalized].length > maximumReductionKeyConceptScalars;
  const serializedList = quoteCommaQuotePattern.test(normalized) ||
    repeatedQuoteCommaSeparatorPattern.test(normalized);
  if (
    normalized.length === 0 || oversized || serializedList ||
    controlCharacterPattern.test(normalized) ||
    structureDelimiterPattern.test(normalized) ||
    jsonPropertyPattern.test(normalized) ||
    jsonEscapePattern.test(normalized) ||
    htmlPattern.test(normalized) ||
    markdownPattern.test(normalized) ||
    domainPattern.test(normalized) ||
    !validateSafeMarkdown(
      normalized,
      maximumReductionKeyConceptScalars * 2,
    ).valid
  ) {
    return { normalized: null, oversized, serializedList };
  }
  return { normalized, oversized: false, serializedList: false };
}

function isRecord(value: unknown): value is Record<string, unknown> {
  return typeof value === "object" && value !== null && !Array.isArray(value);
}
