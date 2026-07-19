import {
  validatePageBatchResult,
  validateSummarySemantics,
} from "./schemas.ts";
import { validateLatex, validateSafeMarkdown } from "./validators.ts";

export const diagnosticVersion = 1;

export type DiagnosticCode =
  | "response_status_not_completed"
  | "response_error_present"
  | "response_incomplete"
  | "response_refusal"
  | "response_output_missing"
  | "response_output_multiple"
  | "response_structured_text_missing"
  | "response_json_parse_failed"
  | "page_schema_failed"
  | "page_unknown_field"
  | "page_number_mismatch"
  | "page_provenance_failed"
  | "page_confidence_failed"
  | "page_warning_failed"
  | "page_equation_reference_failed"
  | "page_markdown_failed"
  | "page_latex_failed"
  | "page_payload_too_large"
  | "page_persistence_failed"
  | "validation_unknown"
  | "final_summary_schema_failed"
  | "final_summary_semantics_failed"
  | "final_summary_markdown_failed"
  | "final_summary_latex_failed"
  | "final_summary_payload_too_large"
  | "final_summary_persistence_failed"
  | "final_validation_unknown";

export type ValidatorStage =
  | "validateResponseEnvelope"
  | "extractSingleStructuredCandidate"
  | "parseStructuredJson"
  | "validatePageSchema"
  | "validatePageSemantics"
  | "validatePageMarkdown"
  | "validatePageLatex"
  | "validatePageProvenance"
  | "persistValidatedPage"
  | "validateFinalSummarySchema"
  | "validateFinalSummarySemantics"
  | "validateFinalSummaryMarkdown"
  | "validateFinalSummaryLatex"
  | "validateFinalSummaryProvenance"
  | "persistFinalSummaryEligibility";

export type DiagnosticMetadata = {
  response_status?:
    | "queued"
    | "in_progress"
    | "completed"
    | "incomplete"
    | "failed"
    | "cancelled"
    | "unknown";
  error_present?: boolean;
  incomplete_details_present?: boolean;
  refusal_count?: number;
  output_item_count?: number;
  structured_candidate_count?: number;
  parsed_json_byte_length?: number;
  top_level_key_count?: number;
  requested_page_number?: number;
  returned_page_number?: number;
  warning_count?: number;
  equation_count?: number;
  source_page_count?: number;
  section_count?: number;
  concept_count?: number;
  validator_stage?: ValidatorStage;
};

export type DiagnosticResult =
  | { ok: true; result: unknown; metadata: DiagnosticMetadata }
  | { ok: false; code: DiagnosticCode; metadata: DiagnosticMetadata };
export type DiagnosticOutcome =
  | { ok: true; metadata: DiagnosticMetadata }
  | { ok: false; code: DiagnosticCode; metadata: DiagnosticMetadata };
type DiagnosticFailure = Extract<DiagnosticResult, { ok: false }>;

const pageKeys = [
  "page_number",
  "summary_markdown",
  "key_concepts",
  "equations",
  "confidence",
  "warnings",
  "trustworthy",
] as const;
const equationKeys = [
  "id",
  "latex",
  "explanation_markdown",
  "source_page",
  "display",
  "confidence",
  "uncertainty",
] as const;
const warningKeys = ["code", "detail", "source_pages"] as const;
const maximumPayloadBytes = 262_144;

