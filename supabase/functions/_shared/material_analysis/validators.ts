import { unified } from "unified";
import remarkParse from "remark-parse";
import { Equation, SafeWarning } from "./contracts.ts";

export interface ValidationResult {
  valid: boolean;
  errors: string[];
}

const markdownParser = unified().use(remarkParse);
const allowedMarkdownNodes = new Set([
  "root",
  "paragraph",
  "text",
  "heading",
  "emphasis",
  "strong",
  "delete",
  "blockquote",
  "list",
  "listItem",
  "code",
  "inlineCode",
  "break",
  "thematicBreak",
]);
const forbiddenMarkdownNodes = new Set([
  "link",
  "linkReference",
  "image",
  "imageReference",
  "definition",
  "html",
]);
const activeTextPattern = /(?:https?:\/\/|mailto:|www\.)\S*/iu;

export function validateSafeMarkdown(
  value: string,
  maxLength = 6_000,
): ValidationResult {
  const errors: string[] = [];
  if (typeof value !== "string" || !value || value.length > maxLength) {
    errors.push("markdown_length");
  }
  if (typeof value !== "string") return result(errors);
  if (/\$\$[\s\S]*?\$\$|(^|[^\\])\$[^\n$]+\$/u.test(value)) {
    errors.push("markdown_latex_delimiter");
  }
  let tree: MarkdownNode;
  try {
    tree = markdownParser.parse(value) as MarkdownNode;
  } catch {
    return result([...errors, "markdown_parse"]);
  }
  walkMarkdown(tree, errors);
  return result(errors);
}

interface MarkdownNode {
  type?: string;
  value?: string;
  children?: MarkdownNode[];
}

function walkMarkdown(node: MarkdownNode, errors: string[]) {
  const type = node.type ?? "";
  if (forbiddenMarkdownNodes.has(type)) errors.push(`markdown_node:${type}`);
  if (!allowedMarkdownNodes.has(type) && !forbiddenMarkdownNodes.has(type)) {
    errors.push(`markdown_node:${type || "unknown"}`);
  }
  if (
    (type === "text" || type === "code" || type === "inlineCode") &&
    activeTextPattern.test(node.value ?? "")
  ) {
    errors.push("markdown_active_text");
  }
  for (const child of node.children ?? []) walkMarkdown(child, errors);
}

const allowedCommands = new Set([
  "frac",
  "sqrt",
  "sum",
  "prod",
  "int",
  "iint",
  "iiint",
  "lim",
  "infty",
  "partial",
  "nabla",
  "cdot",
  "times",
  "div",
  "pm",
  "mp",
  "le",
  "ge",
  "ne",
  "approx",
  "equiv",
  "to",
  "rightarrow",
  "leftarrow",
  "leftrightarrow",
  "vec",
  "hat",
  "bar",
  "overline",
  "underline",
  "mathrm",
  "mathbf",
  "mathit",
  "mathbb",
  "mathcal",
  "text",
  "sin",
  "cos",
  "tan",
  "log",
  "ln",
  "exp",
  "min",
  "max",
  "det",
  "left",
  "right",
  "quad",
  "qquad",
  "ldots",
  "cdots",
  "alpha",
  "beta",
  "gamma",
  "delta",
  "epsilon",
  "varepsilon",
  "zeta",
  "eta",
  "theta",
  "vartheta",
  "iota",
  "kappa",
  "lambda",
  "mu",
  "nu",
  "xi",
  "pi",
  "rho",
  "sigma",
  "tau",
  "upsilon",
  "phi",
  "varphi",
  "chi",
  "psi",
  "omega",
  "Gamma",
  "Delta",
  "Theta",
  "Lambda",
  "Xi",
  "Pi",
  "Sigma",
  "Upsilon",
  "Phi",
  "Psi",
  "Omega",
]);
const allowedEnvironments = new Set([
  "matrix",
  "pmatrix",
  "bmatrix",
  "cases",
  "aligned",
]);
const matrixEnvironments = new Set(allowedEnvironments);
const forbiddenUnicodeControls =
  /[\u202A-\u202E\u2066-\u2069\uFEFF\uFF3C\u2216\u29F5\uFE68]/u;

interface EnvironmentFrame {
  name: string;
  rows: number;
  columns: number;
  maxColumns: number;
}

/**
 * Validates a deliberately narrow KaTeX/flutter_math_fork-compatible subset.
 * Comments, command aliases, dynamic primitives, Unicode slash lookalikes,
 * and control-space forms are rejected instead of normalized.
 */
