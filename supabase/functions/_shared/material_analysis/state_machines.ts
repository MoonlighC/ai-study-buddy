import { BatchState, JobState, PageState } from "./contracts.ts";

export interface TransitionRule<S extends string> {
  from: S;
  to: S;
  terminal: boolean;
  leaseRequired: boolean;
  consumesAttempt: boolean;
  budgetEffect: "none" | "reserve" | "consume" | "retain" | "release";
  responseIdRequired: boolean;
  automaticRetry: boolean;
  explicitUserAction: boolean;
}

export const jobStates: JobState[] = [
  "awaiting_confirmation",
  "prepared",
  "processing",
  "reconciliation_required",
  "user_retry_required",
  "completed",
  "completed_with_warnings",
  "failed",
];
export const pageStates: PageState[] = [
  "pending",
  "batched",
  "processing",
  "completed",
  "partial",
  "missing",
  "failed",
];
export const batchStates: BatchState[] = [
  "prepared",
  "submitted",
  "response_known",
  "dispatch_unknown",
  "reconciliation_required",
  "user_retry_required",
  "completed",
  "failed",
];

export const jobTransitions: TransitionRule<JobState>[] = [
  rule("awaiting_confirmation", "prepared", { explicitUserAction: true }),
  rule("awaiting_confirmation", "failed"),
  rule("prepared", "processing", {
    leaseRequired: true,
    budgetEffect: "reserve",
  }),
  rule("prepared", "failed", { budgetEffect: "release" }),
  rule("processing", "prepared", {
    leaseRequired: true,
    automaticRetry: true,
    budgetEffect: "retain",
  }),
  rule("processing", "reconciliation_required", {
    leaseRequired: true,
    budgetEffect: "retain",
  }),
  rule("processing", "user_retry_required", {
    leaseRequired: true,
    budgetEffect: "retain",
  }),
  rule("processing", "completed", {
    leaseRequired: true,
    budgetEffect: "consume",
  }),
  rule("processing", "completed_with_warnings", {
    leaseRequired: true,
    budgetEffect: "consume",
  }),
  rule("processing", "failed", {
    leaseRequired: true,
    budgetEffect: "release",
  }),
  rule("reconciliation_required", "processing", {
    leaseRequired: true,
    responseIdRequired: true,
  }),
  rule("reconciliation_required", "completed", {
    leaseRequired: true,
    responseIdRequired: true,
    budgetEffect: "consume",
  }),
  rule("reconciliation_required", "completed_with_warnings", {
    leaseRequired: true,
    responseIdRequired: true,
    budgetEffect: "consume",
  }),
  rule("reconciliation_required", "failed", {
    leaseRequired: true,
    responseIdRequired: true,
    budgetEffect: "release",
  }),
  rule("user_retry_required", "prepared", {
    explicitUserAction: true,
    budgetEffect: "retain",
  }),
  rule("user_retry_required", "failed", {
    explicitUserAction: true,
    budgetEffect: "release",
  }),
];

export const pageTransitions: TransitionRule<PageState>[] = [
  rule("pending", "batched"),
  rule("pending", "failed"),
  rule("batched", "processing", {
    leaseRequired: true,
    consumesAttempt: true,
    budgetEffect: "consume",
  }),
  rule("batched", "pending", {
    leaseRequired: true,
    automaticRetry: true,
    budgetEffect: "retain",
  }),
  rule("processing", "completed", { leaseRequired: true }),
  rule("processing", "partial", { leaseRequired: true }),
  rule("processing", "missing", { leaseRequired: true }),
  rule("processing", "pending", {
    leaseRequired: true,
    automaticRetry: true,
    budgetEffect: "retain",
  }),
  rule("processing", "failed", { leaseRequired: true }),
];

