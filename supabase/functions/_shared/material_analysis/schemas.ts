import {
  MaterialAnalysisStatus,
  PageAnalysisResult,
  PageState,
  ReductionResult,
  StructuredSummary,
} from "./contracts.ts";
import {
  validateLatex,
  validateSafeMarkdown,
  ValidationResult,
} from "./validators.ts";

const page = { type: "integer", minimum: 1, maximum: 100 } as const;
const confidence = { type: "number", minimum: 0, maximum: 1 } as const;
const pageArray = { type: "array", items: page, maxItems: 100 } as const;
const warningSchema = closed({
  code: { type: "string", pattern: "^[a-z0-9_]{1,64}$" },
  detail: { type: "string" },
  source_pages: pageArray,
});
const equationSchema = closed({
  id: { type: "string", pattern: "^eq_[a-z0-9_-]{1,60}$" },
  latex: { type: "string" },
  explanation_markdown: { type: "string" },
  source_page: page,
  display: { type: "string", enum: ["inline", "block"] },
  confidence,
  uncertainty: { type: "boolean" },
});

export const pageAnalysisResultSchema = closed({
  page_number: page,
  summary_markdown: { type: "string" },
  key_concepts: { type: "array", items: { type: "string" }, maxItems: 50 },
  equations: { type: "array", items: equationSchema, maxItems: 100 },
  confidence,
  warnings: { type: "array", items: warningSchema, maxItems: 100 },
  trustworthy: { type: "boolean" },
});

export const reductionResultSchema = closed({
  source_pages: pageArray,
  summary_markdown: { type: "string" },
  key_concepts: { type: "array", items: { type: "string" }, maxItems: 100 },
  equation_ids: {
    type: "array",
    items: { type: "string", pattern: "^eq_[a-z0-9_-]{1,60}$" },
    maxItems: 100,
  },
  warnings: { type: "array", items: warningSchema, maxItems: 100 },
  confidence,
});

const blockSchema = {
  anyOf: [
    closed({
      kind: { type: "string", enum: ["prose"] },
      markdown: { type: "string" },
      display: { type: "string", enum: ["inline", "block"] },
    }),
    closed({
      kind: { type: "string", enum: ["equation"] },
      equation_id: { type: "string", pattern: "^eq_[a-z0-9_-]{1,60}$" },
      display: { type: "string", enum: ["inline", "block"] },
    }),
  ],
};

export const structuredSummarySchema = closed({
  language: { type: "string" },
  sections: {
    type: "array",
    minItems: 1,
    maxItems: 24,
    items: closed({
      id: { type: "string", pattern: "^[a-z0-9][a-z0-9_-]{0,63}$" },
      title: { type: "string" },
      blocks: { type: "array", minItems: 1, maxItems: 50, items: blockSchema },
      source_pages: pageArray,
      confidence,
    }),
  },
  key_concepts: {
    type: "array",
    maxItems: 50,
    items: closed({
      title: { type: "string" },
      explanation_markdown: { type: "string" },
      source_pages: pageArray,
      confidence,
    }),
  },
  equations: { type: "array", maxItems: 100, items: equationSchema },
  warnings: { type: "array", maxItems: 100, items: warningSchema },
  partial_extraction: closed({
    is_partial: { type: "boolean" },
    analyzed_pages: pageArray,
    partial_pages: pageArray,
    missing_pages: pageArray,
    page_modes: {
      type: "array",
      minItems: 1,
      maxItems: 100,
      items: closed({
        page,
        mode: { type: "string", enum: ["text", "visual"] },
      }),
    },
  }),
});

