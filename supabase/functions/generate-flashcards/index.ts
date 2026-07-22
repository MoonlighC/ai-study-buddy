import { serve } from "https://deno.land/std@0.224.0/http/server.ts";
import { createClient } from "https://esm.sh/@supabase/supabase-js@2.45.4";

import {
  buildOpenAiRequestBody,
  createGenerateFlashcardsHandler,
  extractResponseText,
  SafeGenerationError,
} from "./handler.ts";
import { canonicalStudySource } from "../_shared/study_generation_source.ts";
import {
  generationLog,
  providerSafeCode,
  resolveProjectKeys,
  SafeConfigurationError,
  safeDatabaseFailure,
  safeProviderToken,
} from "../_shared/generation_runtime.ts";

const defaultModel = "gpt-4.1-mini";
const supabaseUrl = Deno.env.get("SUPABASE_URL") ?? "";
const openAiApiKey = Deno.env.get("OPENAI_API_KEY") ?? "";
const model = Deno.env.get("OPENAI_MODEL") ?? defaultModel;
const reservedCostUsd = 0.03;
let publicKey = "";
let trustedKey = "";
let trustedSource = "";
try {
  ({ publicKey, trustedKey, trustedSource } = resolveProjectKeys(Deno.env.get));
} catch (error) {
  if (!(error instanceof SafeConfigurationError)) throw error;
}
const trustedClient = trustedKey
  ? createClient(supabaseUrl, trustedKey, {
    auth: { persistSession: false, autoRefreshToken: false },
  })
  : null;

