// Sanitized structural regression derived from the 2026-07-23 staging
// final-summary response. No document prose or provider/user identity remains.

export const finalSummaryPartitionOverlapFixture = {
  pageCount: 1,
  expectedPages: [1],
  manifest: [{
    page_number: 1,
    status: "partial",
    route: "visual",
    warnings: [{
      code: "page_content_partial",
      detail: "Only grounded included content is retained.",
      source_pages: [1],
    }],
  }],
  providerResult: {
    language: "en",
    overview_markdown:
      "A compact overview of the grounded material.\n\nIt retains the main themes while leaving provenance in analysis details.",
    topic_titles: ["Grounded content", "Main themes", "Study details"],
    sections: [{
      id: "section_1",
      title: "Grounded summary",
      blocks: [{
        kind: "prose",
        markdown: "Sanitized grounded summary.",
        display: "block",
      }],
      source_pages: [1],
      confidence: 0.8,
    }],
    key_concepts: [],
    equations: [],
    warnings: [{
      code: "page_content_partial",
      detail: "Only grounded included content is retained.",
      source_pages: [1],
    }],
    partial_extraction: {
      is_partial: true,
      analyzed_pages: [1],
      partial_pages: [1],
      missing_pages: [],
      page_modes: [{ page: 1, mode: "visual" }],
    },
  },
};
