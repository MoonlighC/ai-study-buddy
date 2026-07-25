import { PDFDocument } from "pdf-lib";
import {
  MaterialAnalysisStatus,
  ProcessingMode,
  SafeWarning,
  StructuredSummary,
} from "./contracts.ts";
import {
  batchFingerprint,
  sha256Hex,
  stableJson,
} from "./fingerprints_retry.ts";
import { PageRoutingInput, routePage } from "./router.ts";
import { routerVersion } from "./contracts.ts";
import { miniPdfVersion } from "./mini_pdf.ts";
import { validatePublicStatus, validateSummarySemantics } from "./schemas.ts";

export const analysisValidatorVersion = "phase-c-validator-v3";
export const analysisPromptVersion = "phase-c-prompts-v3";
export const analysisConfigurationVersion = "phase-c-server-v2";
export const analysisFingerprintVersion = "phase-c-fingerprint-v2";
export const pageSchemaVersion = "phase-c-page-schema-v3";
export const reductionSchemaVersion = "phase-c-reduction-schema-v2";
export const finalSummarySchemaVersion = "phase-c-final-schema-v3";
export const maximumPdfBytes = 40 * 1024 * 1024;
export const maximumImageBytes = 8 * 1024 * 1024;
export const maximumPages = 100;
export const confirmationPageThreshold = 21;
export const maximumTextBatchPages = 10;
export const maximumTextBatchCharacters = 40_000;
export const maximumVisualBatchPages = 5;
export const maximumReductionInputs = 10;

export type PublicRequest = {
  material_id: string;
  processing_mode?: ProcessingMode;
  confirm_large_document?: boolean;
  analyze_again?: boolean;
};

export type SourceMaterial = {
  id: string;
  user_id: string;
  kind: "pdf" | "image";
  source_kind: "upload";
  storage_bucket: string;
  storage_path: string;
  mime_type: string;
  file_size_bytes: number;
  processing_status: string;
  deleted_at?: string | null;
  metadata?: Record<string, unknown>;
};

export type PagePlan = {
  page_number: number;
  route: "text" | "visual";
  normalized_text: string;
  routing_signals: Record<string, unknown>;
  routing_confidence: number;
  input_hash: string;
};

export type TextPageInput = {
  page_number: number;
  normalized_text: string;
};

export async function buildProcessingVersionContract(input: {
  material: SourceMaterial;
  sourceHash: string;
  processingMode: ProcessingMode;
  pageCount: number;
}) {
  const metadataHash = await sha256Hex(stableJson({
    kind: input.material.kind,
    mime_type: input.material.mime_type,
    file_size_bytes: input.material.file_size_bytes,
    metadata: input.material.metadata ?? {},
  }));
  const contract = {
    fingerprint_version: analysisFingerprintVersion,
    source_content_hash: input.sourceHash,
    source_metadata_hash: metadataHash,
    processing_mode: input.processingMode,
    page_count: input.pageCount,
    router_version: routerVersion,
    prompt_version: analysisPromptVersion,
    page_schema_version: pageSchemaVersion,
    reduction_schema_version: reductionSchemaVersion,
    final_summary_schema_version: finalSummarySchemaVersion,
    validator_version: analysisValidatorVersion,
    openai_configuration_version: analysisConfigurationVersion,
    mini_pdf_version: miniPdfVersion,
  } as const;
  return {
    contract,
    fingerprint: await sha256Hex(stableJson(contract)),
  };
}

export function parsePrepareRequest(value: unknown): Required<PublicRequest> {
  if (
    !isRecord(value) ||
    ![
      ["material_id", "processing_mode", "confirm_large_document"],
      [
        "material_id",
        "processing_mode",
        "confirm_large_document",
        "analyze_again",
      ],
    ].some((keys) => exactKeys(value, keys)) ||
    (Object.hasOwn(value, "analyze_again") &&
      typeof value.analyze_again !== "boolean") ||
    !isUuid(value.material_id) ||
    !["recommended", "economy"].includes(value.processing_mode as string) ||
    typeof value.confirm_large_document !== "boolean"
  ) {
    throw new SafeAnalysisError("invalid_request", 400);
  }
  return {
    material_id: (value.material_id as string).toLowerCase(),
    processing_mode: value.processing_mode as ProcessingMode,
    confirm_large_document: value.confirm_large_document,
    analyze_again: value.analyze_again === true,
  };
}

