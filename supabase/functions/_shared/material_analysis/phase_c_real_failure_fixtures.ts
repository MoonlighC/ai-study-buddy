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

const untrustworthyMissingPage = (pageNumber: number) => ({
  page_number: pageNumber,
  content_status: "missing",
  summary_markdown: "",
  key_concepts: [],
  equations: [],
  confidence: 0,
  warnings: [{
    code: "page_content_missing",
    detail: "No usable grounded content was provided for this page.",
    source_pages: [pageNumber],
  }],
  trustworthy: false,
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

export const ss24Pages1To5MissingUntrustworthy = {
  pages: [
    page(1),
    page(2),
    page(3),
    page(4),
    untrustworthyMissingPage(5),
  ],
};

export const ss24Pages6To10MissingUntrustworthy = {
  pages: [
    page(6),
    page(7),
    page(8),
    page(9),
    untrustworthyMissingPage(10),
  ],
};

export const ss24Pages11To13WithStray10 = {
  pages: [
    page(11),
    page(12),
    {
      page_number: 10,
      content_status: "partial",
      summary_markdown: "Sanitized grounded page 10 content.",
      key_concepts: ["Stray page 10 concept"],
      equations: [],
      confidence: 0.9,
      warnings: [{
        code: "page_content_partial",
        detail: "Only part of page 10 was recoverable.",
        source_pages: [10],
      }],
      trustworthy: true,
    },
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

// Sanitized structural reproduction of the rejected gti9 global reduction.
// Counts and delimiter shape match the observed failure; document prose,
// identifiers, and provider metadata are not retained.
const gti9SerializedSeed =
  "capture register','parallel loading','asynchronous reset','";
const gti9SerializedConcept = [
  ...(
    gti9SerializedSeed +
    "serialized item','".repeat(120)
  ),
].slice(0, 1900).join("");

export const gti9AuthoritativeEquationIds = Array.from(
  { length: 53 },
  (_, index) => `eq_sanitized_${index + 1}`,
);

export const gti9GlobalReductionRaw = {
  source_pages: Array.from({ length: 55 }, (_, index) => index + 1),
  summary_markdown:
    "Sanitized global lecture reduction covering all authoritative pages.",
  key_concepts: [
    "Finite-state machines",
    gti9SerializedConcept,
    "Mealy and Moore automata",
    ...Array.from(
      { length: 97 },
      (_, index) => `Sanitized concept ${index + 1}`,
    ),
  ],
  equation_ids: gti9AuthoritativeEquationIds,
  warnings: Array.from({ length: 8 }, (_, index) => ({
    code: "source_metadata_omitted",
    detail: "Optional source metadata was omitted.",
    source_pages: [index + 1],
  })),
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
  overview_markdown:
    "A compact overview of the validated material.\n\nIt connects the main grounded themes without page-by-page narration.",
  topic_titles: ["Foundations", "Core relationships", "Applications"],
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
