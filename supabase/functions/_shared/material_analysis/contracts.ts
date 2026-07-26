export const analysisSchemaVersion = 1;
export const routerVersion = "phase-c-router-v1";

export type ProcessingMode = "recommended" | "economy";
export type PublicStage =
  | "preparing_document"
  | "analyzing_pages"
  | "recognizing_formulas_and_diagrams"
  | "creating_summary";

export type JobState =
  | "awaiting_confirmation"
  | "prepared"
  | "processing"
  | "reconciliation_required"
  | "user_retry_required"
  | "completed"
  | "completed_with_warnings"
  | "failed";

export type PageState =
  | "pending"
  | "batched"
  | "processing"
  | "completed"
  | "partial"
  | "missing"
  | "failed";

export type BatchState =
  | "prepared"
  | "submitted"
  | "response_known"
  | "dispatch_unknown"
  | "reconciliation_required"
  | "user_retry_required"
  | "completed"
  | "failed";

export type PageRoute = "text" | "visual";
export type DomainProfile = "general" | "stem";

export interface PrepareMaterialAnalysisRequest {
  material_id: string;
  processing_mode: ProcessingMode;
  confirm_large_document: boolean;
}

export interface AdvanceMaterialAnalysisRequest {
  material_id: string;
}

export interface RetryMaterialAnalysisRequest {
  material_id: string;
}

export interface SafeWarning {
  code: string;
  detail: string;
  source_pages: number[];
}

export interface MaterialAnalysisStatus {
  material_id: string;
  processing_mode: ProcessingMode;
  state:
    | "awaiting_confirmation"
    | "processing"
    | "reconciliation_required"
    | "user_retry_required"
    | "completed"
    | "completed_with_warnings"
    | "failed";
  public_stage: PublicStage;
  page_count: number;
  completed_pages: number;
  confirmation_required: boolean;
  can_retry: boolean;
  can_analyze_again: boolean;
  retry_after_seconds: number | null;
  warnings: SafeWarning[];
  summary_schema_version: number | null;
  summary_payload: StructuredSummary | null;
}

export interface ProseBlock {
  kind: "prose";
  markdown: string;
  display: "inline" | "block";
}

export interface EquationBlock {
  kind: "equation";
  equation_id: string;
  display: "inline" | "block";
}

export type SummaryBlock = ProseBlock | EquationBlock;

export interface Equation {
  id: string;
  latex: string;
  explanation_markdown: string;
  source_page: number;
  display: "inline" | "block";
  confidence: number;
  uncertainty: boolean;
}

export interface PageMode {
  page: number;
  mode: PageRoute;
}

export interface StructuredSummary {
  language: string;
  overview_markdown: string;
  topic_titles: string[];
  sections: Array<{
    id: string;
    title: string;
    blocks: SummaryBlock[];
    source_pages: number[];
    confidence: number;
  }>;
  key_concepts: Array<{
    title: string;
    explanation_markdown: string;
    source_pages: number[];
    confidence: number;
  }>;
  equations: Equation[];
  warnings: SafeWarning[];
  partial_extraction: {
    is_partial: boolean;
    analyzed_pages: number[];
    partial_pages: number[];
    missing_pages: number[];
    page_modes: PageMode[];
  };
}

export interface PageAnalysisResult {
  page_number: number;
  content_status: "completed" | "partial" | "missing";
  summary_markdown: string;
  key_concepts: string[];
  equations: Equation[];
  confidence: number;
  warnings: SafeWarning[];
  /** True means every included claim is grounded; it does not mean extraction was complete. */
  trustworthy: boolean;
}

export interface ReductionResult {
  source_pages: number[];
  summary_markdown: string;
  key_concepts: string[];
  equation_ids: string[];
  warnings: SafeWarning[];
  confidence: number;
}

export interface FakeOpenAiBoundary {
  submit(input: {
    fingerprint: string;
    operation: string;
    payload: unknown;
  }): Promise<{ responseId: string; result: unknown }>;
  retrieve(responseId: string): Promise<{ status: string; result?: unknown }>;
  deleteFile(fileId: string): Promise<boolean>;
}

export interface FakeSupabaseBoundary {
  loadOwnedMaterial(principalId: string, materialId: string): Promise<unknown>;
  callTrustedRpc(name: string, args: Record<string, unknown>): Promise<unknown>;
}
