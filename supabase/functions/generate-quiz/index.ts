import { serve } from "https://deno.land/std@0.224.0/http/server.ts";
import { createClient } from "https://esm.sh/@supabase/supabase-js@2.45.4";

import { canonicalStudySource } from "../_shared/study_generation_source.ts";
import {
  generationLog,
  providerSafeCode,
  resolveProjectKeys,
  SafeConfigurationError,
  safeProviderToken,
} from "../_shared/generation_runtime.ts";
import {
  executeStudyGeneration,
  providerResponseFromEnvelope,
  StudyGenerationProviderResponse,
  StudyGenerationReconciliationClaim,
} from "../_shared/study_generation_reconciliation.ts";
import {
  buildOpenAiRequestBody,
  createGenerateQuizHandler,
  extractResponseText,
  parseQuiz,
  QuizResult,
  SafeQuizGenerationError,
} from "./handler.ts";

const defaultModel = "gpt-4.1-mini";
const model = Deno.env.get("OPENAI_MODEL") ?? defaultModel;
const supabaseUrl = Deno.env.get("SUPABASE_URL") ?? "";
const openAiKey = Deno.env.get("OPENAI_API_KEY") ?? "";
const reservedCostUsd = 0.03;
let publicKey = "";
let trustedKey = "";
try {
  ({ publicKey, trustedKey } = resolveProjectKeys(Deno.env.get));
} catch (error) {
  if (!(error instanceof SafeConfigurationError)) throw error;
}
const trusted = trustedKey
  ? createClient(supabaseUrl, trustedKey, {
    auth: { persistSession: false, autoRefreshToken: false },
  })
  : null;