export function parseMaterialOnlyRequest(
  value: unknown,
): { material_id: string } {
  if (
    !isRecord(value) || !exactKeys(value, ["material_id"]) ||
    !isUuid(value.material_id)
  ) {
    throw new SafeAnalysisError("invalid_request", 400);
  }
  return { material_id: (value.material_id as string).toLowerCase() };
}

export function validateSourceMaterial(
  material: unknown,
  principalId: string,
  materialId: string,
): SourceMaterial {
  if (
    !isRecord(material) || material.id !== materialId ||
    material.user_id !== principalId || material.source_kind !== "upload" ||
    material.deleted_at != null ||
    !["pdf", "image"].includes(material.kind as string) ||
    typeof material.storage_bucket !== "string" ||
    typeof material.storage_path !== "string" ||
    typeof material.mime_type !== "string" ||
    !Number.isInteger(material.file_size_bytes)
  ) {
    throw new SafeAnalysisError("material_unavailable", 404);
  }
  const expectedBucket = material.kind === "pdf"
    ? "study-materials"
    : "study-images";
  const allowedMime = material.kind === "pdf"
    ? ["application/pdf"]
    : ["image/png", "image/jpeg", "image/webp"];
  const path = material.storage_path.split("/");
  const maximumBytes = material.kind === "pdf"
    ? maximumPdfBytes
    : maximumImageBytes;
  if (
    material.storage_bucket !== expectedBucket ||
    !allowedMime.includes(material.mime_type) ||
    (material.file_size_bytes as number) < 1 ||
    (material.file_size_bytes as number) > maximumBytes || path.length !== 3 ||
    path[0] !== principalId || path[1] !== materialId || !path[2]
  ) {
    throw new SafeAnalysisError("invalid_source", 422);
  }
  return material as unknown as SourceMaterial;
}

export async function inspectSourceBytes(
  material: SourceMaterial,
  bytes: Uint8Array,
): Promise<{ pageCount: number; sourceHash: string }> {
  if (bytes.length !== material.file_size_bytes || bytes.length === 0) {
    throw new SafeAnalysisError("invalid_source", 422);
  }
  if (!hasSignature(material.mime_type, bytes)) {
    throw new SafeAnalysisError("invalid_source", 422);
  }
  let pageCount = 1;
  if (material.kind === "pdf") {
    try {
      const pdf = await PDFDocument.load(bytes, {
        ignoreEncryption: false,
        updateMetadata: false,
      });
      pageCount = pdf.getPageCount();
    } catch (_) {
      throw new SafeAnalysisError("invalid_source", 422);
    }
    if (pageCount < 1 || pageCount > maximumPages) {
      throw new SafeAnalysisError("page_limit_exceeded", 422);
    }
  }
  return { pageCount, sourceHash: await sha256Hex(bytes) };
}

export function confirmationRequired(pageCount: number): boolean {
  return pageCount >= confirmationPageThreshold;
}

export async function buildPagePlans(input: {
  material: SourceMaterial;
  pageCount: number;
  mode: ProcessingMode;
  selectablePages?: Array<{ page_number: number; text: string }>;
  domainProfile?: "general" | "stem";
}): Promise<PagePlan[]> {
  const selectable = new Map(
    (input.selectablePages ?? []).map((page) => [
      page.page_number,
      normalizePageText(page.text),
    ]),
  );
  const plans: PagePlan[] = [];
  for (let pageNumber = 1; pageNumber <= input.pageCount; pageNumber++) {
    const text = input.material.kind === "image"
      ? ""
      : selectable.get(pageNumber) ?? "";
    const routingInput: PageRoutingInput = {
      pageNumber,
      sourceKind: input.material.kind,
      normalizedText: text,
      textCoordinates: [],
      pageWidth: 612,
      pageHeight: 792,
      textCoverage: text ? Math.min(1, text.length / 3000) : 0,
      damagedCharacterRatio: damagedRatio(text),
      mathDensity: mathDensity(text),
      columnAlignment: 0,
      tableAlignment: /\|.+\|/.test(text) ? 0.5 : 0,
      rasterCoverage: input.material.kind === "image" ? 1 : 0,
      vectorPathComplexity: 0,
      handwritingOrInk: false,
      diagramOrGraph: /\b(diagram|graph|figure|chart)\b/i.test(text),
      readingOrderUncertainty: 0,
      layoutUncertainty: 0,
      domainProfile: input.domainProfile ?? inferDomainProfile(text),
      mode: input.mode,
    };
    const decision = await routePage(routingInput);
    plans.push({
      page_number: pageNumber,
      route: decision.route,
      normalized_text: text,
      routing_signals: {
        reasons: decision.reasons,
        router_version: decision.routerVersion,
      },
      routing_confidence: decision.confidence,
      input_hash: await sha256Hex(text || `visual:${pageNumber}`),
    });
  }
  return plans;
}