export function diagnosePageResponse(
  response: Record<string, unknown>,
  requestedPage: number,
  pageCount: number,
): DiagnosticResult {
  let metadata: DiagnosticMetadata = { requested_page_number: requestedPage };
  try {
    metadata = baseMetadata(response, requestedPage);
    const envelope = validateResponseEnvelope(response, metadata);
    if (envelope) return envelope;
    const candidate = extractSingleStructuredCandidate(response, metadata);
    if (!candidate.ok) return candidate;
    const parsed = parseStructuredJson(candidate.text, metadata);
    if (!parsed.ok) return parsed;
    const schema = validatePageSchema(parsed.result, metadata);
    if (schema) return schema;
    const semantics = validatePageSemantics(parsed.result, metadata);
    if (semantics) return semantics;
    const markdown = validatePageMarkdown(parsed.result, metadata);
    if (markdown) return markdown;
    const latex = validatePageLatex(parsed.result, metadata);
    if (latex) return latex;
    const provenance = validatePageProvenance(
      parsed.result,
      requestedPage,
      pageCount,
      metadata,
    );
    if (provenance) return provenance;
    if (
      !validatePageBatchResult(parsed.result, [requestedPage], pageCount).valid
    ) {
      return failure("page_schema_failed", metadata, "validatePageSemantics");
    }
    return { ok: true, result: parsed.result, metadata };
  } catch (_) {
    return failure("validation_unknown", metadata, "validatePageSemantics");
  }
}

export function diagnoseFinalSummaryResponse(
  response: Record<string, unknown>,
  pageCount: number,
): DiagnosticResult {
  let metadata: DiagnosticMetadata = {};
  try {
    metadata = baseMetadata(response);
    const envelope = validateResponseEnvelope(response, metadata);
    if (envelope) return envelope;
    const candidate = extractSingleStructuredCandidate(response, metadata);
    if (!candidate.ok) return candidate;
    const parsed = parseFinalSummaryJson(candidate.text, metadata);
    if (!parsed.ok) return parsed;
    const schema = validateFinalSummarySchema(parsed.result, metadata);
    if (schema) return schema;
    const semantics = validateFinalSummarySemantics(parsed.result, metadata);
    if (semantics) return semantics;
    const markdown = validateFinalSummaryMarkdown(parsed.result, metadata);
    if (markdown) return markdown;
    const latex = validateFinalSummaryLatex(parsed.result, metadata);
    if (latex) return latex;
    const provenance = validateFinalSummaryProvenance(
      parsed.result,
      pageCount,
      metadata,
    );
    if (provenance) return provenance;
    return { ok: true, result: parsed.result, metadata };
  } catch (_) {
    return failure(
      "final_validation_unknown",
      metadata,
      "validateFinalSummarySemantics",
    );
  }
}

function parseFinalSummaryJson(
  text: string,
  metadata: DiagnosticMetadata,
): { ok: true; result: unknown } | DiagnosticFailure {
  const byteLength = new TextEncoder().encode(text).length;
  metadata.parsed_json_byte_length = Math.min(byteLength, maximumPayloadBytes);
  if (byteLength > maximumPayloadBytes) {
    return failure(
      "final_summary_payload_too_large",
      metadata,
      "parseStructuredJson",
    );
  }
  try {
    const result: unknown = JSON.parse(text);
    metadata.top_level_key_count = isRecord(result)
      ? boundedCount(Object.keys(result).length)
      : 0;
    return { ok: true, result };
  } catch (_) {
    return failure(
      "response_json_parse_failed",
      metadata,
      "parseStructuredJson",
    );
  }
}

