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

export type ReductionValidatorStage =
  | "validateReductionMinimumShape"
  | "validateReductionSchema"
  | "validateReductionMarkdown"
  | "validateReductionSourcePages"
  | "validateReductionEquationReferences"
  | "validateReductionWarningProvenance";

export type ReductionFailureDiagnostic = {
  validatorStage: ReductionValidatorStage;
  safeValidatorCode:
    | "reduction_required_shape_invalid"
    | "reduction_schema_invalid"
    | "reduction_markdown_invalid"
    | "reduction_source_pages_mismatch"
    | "reduction_equation_references_invalid"
    | "reduction_warning_provenance_invalid";
  sourcePageCount: number;
  equationIdCount: number;
  warningCount: number;
};

export function canonicalizeReductionResult(
  result: unknown,
  allowedPages: number[],
  authoritativeEquationIds: string[] = [],
): {
  valid: boolean;
  result: unknown;
  comparison: ReductionKeyConceptComparison;
  failure?: ReductionFailureDiagnostic;
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
  if (!hasMinimumReductionShape(result)) {
    return {
      valid: false,
      result,
      comparison,
      failure: reductionFailure(
        result,
        "validateReductionMinimumShape",
        "reduction_required_shape_invalid",
      ),
    };
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
  const validation = validateReductionResult(
    canonical,
    allowedPages,
    authoritativeEquationIds,
  );
  const failure = validation.valid ? undefined : diagnoseStrictReductionFailure(
    canonical,
    validation.errors,
    allowedPages,
  );
  return {
    valid: validation.valid,
    result: canonical,
    comparison,
    failure,
  };
}

function hasMinimumReductionShape(
  value: unknown,
): value is Record<string, unknown> & { key_concepts: unknown[] } {
  if (!isRecord(value) || !Array.isArray(value.key_concepts)) return false;
  const required = [
    "source_pages",
    "summary_markdown",
    "key_concepts",
    "equation_ids",
    "warnings",
    "confidence",
  ];
  return Object.keys(value).length === required.length &&
    required.every((key) => Object.hasOwn(value, key));
}

function diagnoseStrictReductionFailure(
  value: ReductionResult,
  errors: string[],
  allowedPages: number[],
): ReductionFailureDiagnostic {
  if (
    errors.includes("summary_markdown") ||
    errors.includes("reduction_markdown_dollar_math")
  ) {
    return reductionFailure(
      value,
      "validateReductionMarkdown",
      "reduction_markdown_invalid",
    );
  }
  if (
    errors.includes("source_pages") &&
    Array.isArray(value.source_pages) &&
    value.source_pages.every(Number.isInteger) &&
    value.source_pages.length >= 1 &&
    value.source_pages.length <= 100 &&
    value.source_pages.every((page) =>
      (page as number) >= 1 &&
      (page as number) <= Math.max(1, ...allowedPages)
    )
  ) {
    return reductionFailure(
      value,
      "validateReductionSourcePages",
      "reduction_source_pages_mismatch",
    );
  }
  if (errors.includes("equation_references")) {
    return reductionFailure(
      value,
      "validateReductionEquationReferences",
      "reduction_equation_references_invalid",
    );
  }
  if (errors.includes("warning_page_provenance")) {
    return reductionFailure(
      value,
      "validateReductionWarningProvenance",
      "reduction_warning_provenance_invalid",
    );
  }
  return reductionFailure(
    value,
    "validateReductionSchema",
    "reduction_schema_invalid",
  );
}

function reductionFailure(
  value: unknown,
  validatorStage: ReductionFailureDiagnostic["validatorStage"],
  safeValidatorCode: ReductionFailureDiagnostic["safeValidatorCode"],
): ReductionFailureDiagnostic {
  return {
    validatorStage,
    safeValidatorCode,
    sourcePageCount: arrayLength(value, "source_pages"),
    equationIdCount: arrayLength(value, "equation_ids"),
    warningCount: arrayLength(value, "warnings"),
  };
}

function arrayLength(value: unknown, key: string): number {
  return isRecord(value) && Array.isArray(value[key]) ? value[key].length : 0;
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