export function createTextBatches(pages: TextPageInput[]): TextPageInput[][] {
  const batches: TextPageInput[][] = [];
  let current: TextPageInput[] = [];
  let characters = 0;
  for (const page of pages) {
    if (!Number.isInteger(page.page_number) || page.page_number < 1) {
      throw new Error("invalid_page_number");
    }
    const normalized = normalizePageText(page.normalized_text);
    if (!normalized || normalized.length > maximumTextBatchCharacters) {
      throw new Error("invalid_page_text");
    }
    const renderedLength =
      renderDelimitedPage(page.page_number, normalized).length;
    if (
      current.length &&
      (current.length >= maximumTextBatchPages ||
        characters + renderedLength > maximumTextBatchCharacters)
    ) {
      batches.push(current);
      current = [];
      characters = 0;
    }
    if (renderedLength > maximumTextBatchCharacters) {
      throw new Error("page_text_limit");
    }
    current.push({
      page_number: page.page_number,
      normalized_text: normalized,
    });
    characters += renderedLength;
  }
  if (current.length) batches.push(current);
  return batches;
}

export function renderTextBatch(pages: TextPageInput[]): string {
  if (pages.length < 1 || pages.length > maximumTextBatchPages) {
    throw new Error("text_batch_page_limit");
  }
  const output = pages.map((page) =>
    renderDelimitedPage(
      page.page_number,
      normalizePageText(page.normalized_text),
    )
  ).join("\n");
  if (output.length > maximumTextBatchCharacters) {
    throw new Error("text_batch_character_limit");
  }
  return output;
}

export function createVisualBatches(pageNumbers: number[]): number[][] {
  assertSortedUniquePages(pageNumbers);
  const result: number[][] = [];
  for (
    let index = 0;
    index < pageNumbers.length;
    index += maximumVisualBatchPages
  ) {
    result.push(pageNumbers.slice(index, index + maximumVisualBatchPages));
  }
  return result;
}

export function createReductionGroups<T>(inputs: T[]): T[][] {
  if (!inputs.length) throw new Error("reduction_inputs_required");
  const groups: T[][] = [];
  for (let index = 0; index < inputs.length; index += maximumReductionInputs) {
    groups.push(inputs.slice(index, index + maximumReductionInputs));
  }
  return groups;
}

export async function operationFingerprint(input: {
  operation: string;
  mode: ProcessingMode;
  pageNumbers: number[];
  inputHashes: string[];
  reductionLevel?: number;
}) {
  return await batchFingerprint({
    operation: input.operation,
    mode: input.mode,
    pageNumbers: input.pageNumbers,
    inputHashes: input.inputHashes,
    routerVersion: "phase-c-router-v1",
    promptVersion: analysisPromptVersion,
    schemaVersion: 1,
    reductionLevel: input.reductionLevel ?? 0,
    configurationVersion: analysisConfigurationVersion,
  });
}

export async function validationHash(value: unknown): Promise<string> {
  return await sha256Hex(stableJson(value));
}