function validateFinalSummarySchema(
  result: unknown,
  metadata: DiagnosticMetadata,
): DiagnosticResult | null {
  if (
    !isRecord(result) ||
    !hasExactKeys(result, [
      "language",
      "sections",
      "key_concepts",
      "equations",
      "warnings",
      "partial_extraction",
    ]) ||
    typeof result.language !== "string" || result.language.length < 1 ||
    result.language.length > 32 || !Array.isArray(result.sections) ||
    result.sections.length < 1 || result.sections.length > 24 ||
    !Array.isArray(result.key_concepts) || result.key_concepts.length > 50 ||
    !Array.isArray(result.equations) || result.equations.length > 100 ||
    !Array.isArray(result.warnings) || result.warnings.length > 100 ||
    !isRecord(result.partial_extraction)
  ) {
    return failure(
      "final_summary_schema_failed",
      metadata,
      "validateFinalSummarySchema",
    );
  }
  metadata.section_count = boundedCount(result.sections.length);
  metadata.concept_count = boundedCount(result.key_concepts.length);
  metadata.equation_count = boundedCount(result.equations.length);
  metadata.warning_count = boundedCount(result.warnings.length);
  const extraction = result.partial_extraction;
  if (
    !hasExactKeys(extraction, [
      "is_partial",
      "analyzed_pages",
      "partial_pages",
      "missing_pages",
      "page_modes",
    ]) || typeof extraction.is_partial !== "boolean" ||
    !Array.isArray(extraction.analyzed_pages) ||
    !Array.isArray(extraction.partial_pages) ||
    !Array.isArray(extraction.missing_pages) ||
    !Array.isArray(extraction.page_modes) || extraction.page_modes.length < 1 ||
    extraction.page_modes.length > 100
  ) {
    return failure(
      "final_summary_schema_failed",
      metadata,
      "validateFinalSummarySchema",
    );
  }
  for (const section of result.sections) {
    if (
      !isRecord(section) ||
      !hasExactKeys(section, [
        "id",
        "title",
        "blocks",
        "source_pages",
        "confidence",
      ]) || !Array.isArray(section.blocks) || section.blocks.length < 1 ||
      section.blocks.length > 50 || !Array.isArray(section.source_pages)
    ) return finalSchemaFailure(metadata);
    for (const block of section.blocks) {
      if (
        !isRecord(block) ||
        !["prose", "equation"].includes(String(block.kind)) ||
        !["inline", "block"].includes(String(block.display)) ||
        (block.kind === "prose" &&
          !hasExactKeys(block, ["kind", "markdown", "display"])) ||
        (block.kind === "equation" &&
          !hasExactKeys(block, ["kind", "equation_id", "display"]))
      ) return finalSchemaFailure(metadata);
    }
  }
  for (const concept of result.key_concepts) {
    if (
      !isRecord(concept) ||
      !hasExactKeys(concept, [
        "title",
        "explanation_markdown",
        "source_pages",
        "confidence",
      ]) || !Array.isArray(concept.source_pages)
    ) return finalSchemaFailure(metadata);
  }
  for (const equation of result.equations) {
    if (
      !isRecord(equation) ||
      !hasExactKeys(equation, equationKeys) ||
      typeof equation.latex !== "string"
    ) return finalSchemaFailure(metadata);
  }
  for (const warning of result.warnings) {
    if (!isRecord(warning) || !hasExactKeys(warning, warningKeys)) {
      return finalSchemaFailure(metadata);
    }
  }
  return null;
}

function finalSchemaFailure(metadata: DiagnosticMetadata): DiagnosticFailure {
  return failure(
    "final_summary_schema_failed",
    metadata,
    "validateFinalSummarySchema",
  );
}

function validateFinalSummarySemantics(
  result: unknown,
  metadata: DiagnosticMetadata,
): DiagnosticResult | null {
  const summary = result as Record<string, unknown>;
  const equations = summary.equations as Record<string, unknown>[];
  const ids = equations.map((equation) => equation.id);
  if (
    new Set(ids).size !== ids.length ||
    equations.some((equation) =>
      typeof equation.id !== "string" ||
      !/^eq_[a-z0-9_-]{1,60}$/.test(equation.id) ||
      !Number.isInteger(equation.source_page) ||
      !["inline", "block"].includes(String(equation.display)) ||
      !validConfidence(equation.confidence) ||
      typeof equation.uncertainty !== "boolean"
    )
  ) return finalSemanticsFailure(metadata);
  const references: unknown[] = [];
  for (const section of summary.sections as Record<string, unknown>[]) {
    if (
      typeof section.id !== "string" ||
      !/^[a-z0-9][a-z0-9_-]{0,63}$/.test(section.id) ||
      typeof section.title !== "string" || !validConfidence(section.confidence)
    ) return finalSemanticsFailure(metadata);
    for (const block of section.blocks as Record<string, unknown>[]) {
      if (block.kind === "equation") references.push(block.equation_id);
    }
  }
  if (
    references.some((reference) => !ids.includes(reference)) ||
    new Set(references).size !== references.length ||
    ids.some((id) => !references.includes(id))
  ) return finalSemanticsFailure(metadata);
  for (const concept of summary.key_concepts as Record<string, unknown>[]) {
    if (
      typeof concept.title !== "string" ||
      !validConfidence(concept.confidence)
    ) return finalSemanticsFailure(metadata);
  }
  return null;
}