serve(createGenerateFlashcardsHandler({
  async verifyJwt(jwt) {
    if (!supabaseUrl || !publicKey) return null;
    const client = clientFor(jwt);
    const { data, error } = await client.auth.getUser(jwt);
    return error || !data.user ? null : data.user.id;
  },
  async loadOwnedMaterial(userId, materialId, _jwt) {
    if (!trustedClient) {
      throw new SafeGenerationError("configuration_unavailable");
    }
    const { data, error } = await trustedClient.rpc(
      "load_study_generation_source_internal",
      { p_user_id: userId, p_material_id: materialId },
    ).maybeSingle();
    if (error || data !== null && !isRecord(data)) {
      throw new Error("material_load_failed");
    }
    return data as Record<string, unknown> | null;
  },
  async loadExistingCards(userId, materialId, jwt) {
    const { data, error } = await clientFor(jwt)
      .from("flashcards")
      .select("id,subject_id,material_id,front,back,topic,difficulty")
      .eq("user_id", userId)
      .eq("material_id", materialId)
      .is("deleted_at", null)
      .order("created_at", { ascending: true });
    if (error || !Array.isArray(data)) throw new Error("flashcard_load_failed");
    return data;
  },
  async generateCandidates(input) {
    if (!openAiApiKey) {
      throw new SafeGenerationError("configuration_unavailable");
    }
    const response = await fetch("https://api.openai.com/v1/responses", {
      method: "POST",
      headers: {
        Authorization: `Bearer ${openAiApiKey}`,
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
    const providerError = isRecord(data) && isRecord(data.error)
      ? data.error
      : null;
    generationLog("generate-flashcards", "openai_response_received", {
      status: response.status,
      code: safeProviderToken(providerError?.code) ??
        providerSafeCode(response.status),
      reason: safeProviderToken(providerError?.type),
    });
    if (!response.ok) {
      throw new SafeGenerationError(
        providerSafeCode(response.status),
        response.status,
      );
    }
    const text = extractResponseText(data);
    if (!text) throw new SafeGenerationError("response_parse_failed");
    const usage = responseUsage(data);
    if (usage.inputTokens === 0 || usage.outputTokens === 0) {
      throw new SafeGenerationError("response_parse_failed");
    }
    return { text, ...usage };
  },
  async reserveOperation(input) {
    ensureDefaultPricedModel();
    if (!openAiApiKey) {
      throw new SafeGenerationError("configuration_unavailable");
    }
    if (!trustedClient) {
      throw new SafeGenerationError("configuration_unavailable");
    }
    const { data, error } = await trustedClient.rpc(
      "reserve_study_generation_internal",
      {
        p_user_id: input.userId,
        p_operation_id: input.operationId,
        p_material_id: input.materialId,
        p_feature: "generate_flashcards",
        p_request_hash: input.requestHash,
        p_quantity: input.count,
        p_reserved_cost_usd: reservedCostUsd,
        p_model: model,
      },
    ).single();
    if (error || !isRecord(data)) throw reservationError(error);
    const status = data.operation_status;
    if (
      status !== "reserved" && status !== "succeeded" && status !== "failed"
    ) {
      throw new SafeGenerationError("database_write_failed");
    }
    return { status };
  },
  async claimProvider(userId, operationId) {
    if (!trustedClient) {
      throw new SafeGenerationError("configuration_unavailable");
    }
    const { data, error } = await trustedClient.rpc(
      "claim_study_generation_provider_internal",
      { p_user_id: userId, p_operation_id: operationId },
    );
    if (error || typeof data !== "boolean") {
      throw new SafeGenerationError("database_write_failed");
    }
    return data;
  },
  async awaitOperation(userId, operationId) {
    if (!trustedClient) {
      throw new SafeGenerationError("configuration_unavailable");
    }
    for (let attempt = 0; attempt < 150; attempt++) {
      const { data, error } = await trustedClient.rpc(
        "get_study_generation_operation_internal",
        { p_user_id: userId, p_operation_id: operationId },
      ).maybeSingle();
      if (error || !isRecord(data)) {
        throw new SafeGenerationError("database_write_failed");
      }
      if (data.operation_status === "failed") {
        throw new SafeGenerationError("generation_failed");
      }
      if (data.operation_status === "succeeded") {
        const ids = Array.isArray(data.result_ids) ? data.result_ids : [];
        if (ids.length === 0) return [];
        const result = await trustedClient.from("flashcards")
          .select("id,subject_id,material_id,front,back,topic,difficulty")
          .eq("user_id", userId).in("id", ids).is("deleted_at", null)
          .order("created_at", { ascending: true });
        if (result.error || !Array.isArray(result.data)) {
          throw new SafeGenerationError("database_write_failed");
        }
        return result.data;
      }
      await delay(200);
    }
    throw new SafeGenerationError("generation_in_progress", 409);
  },
  async completeOperation(input) {
    if (!trustedClient) {
      throw new SafeGenerationError("configuration_unavailable");
    }
    const actualCost = generationCost(input.inputTokens, input.outputTokens);
    const { data, error } = await trustedClient.rpc(
      "complete_flashcard_generation_internal",
      {
        p_user_id: input.userId,
        p_operation_id: input.operationId,
        p_material_id: input.materialId,
        p_cards: input.cards,
        p_model: model,
        p_input_tokens: input.inputTokens,
        p_output_tokens: input.outputTokens,
        p_actual_cost_usd: actualCost,
      },
    );
    if (error || !Array.isArray(data)) {
      generationLog("generate-flashcards", "known_failure", {
        reason: "database_write_failed",
        ...safeDatabaseFailure(error),
      });
      throw new SafeGenerationError("database_write_failed");
    }
    return data;
  },
  async failOperation(userId, operationId, code, retainReservedCost) {
    if (!trustedClient) return;
    const { error } = await trustedClient.rpc(
      "fail_study_generation_internal",
      {
        p_user_id: userId,
        p_operation_id: operationId,
        p_safe_failure_code: code,
        p_retain_reserved_cost: retainReservedCost,
      },
    );
    if (error) throw new Error("generation_failure_finalize_failed");
  },
  canonicalSource: canonicalStudySource,
  model,
  log: (stage, details) =>
    generationLog("generate-flashcards", stage, {
      ...details,
      ...(stage === "auth_verified" ? { reason: trustedSource } : {}),
    }),
}));

function clientFor(jwt: string) {
  return createClient(supabaseUrl, publicKey, {
    global: { headers: { Authorization: `Bearer ${jwt}` } },
  });
}

function isRecord(value: unknown): value is Record<string, unknown> {
  return typeof value === "object" && value !== null && !Array.isArray(value);
}

function ensureDefaultPricedModel() {
  if (model !== defaultModel) {
    throw new SafeGenerationError("configuration_unavailable");
  }
}

function generationCost(inputTokens: number, outputTokens: number) {
  return Math.min(
    reservedCostUsd,
    Math.ceil(
      (inputTokens * 0.4 / 1_000_000 + outputTokens * 1.6 / 1_000_000) *
        1_000_000,
    ) / 1_000_000,
  );
}

function responseUsage(data: unknown) {
  const usage = isRecord(data) && isRecord(data.usage) ? data.usage : {};
  return {
    inputTokens: nonnegativeInteger(usage.input_tokens),
    outputTokens: nonnegativeInteger(usage.output_tokens),
  };
}

function nonnegativeInteger(value: unknown) {
  return typeof value === "number" && Number.isInteger(value) && value >= 0
    ? value
    : 0;
}

function reservationError(error: unknown) {
  const message = isRecord(error) && typeof error.message === "string"
    ? error.message
    : "";
  if (message.includes("limit_exceeded")) {
    return new SafeGenerationError("daily_limit_exceeded", 429);
  }
  return new SafeGenerationError("database_write_failed");
}

function delay(milliseconds: number) {
  return new Promise((resolve) => setTimeout(resolve, milliseconds));
}