serve(createGenerateQuizHandler({
  async verifyJwt(jwt) {
    if (!supabaseUrl || !publicKey) return null;
    const { data, error } = await createClient(supabaseUrl, publicKey).auth
      .getUser(jwt);
    return error || !data.user ? null : data.user.id;
  },
  async loadOwnedMaterial(userId, materialId) {
    requireConfigured(false);
    const { data, error } = await trusted!.rpc(
      "load_study_generation_source_internal",
      { p_user_id: userId, p_material_id: materialId },
    ).maybeSingle();
    if (error) throw new SafeQuizGenerationError("database_write_failed");
    if (data !== null && !isRecord(data)) {
      throw new SafeQuizGenerationError("database_write_failed");
    }
    return data as Record<string, unknown> | null;
  },
  async loadExistingQuiz(userId, materialId, count) {
    requireConfigured(false);
    const quizResult = await trusted!.from("quizzes").select(
      "id,material_id,title,question_count",
    ).eq("user_id", userId).eq("material_id", materialId).eq(
      "question_count",
      count,
    ).is("deleted_at", null).order("created_at", { ascending: false }).limit(1)
      .maybeSingle();
    if (quizResult.error || !quizResult.data) return null;
    const questionResult = await trusted!.from("quiz_questions").select(
      "id,quiz_id,subject_id,material_id,question,options,correct_answer,explanation,topic,difficulty,sort_order",
    ).eq("user_id", userId).eq("quiz_id", quizResult.data.id).is(
      "deleted_at",
      null,
    ).order("sort_order");
    if (
      questionResult.error || !Array.isArray(questionResult.data) ||
      questionResult.data.length !== count
    ) return null;
    return {
      quiz_id: quizResult.data.id,
      material_id: materialId,
      title: quizResult.data.title,
      questions: questionResult.data,
    };
  },
  canonicalSource: canonicalStudySource,
  async reserveOperation(input) {
    requireConfigured();
    const { data, error } = await trusted!.rpc(
      "reserve_study_generation_internal",
      {
        p_user_id: input.userId,
        p_operation_id: input.operationId,
        p_material_id: input.materialId,
        p_feature: "generate_quiz_questions",
        p_request_hash: input.requestHash,
        p_quantity: input.count,
        p_reserved_cost_usd: reservedCostUsd,
        p_model: model,
      },
    ).single();
    if (error || !isRecord(data)) throw reservationError(error);
    if (!isOperationStatus(data.operation_status)) {
      throw new SafeQuizGenerationError("database_write_failed");
    }
    return { status: data.operation_status };
  },
  async executeOperation(input) {
    requireConfigured();
    return await executeStudyGeneration<QuizResult>({
      claimProvider: async () => {
        const { data, error } = await trusted!.rpc(
          "claim_study_generation_provider_internal",
          {
            p_user_id: input.userId,
            p_operation_id: input.operationId,
          },
        );
        if (error || typeof data !== "boolean") {
          throw new SafeQuizGenerationError("database_write_failed");
        }
        return data;
      },
      submitProvider: async () => {
        generationLog("generate-quiz", "openai_request_started", {
          model,
          requested_count: input.count,
        });
        return await providerRequest(
          "POST",
          "https://api.openai.com/v1/responses",
          buildOpenAiRequestBody(model, input.sourceText, input.count),
        );
      },
      recordProviderResponse: async (response) => {
        const { error } = await trusted!.rpc(
          "record_study_generation_response_internal",
          {
            p_user_id: input.userId,
            p_operation_id: input.operationId,
            p_provider_response_identity: response.identity,
            p_provider_status: response.status,
          },
        );
        if (error) {
          throw new SafeQuizGenerationError("database_write_failed");
        }
      },
      claimReconciliation: async (token) =>
        await claimReconciliation(input.userId, input.operationId, token),
      retrieveProvider: async (identity) =>
        await providerRequest(
          "GET",
          `https://api.openai.com/v1/responses/${encodeURIComponent(identity)}`,
        ),
      updateProviderStatus: async (token, status) => {
        const { error } = await trusted!.rpc(
          "update_study_generation_provider_status_internal",
          {
            p_user_id: input.userId,
            p_operation_id: input.operationId,
            p_reconciliation_token: token,
            p_provider_status: status,
          },
        );
        if (error) {
          throw new SafeQuizGenerationError("database_write_failed");
        }
      },
      persist: async (response, token) => {
        const output = completedOutput(response);
        const draft = parseQuiz(output.text, input.count);
        const cost = generationCost(output.inputTokens, output.outputTokens);
        const { data, error } = await trusted!.rpc(
          "complete_quiz_generation_internal",
          {
            p_user_id: input.userId,
            p_operation_id: input.operationId,
            p_material_id: input.materialId,
            p_title: draft.title,
            p_questions: draft.questions,
            p_model: model,
            p_input_tokens: output.inputTokens,
            p_output_tokens: output.outputTokens,
            p_actual_cost_usd: cost,
            p_reconciliation_token: token,
          },
        );
        if (
          error || !Array.isArray(data) ||
          data.length !== draft.questions.length
        ) {
          throw new SafeQuizGenerationError("database_write_failed");
        }
        return {
          quiz_id: data[0].quiz_id,
          material_id: input.materialId,
          title: draft.title,
          questions: data,
        };
      },
      replay: async (ids) => await replayQuiz(input, ids),
      fail: async (code, phase, token) => {
        const { error } = await trusted!.rpc(
          "fail_study_generation_reconciliation_internal",
          {
            p_user_id: input.userId,
            p_operation_id: input.operationId,
            p_safe_failure_code: code,
            p_failure_phase: phase,
            p_reconciliation_token: token ?? null,
          },
        );
        if (error) {
          throw new SafeQuizGenerationError("database_write_failed");
        }
      },
      createToken: () => crypto.randomUUID(),
      wait: (milliseconds) =>
        new Promise((resolve) => setTimeout(resolve, milliseconds)),
    });
  },
  log: (stage, details) => generationLog("generate-quiz", stage, details),
}));

async function claimReconciliation(
  userId: string,
  operationId: string,
  token: string,
): Promise<StudyGenerationReconciliationClaim> {
  const { data, error } = await trusted!.rpc(
    "claim_study_generation_reconciliation_internal",
    {
      p_user_id: userId,
      p_operation_id: operationId,
      p_reconciliation_token: token,
    },
  ).single();
  if (error || !isRecord(data)) {
    throw new SafeQuizGenerationError("database_write_failed");
  }
  const status = data.operation_status;
  if (status === "succeeded") {
    return { kind: "completed", resultIds: stringArray(data.result_ids) };
  }
  if (
    status === "failed" || status === "failed_before_provider" ||
    status === "failed_after_provider"
  ) {
    return {
      kind: "failed",
      safeCode: safeString(data.safe_failure_code) || "generation_failed",
    };
  }
  if (data.claimed === true) {
    const identity = safeString(data.provider_response_identity);
    if (!identity) {
      throw new SafeQuizGenerationError("database_write_failed");
    }
    return { kind: "claimed", token, responseIdentity: identity };
  }
  return {
    kind: "active",
    status: status === "provider_claimed" || status === "reserved"
      ? "generating"
      : "reconciling",
  };
}