function finalSemanticsFailure(
  metadata: DiagnosticMetadata,
): DiagnosticFailure {
  return failure(
    "final_summary_semantics_failed",
    metadata,
    "validateFinalSummarySemantics",
  );
}

function validateFinalSummaryMarkdown(
  result: unknown,
  metadata: DiagnosticMetadata,
): DiagnosticResult | null {
  const summary = result as Record<string, unknown>;
  for (const section of summary.sections as Record<string, unknown>[]) {
    for (const block of section.blocks as Record<string, unknown>[]) {
      if (
        block.kind === "prose" &&
        (typeof block.markdown !== "string" || block.markdown.length < 1 ||
          block.markdown.length > 6000 ||
          !validateSafeMarkdown(block.markdown).valid)
      ) return finalMarkdownFailure(metadata);
    }
  }
  for (const concept of summary.key_concepts as Record<string, unknown>[]) {
    if (
      typeof concept.explanation_markdown !== "string" ||
      concept.explanation_markdown.length < 1 ||
      concept.explanation_markdown.length > 3000 ||
      !validateSafeMarkdown(concept.explanation_markdown, 3000).valid
    ) return finalMarkdownFailure(metadata);
  }
  for (const equation of summary.equations as Record<string, unknown>[]) {
    if (
      typeof equation.explanation_markdown !== "string" ||
      equation.explanation_markdown.length > 2000 ||
      (equation.explanation_markdown.length > 0 &&
        !validateSafeMarkdown(equation.explanation_markdown, 2000).valid)
    ) return finalMarkdownFailure(metadata);
  }
  return null;
}

function finalMarkdownFailure(metadata: DiagnosticMetadata): DiagnosticFailure {
  return failure(
    "final_summary_markdown_failed",
    metadata,
    "validateFinalSummaryMarkdown",
  );
}

function validateFinalSummaryLatex(
  result: unknown,
  metadata: DiagnosticMetadata,
): DiagnosticResult | null {
  const equations = (result as Record<string, unknown>)
    .equations as Record<string, unknown>[];
  if (
    equations.some((equation) =>
      typeof equation.latex !== "string" || !validateLatex(equation.latex).valid
    )
  ) {
    return failure(
      "final_summary_latex_failed",
      metadata,
      "validateFinalSummaryLatex",
    );
  }
  return null;
}

function validateFinalSummaryProvenance(
  result: unknown,
  pageCount: number,
  metadata: DiagnosticMetadata,
): DiagnosticResult | null {
  const summary = result as Record<string, unknown>;
  const sourcePages = new Set<number>();
  const collect = (value: unknown) => {
    if (!Array.isArray(value)) return;
    for (const page of value) if (Number.isInteger(page)) sourcePages.add(page);
  };
  for (const section of summary.sections as Record<string, unknown>[]) {
    collect(section.source_pages);
  }
  for (const concept of summary.key_concepts as Record<string, unknown>[]) {
    collect(concept.source_pages);
  }
  for (const equation of summary.equations as Record<string, unknown>[]) {
    if (Number.isInteger(equation.source_page)) {
      sourcePages.add(equation.source_page as number);
    }
  }
  for (const warning of summary.warnings as Record<string, unknown>[]) {
    collect(warning.source_pages);
  }
  metadata.source_page_count = boundedCount(sourcePages.size);
  if (!validateSummarySemantics(result, pageCount).valid) {
    return failure(
      "final_summary_semantics_failed",
      metadata,
      "validateFinalSummaryProvenance",
    );
  }
  return null;
}

