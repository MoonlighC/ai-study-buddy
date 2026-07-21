import { validateLatex } from "./validators.ts";

export type LatexFailureCategory =
  | "unsupported_command"
  | "unsupported_environment"
  | "forbidden_delimiter"
  | "malformed_braces"
  | "forbidden_comment"
  | "forbidden_url_link_command"
  | "forbidden_package_macro_definition"
  | "unsupported_unicode_character_class"
  | "control_spacing_syntax"
  | "length_nesting_count_limit"
  | "another_bounded_enum";

export type SafeLatexDiagnostic = {
  provider_status: "completed";
  output_item_count: 1;
  output_text_candidate_count: 1;
  validator_stage: "validateFinalSummaryLatex";
  equation_index: number | null;
  validator_rule_code: string | null;
  category: LatexFailureCategory | null;
  string_length: number | null;
  unicode_code_point_count: number | null;
  maximum_nesting_depth: number | null;
  command_count: number | null;
  environment_count: number | null;
  offending_syntax: string | null;
  offending_unicode_code_point: string | null;
  equations_passing_before_failure: number;
  total_equation_count: number;
};

type EquationRecord = { latex: string };

export function diagnoseFinalSummaryLatex(
  equations: EquationRecord[],
): SafeLatexDiagnostic {
  if (equations.length > 100) throw new Error("invalid_diagnostic_input");
  for (let index = 0; index < equations.length; index++) {
    const value = equations[index]?.latex;
    if (typeof value !== "string") throw new Error("invalid_diagnostic_input");
    const validation = validateLatex(value);
    if (validation.valid) continue;
    const first = validation.errors[0] ?? "latex_length";
    const rule = classifyRule(first);
    const stats = safeStats(value);
    return {
      ...base(equations.length, index),
      equation_index: index,
      validator_rule_code: rule.code,
      category: rule.category,
      string_length: value.length,
      unicode_code_point_count: [...value].length,
      maximum_nesting_depth: stats.maximumNestingDepth,
      command_count: stats.commandCount,
      environment_count: stats.environmentCount,
      offending_syntax: rule.syntax,
      offending_unicode_code_point: first === "latex_unicode_control"
        ? firstForbiddenUnicode(value)
        : null,
    };
  }
  return {
    ...base(equations.length, equations.length),
    equation_index: null,
    validator_rule_code: null,
    category: null,
    string_length: null,
    unicode_code_point_count: null,
    maximum_nesting_depth: null,
    command_count: null,
    environment_count: null,
    offending_syntax: null,
    offending_unicode_code_point: null,
  };
}

function base(total: number, passing: number) {
  return {
    provider_status: "completed" as const,
    output_item_count: 1 as const,
    output_text_candidate_count: 1 as const,
    validator_stage: "validateFinalSummaryLatex" as const,
    equations_passing_before_failure: passing,
    total_equation_count: total,
  };
}

function classifyRule(error: string): {
  code: string;
  category: LatexFailureCategory;
  syntax: string | null;
} {
  if (error.startsWith("latex_command:")) {
    const command = safeSyntax(error.slice("latex_command:".length));
    const category = command && urlCommands.has(command)
      ? "forbidden_url_link_command"
      : command && macroCommands.has(command)
      ? "forbidden_package_macro_definition"
      : "unsupported_command";
    return { code: "latex_command_unsupported", category, syntax: command };
  }
  if (error.startsWith("latex_environment:")) {
    const environment = safeSyntax(error.slice("latex_environment:".length));
    return {
      code: "latex_environment_unsupported",
      category: "unsupported_environment",
      syntax: environment ? `begin:${environment}` : null,
    };
  }
  return {
    code: fixedCodes.has(error) ? error : "latex_control_symbol",
    category: categoryFor(error),
    syntax: null,
  };
}

const fixedCodes = new Set([
  "latex_length",
  "latex_dollar_delimiter",
  "latex_comments_forbidden",
  "latex_unicode_control",
  "latex_unbalanced_groups",
  "latex_dangling_escape",
  "latex_control_space",
  "latex_row_outside_environment",
  "latex_control_symbol",
  "latex_environment_syntax",
  "latex_environment_balance",
  "latex_matrix_size",
  "latex_nesting_depth",
]);
const urlCommands = new Set(["href", "url", "includegraphics"]);
const macroCommands = new Set([
  "newcommand",
  "renewcommand",
  "def",
  "usepackage",
  "require",
  "input",
  "include",
  "write",
  "csname",
]);

function categoryFor(error: string): LatexFailureCategory {
  if (error === "latex_dollar_delimiter") return "forbidden_delimiter";
  if (error === "latex_comments_forbidden") return "forbidden_comment";
  if (error === "latex_unicode_control") {
    return "unsupported_unicode_character_class";
  }
  if (error === "latex_unbalanced_groups") return "malformed_braces";
  if (error === "latex_control_space") return "control_spacing_syntax";
  if (
    ["latex_length", "latex_nesting_depth", "latex_matrix_size"].includes(error)
  ) {
    return "length_nesting_count_limit";
  }
  if (
    ["latex_environment_syntax", "latex_environment_balance"].includes(error)
  ) {
    return "unsupported_environment";
  }
  return "another_bounded_enum";
}

function safeSyntax(value: string) {
  return /^[A-Za-z]{1,32}$/.test(value) ? value : null;
}

function safeStats(value: string) {
  let depth = 0;
  let maximumNestingDepth = 0;
  let commandCount = 0;
  let environmentCount = 0;
  for (let index = 0; index < value.length; index++) {
    if (value[index] === "{") {
      depth++;
      maximumNestingDepth = Math.max(maximumNestingDepth, depth);
    } else if (value[index] === "}") {
      depth = Math.max(0, depth - 1);
    } else if (
      value[index] === "\\" && /[A-Za-z]/.test(value[index + 1] ?? "")
    ) {
      commandCount++;
      let end = index + 1;
      while (/[A-Za-z]/.test(value[end] ?? "")) end++;
      if (value.slice(index + 1, end) === "begin") environmentCount++;
      index = end - 1;
    }
  }
  return { maximumNestingDepth, commandCount, environmentCount };
}

function firstForbiddenUnicode(value: string) {
  for (const character of value) {
    const point = character.codePointAt(0)!;
    if (
      (point >= 0x202a && point <= 0x202e) ||
      (point >= 0x2066 && point <= 0x2069) ||
      [0xfeff, 0xff3c, 0x2216, 0x29f5, 0xfe68].includes(point)
    ) {
      return `U+${point.toString(16).toUpperCase().padStart(4, "0")}`;
    }
  }
  return null;
}
