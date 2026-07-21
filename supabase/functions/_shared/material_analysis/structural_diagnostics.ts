import {
  pageBatchResultSchema,
  reductionResultSchema,
  structuredSummarySchema,
  validatePageBatchResult,
  validateReductionResult,
  validateSummarySemantics,
} from "./schemas.ts";

export type StructuralDiagnosticRequest = {
  operation:
    | "page_text"
    | "page_visual"
    | "page_recovery"
    | "reduction"
    | "final_summary";
  expectedPages: number[];
  allowedEquationIds?: string[];
  pageCount: number;
};

export type StructuralMismatch = {
  path: string;
  code:
    | "type_mismatch"
    | "nullability_mismatch"
    | "enum_mismatch"
    | "pattern_mismatch"
    | "count_min"
    | "count_max"
    | "number_min"
    | "number_max";
  expected_type: string;
  observed_type: string;
};

export type StructuralFailureDiagnostic = {
  operation: StructuralDiagnosticRequest["operation"];
  provider_status:
    | "queued"
    | "in_progress"
    | "completed"
    | "incomplete"
    | "failed"
    | "cancelled"
    | "unknown";
  validator_stage: string;
  json_parse_success: boolean;
  top_level_keys: string[];
  observed_types: Record<string, string>;
  missing_required: string[];
  unexpected_fields: string[];
  mismatches: StructuralMismatch[];
  array_object_counts: Record<string, number>;
  parsed_json_byte_length: number;
  schema_version:
    | "phase-c-page-schema-v1"
    | "phase-c-reduction-schema-v1"
    | "phase-c-final-schema-v1";
  safe_failure_code: string;
};

type Accumulator = {
  observed: Map<string, string>;
  missing: Set<string>;
  unexpected: Set<string>;
  mismatches: Map<string, StructuralMismatch>;
  counts: Map<string, number>;
};

const maximumPayloadBytes = 262_144;
const maximumPaths = 256;
const safeKeyPattern = /^[a-z][a-z0-9_]{0,63}$/;

export function diagnoseStructuralFailure(
  response: Record<string, unknown>,
  request: StructuralDiagnosticRequest,
): StructuralFailureDiagnostic {
  const operation = request.operation;
  const schemaVersion = operation === "reduction"
    ? "phase-c-reduction-schema-v1"
    : operation === "final_summary"
    ? "phase-c-final-schema-v1"
    : "phase-c-page-schema-v1";
  const base: StructuralFailureDiagnostic = {
    operation,
    provider_status: providerStatus(response.status),
    validator_stage: "validateResponseEnvelope",
    json_parse_success: false,
    top_level_keys: [],
    observed_types: {},
    missing_required: [],
    unexpected_fields: [],
    mismatches: [],
    array_object_counts: {},
    parsed_json_byte_length: 0,
    schema_version: schemaVersion,
    safe_failure_code: "response_status_not_completed",
  };
  if (base.provider_status !== "completed") return base;
  const candidates = structuredCandidates(response);
  if (candidates.length !== 1) {
    return {
      ...base,
      validator_stage: "extractSingleStructuredCandidate",
      safe_failure_code: candidates.length === 0
        ? "response_output_missing"
        : "response_output_multiple",
    };
  }
  const bytes = new TextEncoder().encode(candidates[0]).length;
  base.parsed_json_byte_length = Math.min(bytes, maximumPayloadBytes);
  if (bytes > maximumPayloadBytes) {
    return {
      ...base,
      validator_stage: "parseStructuredJson",
      safe_failure_code: "response_payload_too_large",
    };
  }
  let parsed: unknown;
  try {
    parsed = JSON.parse(candidates[0]);
  } catch (_) {
    return {
      ...base,
      validator_stage: "parseStructuredJson",
      safe_failure_code: "response_json_parse_failed",
    };
  }
  base.json_parse_success = true;
  if (record(parsed)) {
    base.top_level_keys = Object.keys(parsed).map(safeKey).sort().slice(0, 32);
  }
  const acc = accumulator();
  compareSchema(schemaFor(operation), parsed, "$", acc, 0);
  base.observed_types = Object.fromEntries(acc.observed);
  base.missing_required = [...acc.missing].sort().slice(0, maximumPaths);
  base.unexpected_fields = [...acc.unexpected].sort().slice(0, maximumPaths);
  base.mismatches = [...acc.mismatches.values()].slice(0, maximumPaths);
  base.array_object_counts = Object.fromEntries(acc.counts);
  const prefix = operation === "reduction"
    ? "reduction"
    : operation === "final_summary"
    ? "final_summary"
    : "page";
  if (
    base.missing_required.length > 0 || base.unexpected_fields.length > 0 ||
    base.mismatches.length > 0
  ) {
    return {
      ...base,
      validator_stage: `validate${pascal(prefix)}Schema`,
      safe_failure_code: `${prefix}_schema_failed`,
    };
  }
  const validation = operation === "reduction"
    ? validateReductionResult(
      parsed,
      request.expectedPages,
      request.allowedEquationIds ?? [],
    )
    : operation === "final_summary"
    ? validateSummarySemantics(parsed, request.pageCount)
    : validatePageBatchResult(
      parsed,
      request.expectedPages,
      request.pageCount,
    );
  const stage = semanticStage(prefix, validation.errors);
  return {
    ...base,
    validator_stage: stage,
    safe_failure_code: `${prefix}_${
      stage.endsWith("Markdown")
        ? "markdown"
        : stage.endsWith("Latex")
        ? "latex"
        : "semantics"
    }_failed`,
  };
}