export function validateResponseEnvelope(
  response: Record<string, unknown>,
  metadata: DiagnosticMetadata,
): DiagnosticResult | null {
  if (metadata.error_present) {
    return failure(
      "response_error_present",
      metadata,
      "validateResponseEnvelope",
    );
  }
  if (
    metadata.response_status === "incomplete" ||
    metadata.incomplete_details_present
  ) {
    return failure("response_incomplete", metadata, "validateResponseEnvelope");
  }
  if (metadata.response_status !== "completed") {
    return failure(
      "response_status_not_completed",
      metadata,
      "validateResponseEnvelope",
    );
  }
  return null;
}

export function extractSingleStructuredCandidate(
  response: Record<string, unknown>,
  metadata: DiagnosticMetadata,
): { ok: true; text: string } | DiagnosticFailure {
  const output = Array.isArray(response.output) ? response.output : [];
  metadata.output_item_count = boundedCount(output.length);
  if (output.length === 0) {
    return failure(
      "response_output_missing",
      metadata,
      "extractSingleStructuredCandidate",
    );
  }
  const candidates: string[] = [];
  let refusals = 0;
  for (const item of output.slice(0, 100)) {
    if (!isRecord(item) || !Array.isArray(item.content)) continue;
    for (const content of item.content.slice(0, 100)) {
      if (!isRecord(content)) continue;
      if (content.type === "refusal" || typeof content.refusal === "string") {
        refusals++;
      }
      if (content.type === "output_text" && typeof content.text === "string") {
        candidates.push(content.text);
      }
    }
  }
  metadata.refusal_count = boundedCount(refusals);
  metadata.structured_candidate_count = boundedCount(candidates.length);
  if (refusals > 0) {
    return failure(
      "response_refusal",
      metadata,
      "extractSingleStructuredCandidate",
    );
  }
  if (candidates.length > 1) {
    return failure(
      "response_output_multiple",
      metadata,
      "extractSingleStructuredCandidate",
    );
  }
  if (candidates.length === 0 || candidates[0].length === 0) {
    return failure(
      "response_structured_text_missing",
      metadata,
      "extractSingleStructuredCandidate",
    );
  }
  return { ok: true, text: candidates[0] };
}

export function parseStructuredJson(
  text: string,
  metadata: DiagnosticMetadata,
): { ok: true; result: unknown } | DiagnosticFailure {
  const byteLength = new TextEncoder().encode(text).length;
  metadata.parsed_json_byte_length = Math.min(byteLength, maximumPayloadBytes);
  if (byteLength > maximumPayloadBytes) {
    return failure(
      "page_payload_too_large",
      metadata,
      "parseStructuredJson",
    );
  }
  try {
    const result: unknown = JSON.parse(text);
    metadata.top_level_key_count = isRecord(result)
      ? boundedCount(Object.keys(result).length)
      : 0;
    return { ok: true, result };
  } catch (_) {
    return failure(
      "response_json_parse_failed",
      metadata,
      "parseStructuredJson",
    );
  }
}