export const publicStatusSchema = closed({
  material_id: { type: "string", format: "uuid" },
  processing_mode: { type: "string", enum: ["recommended", "economy"] },
  state: {
    type: "string",
    enum: [
      "awaiting_confirmation",
      "processing",
      "reconciliation_required",
      "user_retry_required",
      "completed",
      "completed_with_warnings",
      "failed",
    ],
  },
  public_stage: {
    type: "string",
    enum: [
      "preparing_document",
      "analyzing_pages",
      "recognizing_formulas_and_diagrams",
      "creating_summary",
    ],
  },
  page_count: page,
  completed_pages: { type: "integer", minimum: 0, maximum: 100 },
  confirmation_required: { type: "boolean" },
  can_retry: { type: "boolean" },
  retry_after_seconds: {
    anyOf: [{ type: "integer", minimum: 0, maximum: 900 }, { type: "null" }],
  },
  warnings: { type: "array", maxItems: 100, items: warningSchema },
  summary_schema_version: {
    anyOf: [{ type: "integer", minimum: 1 }, { type: "null" }],
  },
  summary_payload: { anyOf: [structuredSummarySchema, { type: "null" }] },
});

export function validateStructuredOutputSubset(
  schema: unknown,
): ValidationResult {
  const errors: string[] = [];
  const supported = new Set([
    "type",
    "properties",
    "required",
    "additionalProperties",
    "items",
    "enum",
    "anyOf",
    "pattern",
    "format",
    "minimum",
    "maximum",
    "exclusiveMinimum",
    "exclusiveMaximum",
    "multipleOf",
    "minItems",
    "maxItems",
    "$ref",
    "$defs",
    "description",
  ]);
  const walk = (value: unknown, path: string) => {
    if (!isRecord(value)) return;
    for (const key of Object.keys(value)) {
      if (!supported.has(key)) errors.push(`unsupported:${path}.${key}`);
    }
    if (value.type === "object") {
      if (value.additionalProperties !== false) {
        errors.push(`open_object:${path}`);
      }
      if (!Array.isArray(value.required)) {
        errors.push(`required_missing:${path}`);
      }
      const properties = isRecord(value.properties) ? value.properties : {};
      if (!sameStrings(Object.keys(properties), value.required as unknown[])) {
        errors.push(`required_mismatch:${path}`);
      }
      for (const [key, child] of Object.entries(properties)) {
        walk(child, `${path}.${key}`);
      }
    }
    if (value.items) walk(value.items, `${path}[]`);
    if (Array.isArray(value.anyOf)) {
      value.anyOf.forEach((child, index) =>
        walk(child, `${path}.anyOf${index}`)
      );
    }
  };
  walk(schema, "$root");
  return finish(errors);
}

export function validateSummarySemantics(
  input: unknown,
  pageCount: number,
): ValidationResult {
  const errors: string[] = [];
  if (!Number.isInteger(pageCount) || pageCount < 1 || pageCount > 100) {
    return finish(["page_count"]);
  }
  if (!isStructuredSummary(input, errors)) return finish(errors);
  const summary = input as StructuredSummary;
  const expected = range(pageCount);
  const extraction = summary.partial_extraction;
  const sets = [
    extraction.analyzed_pages,
    extraction.partial_pages,
    extraction.missing_pages,
  ];
  for (const pages of sets) {
    if (!isSortedUniquePages(pages, pageCount)) errors.push("page_set_invalid");
  }
  const combined = sets.flat();
  if (
    !isSortedUniquePages([...combined].sort((a, b) => a - b), pageCount) ||
    !sameNumbers([...combined].sort((a, b) => a - b), expected)
  ) {
    errors.push("page_partition");
  }
  const modePages = extraction.page_modes.map((entry) => entry.page);
  if (
    !sameNumbers([...modePages].sort((a, b) => a - b), expected) ||
    new Set(modePages).size !== modePages.length
  ) errors.push("manifest_coverage");
  if (
    extraction.is_partial !==
      (extraction.partial_pages.length > 0 ||
        extraction.missing_pages.length > 0)
  ) {
    errors.push("partial_flag");
  }
  const authoritativePages = new Set([
    ...extraction.analyzed_pages,
    ...extraction.partial_pages,
  ]);
  const equationIds = summary.equations.map((equation) => equation.id);
  if (new Set(equationIds).size !== equationIds.length) {
    errors.push("duplicate_equation_id");
  }
  const references: string[] = [];
  for (const equation of summary.equations) {
    if (!authoritativePages.has(equation.source_page)) {
      errors.push("equation_source_page");
    }
  }
  for (const section of summary.sections) {
    if (!validClaimPages(section.source_pages, authoritativePages, pageCount)) {
      errors.push("section_sources");
    }
    for (const block of section.blocks) {
      if (block.kind === "equation") references.push(block.equation_id);
    }
  }
  for (const concept of summary.key_concepts) {
    if (!validClaimPages(concept.source_pages, authoritativePages, pageCount)) {
      errors.push("concept_sources");
    }
  }
  if (references.some((id) => !equationIds.includes(id))) {
    errors.push("equation_reference");
  }
  if (new Set(references).size !== references.length) {
    errors.push("duplicate_equation_reference");
  }
  if (equationIds.some((id) => !references.includes(id))) {
    errors.push("unused_equation");
  }
  return finish(errors);
}

