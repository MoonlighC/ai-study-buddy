import { Equation, PageAnalysisResult } from "./contracts.ts";
import {
  providerPageWarningCodes,
  validateDownstreamPageBatchResult,
  validatePageBatchStructure,
  validatePageResult,
} from "./schemas.ts";
import { canonicalizeLatex, validateLatex } from "./validators.ts";

export type PageBatchCanonicalizationComparison = {
  expectedPageCount: number;
  returnedPageCount: number;
  normalizedMissingTrustworthyCount: number;
  discardedStrayPageCount: number;
  synthesizedMissingPageCount: number;
  missingPageNumbersCount: number;
};

export function canonicalizePageBatchResult(
  result: unknown,
  expectedPages: number[],
  pageCount: number,
): {
  valid: boolean;
  result: unknown;
  degradedEquationIds: string[];
  comparison: PageBatchCanonicalizationComparison;
  providerWarningViolation: {
    pageIndex: number;
    warningIndex: number;
    code: string;
  } | null;
} {
  const comparison = {
    expectedPageCount: expectedPages.length,
    returnedPageCount: isRecord(result) && Array.isArray(result.pages)
      ? result.pages.length
      : 0,
    normalizedMissingTrustworthyCount: 0,
    discardedStrayPageCount: 0,
    synthesizedMissingPageCount: 0,
    missingPageNumbersCount: 0,
  };
  if (!isRecord(result) || !Array.isArray(result.pages)) {
    return {
      valid: false,
      result,
      degradedEquationIds: [],
      comparison,
      providerWarningViolation: null,
    };
  }
  if (
    result.pages.length > expectedPages.length ||
    !validatePageBatchStructure(result, result.pages.length).valid
  ) {
    return {
      valid: false,
      result,
      degradedEquationIds: [],
      comparison,
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
      providerWarningViolation = {
        pageIndex,
        warningIndex,
        code: warning.code,
      };
      return true;
    })
  );
  if (providerWarningViolation) {
    return {
      valid: false,
      result,
      degradedEquationIds: [],
      comparison,
      providerWarningViolation,
    };
  }
  const returnedPageNumbers = (result.pages as PageAnalysisResult[]).map(
    (page) => page.page_number,
  );
  const returnedPageSet = new Set(returnedPageNumbers);
  const expectedPageSet = new Set(expectedPages);
  if (returnedPageSet.size !== returnedPageNumbers.length) {
    return {
      valid: false,
      result,
      degradedEquationIds: [],
      comparison,
      providerWarningViolation: null,
    };
  }
  const normalizedPages = (result.pages as PageAnalysisResult[]).map((page) => {
    if (
      !expectedPageSet.has(page.page_number) ||
      !canNormalizeMissingTrustworthy(page, pageCount)
    ) {
      return page;
    }
    comparison.normalizedMissingTrustworthyCount++;
    return { ...page, trustworthy: true };
  });
  const missingExpectedPages = expectedPages.filter((page) =>
    !returnedPageSet.has(page)
  );
  const strayPages = normalizedPages.filter((page) =>
    !expectedPageSet.has(page.page_number)
  );
  let retainedPages = normalizedPages;
  if (strayPages.length > 0) {
    if (
      strayPages.length !== 1 ||
      missingExpectedPages.length !== 1 ||
      !validatePageResult(
        strayPages[0],
        strayPages[0].page_number,
        pageCount,
      ).valid ||
      !hasSelfConsistentStrayProvenance(strayPages[0], expectedPageSet)
    ) {
      return {
        valid: false,
        result,
        degradedEquationIds: [],
        comparison,
        providerWarningViolation: null,
      };
    }
    retainedPages = normalizedPages.filter((page) =>
      expectedPageSet.has(page.page_number)
    );
    comparison.discardedStrayPageCount = 1;
  }
  const retainedPageNumbers = retainedPages.map((page) => page.page_number);
  const retainedPageSet = new Set(retainedPageNumbers);
  const expectedReturnedOrder = expectedPages.filter((page) =>
    retainedPageSet.has(page)
  );
  if (
    expectedReturnedOrder.some((page, index) =>
      page !== retainedPageNumbers[index]
    )
  ) {
    return {
      valid: false,
      result,
      degradedEquationIds: [],
      comparison,
      providerWarningViolation: null,
    };
  }
  const degradedEquationIds: string[] = [];
  const returnedPages = new Map(
    retainedPages.map((page) => {
      const equations: Equation[] = [];
      for (const equation of page.equations) {
        const canonicalLatex = canonicalizeLatex(equation.latex);
        if (validateLatex(canonicalLatex).valid) {
          equations.push({ ...equation, latex: canonicalLatex });
        } else {
          degradedEquationIds.push(equation.id);
        }
      }
      const equationDegraded = equations.length !== page.equations.length;
      const warnings = [...page.warnings];
      if (equationDegraded) {
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
        if (
          !warnings.some((warning) => warning.code === "page_content_partial")
        ) {
          warnings.push({
            code: "page_content_partial",
            detail:
              "Grounded page content is preserved, but an unsafe equation was omitted.",
            source_pages: [page.page_number],
          });
        }
      }
      const partialWarning = warnings.some((warning) =>
        warning.code === "page_content_partial" ||
        warning.code === "invalid_equation_latex"
      );
      return {
        ...page,
        content_status: page.content_status === "completed" && partialWarning
          ? "partial" as const
          : page.content_status,
        equations,
        confidence: equationDegraded
          ? Math.min(page.confidence, 0.5)
          : page.confidence,
        warnings,
      };
    }).map((page) => [page.page_number, page]),
  );
  const missingPages = expectedPages.filter((page) => !returnedPages.has(page));
  comparison.synthesizedMissingPageCount = missingPages.length;
  comparison.missingPageNumbersCount = missingPages.length;
  const pages = expectedPages.map((pageNumber) =>
    returnedPages.get(pageNumber) ?? syntheticMissingPage(pageNumber)
  );
  const canonical = { pages };
  return {
    valid: validateDownstreamPageBatchResult(
      canonical,
      expectedPages,
      pageCount,
    ).valid,
    result: canonical,
    degradedEquationIds,
    comparison,
    providerWarningViolation,
  };
}