export function validatePageSchema(
  result: unknown,
  metadata: DiagnosticMetadata,
): DiagnosticResult | null {
  if (
    !isRecord(result) || !Array.isArray(result.pages) ||
    result.pages.length !== 1
  ) {
    return failure("page_schema_failed", metadata, "validatePageSchema");
  }
  if (hasUnknownKeys(result, ["pages"])) {
    return failure("page_unknown_field", metadata, "validatePageSchema");
  }
  const page = result.pages[0];
  if (!isRecord(page)) {
    return failure("page_schema_failed", metadata, "validatePageSchema");
  }
  if (hasUnknownKeys(page, pageKeys)) {
    return failure("page_unknown_field", metadata, "validatePageSchema");
  }
  if (!hasExactKeys(page, pageKeys)) {
    return failure("page_schema_failed", metadata, "validatePageSchema");
  }
  if (
    Number.isInteger(page.page_number) && page.page_number >= 1 &&
    page.page_number <= 100
  ) {
    metadata.returned_page_number = page.page_number;
  }
  if (
    !Number.isInteger(page.page_number) ||
    typeof page.summary_markdown !== "string" ||
    !Array.isArray(page.key_concepts) || !Array.isArray(page.equations) ||
    !Array.isArray(page.warnings) || typeof page.trustworthy !== "boolean" ||
    page.equations.length > 100 || page.warnings.length > 100 ||
    page.key_concepts.length > 50
  ) {
    return failure("page_schema_failed", metadata, "validatePageSchema");
  }
  metadata.equation_count = boundedCount(page.equations.length);
  metadata.warning_count = boundedCount(page.warnings.length);
  for (const equation of page.equations) {
    if (!isRecord(equation)) {
      return failure("page_schema_failed", metadata, "validatePageSchema");
    }
    if (hasUnknownKeys(equation, equationKeys)) {
      return failure("page_unknown_field", metadata, "validatePageSchema");
    }
    if (!hasExactKeys(equation, equationKeys)) {
      return failure("page_schema_failed", metadata, "validatePageSchema");
    }
  }
  for (const warning of page.warnings) {
    if (!isRecord(warning)) {
      return failure("page_warning_failed", metadata, "validatePageSemantics");
    }
    if (hasUnknownKeys(warning, warningKeys)) {
      return failure("page_unknown_field", metadata, "validatePageSchema");
    }
    if (!hasExactKeys(warning, warningKeys)) {
      return failure("page_warning_failed", metadata, "validatePageSemantics");
    }
  }
  return null;
}

export function validatePageSemantics(
  result: unknown,
  metadata: DiagnosticMetadata,
): DiagnosticResult | null {
  const page = pageRecord(result)!;
  if (
    page.trustworthy !== true ||
    !(page.key_concepts as unknown[]).every((value: unknown) =>
      typeof value === "string" && value.length >= 1 && value.length <= 500
    )
  ) return failure("page_schema_failed", metadata, "validatePageSemantics");
  const equations = page.equations as Record<string, unknown>[];
  const ids = equations.map((equation) => equation.id);
  if (
    new Set(ids).size !== ids.length ||
    equations.some((equation) =>
      typeof equation.id !== "string" ||
      !/^eq_[a-z0-9_-]{1,60}$/.test(equation.id) ||
      !["inline", "block"].includes(String(equation.display)) ||
      typeof equation.uncertainty !== "boolean" ||
      !Number.isInteger(equation.source_page)
    )
  ) {
    return failure(
      "page_equation_reference_failed",
      metadata,
      "validatePageSemantics",
    );
  }
  if (
    !validConfidence(page.confidence) ||
    equations.some((equation) => !validConfidence(equation.confidence))
  ) {
    return failure(
      "page_confidence_failed",
      metadata,
      "validatePageSemantics",
    );
  }
  const warnings = page.warnings as Record<string, unknown>[];
  if (
    warnings.some((warning) =>
      typeof warning.code !== "string" ||
      !/^[a-z0-9_]{1,64}$/.test(warning.code) ||
      typeof warning.detail !== "string" || warning.detail.length < 1 ||
      warning.detail.length > 500 || !Array.isArray(warning.source_pages) ||
      warning.source_pages.length > 100 ||
      !sortedUniquePages(warning.source_pages)
    )
  ) return failure("page_warning_failed", metadata, "validatePageSemantics");
  return null;
}

export function validatePageMarkdown(
  result: unknown,
  metadata: DiagnosticMetadata,
): DiagnosticResult | null {
  const page = pageRecord(result)!;
  if (!validateSafeMarkdown(page.summary_markdown as string).valid) {
    return failure("page_markdown_failed", metadata, "validatePageMarkdown");
  }
  for (const equation of page.equations as Record<string, unknown>[]) {
    if (
      typeof equation.explanation_markdown !== "string" ||
      equation.explanation_markdown.length > 2000 ||
      (equation.explanation_markdown.length > 0 &&
        !validateSafeMarkdown(equation.explanation_markdown, 2000).valid)
    ) return failure("page_markdown_failed", metadata, "validatePageMarkdown");
  }
  return null;
}

