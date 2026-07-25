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
    type === "text" &&
    /\$\$[\s\S]*?\$\$|(^|[^\\])\$[^\n$]+\$/u.test(node.value ?? "")
  ) {
    errors.push("markdown_latex_delimiter");
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
  "vee",
  "wedge",
  "land",
  "lor",
  "neg",
  "oplus",
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

const safeWordOperators: Readonly<Record<string, string>> = {
  times: "\\times",
  vee: "\\vee",
  wedge: "\\wedge",
};

/**
 * Canonicalizes only the narrow provider spellings proven safe by real output.
 * Protected text groups remain byte-for-byte unchanged and no unknown command
 * or malformed structure is repaired.
 */
export function canonicalizeLatex(value: string): string {
  if (typeof value !== "string") return value;
  const lexical = latexLexicalProtection(value);
  if (lexical.malformedProtectedGroup) return value;
  const skipWordOperators = hasUrl(value) || programmingLike(value);
  let output = "";
  let index = 0;
  while (index < value.length) {
    const character = value[index];
    if (character === "\\") {
      const next = value[index + 1];
      if (next === undefined) {
        output += character;
        index++;
        continue;
      }
      if (",:;!".includes(next)) {
        output += lexical.protected[index] ? value.slice(index, index + 2) : " ";
        index += 2;
        continue;
      }
      if (/[A-Za-z]/u.test(next)) {
        let end = index + 1;
        while (end < value.length && /[A-Za-z]/u.test(value[end])) end++;
        const command = value.slice(index + 1, end);
        if (!lexical.protected[index] && command === "dots") {
          output += "\\ldots";
        } else {
          output += value.slice(index, end);
        }
        index = end;
        continue;
      }
      output += value.slice(index, index + 2);
      index += 2;
      continue;
    }
    if (!lexical.protected[index] && /[A-Za-z]/u.test(character)) {
      let end = index + 1;
      while (end < value.length && /[A-Za-z]/u.test(value[end])) end++;
      const word = value.slice(index, end);
      output += !skipWordOperators && safeWordOperators[word] &&
          hasMathematicalAtomsOnBothSides(value, index, end, lexical.protected)
        ? safeWordOperators[word]
        : word;
      index = end;
      continue;
    }
    output += character;
    index++;
  }
  return output;
}

type LatexLexicalProtection = {
  protected: boolean[];
  malformedProtectedGroup: boolean;
};

function latexLexicalProtection(value: string): LatexLexicalProtection {
  const protectedCharacters = Array<boolean>(value.length).fill(false);
  const groupProtection: boolean[] = [];
  let protectedDepth = 0;
  let pendingProtected = false;
  let malformedProtectedGroup = false;
  for (let index = 0; index < value.length; index++) {
    protectedCharacters[index] = protectedDepth > 0;
    const character = value[index];
    if (character === "\\") {
      let end = index + 1;
      if (end < value.length && /[A-Za-z]/u.test(value[end])) {
        while (end < value.length && /[A-Za-z]/u.test(value[end])) end++;
        const command = value.slice(index + 1, end);
        for (let mark = index; mark < end; mark++) {
          protectedCharacters[mark] = protectedDepth > 0;
        }
        if (
          protectedDepth === 0 &&
          (command === "text" || command === "mathrm")
        ) {
          let open = end;
          while (open < value.length && /[ \t\r\n]/u.test(value[open])) open++;
          if (value[open] === "{") {
            pendingProtected = true;
          } else {
            malformedProtectedGroup = true;
          }
        }
        index = end - 1;
        continue;
      }
      if (end < value.length) {
        protectedCharacters[end] = protectedDepth > 0;
        index = end;
      }
      continue;
    }
    if (character === "{") {
      const protects = protectedDepth > 0 || pendingProtected;
      groupProtection.push(protects);
      if (protects) protectedDepth++;
      pendingProtected = false;
      protectedCharacters[index] = protects;
      continue;
    }
    if (character === "}") {
      const protects = groupProtection.pop();
      if (protects === undefined) {
        pendingProtected = false;
        continue;
      }
      protectedCharacters[index] = protectedDepth > 0;
      if (protects) protectedDepth--;
      pendingProtected = false;
      continue;
    }
    if (pendingProtected && !/[ \t\r\n]/u.test(character)) {
      malformedProtectedGroup = true;
      pendingProtected = false;
    }
  }
  if (pendingProtected || protectedDepth > 0) malformedProtectedGroup = true;
  return {
    protected: protectedCharacters,
    malformedProtectedGroup,
  };
}

function hasMathematicalAtomsOnBothSides(
  value: string,
  start: number,
  end: number,
  protectedCharacters: boolean[],
) {
  let left = start - 1;
  while (left >= 0 && /\s/u.test(value[left])) left--;
  let right = end;
  while (right < value.length && /\s/u.test(value[right])) right++;
  return recognizedLeftAtom(value, left, protectedCharacters) &&
    recognizedRightAtom(value, right, protectedCharacters);
}

function recognizedLeftAtom(
  value: string,
  index: number,
  protectedCharacters: boolean[],
) {
  if (index < 0 || protectedCharacters[index]) return false;
  if (/[0-9)\]}]/u.test(value[index])) return true;
  if (!/[A-Za-z]/u.test(value[index])) return false;
  let start = index;
  while (start > 0 && /[A-Za-z]/u.test(value[start - 1])) start--;
  return index - start === 0;
}