function syntheticMissingPage(pageNumber: number): PageAnalysisResult {
  return {
    page_number: pageNumber,
    content_status: "missing",
    summary_markdown: "",
    key_concepts: [],
    equations: [],
    confidence: 0,
    warnings: [{
      code: "page_missing",
      detail: "This page could not be analyzed.",
      source_pages: [pageNumber],
    }, {
      code: "page_content_missing",
      detail: "No usable grounded content was available.",
      source_pages: [pageNumber],
    }],
    trustworthy: true,
  };
}

function canNormalizeMissingTrustworthy(
  page: PageAnalysisResult,
  pageCount: number,
): boolean {
  if (
    page.content_status !== "missing" ||
    page.summary_markdown !== "" ||
    page.key_concepts.length !== 0 ||
    page.equations.length !== 0 ||
    page.confidence !== 0 ||
    page.trustworthy !== false ||
    !page.warnings.some((warning) => warning.code === "page_content_missing") ||
    page.warnings.some((warning) =>
      !providerPageWarningCodes.includes(
        warning.code as typeof providerPageWarningCodes[number],
      ) ||
      warning.source_pages.length === 0 ||
      warning.source_pages.some((sourcePage) => sourcePage !== page.page_number)
    )
  ) {
    return false;
  }
  return validatePageResult(
    { ...page, trustworthy: true },
    page.page_number,
    pageCount,
  ).valid;
}

function hasSelfConsistentStrayProvenance(
  page: PageAnalysisResult,
  expectedPageSet: Set<number>,
): boolean {
  const warningPages = page.warnings.flatMap((warning) => warning.source_pages);
  const equationPages = page.equations.map((equation) => equation.source_page);
  return warningPages.every((sourcePage) =>
    sourcePage === page.page_number && !expectedPageSet.has(sourcePage)
  ) &&
    equationPages.every((sourcePage) =>
      sourcePage === page.page_number && !expectedPageSet.has(sourcePage)
    );
}

function isRecord(value: unknown): value is Record<string, unknown> {
  return typeof value === "object" && value !== null && !Array.isArray(value);
}
