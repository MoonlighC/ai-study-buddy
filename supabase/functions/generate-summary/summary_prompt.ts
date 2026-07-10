export const conciseSummaryOutputTokens = 220;
export const pdfStudySummaryOutputTokens = 1_400;

export function buildSummaryRequestBody(
  model: string,
  inputText: string,
  isReadyUpload: boolean,
) {
  return {
    model,
    instructions: isReadyUpload
      ? pdfStudySummaryInstructions
      : conciseSummaryInstructions,
    input: inputText,
    max_output_tokens: isReadyUpload
      ? pdfStudySummaryOutputTokens
      : conciseSummaryOutputTokens,
  };
}

export const conciseSummaryInstructions =
  "Create a concise, study-focused summary for a student. Summarize only the provided material. Do not ask the user to provide material. Do not invent facts or use outside knowledge. Use 4 to 6 sentences. Preserve the language of the material. Do not add flashcards, quiz questions, or unrelated advice.";

export const pdfStudySummaryInstructions =
  "Create a structured study summary of roughly 400 to 700 words using only the supplied portion of extracted PDF or image text. Preserve the language of the material. Use these plain-text headings in this order: Overview; Key concepts; Important formulas or relationships; Main examples/applications; What to remember. Explain the material clearly without inventing facts or relying on outside knowledge. Extraction can lose diagram details and damage formula notation: include a diagram detail, formula, or relationship only when it is reliably recoverable from the supplied text, and explicitly state that details were omitted when they cannot be recovered reliably. Do not reconstruct unreadable formulas or missing diagram content. Do not ask for more input. Do not add flashcards, quiz questions, or unrelated advice. The supplied text may be capped, so do not claim coverage of content that is not present in the input.";