async function replayQuiz(
  input: {
    userId: string;
    materialId: string;
  },
  ids: string[],
): Promise<QuizResult> {
  if (ids.length === 0) {
    throw new SafeQuizGenerationError("database_write_failed");
  }
  const questions = await trusted!.from("quiz_questions").select(
    "id,quiz_id,subject_id,material_id,question,options,correct_answer,explanation,topic,difficulty,sort_order",
  ).eq("user_id", input.userId).in("id", ids).is("deleted_at", null).order(
    "sort_order",
  );
  if (
    questions.error || !Array.isArray(questions.data) ||
    questions.data.length !== ids.length
  ) {
    throw new SafeQuizGenerationError("database_write_failed");
  }
  const quizId = questions.data[0].quiz_id;
  const quiz = await trusted!.from("quizzes").select("id,title").eq(
    "id",
    quizId,
  ).eq("user_id", input.userId).is("deleted_at", null).single();
  if (quiz.error || !quiz.data) {
    throw new SafeQuizGenerationError("database_write_failed");
  }
  return {
    quiz_id: quiz.data.id,
    material_id: input.materialId,
    title: quiz.data.title,
    questions: questions.data,
  };
}

async function providerRequest(
  method: "POST" | "GET",
  url: string,
  body?: Record<string, unknown>,
): Promise<StudyGenerationProviderResponse> {
  const response = await fetch(url, {
    method,
    headers: {
      Authorization: `Bearer ${openAiKey}`,
      ...(body ? { "Content-Type": "application/json" } : {}),
    },
    ...(body ? { body: JSON.stringify(body) } : {}),
  });
  let data: unknown;
  try {
    data = await response.json();
  } catch (_) {
    data = null;
  }
  const providerError = isRecord(data) && isRecord(data.error)
    ? data.error
    : null;
  generationLog("generate-quiz", "openai_response_received", {
    status: response.status,
    code: safeProviderToken(providerError?.code) ??
      providerSafeCode(response.status),
  });
  if (!response.ok) {
    throw new SafeQuizGenerationError(
      providerSafeCode(response.status),
      response.status,
    );
  }
  return providerResponseFromEnvelope(data);
}

function completedOutput(response: StudyGenerationProviderResponse) {
  if (response.status !== "completed") {
    throw new SafeQuizGenerationError("provider_terminal_failed");
  }
  const text = extractResponseText(response.envelope);
  const usage = isRecord(response.envelope) &&
      isRecord(response.envelope.usage)
    ? response.envelope.usage
    : {};
  const inputTokens = integer(usage.input_tokens);
  const outputTokens = integer(usage.output_tokens);
  if (!text || !inputTokens || !outputTokens) {
    throw new SafeQuizGenerationError("response_parse_failed");
  }
  return { text, inputTokens, outputTokens };
}

function requireConfigured(provider = true) {
  if (!trusted || provider && (!openAiKey || model !== defaultModel)) {
    throw new SafeQuizGenerationError("configuration_unavailable");
  }
}

function generationCost(inputTokens: number, outputTokens: number) {
  return Math.min(
    reservedCostUsd,
    Math.ceil(
      (inputTokens * 0.4 / 1e6 + outputTokens * 1.6 / 1e6) * 1e6,
    ) / 1e6,
  );
}

function integer(value: unknown) {
  return typeof value === "number" && Number.isInteger(value) && value >= 0
    ? value
    : 0;
}

function reservationError(error: unknown) {
  const message = isRecord(error) && typeof error.message === "string"
    ? error.message
    : "";
  if (message.includes("limit_exceeded")) {
    return new SafeQuizGenerationError("daily_limit_exceeded", 429);
  }
  if (message.includes("generation_operation_conflict")) {
    return new SafeQuizGenerationError("generation_operation_conflict", 409);
  }
  return new SafeQuizGenerationError("database_write_failed");
}

function isOperationStatus(value: unknown): value is
  | "reserved"
  | "provider_claimed"
  | "reconciliation_required"
  | "persisting"
  | "succeeded"
  | "failed"
  | "failed_before_provider"
  | "failed_after_provider" {
  return value === "reserved" || value === "provider_claimed" ||
    value === "reconciliation_required" || value === "persisting" ||
    value === "succeeded" || value === "failed" ||
    value === "failed_before_provider" || value === "failed_after_provider";
}

function stringArray(value: unknown) {
  return Array.isArray(value)
    ? value.filter((item): item is string => typeof item === "string")
    : [];
}

function safeString(value: unknown) {
  return typeof value === "string" && /^[A-Za-z0-9_-]{1,255}$/.test(value)
    ? value
    : "";
}

function isRecord(value: unknown): value is Record<string, unknown> {
  return typeof value === "object" && value !== null && !Array.isArray(value);
}