function compareSchema(
  rawSchema: unknown,
  value: unknown,
  path: string,
  acc: Accumulator,
  depth: number,
) {
  if (!record(rawSchema) || depth > 8 || acc.observed.size >= maximumPaths) {
    return;
  }
  const schema = rawSchema;
  observe(path, value, acc);
  if (Array.isArray(schema.anyOf)) {
    const variants = schema.anyOf.map((variant) => {
      const candidate = accumulator();
      compareSchema(variant, value, path, candidate, depth + 1);
      return candidate;
    });
    variants.sort((a, b) => score(a) - score(b));
    merge(acc, variants[0]);
    return;
  }
  const expected = typeof schema.type === "string" ? schema.type : "any";
  const observed = jsonType(value);
  if (!typeMatches(expected, observed)) {
    mismatch(acc, {
      path,
      code: value === null ? "nullability_mismatch" : "type_mismatch",
      expected_type: expected,
      observed_type: observed,
    });
    return;
  }
  if (Array.isArray(schema.enum) && !schema.enum.includes(value)) {
    mismatch(acc, {
      path,
      code: "enum_mismatch",
      expected_type: "enum",
      observed_type: observed,
    });
  }
  if (
    typeof value === "string" && typeof schema.pattern === "string" &&
    !new RegExp(schema.pattern).test(value)
  ) {
    mismatch(acc, {
      path,
      code: "pattern_mismatch",
      expected_type: "string",
      observed_type: "string",
    });
  }
  if (typeof value === "number") {
    if (typeof schema.minimum === "number" && value < schema.minimum) {
      mismatch(acc, {
        path,
        code: "number_min",
        expected_type: expected,
        observed_type: observed,
      });
    }
    if (typeof schema.maximum === "number" && value > schema.maximum) {
      mismatch(acc, {
        path,
        code: "number_max",
        expected_type: expected,
        observed_type: observed,
      });
    }
  }
  if (Array.isArray(value)) {
    count(path, value.length, acc);
    if (typeof schema.minItems === "number" && value.length < schema.minItems) {
      mismatch(acc, {
        path,
        code: "count_min",
        expected_type: "array",
        observed_type: "array",
      });
    }
    if (typeof schema.maxItems === "number" && value.length > schema.maxItems) {
      mismatch(acc, {
        path,
        code: "count_max",
        expected_type: "array",
        observed_type: "array",
      });
    }
    for (const item of value.slice(0, 100)) {
      compareSchema(schema.items, item, `${path}[]`, acc, depth + 1);
    }
  }
  if (record(value)) {
    count(path, Object.keys(value).length, acc);
    const properties = record(schema.properties) ? schema.properties : {};
    const required = Array.isArray(schema.required)
      ? schema.required.filter((key): key is string => typeof key === "string")
      : [];
    for (const key of required) {
      if (!(key in value)) acc.missing.add(`${path}.${safeKey(key)}`);
    }
    for (const [key, child] of Object.entries(value)) {
      const safe = safeKey(key);
      if (!(key in properties)) {
        acc.unexpected.add(`${path}.${safe}`);
        observe(`${path}.${safe}`, child, acc);
        continue;
      }
      compareSchema(properties[key], child, `${path}.${safe}`, acc, depth + 1);
    }
  }
}