export function validatePageResult(
  input: unknown,
  expectedPage: number,
  pageCount = expectedPage,
  terminalStatus: Extract<PageState, "completed" | "partial" | "missing"> =
    "completed",
): ValidationResult {
  const errors: string[] = [];
  if (terminalStatus === "missing") {
    if (input !== null) errors.push("missing_has_authoritative_result");
    return finish(errors);
  }
  if (!isPageAnalysisResult(input, errors, pageCount)) return finish(errors);
  const pageResult = input as PageAnalysisResult;
  if (pageResult.page_number !== expectedPage) errors.push("page_number");
  if (!pageResult.trustworthy) errors.push("trustworthy_content_required");
  if (terminalStatus === "partial" && pageResult.warnings.length === 0) {
    errors.push("partial_warning_required");
  }
  if (
    pageResult.warnings.some((warning) =>
      warning.source_pages.some((pageNumber) => pageNumber !== expectedPage)
    )
  ) errors.push("warning_page_provenance");
  if (
    pageResult.equations.some((equation) =>
      equation.source_page !== expectedPage
    )
  ) {
    errors.push("equation_page_provenance");
  }
  return finish(errors);
}

export function validateReductionResult(
  input: unknown,
  allowedPages: number[],
  authoritativeEquationIds: string[] = [],
): ValidationResult {
  const errors: string[] = [];
  const pageCount = Math.max(0, ...allowedPages);
  if (!isReductionResult(input, errors, Math.max(1, pageCount))) {
    return finish(errors);
  }
  const reduction = input as ReductionResult;
  if (
    !sameNumbers(reduction.source_pages, allowedPages) ||
    !isSortedUniquePages(reduction.source_pages, Math.max(1, pageCount))
  ) {
    errors.push("source_pages");
  }
  if (
    new Set(reduction.equation_ids).size !== reduction.equation_ids.length ||
    reduction.equation_ids.some((id) => !authoritativeEquationIds.includes(id))
  ) {
    errors.push("equation_references");
  }
  if (
    reduction.warnings.some((warning) =>
      warning.source_pages.some((pageNumber) =>
        !allowedPages.includes(pageNumber)
      )
    )
  ) errors.push("warning_page_provenance");
  return finish(errors);
}

export function validatePublicStatus(
  status: MaterialAnalysisStatus,
): ValidationResult {
  const errors: string[] = [];
  if (status.completed_pages > status.page_count) errors.push("progress");
  if (
    (status.state === "completed" ||
      status.state === "completed_with_warnings") &&
    !status.summary_payload
  ) errors.push("summary_required");
  return finish(errors);
}