export function validatePageLatex(
  result: unknown,
  metadata: DiagnosticMetadata,
): DiagnosticResult | null {
  const page = pageRecord(result)!;
  if (
    (page.equations as Record<string, unknown>[]).some((equation) =>
      typeof equation.latex !== "string" ||
      !validateLatex(equation.latex).valid
    )
  ) return failure("page_latex_failed", metadata, "validatePageLatex");
  return null;
}

export function validatePageProvenance(
  result: unknown,
  requestedPage: number,
  pageCount: number,
  metadata: DiagnosticMetadata,
): DiagnosticResult | null {
  const page = pageRecord(result)!;
  if (page.page_number !== requestedPage) {
    return failure(
      "page_number_mismatch",
      metadata,
      "validatePageProvenance",
    );
  }
  const sourcePages = new Set<number>();
  for (const equation of page.equations as Record<string, unknown>[]) {
    if (Number.isInteger(equation.source_page)) {
      sourcePages.add(equation.source_page as number);
    }
    if (equation.source_page !== requestedPage) {
      metadata.source_page_count = boundedCount(sourcePages.size);
      return failure(
        "page_provenance_failed",
        metadata,
        "validatePageProvenance",
      );
    }
  }
  for (const warning of page.warnings as Record<string, unknown>[]) {
    for (const sourcePage of warning.source_pages as number[]) {
      sourcePages.add(sourcePage);
      if (
        sourcePage !== requestedPage || sourcePage < 1 || sourcePage > pageCount
      ) {
        metadata.source_page_count = boundedCount(sourcePages.size);
        return failure(
          "page_provenance_failed",
          metadata,
          "validatePageProvenance",
        );
      }
    }
  }
  metadata.source_page_count = boundedCount(sourcePages.size);
  return null;
}

function baseMetadata(
  response: Record<string, unknown>,
  requestedPage?: number,
): DiagnosticMetadata {
  const metadata: DiagnosticMetadata = {
    response_status: responseStatus(response.status),
    error_present: response.error !== undefined && response.error !== null,
    incomplete_details_present: response.incomplete_details !== undefined &&
      response.incomplete_details !== null,
  };
  if (requestedPage !== undefined) {
    metadata.requested_page_number = requestedPage;
  }
  return metadata;
}

function responseStatus(value: unknown): DiagnosticMetadata["response_status"] {
  return [
      "queued",
      "in_progress",
      "completed",
      "incomplete",
      "failed",
      "cancelled",
    ].includes(String(value))
    ? value as DiagnosticMetadata["response_status"]
    : "unknown";
}

function failure(
  code: DiagnosticCode,
  metadata: DiagnosticMetadata,
  stage: ValidatorStage,
): DiagnosticFailure {
  return { ok: false, code, metadata: { ...metadata, validator_stage: stage } };
}

function pageRecord(result: unknown): Record<string, unknown> | null {
  return isRecord(result) && Array.isArray(result.pages) &&
      isRecord(result.pages[0])
    ? result.pages[0]
    : null;
}

function hasUnknownKeys(
  value: Record<string, unknown>,
  allowed: readonly string[],
) {
  return Object.keys(value).some((key) => !allowed.includes(key));
}

function hasExactKeys(
  value: Record<string, unknown>,
  expected: readonly string[],
) {
  return expected.every((key) => Object.hasOwn(value, key)) &&
    Object.keys(value).length === expected.length;
}

function validConfidence(value: unknown) {
  return typeof value === "number" && Number.isFinite(value) && value >= 0 &&
    value <= 1;
}

function sortedUniquePages(value: unknown[]) {
  return value.every((page, index) =>
    Number.isInteger(page) && (page as number) >= 1 &&
    (page as number) <= 100 &&
    (index === 0 || (value[index - 1] as number) < (page as number))
  );
}

function boundedCount(value: number) {
  return Math.max(0, Math.min(100, Math.trunc(value)));
}

function isRecord(value: unknown): value is Record<string, any> {
  return typeof value === "object" && value !== null && !Array.isArray(value);
}