export function validateLatex(value: string): ValidationResult {
  const errors: string[] = [];
  if (
    typeof value !== "string" || value.trim().length === 0 ||
    value.length > 512
  ) {
    errors.push("latex_length");
  }
  if (typeof value !== "string") return result(errors);
  if (value.includes("$")) errors.push("latex_dollar_delimiter");
  if (value.includes("%")) errors.push("latex_comments_forbidden");
  if (forbiddenUnicodeControls.test(value)) {
    errors.push("latex_unicode_control");
  }

  let groupDepth = 0;
  let maxGroupDepth = 0;
  const environments: EnvironmentFrame[] = [];
  for (let index = 0; index < value.length; index++) {
    const character = value[index];
    if (character === "{") {
      groupDepth++;
      maxGroupDepth = Math.max(maxGroupDepth, groupDepth);
      continue;
    }
    if (character === "}") {
      groupDepth--;
      if (groupDepth < 0) errors.push("latex_unbalanced_groups");
      continue;
    }
    if (character === "&" && environments.length > 0) {
      const frame = environments.at(-1)!;
      frame.columns++;
      frame.maxColumns = Math.max(frame.maxColumns, frame.columns);
      continue;
    }
    if (character !== "\\") continue;
    const next = value[index + 1];
    if (next === undefined) {
      errors.push("latex_dangling_escape");
      continue;
    }
    if (/\s/u.test(next)) {
      errors.push("latex_control_space");
      continue;
    }
    if (next === "\\") {
      if (environments.length === 0) {
        errors.push("latex_row_outside_environment");
      } else {
        const frame = environments.at(-1)!;
        frame.rows++;
        frame.columns = 1;
      }
      index++;
      continue;
    }
    if (!/[A-Za-z]/u.test(next)) {
      if (!"{}_#&,^".includes(next)) errors.push("latex_control_symbol");
      index++;
      continue;
    }
    let end = index + 1;
    while (end < value.length && /[A-Za-z]/u.test(value[end])) end++;
    const command = value.slice(index + 1, end);
    index = end - 1;
    if (command === "begin" || command === "end") {
      const parsed = parseEnvironmentName(value, end);
      if (!parsed) {
        errors.push("latex_environment_syntax");
        continue;
      }
      index = parsed.end - 1;
      if (!allowedEnvironments.has(parsed.name)) {
        errors.push(`latex_environment:${parsed.name}`);
      }
      if (command === "begin") {
        environments.push({
          name: parsed.name,
          rows: 1,
          columns: 1,
          maxColumns: 1,
        });
      } else {
        const frame = environments.pop();
        if (!frame || frame.name !== parsed.name) {
          errors.push("latex_environment_balance");
        } else if (
          matrixEnvironments.has(frame.name) &&
          (frame.rows > 12 || frame.maxColumns > 12)
        ) {
          errors.push("latex_matrix_size");
        }
      }
      continue;
    }
    if (!allowedCommands.has(command)) errors.push(`latex_command:${command}`);
  }
  if (groupDepth !== 0) errors.push("latex_unbalanced_groups");
  if (maxGroupDepth > 16) errors.push("latex_nesting_depth");
  if (environments.length > 0) errors.push("latex_environment_balance");
  return result(errors);
}

function parseEnvironmentName(
  value: string,
  start: number,
): { name: string; end: number } | null {
  let index = start;
  while (index < value.length && /[ \t\r\n]/u.test(value[index])) index++;
  if (value[index] !== "{") return null;
  const close = value.indexOf("}", index + 1);
  if (close < 0) return null;
  const name = value.slice(index + 1, close);
  if (!/^[A-Za-z]+$/u.test(name)) return null;
  return { name, end: close + 1 };
}

export function safeEquationFallback(
  equation: Equation,
): { equation: Equation; warning: SafeWarning | null } {
  const validation = validateLatex(equation.latex);
  if (validation.valid) return { equation, warning: null };
  const plain = equation.latex.replaceAll("\\", "\\\\").replaceAll("{", "\\{")
    .replaceAll("}", "\\}");
  return {
    equation: {
      ...equation,
      latex: plain,
      uncertainty: true,
      confidence: Math.min(equation.confidence, 0.25),
    },
    warning: {
      code: "invalid_equation_latex",
      detail:
        "An equation could not be rendered safely and is shown as plain text.",
      source_pages: [equation.source_page],
    },
  };
}

function result(errors: string[]): ValidationResult {
  return { valid: errors.length === 0, errors: [...new Set(errors)] };
}