function isStructuredSummary(
  value: unknown,
  errors: string[],
): value is StructuredSummary {
  if (
    !exactRecord(
      value,
      [
        "language",
        "sections",
        "key_concepts",
        "equations",
        "warnings",
        "partial_extraction",
      ],
      errors,
      "summary",
    )
  ) return false;
  if (!boundedString(value.language, 1, 32)) errors.push("language");
  if (!boundedArray(value.sections, 1, 24)) errors.push("sections");
  else {value.sections.forEach((section, index) =>
      validateSection(section, errors, index)
    );}
  if (!boundedArray(value.key_concepts, 0, 50)) errors.push("key_concepts");
  else {value.key_concepts.forEach((concept, index) =>
      validateConcept(concept, errors, index)
    );}
  if (!boundedArray(value.equations, 0, 100)) errors.push("equations");
  else {value.equations.forEach((equation, index) =>
      validateEquation(equation, errors, `equations.${index}`)
    );}
  validateWarnings(value.warnings, errors, 100);
  if (
    !exactRecord(
      value.partial_extraction,
      [
        "is_partial",
        "analyzed_pages",
        "partial_pages",
        "missing_pages",
        "page_modes",
      ],
      errors,
      "partial_extraction",
    )
  ) return false;
  if (typeof value.partial_extraction.is_partial !== "boolean") {
    errors.push("partial_extraction.is_partial");
  }
  for (
    const key of ["analyzed_pages", "partial_pages", "missing_pages"] as const
  ) {
    if (
      !boundedArray(value.partial_extraction[key], 0, 100) ||
      !(value.partial_extraction[key] as unknown[]).every(Number.isInteger)
    ) errors.push(`partial_extraction.${key}`);
  }
  if (!boundedArray(value.partial_extraction.page_modes, 1, 100)) {
    errors.push("partial_extraction.page_modes");
  } else {value.partial_extraction.page_modes.forEach((mode, index) => {
      if (
        !exactRecord(mode, ["page", "mode"], errors, `page_modes.${index}`) ||
        !Number.isInteger(mode.page) ||
        !["text", "visual"].includes(mode.mode as string)
      ) {
        errors.push(`page_modes.${index}`);
      }
    });}
  return errors.length === 0;
}

function isPageAnalysisResult(
  value: unknown,
  errors: string[],
  pageCount: number,
): value is PageAnalysisResult {
  if (
    !exactRecord(
      value,
      [
        "page_number",
        "summary_markdown",
        "key_concepts",
        "equations",
        "confidence",
        "warnings",
        "trustworthy",
      ],
      errors,
      "page_result",
    )
  ) return false;
  const pageNumber = value.page_number;
  if (
    !Number.isInteger(pageNumber) || (pageNumber as number) < 1 ||
    (pageNumber as number) > pageCount
  ) errors.push("page_number");
  if (
    !boundedString(value.summary_markdown, 1, 6000) ||
    !validateSafeMarkdown(value.summary_markdown as string).valid
  ) errors.push("summary_markdown");
  if (
    !boundedArray(value.key_concepts, 0, 50) ||
    !value.key_concepts.every((item) => boundedString(item, 1, 500))
  ) errors.push("key_concepts");
  if (!boundedArray(value.equations, 0, 100)) errors.push("equations");
  else {value.equations.forEach((equation, index) =>
      validateEquation(equation, errors, `equations.${index}`)
    );}
  if (Array.isArray(value.equations)) {
    const ids = value.equations.filter(isRecord).map((equation) => equation.id);
    if (new Set(ids).size !== ids.length) errors.push("duplicate_equation_id");
  }
  if (!validConfidence(value.confidence)) errors.push("confidence");
  validateWarnings(value.warnings, errors, 100, pageCount);
  if (typeof value.trustworthy !== "boolean") errors.push("trustworthy");
  return errors.length === 0;
}