function structuredCandidates(response: Record<string, unknown>) {
  const candidates: string[] = [];
  if (!Array.isArray(response.output)) return candidates;
  for (const item of response.output) {
    if (!record(item) || !Array.isArray(item.content)) continue;
    for (const content of item.content) {
      if (
        record(content) && content.type === "output_text" &&
        typeof content.text === "string"
      ) candidates.push(content.text);
    }
  }
  return candidates.slice(0, 2);
}

function schemaFor(operation: StructuralDiagnosticRequest["operation"]) {
  if (operation === "reduction") return reductionResultSchema;
  if (operation === "final_summary") return structuredSummarySchema;
  return pageBatchResultSchema;
}

function providerStatus(
  value: unknown,
): StructuralFailureDiagnostic["provider_status"] {
  return [
      "queued",
      "in_progress",
      "completed",
      "incomplete",
      "failed",
      "cancelled",
    ].includes(String(value))
    ? value as StructuralFailureDiagnostic["provider_status"]
    : "unknown";
}

function semanticStage(prefix: string, errors: string[]) {
  if (errors.some((error) => error.includes("latex"))) {
    return `validate${pascal(prefix)}Latex`;
  }
  if (errors.some((error) => error.includes("markdown"))) {
    return `validate${pascal(prefix)}Markdown`;
  }
  return `validate${pascal(prefix)}Semantics`;
}

function pascal(value: string) {
  return value.split("_").map((part) =>
    part.length === 0 ? "" : part[0].toUpperCase() + part.slice(1)
  ).join("");
}

function accumulator(): Accumulator {
  return {
    observed: new Map(),
    missing: new Set(),
    unexpected: new Set(),
    mismatches: new Map(),
    counts: new Map(),
  };
}

function observe(path: string, value: unknown, acc: Accumulator) {
  if (acc.observed.size < maximumPaths && !acc.observed.has(path)) {
    acc.observed.set(path, jsonType(value));
  }
}

function count(path: string, value: number, acc: Accumulator) {
  if (acc.counts.size < maximumPaths && !acc.counts.has(path)) {
    acc.counts.set(path, Math.min(1000, value));
  }
}

function mismatch(acc: Accumulator, value: StructuralMismatch) {
  const key =
    `${value.path}:${value.code}:${value.expected_type}:${value.observed_type}`;
  if (acc.mismatches.size < maximumPaths && !acc.mismatches.has(key)) {
    acc.mismatches.set(key, value);
  }
}

function merge(target: Accumulator, source: Accumulator) {
  for (const [key, value] of source.observed) {
    if (target.observed.size < maximumPaths && !target.observed.has(key)) {
      target.observed.set(key, value);
    }
  }
  for (const value of source.missing) target.missing.add(value);
  for (const value of source.unexpected) target.unexpected.add(value);
  for (const [key, value] of source.mismatches) {
    if (target.mismatches.size < maximumPaths) {
      target.mismatches.set(key, value);
    }
  }
  for (const [key, value] of source.counts) {
    if (target.counts.size < maximumPaths && !target.counts.has(key)) {
      target.counts.set(key, value);
    }
  }
}

function score(value: Accumulator) {
  return value.missing.size + value.unexpected.size + value.mismatches.size;
}

function typeMatches(expected: string, observed: string) {
  return expected === observed ||
    expected === "number" && observed === "integer";
}

function jsonType(value: unknown) {
  if (value === null) return "null";
  if (Array.isArray(value)) return "array";
  if (typeof value === "number" && Number.isInteger(value)) return "integer";
  if (record(value)) return "object";
  return typeof value === "undefined" ? "missing" : typeof value;
}

function safeKey(value: string) {
  return safeKeyPattern.test(value) ? value : "_invalid_key";
}

function record(value: unknown): value is Record<string, unknown> {
  return typeof value === "object" && value !== null && !Array.isArray(value);
}
