import { StructuredSummary } from "./material_analysis/contracts.ts";
import {
  validateSummarySemantics,
  validateSummarySemanticsLegacyV2,
} from "./material_analysis/schemas.ts";
import {
  validateLatex,
  validateLatexLegacyV2,
  validateSafeMarkdown,
} from "./material_analysis/validators.ts";

export const studySummarySchemaVersion = 1;
export const studySummaryValidatorVersions = [
  "phase-c-validator-v2",
  "phase-c-validator-v3",
] as const;

export type CanonicalStudySource = {
  kind: "extracted_text" | "structured_summary";
  text: string;
};

type SourceRow = Record<string, unknown>;

/** Builds study input only from server-loaded, persisted authoritative data. */
export function canonicalStudySource(row: SourceRow): CanonicalStudySource {
  const content = stringValue(row.content_text);
  if (content && isEligibleManualText(row)) {
    return { kind: "extracted_text", text: content };
  }

  const summary = row.summary_payload;
  const pageCount = integerValue(row.analysis_page_count);
  const terminalAnalysis = row.analysis_status === "completed" ||
    row.analysis_status === "completed_with_warnings";
  if (terminalAnalysis) {
    if (
      !isRecord(summary) ||
      row.summary_schema_version !== studySummarySchemaVersion ||
      !studySummaryValidatorVersions.includes(
        row
          .summary_validation_version as typeof studySummaryValidatorVersions[
            number
          ],
      ) ||
      !isSha256(row.summary_validation_hash) ||
      pageCount < 1 ||
      !(row.summary_validation_version === "phase-c-validator-v2"
        ? validateSummarySemanticsLegacyV2(summary, pageCount)
        : validateSummarySemantics(summary, pageCount)).valid ||
      !safeSummaryContent(
        summary as unknown as StructuredSummary,
        row
          .summary_validation_version as typeof studySummaryValidatorVersions[
            number
          ],
      )
    ) {
      throw new StudySourceError("material_not_study_ready");
    }

    return {
      kind: "structured_summary",
      text: serializeSummary(summary as unknown as StructuredSummary),
    };
  }

  if (content && isEligibleLegacyUploadText(row)) {
    return { kind: "extracted_text", text: content };
  }

  throw new StudySourceError("material_not_study_ready");
}

export class StudySourceError extends Error {
  constructor(readonly code: string) {
    super(code);
  }
}

function safeSummaryContent(
  summary: StructuredSummary,
  validationVersion: typeof studySummaryValidatorVersions[number],
) {
  const validateEquation = validationVersion === "phase-c-validator-v2"
    ? validateLatexLegacyV2
    : validateLatex;
  return (
    !Object.hasOwn(summary, "overview_markdown") ||
    typeof summary.overview_markdown === "string" &&
      validateSafeMarkdown(summary.overview_markdown, 1_200).valid
  ) &&
    summary.sections.every((section) =>
      section.blocks.every((block) =>
        block.kind === "equation" || validateSafeMarkdown(block.markdown).valid
      )
    ) &&
    summary.key_concepts.every((concept) =>
      validateSafeMarkdown(concept.explanation_markdown).valid
    ) &&
    summary.equations.every((equation) =>
      validateEquation(equation.latex).valid &&
      (equation.explanation_markdown.length === 0 ||
        validateSafeMarkdown(equation.explanation_markdown).valid)
    ) && summary.warnings.every((warning) =>
      typeof warning.code === "string" &&
      typeof warning.detail === "string" &&
      warning.detail.length <= 2_000
    );
}

function serializeSummary(summary: StructuredSummary) {
  const equations = new Map(summary.equations.map((item) => [item.id, item]));
  const lines: string[] = [`Language: ${summary.language}`];
  for (const section of summary.sections) {
    lines.push(`Section: ${section.title}`);
    lines.push(`Source pages: ${section.source_pages.join(", ")}`);
    for (const block of section.blocks) {
      if (block.kind === "prose") {
        lines.push(block.markdown);
      } else {
        const equation = equations.get(block.equation_id);
        if (equation) {
          lines.push(
            `Equation (${equation.id}, page ${equation.source_page}): ${equation.latex}`,
          );
          if (equation.explanation_markdown) {
            lines.push(
              `Equation explanation: ${equation.explanation_markdown}`,
            );
          }
        }
      }
    }
  }
  for (const concept of summary.key_concepts) {
    lines.push(`Concept: ${concept.title}`);
    lines.push(`Source pages: ${concept.source_pages.join(", ")}`);
    lines.push(concept.explanation_markdown);
  }
  for (const warning of summary.warnings) {
    lines.push(
      `Warning ${warning.code} (pages ${
        warning.source_pages.join(", ")
      }): ${warning.detail}`,
    );
  }
  return lines.join("\n\n").trim();
}

function isEligibleManualText(row: SourceRow) {
  return row.kind === "pasted_text" && row.source_kind === "manual";
}

function isEligibleLegacyUploadText(row: SourceRow) {
  return (row.kind === "pdf" || row.kind === "image") &&
    row.source_kind === "upload" && row.processing_status === "ready";
}

function stringValue(value: unknown) {
  return typeof value === "string" ? value.trim() : "";
}

function integerValue(value: unknown) {
  return typeof value === "number" && Number.isInteger(value) ? value : 0;
}

function isSha256(value: unknown) {
  return typeof value === "string" && /^[0-9a-f]{64}$/u.test(value);
}

function isRecord(value: unknown): value is Record<string, unknown> {
  return typeof value === "object" && value !== null && !Array.isArray(value);
}