export function projectSummaryToSafeMarkdown(
  summary: StructuredSummary,
): string {
  const semantic = validateSummarySemantics(
    summary,
    summary.partial_extraction.page_modes.length,
  );
  if (!semantic.valid) throw new Error("invalid_summary_projection");
  const equations = new Map(
    summary.equations.map((equation) => [equation.id, equation]),
  );
  const lines: string[] = [];
  for (const section of summary.sections) {
    lines.push(`## ${plainText(section.title)}`);
    for (const block of section.blocks) {
      if (block.kind === "prose") lines.push(block.markdown);
      else {
        const equation = equations.get(block.equation_id);
        if (equation) {
          lines.push(`Equation: ${equation.latex}`);
          if (equation.explanation_markdown) {
            lines.push(equation.explanation_markdown);
          }
        }
      }
    }
    lines.push(`Pages: ${section.source_pages.join(", ")}`);
  }
  if (summary.key_concepts.length) {
    lines.push("## Key concepts");
    for (const concept of summary.key_concepts) {
      lines.push(
        `- ${plainText(concept.title)}: ${concept.explanation_markdown}`,
      );
    }
  }
  if (summary.partial_extraction.is_partial) {
    lines.push("## Processing notes");
    if (summary.partial_extraction.partial_pages.length) {
      lines.push(
        `Partial pages: ${summary.partial_extraction.partial_pages.join(", ")}`,
      );
    }
    if (summary.partial_extraction.missing_pages.length) {
      lines.push(
        `Missing pages: ${summary.partial_extraction.missing_pages.join(", ")}`,
      );
    }
  }
  return lines.join("\n\n").slice(0, 100_000);
}

export function sanitizePublicStatus(value: unknown): MaterialAnalysisStatus {
  if (!isRecord(value)) throw new SafeAnalysisError("status_unavailable", 500);
  const allowed = [
    "material_id",
    "processing_mode",
    "state",
    "public_stage",
    "page_count",
    "completed_pages",
    "confirmation_required",
    "can_retry",
    "can_analyze_again",
    "retry_after_seconds",
    "warnings",
    "summary_schema_version",
    "summary_payload",
  ];
  const status = Object.fromEntries(
    allowed.map((key) => [key, value[key]]),
  ) as unknown as MaterialAnalysisStatus;
  if (
    !validatePublicStatus(status).valid || !isUuid(status.material_id) ||
    !Array.isArray(status.warnings) ||
    status.warnings.some((warning) => !isSafeWarning(warning))
  ) {
    throw new SafeAnalysisError("status_unavailable", 500);
  }
  return status;
}

export function analysisLog(
  operation: "prepare" | "advance" | "retry" | "diagnostic",
  stage: string,
  details: Record<string, unknown> = {},
  write: (line: string) => void = console.log,
) {
  const safe: Record<string, unknown> = { operation, stage };
  for (
    const key of [
      "status",
      "page_count",
      "completed_pages",
      "retry_after_seconds",
      "refusal_count",
      "output_item_count",
      "structured_candidate_count",
      "parsed_json_byte_length",
      "top_level_key_count",
      "requested_page_number",
      "returned_page_number",
      "warning_count",
      "equation_count",
      "source_page_count",
      "first_failing_page_number",
      "equation_index",
      "batch_result_count",
      "authoritative_equation_count",
      "provider_equation_count",
      "referenced_equation_objects_added",
      "orphan_references_added",
    ]
  ) {
    const value = details[key];
    if (typeof value === "number" && Number.isFinite(value)) {
      safe[key] = Math.max(0, Math.min(1000, Math.trunc(value)));
    }
  }
  for (
    const key of [
      "reason",
      "public_stage",
      "state",
      "operation_kind",
      "response_status",
      "validator_stage",
      "validator_code",
      "field_path",
      "warning_code",
    ]
  ) {
    const value = details[key];
    const safeValidatorStage = key === "validator_stage" &&
      typeof value === "string" && [
      "validateResponseEnvelope",
      "extractSingleStructuredCandidate",
      "parseStructuredJson",
      "validatePageSchema",
      "validatePageSemantics",
      "validatePageMarkdown",
      "validatePageLatex",
      "validatePageProvenance",
      "persistValidatedPage",
      "validateVersionContract",
      "canonicalizeFinalSummaryEquations",
      "validateAuthoritativeEquations",
    ].includes(value);
    if (
      typeof value === "string" &&
      (safeValidatorStage ||
        (key === "field_path" &&
          /^pages(?:\.[0-9]+(?:\.(?:page_number|warnings\.[0-9]+\.code|equations\.[0-9]+\.latex))?)?$/
            .test(value)) ||
        (key === "validator_code" && /^[a-z0-9_:-]{1,96}$/.test(value)) ||
        /^[a-z0-9_-]{1,64}$/.test(value))
    ) {
      safe[key] = value;
    }
  }
  for (
    const key of [
      "error_present",
      "incomplete_details_present",
      "equation_id_present",
      "equation_fields_replaced",
    ]
  ) {
    if (typeof details[key] === "boolean") safe[key] = details[key];
  }
  if (
    Array.isArray(details.expected_page_numbers) &&
    details.expected_page_numbers.length <= 5 &&
    details.expected_page_numbers.every((page) =>
      Number.isInteger(page) && page >= 1 && page <= 100
    )
  ) {
    safe.expected_page_numbers = details.expected_page_numbers;
  }
  write(JSON.stringify(safe));
}