function isReductionResult(
  value: unknown,
  errors: string[],
  pageCount: number,
): value is ReductionResult {
  if (
    !exactRecord(
      value,
      [
        "source_pages",
        "summary_markdown",
        "key_concepts",
        "equation_ids",
        "warnings",
        "confidence",
      ],
      errors,
      "reduction",
    )
  ) return false;
  if (
    !boundedArray(value.source_pages, 1, 100) ||
    !value.source_pages.every(Number.isInteger)
  ) errors.push("source_pages");
  if (
    !boundedString(value.summary_markdown, 1, 12000) ||
    !validateSafeMarkdown(value.summary_markdown as string, 12000).valid
  ) errors.push("summary_markdown");
  if (
    !boundedArray(value.key_concepts, 0, 100) ||
    !value.key_concepts.every((item) => boundedString(item, 1, 500))
  ) errors.push("key_concepts");
  if (
    !boundedArray(value.equation_ids, 0, 100) ||
    !value.equation_ids.every((id) =>
      typeof id === "string" && /^eq_[a-z0-9_-]{1,60}$/.test(id)
    )
  ) errors.push("equation_ids");
  validateWarnings(value.warnings, errors, 100, pageCount);
  if (!validConfidence(value.confidence)) errors.push("confidence");
  return errors.length === 0;
}

function validateSection(value: unknown, errors: string[], index: number) {
  if (
    !exactRecord(
      value,
      ["id", "title", "blocks", "source_pages", "confidence"],
      errors,
      `sections.${index}`,
    )
  ) return;
  if (
    !boundedString(value.id, 1, 64) ||
    !/^[a-z0-9][a-z0-9_-]{0,63}$/.test(value.id as string)
  ) errors.push(`sections.${index}.id`);
  if (!boundedString(value.title, 1, 200)) {
    errors.push(`sections.${index}.title`);
  }
  if (!boundedArray(value.blocks, 1, 50)) {
    errors.push(`sections.${index}.blocks`);
  } else {value.blocks.forEach((block, blockIndex) =>
      validateBlock(block, errors, `sections.${index}.blocks.${blockIndex}`)
    );}
  if (
    !boundedArray(value.source_pages, 1, 100) ||
    !value.source_pages.every(Number.isInteger)
  ) errors.push(`sections.${index}.source_pages`);
  if (!validConfidence(value.confidence)) {
    errors.push(`sections.${index}.confidence`);
  }
}

function validateBlock(value: unknown, errors: string[], path: string) {
  if (
    !isRecord(value) || !["prose", "equation"].includes(value.kind as string)
  ) {
    errors.push(path);
    return;
  }
  if (value.kind === "prose") {
    if (
      !exactRecord(value, ["kind", "markdown", "display"], errors, path) ||
      !boundedString(value.markdown, 1, 6000) ||
      !validateSafeMarkdown(value.markdown as string).valid
    ) errors.push(path);
  } else if (
    !exactRecord(value, ["kind", "equation_id", "display"], errors, path) ||
    typeof value.equation_id !== "string" ||
    !/^eq_[a-z0-9_-]{1,60}$/.test(value.equation_id)
  ) errors.push(path);
  if (!["inline", "block"].includes(value.display as string)) {
    errors.push(`${path}.display`);
  }
}

function validateConcept(value: unknown, errors: string[], index: number) {
  if (
    !exactRecord(
      value,
      ["title", "explanation_markdown", "source_pages", "confidence"],
      errors,
      `concepts.${index}`,
    )
  ) return;
  if (!boundedString(value.title, 1, 200)) {
    errors.push(`concepts.${index}.title`);
  }
  if (
    !boundedString(value.explanation_markdown, 1, 3000) ||
    !validateSafeMarkdown(value.explanation_markdown as string, 3000).valid
  ) errors.push(`concepts.${index}.markdown`);
  if (
    !boundedArray(value.source_pages, 1, 100) ||
    !value.source_pages.every(Number.isInteger)
  ) errors.push(`concepts.${index}.source_pages`);
  if (!validConfidence(value.confidence)) {
    errors.push(`concepts.${index}.confidence`);
  }
}

