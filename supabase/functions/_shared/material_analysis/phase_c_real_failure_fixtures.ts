import { Equation } from "./contracts.ts";

const equation = (id: string, latex: string, sourcePage: number): Equation => ({
  id,
  latex,
  explanation_markdown: "Sanitized grounded equation.",
  source_page: sourcePage,
  display: "block",
  confidence: 0.9,
  uncertainty: false,
});

const page = (
  pageNumber: number,
  equations: Equation[] = [],
  warnings: unknown[] = [],
) => ({
  page_number: pageNumber,
  content_status: "completed",
  summary_markdown: `Sanitized grounded page ${pageNumber}.`,
  key_concepts: [`Concept ${pageNumber}`],
  equations,
  confidence: 0.9,
  warnings,
  trustworthy: true,
});

export const gti6Pages11To15Raw = {
  pages: [
    page(11),
    page(
      12,
      [equation(
        "eq_page12_1",
        String.raw`A = (E_1 times S) vee (E_2 times \bar{S})`,
        12,
      )],
      [{
        code: "invalid_equation_latex",
        detail:
          "Provider-supplied warning is not accepted at the page boundary.",
        source_pages: [12],
      }],
    ),
    page(13),
    page(14),
    page(15),
  ],
};

export const gti6Pages11To15Provider = {
  pages: gti6Pages11To15Raw.pages.map((value) =>
    value.page_number === 12 ? { ...value, warnings: [] } : value
  ),
};

export const gti7Pages21To25 = {
  pages: [21, 22, 23, 24, 25].map((value) => page(value)),
};

export const gti7Pages26To30 = {
  pages: [
    page(26),
    page(27),
    page(28),
    page(
      29,
      [equation("eq_page29_1", String.raw`x_1,\dots,x_n`, 29)],
      [{
        code: "page_content_partial",
        detail:
          "The symbolic formatting is only partially recoverable from the page image.",
        source_pages: [29],
      }],
    ),
    page(30, [equation("eq_page30_1", String.raw`x\;+\;y`, 30)]),
  ],
};

export const ss24Pages6To9 = {
  pages: [
    page(6),
    page(7),
    page(8),
    page(9, [], [{
      code: "source_metadata_omitted",
      detail: "Optional source metadata was not included.",
      source_pages: [9],
    }]),
  ],
};

const serializedReductionConcept =
  "zero-output condition','boolean algebra laws','switch algebra',".repeat(10);

export const gti6FinalReductionRaw = {
  source_pages: [41, 42, 43, 44, 45, 46, 47, 48, 49, 50],
  summary_markdown: "Sanitized grounded final reduction.",
  key_concepts: [
    "Nullausgabebedingung",
    serializedReductionConcept,
    "Boolean algebra laws",
  ],
  equation_ids: ["eq_page41_1"],
  warnings: [{
    code: "source_metadata_omitted",
    detail: "Optional source metadata was not included.",
    source_pages: [41],
  }],
  confidence: 0.9,
};

export const grumciReduction = {
  source_pages: [1, 2, 3, 4],
  summary_markdown: "Sanitized grounded reduction.",
  key_concepts: ["Sanitized concept"],
  equation_ids: ["eq_page1_1"],
  warnings: [],
  confidence: 0.9,
};

export const grumciAuthoritativeEquation = equation(
  "eq_page1_1",
  String.raw`x \oplus y`,
  1,
);

export const grumciFinalSummary = {
  language: "en",
  sections: [{
    id: "section_page_1",
    title: "Sanitized section",
    blocks: [{
      kind: "prose",
      markdown: "Sanitized grounded summary.",
      display: "block",
    }],
    source_pages: [1],
    confidence: 0.9,
  }],
  key_concepts: [],
  equations: [{ ...grumciAuthoritativeEquation }],
  warnings: [],
  partial_extraction: {
    is_partial: false,
    analyzed_pages: [1, 2, 3, 4],
    partial_pages: [],
    missing_pages: [],
    page_modes: [1, 2, 3, 4].map((pageNumber) => ({
      page: pageNumber,
      mode: "visual",
    })),
  },
};
