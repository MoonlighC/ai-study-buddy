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
  buildOpenAiRequestBody,
  createGenerateQuizHandler,
  extractResponseText,
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
    if (!trusted) {
      throw new SafeQuizGenerationError("configuration_unavailable");
    }
    const { data, error } = await trusted.rpc(
      "load_study_generation_source_internal",
      { p_user_id: userId, p_material_id: materialId },
    ).maybeSingle();
    if (error) throw new SafeQuizGenerationError("database_write_failed");
    return data;
  },
  async loadExistingQuiz(userId, materialId, count) {
    if (!trusted) {
      throw new SafeQuizGenerationError("configuration_unavailable");
    }
    const quizResult = await trusted.from("quizzes").select(
      "id,material_id,title,question_count",
    ).eq("user_id", userId).eq("material_id", materialId).eq(
      "question_count",
      count,
    ).is("deleted_at", null).order("created_at", { ascending: false }).limit(1)
      .maybeSingle();
    if (quizResult.error || !quizResult.data) return null;
    const questionResult = await trusted.from("quiz_questions").select(
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
    if (!trusted || !openAiKey || model !== defaultModel) {
      throw new SafeQuizGenerationError("configuration_unavailable");
    }
    const { data, error } = await trusted.rpc(
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
    if (error) {
      throw new SafeQuizGenerationError(
        String(error.message).includes("limit_exceeded")
          ? "daily_limit_exceeded"
          : "database_write_failed",
        String(error.message).includes("limit_exceeded") ? 429 : undefined,
      );
    }
    return { status: data.operation_status };
  },
  async claimProvider(userId, operationId) {
    if (!trusted) {
      throw new SafeQuizGenerationError("configuration_unavailable");
    }
    const { data, error } = await trusted.rpc(
      "claim_study_generation_provider_internal",
      { p_user_id: userId, p_operation_id: operationId },
    );
    if (error || typeof data !== "boolean") {
      throw new SafeQuizGenerationError("database_write_failed");
    }
    return data;
  },
  async awaitOperation(userId, operationId, materialId) {
    if (!trusted) {
      throw new SafeQuizGenerationError("configuration_unavailable");
    }
    for (let i = 0; i < 150; i++) {
      const { data, error } = await trusted.rpc(
        "get_study_generation_operation_internal",
        { p_user_id: userId, p_operation_id: operationId },
      ).maybeSingle();
      if (error || !data) {
        throw new SafeQuizGenerationError("database_write_failed");
      }
      if (data.operation_status === "failed") {
        throw new SafeQuizGenerationError("generation_failed");
      }
      if (data.operation_status === "succeeded") {
        const ids = data.result_ids ?? [];
        const questions = await trusted.from("quiz_questions").select(
          "id,quiz_id,subject_id,material_id,question,options,correct_answer,explanation,topic,difficulty,sort_order",
        ).in("id", ids).order("sort_order");
        if (questions.error || !questions.data?.length) {
          throw new SafeQuizGenerationError("database_write_failed");
        }
        const quiz = await trusted.from("quizzes").select("id,title").eq(
          "id",
          questions.data[0].quiz_id,
        ).single();
        if (quiz.error) {
          throw new SafeQuizGenerationError("database_write_failed");
        }
        return {
          quiz_id: quiz.data.id,
          material_id: materialId,
          title: quiz.data.title,
          questions: questions.data,
        };
      }
      await new Promise((resolve) => setTimeout(resolve, 200));
    }
    throw new SafeQuizGenerationError("generation_in_progress", 409);
  },
  async generate(input) {
    const response = await fetch("https://api.openai.com/v1/responses", {
      method: "POST",
      headers: {
        Authorization: `Bearer ${openAiKey}`,
        "Content-Type": "application/json",
      },
      body: JSON.stringify(
        buildOpenAiRequestBody(model, input.text, input.count),
      ),
    });
    let data: unknown;
    try {
      data = await response.json();
    } catch (_) {
      data = null;
    }
    const error = data && typeof data === "object" && "error" in data
      ? (data as { error?: Record<string, unknown> }).error
      : undefined;
    generationLog("generate-quiz", "openai_response_received", {
      status: response.status,
      code: safeProviderToken(error?.code) ?? providerSafeCode(response.status),
    });
    if (!response.ok) {
      throw new SafeQuizGenerationError(
        providerSafeCode(response.status),
        response.status,
      );
    }
    const usage = data && typeof data === "object" && "usage" in data
      ? (data as { usage?: Record<string, unknown> }).usage ?? {}
      : {};
    const inputTokens = integer(usage.input_tokens);
    const outputTokens = integer(usage.output_tokens);
    const text = extractResponseText(data);
    if (!text || !inputTokens || !outputTokens) {
      throw new SafeQuizGenerationError("response_parse_failed");
    }
    return { text, inputTokens, outputTokens };
  },
  async complete(input) {
    if (!trusted) {
      throw new SafeQuizGenerationError("configuration_unavailable");
    }
    const cost = Math.min(
      reservedCostUsd,
      Math.ceil(
        (input.inputTokens * 0.4 / 1e6 + input.outputTokens * 1.6 / 1e6) * 1e6,
      ) / 1e6,
    );
    const { data, error } = await trusted.rpc(
      "complete_quiz_generation_internal",
      {
        p_user_id: input.userId,
        p_operation_id: input.operationId,
        p_material_id: input.materialId,
        p_title: input.draft.title,
        p_questions: input.draft.questions,
        p_model: model,
        p_input_tokens: input.inputTokens,
        p_output_tokens: input.outputTokens,
        p_actual_cost_usd: cost,
      },
    );
    if (
      error || !Array.isArray(data) ||
      data.length !== input.draft.questions.length
    ) throw new SafeQuizGenerationError("database_write_failed");
    return {
      quiz_id: data[0].quiz_id,
      material_id: input.materialId,
      title: input.draft.title,
      questions: data,
    };
  },
  async fail(userId, operationId, code, retainReservedCost) {
    if (trusted) {
      await trusted.rpc("fail_study_generation_internal", {
        p_user_id: userId,
        p_operation_id: operationId,
        p_safe_failure_code: code,
        p_retain_reserved_cost: retainReservedCost,
      });
    }
  },
  log: (stage, details) => generationLog("generate-quiz", stage, details),
}));

function integer(value: unknown) {
  return typeof value === "number" && Number.isInteger(value) && value >= 0
    ? value
    : 0;
}
