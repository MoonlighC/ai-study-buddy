import { DomainProfile, PageRoute, ProcessingMode } from "./contracts.ts";
import { routerVersion } from "./contracts.ts";
import { sha256Hex, stableJson } from "./fingerprints_retry.ts";

export interface TextBox {
  x: number;
  y: number;
  width: number;
  height: number;
}

export interface PageRoutingInput {
  pageNumber: number;
  sourceKind: "pdf" | "image";
  normalizedText: string;
  textCoordinates: TextBox[];
  pageWidth: number;
  pageHeight: number;
  textCoverage: number;
  damagedCharacterRatio: number;
  mathDensity: number;
  columnAlignment: number;
  tableAlignment: number;
  rasterCoverage: number;
  vectorPathComplexity: number;
  handwritingOrInk: boolean;
  diagramOrGraph: boolean;
  readingOrderUncertainty: number;
  layoutUncertainty: number;
  domainProfile: DomainProfile;
  mode: ProcessingMode;
}

export interface RoutingDecision {
  route: PageRoute;
  confidence: number;
  reasons: string[];
  routerVersion: string;
  fingerprint: string;
}

export async function routePage(
  input: PageRoutingInput,
): Promise<RoutingDecision> {
  validateInput(input);
  const reasons: string[] = [];
  const usefulText = input.normalizedText.length >= 80 &&
    (input.normalizedText.match(/[\p{L}\p{N}]/gu)?.length ?? 0) >= 20 &&
    input.textCoverage >= 0.03 && input.damagedCharacterRatio <= 0.01;

  let route: PageRoute = "text";
  if (input.sourceKind === "image") reasons.push("original_image");
  if (!usefulText) reasons.push("text_unusable");

  if (input.mode === "recommended") {
    const stem = input.domainProfile === "stem";
    const mathThreshold = stem ? 0.015 : 0.03;
    const rasterThreshold = stem ? 0.04 : 0.08;
    const vectorThreshold = stem ? 20 : 40;
    if (input.mathDensity >= mathThreshold) reasons.push("math_dense");
    if (input.columnAlignment >= 0.6) reasons.push("columns");
    if (input.tableAlignment >= 0.6) reasons.push("table");
    if (input.rasterCoverage >= rasterThreshold) reasons.push("embedded_image");
    if (input.vectorPathComplexity >= vectorThreshold) {
      reasons.push("vector_complexity");
    }
    if (input.handwritingOrInk) reasons.push("handwriting");
    if (input.diagramOrGraph) reasons.push("diagram_or_graph");
    if (input.readingOrderUncertainty > 0.15 || input.layoutUncertainty > 0.1) {
      reasons.push("layout_uncertain");
    }
  }

  if (reasons.length > 0) route = "visual";
  const confidence = route === "visual"
    ? Math.min(1, 0.65 + reasons.length * 0.05)
    : Math.min(1, 0.7 + input.textCoverage * 0.3);
  const canonical = {
    ...input,
    routerVersion,
    route,
    reasons: [...reasons].sort(),
  };
  return {
    route,
    confidence: Number(confidence.toFixed(4)),
    reasons,
    routerVersion,
    fingerprint: await sha256Hex(stableJson(canonical)),
  };
}

function validateInput(input: PageRoutingInput) {
  if (
    !Number.isInteger(input.pageNumber) || input.pageNumber < 1 ||
    input.pageNumber > 100
  ) {
    throw new Error("page_out_of_range");
  }
  for (
    const value of [
      input.textCoverage,
      input.damagedCharacterRatio,
      input.mathDensity,
      input.columnAlignment,
      input.tableAlignment,
      input.rasterCoverage,
      input.readingOrderUncertainty,
      input.layoutUncertainty,
    ]
  ) {
    if (!Number.isFinite(value) || value < 0 || value > 1) {
      throw new Error("signal_out_of_range");
    }
  }
  if (
    input.pageWidth <= 0 || input.pageHeight <= 0 ||
    input.vectorPathComplexity < 0
  ) {
    throw new Error("invalid_page_geometry");
  }
}