function validateEquation(value: unknown, errors: string[], path: string) {
  if (
    !exactRecord(
      value,
      [
        "id",
        "latex",
        "explanation_markdown",
        "source_page",
        "display",
        "confidence",
        "uncertainty",
      ],
      errors,
      path,
    )
  ) return;
  if (typeof value.id !== "string" || !/^eq_[a-z0-9_-]{1,60}$/.test(value.id)) {
    errors.push(`${path}.id`);
  }
  if (
    !boundedString(value.latex, 1, 512) ||
    !validateLatex(value.latex as string).valid
  ) errors.push(`${path}.latex`);
  if (
    typeof value.explanation_markdown !== "string" ||
    value.explanation_markdown.length > 2000 ||
    (value.explanation_markdown.length > 0 &&
      !validateSafeMarkdown(value.explanation_markdown, 2000).valid)
  ) errors.push(`${path}.markdown`);
  if (!Number.isInteger(value.source_page)) errors.push(`${path}.source_page`);
  if (!["inline", "block"].includes(value.display as string)) {
    errors.push(`${path}.display`);
  }
  if (!validConfidence(value.confidence)) errors.push(`${path}.confidence`);
  if (typeof value.uncertainty !== "boolean") {
    errors.push(`${path}.uncertainty`);
  }
}

function validateWarnings(
  value: unknown,
  errors: string[],
  limit: number,
  pageCount = 100,
) {
  if (!boundedArray(value, 0, limit)) {
    errors.push("warnings");
    return;
  }
  value.forEach((warning, index) => {
    if (
      !exactRecord(
        warning,
        ["code", "detail", "source_pages"],
        errors,
        `warnings.${index}`,
      )
    ) return;
    if (
      typeof warning.code !== "string" ||
      !/^[a-z0-9_]{1,64}$/.test(warning.code)
    ) errors.push(`warnings.${index}.code`);
    if (!boundedString(warning.detail, 1, 500)) {
      errors.push(`warnings.${index}.detail`);
    }
    if (
      !boundedArray(warning.source_pages, 0, 100) ||
      !isSortedUniquePages(warning.source_pages as number[], pageCount)
    ) errors.push(`warnings.${index}.source_pages`);
  });
}

function closed(properties: Record<string, unknown>) {
  return {
    type: "object",
    additionalProperties: false,
    properties,
    required: Object.keys(properties),
  };
}
function exactRecord(
  value: unknown,
  keys: string[],
  errors: string[],
  path: string,
): value is Record<string, unknown> {
  if (!isRecord(value)) {
    errors.push(`${path}.object`);
    return false;
  }
  if (!sameStrings(Object.keys(value), keys)) errors.push(`${path}.fields`);
  return true;
}
function isRecord(value: unknown): value is Record<string, any> {
  return value !== null && typeof value === "object" && !Array.isArray(value);
}
function boundedArray(
  value: unknown,
  min: number,
  max: number,
): value is unknown[] {
  return Array.isArray(value) && value.length >= min && value.length <= max;
}
function boundedString(
  value: unknown,
  min: number,
  max: number,
): value is string {
  return typeof value === "string" && value.length >= min &&
    value.length <= max;
}
function validConfidence(value: unknown) {
  return typeof value === "number" && Number.isFinite(value) && value >= 0 &&
    value <= 1;
}
function isSortedUniquePages(values: number[], pageCount: number) {
  return Array.isArray(values) &&
    values.every((value, index) =>
      Number.isInteger(value) && value >= 1 && value <= pageCount &&
      (index === 0 || values[index - 1] < value)
    );
}
function validClaimPages(
  values: number[],
  allowed: Set<number>,
  pageCount: number,
) {
  return values.length > 0 && isSortedUniquePages(values, pageCount) &&
    values.every((pageNumber) => allowed.has(pageNumber));
}
function range(count: number) {
  return Array.from({ length: count }, (_, index) => index + 1);
}
function sameNumbers(left: number[], right: number[]) {
  return left.length === right.length &&
    left.every((value, index) => value === right[index]);
}
function sameStrings(left: unknown[], right: unknown[]) {
  return left.length === right.length &&
    [...left].map(String).sort().every((value, index) =>
      value === [...right].map(String).sort()[index]
    );
}
function finish(errors: string[]): ValidationResult {
  return { valid: errors.length === 0, errors: [...new Set(errors)] };
}
