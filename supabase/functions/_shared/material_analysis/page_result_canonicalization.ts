import { Equation, PageAnalysisResult } from "./contracts.ts";
import {
  providerPageWarningCodes,
  validateDownstreamPageBatchResult,
  validatePageBatchStructure,
} from "./schemas.ts";
import { canonicalizeLatex, validateLatex } from "./validators.ts";

export function canonicalizePageBatchResult(
  result: unknown,
  expectedPages: number[],
  pageCount: number,
): {
  valid: boolean;
  result: unknown;
  degradedEquationIds: string[];
  providerWarningViolation: {
    pageIndex: number;
    warningIndex: number;
    code: string;
  } | null;
} {
  if (!isRecord(result) || !Array.isArray(result.pages)) {
    return {
      valid: false,
      result,
      degradedEquationIds: [],
      providerWarningViolation: null,
    };
  }
  if (!validatePageBatchStructure(result, expectedPages.length).valid) {
    return {
      valid: false,
      result,
      degradedEquationIds: [],
      providerWarningViolation: null,
    };
  }
  let providerWarningViolation: {
    pageIndex: number;
    warningIndex: number;
    code: string;
  } | null = null;
  (result.pages as PageAnalysisResult[]).some((page, pageIndex) =>
    page.warnings.some((warning, warningIndex) => {
      if (
        providerPageWarningCodes.includes(
          warning.code as typeof providerPageWarningCodes[number],
        )
      ) return false;
      providerWarningViolation = { pageIndex, warningIndex, code: warning.code };
      return true;
    })
  );
  const degradedEquationIds: string[] = [];
  const pages = (result.pages as PageAnalysisResult[]).map((page) => {
    const equations: Equation[] = [];
    for (const equation of page.equations) {
      const canonicalLatex = canonicalizeLatex(equation.latex);
      if (validateLatex(canonicalLatex).valid) {
        equations.push({ ...equation, latex: canonicalLatex });
      } else {
        degradedEquationIds.push(equation.id);
      }
    }
    if (equations.length === page.equations.length) {
      return { ...page, equations };
    }
    const warnings = [...page.warnings];
    if (
      !warnings.some((warning) => warning.code === "invalid_equation_latex")
    ) {
      warnings.push({
        code: "invalid_equation_latex",
        detail:
          "An equation was omitted because it could not be rendered safely.",
        source_pages: [page.page_number],
      });
    }
    if (!warnings.some((warning) => warning.code === "page_content_partial")) {
      warnings.push({
        code: "page_content_partial",
        detail:
          "Grounded page content is preserved, but an unsafe equation was omitted.",
        source_pages: [page.page_number],
      });
    }
    return {
      ...page,
      content_status: "partial" as const,
      equations,
      confidence: Math.min(page.confidence, 0.5),
      warnings,
    };
  });
  const canonical = { pages };
  return {
    valid: !providerWarningViolation &&
      validateDownstreamPageBatchResult(
        canonical,
        expectedPages,
        pageCount,
    ).valid,
    result: canonical,
    degradedEquationIds,
    providerWarningViolation,
  };
}

function isRecord(value: unknown): value is Record<string, unknown> {
  return typeof value === "object" && value !== null && !Array.isArray(value);
}