function recognizedRightAtom(
  value: string,
  index: number,
  protectedCharacters: boolean[],
) {
  if (index >= value.length || protectedCharacters[index]) return false;
  if (/[0-9([{]/u.test(value[index]) || value[index] === "\\") return true;
  if (!/[A-Za-z]/u.test(value[index])) return false;
  let end = index + 1;
  while (end < value.length && /[A-Za-z]/u.test(value[end])) end++;
  return end - index === 1;
}

function hasUrl(value: string) {
  return /(?:https?:\/\/|www\.|[A-Za-z0-9-]+\.(?:com|org|net|io)(?:\/|$))/iu
    .test(value);
}

function programmingLike(value: string) {
  const withoutLatexSpacing = value.replace(/\\[,;:!]/gu, " ");
  return /(?:;|['"`]|\+\+|--|\$\{|(?:^|\W)(?:print|int|double|String|bool|var|while|for|if|else|return)(?:\W|$))/u
    .test(withoutLatexSpacing);
}

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
  const lexical = latexLexicalProtection(value);
  if (lexical.malformedProtectedGroup) {
    errors.push("latex_protected_group_syntax");
  }
  if (value.includes("$")) errors.push("latex_dollar_delimiter");
  if (value.includes("%")) errors.push("latex_comments_forbidden");
  if (hasUrl(value)) errors.push("latex_url_forbidden");
  if (forbiddenUnicodeControls.test(value)) {
    errors.push("latex_unicode_control");
  }
  const unprotected = value.split("").map((character, index) =>
    lexical.protected[index] ? " " : character
  ).join("");
  if (programmingLike(unprotected)) {
    errors.push("equation_non_mathematical");
  }
  if (hasBareProseOutsideProtected(value, lexical.protected)) {
    errors.push("equation_bare_prose");
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
      if (lexical.protected[index] && ",:;!".includes(next)) {
        index++;
        continue;
      }
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

/**
 * Replays the Phase C v2 acceptance boundary for already-persisted summaries.
 * The v3-only lexical hardening must not retroactively reinterpret trusted v2
 * rows when they are loaded as study-generation input.
 */
export function validateLatexLegacyV2(value: string): ValidationResult {
  const v3OnlyErrors = new Set([
    "latex_protected_group_syntax",
    "latex_url_forbidden",
    "equation_bare_prose",
  ]);
  const validation = validateLatex(value);
  return result(validation.errors.filter((error) => !v3OnlyErrors.has(error)));
}

function hasBareProseOutsideProtected(
  value: string,
  protectedCharacters: boolean[],
) {
  let bareWordCount = 0;
  for (let index = 0; index < value.length; index++) {
    if (protectedCharacters[index]) continue;
    if (value[index] === "\\") {
      if (/[A-Za-z]/u.test(value[index + 1] ?? "")) {
        index++;
        while (index + 1 < value.length && /[A-Za-z]/u.test(value[index + 1])) {
          index++;
        }
      } else {
        index++;
      }
      continue;
    }
    if (!/[A-Za-z]/u.test(value[index])) continue;
    let end = index + 1;
    while (end < value.length && /[A-Za-z]/u.test(value[end])) end++;
    const word = value.slice(index, end);
    const prefix = value.slice(Math.max(0, index - 8), index);
    if (
      word.length > 1 &&
      !(
        allowedEnvironments.has(word) &&
        (/\\begin\s*\{$/u.test(prefix) || /\\end\s*\{$/u.test(prefix))
      )
    ) {
      bareWordCount++;
      if (bareWordCount > 1) return true;
    }
    index = end - 1;
  }
  return false;
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