export const batchTransitions: TransitionRule<BatchState>[] = [
  rule("prepared", "submitted", {
    leaseRequired: true,
    consumesAttempt: true,
    budgetEffect: "consume",
  }),
  rule("prepared", "failed", { leaseRequired: true, budgetEffect: "release" }),
  rule("submitted", "response_known", {
    leaseRequired: true,
    responseIdRequired: true,
    budgetEffect: "retain",
  }),
  rule("submitted", "dispatch_unknown", {
    leaseRequired: true,
    budgetEffect: "retain",
  }),
  rule("submitted", "prepared", {
    leaseRequired: true,
    automaticRetry: true,
    budgetEffect: "retain",
  }),
  rule("submitted", "reconciliation_required", {
    leaseRequired: true,
    responseIdRequired: true,
    budgetEffect: "retain",
  }),
  rule("submitted", "user_retry_required", {
    leaseRequired: true,
    budgetEffect: "retain",
  }),
  rule("submitted", "failed", { leaseRequired: true, budgetEffect: "release" }),
  rule("response_known", "completed", {
    leaseRequired: true,
    responseIdRequired: true,
    budgetEffect: "retain",
  }),
  rule("response_known", "failed", {
    leaseRequired: true,
    responseIdRequired: true,
    budgetEffect: "release",
  }),
  rule("response_known", "reconciliation_required", {
    leaseRequired: true,
    responseIdRequired: true,
    budgetEffect: "retain",
  }),
  rule("dispatch_unknown", "response_known", {
    leaseRequired: true,
    responseIdRequired: true,
    budgetEffect: "retain",
  }),
  rule("dispatch_unknown", "reconciliation_required", {
    leaseRequired: true,
    responseIdRequired: true,
    budgetEffect: "retain",
  }),
  rule("dispatch_unknown", "user_retry_required", {
    leaseRequired: true,
    budgetEffect: "retain",
  }),
  rule("reconciliation_required", "response_known", {
    leaseRequired: true,
    responseIdRequired: true,
    budgetEffect: "retain",
  }),
  rule("reconciliation_required", "completed", {
    leaseRequired: true,
    responseIdRequired: true,
    budgetEffect: "retain",
  }),
  rule("reconciliation_required", "failed", {
    leaseRequired: true,
    responseIdRequired: true,
    budgetEffect: "release",
  }),
  rule("user_retry_required", "prepared", {
    explicitUserAction: true,
    budgetEffect: "retain",
  }),
  rule("user_retry_required", "failed", {
    explicitUserAction: true,
    budgetEffect: "release",
  }),
];

export function transitionRule<S extends string>(
  table: TransitionRule<S>[],
  from: S,
  to: S,
): TransitionRule<S> | null {
  return table.find((entry) => entry.from === from && entry.to === to) ?? null;
}

export function assertTransition<S extends string>(input: {
  table: TransitionRule<S>[];
  from: S;
  to: S;
  leaseToken?: string;
  responseId?: string;
  explicitUserAction?: boolean;
}): TransitionRule<S> {
  const found = transitionRule(input.table, input.from, input.to);
  if (!found) throw new Error("transition_forbidden");
  if (found.leaseRequired && !input.leaseToken) {
    throw new Error("lease_required");
  }
  if (found.responseIdRequired && !input.responseId) {
    throw new Error("response_id_required");
  }
  if (found.explicitUserAction && input.explicitUserAction !== true) {
    throw new Error("explicit_user_action_required");
  }
  return found;
}

export interface PageAttempts {
  grouped: number;
  recovery: number;
  total: number;
}

export function consumePageAttempt(
  current: PageAttempts,
  kind: "grouped" | "recovery",
): PageAttempts {
  const next = {
    ...current,
    [kind]: current[kind] + 1,
    total: current.total + 1,
  };
  if (next.grouped > 2 || next.recovery > 1 || next.total > 3) {
    throw new Error("page_attempt_budget_exhausted");
  }
  return next;
}

function rule<S extends string>(
  from: S,
  to: S,
  overrides: Partial<Omit<TransitionRule<S>, "from" | "to" | "terminal">> = {},
): TransitionRule<S> {
  return {
    from,
    to,
    terminal: [
      "completed",
      "completed_with_warnings",
      "partial",
      "missing",
      "failed",
    ].includes(to),
    leaseRequired: false,
    consumesAttempt: false,
    budgetEffect: "none",
    responseIdRequired: false,
    automaticRetry: false,
    explicitUserAction: false,
    ...overrides,
  };
}
