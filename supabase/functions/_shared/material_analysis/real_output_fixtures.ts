// Sanitized, fixed regressions derived from the five real provider outputs in
// the 2026-07-23 diagnostic bundle. Only model-output content is retained.

export type RealOutputFixture = {
  name: string;
  category:
    | "valid_positive"
    | "valid_partial"
    | "invalid_code_in_equation"
    | "invalid_dollar_math"
    | "valid_completed_with_metadata_omission";
  operation: "page" | "reduction";
  expectedValid: boolean;
  expectedCode?: string;
  expectedPages: number[];
  allowedEquationIds?: string[];
  payload: unknown;
};

const equation = (id: string, latex: string, sourcePage: number) => ({
  id,
  latex,
  explanation_markdown: "Grounded expression from the page.",
  source_page: sourcePage,
  display: "block",
  confidence: 0.98,
  uncertainty: false,
});

export const realOutputFixtures: RealOutputFixture[] = [
  {
    name: "output_1_grounded_uncertain_pages",
    category: "valid_partial",
    operation: "page",
    expectedValid: true,
    expectedPages: [1, 2],
    payload: {
      pages: [
        {
          page_number: 1,
          content_status: "completed",
          summary_markdown:
            "The page contains grounded sampling and audio-size tasks.",
          key_concepts: ["Sampling frequency", "Audio file size"],
          equations: [equation("eq_1_page1", "f_{s} \\ge 2 \\cdot f_{max}", 1)],
          confidence: 0.95,
          warnings: [],
          trustworthy: true,
        },
        {
          page_number: 2,
          content_status: "partial",
          summary_markdown:
            "The grounded portion asks about the PCM processing order.",
          key_concepts: ["PCM processing chain", "Quantization"],
          equations: [],
          confidence: 0.72,
          warnings: [{
            code: "page_content_partial",
            detail:
              "Some terminology could not be extracted confidently; only grounded content is included.",
            source_pages: [2],
          }],
          trustworthy: true,
        },
      ],
    },
  },
  {
    name: "output_2_programming_source_in_equations",
    category: "invalid_code_in_equation",
    operation: "page",
    expectedValid: false,
    expectedCode: "page_equation_non_mathematical",
    expectedPages: [11],
    payload: {
      pages: [{
        page_number: 11,
        content_status: "completed",
        summary_markdown:
          "The page explains statements, variables, assignment, and string interpolation.",
        key_concepts: ["Statements", "Variables", "String interpolation"],
        equations: [
          equation("eq_11_1", "print (1234); print (3.14589);", 11),
          equation("eq_11_2", "int i; String s;", 11),
        ],
        confidence: 0.97,
        warnings: [],
        trustworthy: true,
      }],
    },
  },
  {
    name: "output_3_grounded_image_text_partial",
    category: "valid_partial",
    operation: "page",
    expectedValid: true,
    expectedPages: [9],
    payload: {
      pages: [{
        page_number: 9,
        content_status: "partial",
        summary_markdown:
          "The readable content shows a source-code to bytecode execution flow.",
        key_concepts: ["Source code", "Bytecode", "Execution"],
        equations: [],
        confidence: 0.9,
        warnings: [{
          code: "page_content_partial",
          detail:
            "Embedded bytecode and diagram text was only partly legible; the included claims remain grounded.",
          source_pages: [9],
        }],
        trustworthy: true,
      }],
    },
  },
  {
    name: "output_4_completed_metadata_omitted",
    category: "valid_completed_with_metadata_omission",
    operation: "page",
    expectedValid: true,
    expectedPages: [4],
    payload: {
      pages: [{
        page_number: 4,
        content_status: "completed",
        summary_markdown:
          "The page compares editor, command-line, IDE, and browser-based development workflows.",
        key_concepts: ["Editor", "Command line", "IDE", "Development workflow"],
        equations: [],
        confidence: 0.95,
        warnings: [{
          code: "source_metadata_omitted",
          detail:
            "A visible URL was intentionally omitted from the study content.",
          source_pages: [4],
        }],
        trustworthy: true,
      }],
    },
  },
  {
    name: "output_5_reduction_with_dollar_math",
    category: "invalid_dollar_math",
    operation: "reduction",
    expectedValid: false,
    expectedCode: "reduction_markdown_dollar_math",
    expectedPages: [1, 2],
    allowedEquationIds: ["eq_p1_1", "eq_p2_1"],
    payload: {
      source_pages: [1, 2],
      summary_markdown:
        "## Source page 1\nThe charge is $Q(t1)=0.5\\,\\mu As$.\n\n## Source page 2\nThe voltage is $u_c(t1)=1\\,V$.",
      key_concepts: ["Charge", "Voltage"],
      equation_ids: ["eq_p1_1", "eq_p2_1"],
      warnings: [],
      confidence: 0.97,
    },
  },
];