export class SafeAnalysisError extends Error {
  constructor(readonly code: string, readonly status: number) {
    super(code);
  }
}

function hasSignature(mime: string, bytes: Uint8Array): boolean {
  if (mime === "application/pdf") {
    return startsWith(bytes, [0x25, 0x50, 0x44, 0x46, 0x2d]);
  }
  if (mime === "image/png") {
    return startsWith(bytes, [0x89, 0x50, 0x4e, 0x47, 0x0d, 0x0a, 0x1a, 0x0a]);
  }
  if (mime === "image/jpeg") return startsWith(bytes, [0xff, 0xd8, 0xff]);
  if (mime === "image/webp") {
    return bytes.length >= 12 && startsWith(bytes, [0x52, 0x49, 0x46, 0x46]) &&
      String.fromCharCode(...bytes.slice(8, 12)) === "WEBP";
  }
  return false;
}

function startsWith(bytes: Uint8Array, signature: number[]) {
  return bytes.length >= signature.length &&
    signature.every((value, index) => bytes[index] === value);
}

function renderDelimitedPage(pageNumber: number, text: string) {
  return `<original_page number="${pageNumber}">\n${text}\n</original_page>`;
}

function normalizePageText(value: string) {
  return value.normalize("NFC").replace(/\r\n?/g, "\n")
    // deno-lint-ignore no-control-regex -- untrusted source text is stripped deliberately.
    .replace(/[\u0000-\u0008\u000B\u000C\u000E-\u001F\u007F]/g, "")
    .trim();
}

function damagedRatio(text: string) {
  if (!text) return 1;
  return (text.match(/\uFFFD/g)?.length ?? 0) / text.length;
}

function mathDensity(text: string) {
  if (!text) return 0;
  return Math.min(1, (text.match(/[=+\-*/^∑√∫]/g)?.length ?? 0) / text.length);
}

function inferDomainProfile(text: string): "general" | "stem" {
  return /\b(theorem|equation|algorithm|molecule|physics|calculus|matrix)\b/i
      .test(text) ||
      mathDensity(text) >= 0.01
    ? "stem"
    : "general";
}

function assertSortedUniquePages(pages: number[]) {
  if (
    !pages.length ||
    pages.some((page, index) =>
      !Number.isInteger(page) || page < 1 || page > maximumPages ||
      (index > 0 && pages[index - 1] >= page)
    )
  ) throw new Error("invalid_page_manifest");
}

function plainText(value: string) {
  return value.replace(/[\r\n]+/g, " ").replace(/[<>]/g, "").trim();
}

function isSafeWarning(value: unknown): value is SafeWarning {
  return isRecord(value) && typeof value.code === "string" &&
    /^[a-z0-9_]{1,64}$/.test(value.code) && typeof value.detail === "string" &&
    value.detail.length <= 500 && Array.isArray(value.source_pages) &&
    value.source_pages.every((page) =>
      Number.isInteger(page) && page >= 1 && page <= 100
    );
}

function exactKeys(value: Record<string, unknown>, keys: string[]) {
  const actual = Object.keys(value).sort();
  return actual.length === keys.length &&
    keys.slice().sort().every((key, index) => key === actual[index]);
}

function isUuid(value: unknown): value is string {
  return typeof value === "string" &&
    /^[0-9a-f]{8}-[0-9a-f]{4}-[1-5][0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$/i
      .test(value);
}

function isRecord(value: unknown): value is Record<string, unknown> {
  return typeof value === "object" && value !== null && !Array.isArray(value);
}
