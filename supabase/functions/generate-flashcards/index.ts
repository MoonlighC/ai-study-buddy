import { serve } from "https://deno.land/std@0.224.0/http/server.ts";
import { createClient } from "https://esm.sh/@supabase/supabase-js@2.45.4";

import {
  buildOpenAiRequestBody,
  createGenerateFlashcardsHandler,
  duplicateKey,
  duplicateKeyForRow,
  extractResponseText,
  parseFlashcardCandidates,
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
import {
  executeStudyGeneration,
  providerResponseFromEnvelope,
  StudyGenerationProviderResponse,
  StudyGenerationReconciliationClaim,
} from "../_shared/study_generation_reconciliation.ts";

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
    requireTrusted();
    const { data, error } = await trustedClient!.rpc(
      "load_study_generation_source_internal",
      { p_user_id: userId, p_material_id: materialId },
    ).maybeSingle();
    if (error || data !== null && !isRecord(data)) {
      throw new SafeGenerationError("database_write_failed");
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
    if (error || !Array.isArray(data)) {
      throw new SafeGenerationError("database_write_failed");
    }
    return data;
  },
  async reserveOperation(input) {
    ensureConfigured();
    const { data, error } = await trustedClient!.rpc(
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
    if (!isOperationStatus(status)) {
      throw new SafeGenerationError("database_write_failed");
    }
    return { status };
  },
  async executeOperation(input) {
    ensureConfigured();
    return await executeStudyGeneration({
      claimProvider: async () => {
        const { data, error } = await trustedClient!.rpc(
          "claim_study_generation_provider_internal",
          {
            p_user_id: input.userId,
            p_operation_id: input.operationId,
          },
        );
        if (error || typeof data !== "boolean") {
          throw new SafeGenerationError("database_write_failed");
        }
        return data;
      },
      submitProvider: async () => {
        generationLog("generate-flashcards", "openai_request_started", {
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
        const { error } = await trustedClient!.rpc(
          "record_study_generation_response_internal",
          {
            p_user_id: input.userId,
            p_operation_id: input.operationId,
            p_provider_response_identity: response.identity,
            p_provider_status: response.status,
          },
        );
        if (error) throw new SafeGenerationError("database_write_failed");
      },
      claimReconciliation: async (token) =>
        await claimReconciliation(input.userId, input.operationId, token),
      retrieveProvider: async (identity) =>
        await providerRequest(
          "GET",
          `https://api.openai.com/v1/responses/${encodeURIComponent(identity)}`,
        ),
      updateProviderStatus: async (token, status) => {
        const { error } = await trustedClient!.rpc(
          "update_study_generation_provider_status_internal",
          {
            p_user_id: input.userId,
            p_operation_id: input.operationId,
            p_reconciliation_token: token,
            p_provider_status: status,
          },
        );
        if (error) throw new SafeGenerationError("database_write_failed");
      },
      persist: async (response, token) => {
        const generated = completedOutput(response);
        const parsed = parseFlashcardCandidates(generated.text, input.count);
        const existingKeys = new Set(
          input.existingCards.map(duplicateKeyForRow),
        );
        const newKeys = new Set<string>();
        const cards = parsed.filter((card) => {
          const key = duplicateKey(card.front, card.back);
          if (existingKeys.has(key) || newKeys.has(key)) return false;
          newKeys.add(key);
          return true;
        });
        const actualCost = generationCost(
          generated.inputTokens,
          generated.outputTokens,
        );
        const { data, error } = await trustedClient!.rpc(
          "complete_flashcard_generation_internal",
          {
            p_user_id: input.userId,
            p_operation_id: input.operationId,
            p_material_id: input.materialId,
            p_cards: cards,
            p_model: model,
            p_input_tokens: generated.inputTokens,
            p_output_tokens: generated.outputTokens,
            p_actual_cost_usd: actualCost,
            p_reconciliation_token: token,
          },
        );
        if (error || !Array.isArray(data) || data.length !== cards.length) {
          generationLog("generate-flashcards", "known_failure", {
            reason: "database_write_failed",
            ...safeDatabaseFailure(error),
          });
          throw new SafeGenerationError("database_write_failed");
        }
        return data;
      },
      replay: async (ids) => {
        if (ids.length === 0) return [];
        const { data, error } = await trustedClient!.from("flashcards")
          .select("id,subject_id,material_id,front,back,topic,difficulty")
          .eq("user_id", input.userId)
          .in("id", ids)
          .is("deleted_at", null)
          .order("created_at", { ascending: true });
        if (error || !Array.isArray(data) || data.length !== ids.length) {
          throw new SafeGenerationError("database_write_failed");
        }
        return data;
      },
      fail: async (code, phase, token) => {
        const { error } = await trustedClient!.rpc(
          "fail_study_generation_reconciliation_internal",
          {
            p_user_id: input.userId,
            p_operation_id: input.operationId,
            p_safe_failure_code: code,
            p_failure_phase: phase,
            p_reconciliation_token: token ?? null,
          },
        );
        if (error) throw new SafeGenerationError("database_write_failed");
      },
      createToken: () => crypto.randomUUID(),
      wait: (milliseconds) =>
        new Promise((resolve) => setTimeout(resolve, milliseconds)),
    });
  },
  canonicalSource: canonicalStudySource,
  model,
  log: (stage, details) =>
    generationLog("generate-flashcards", stage, {
      ...details,
      ...(stage === "auth_verified" ? { reason: trustedSource } : {}),
    }),
}));

async function claimReconciliation(
  userId: string,
  operationId: string,
  token: string,
): Promise<StudyGenerationReconciliationClaim> {
  const { data, error } = await trustedClient!.rpc(
    "claim_study_generation_reconciliation_internal",
    {
      p_user_id: userId,
      p_operation_id: operationId,
      p_reconciliation_token: token,
    },
  ).single();
  if (error || !isRecord(data)) {
    throw new SafeGenerationError("database_write_failed");
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
    if (!identity) throw new SafeGenerationError("database_write_failed");
    return { kind: "claimed", token, responseIdentity: identity };
  }
  return {
    kind: "active",
    status: status === "provider_claimed" || status === "reserved"
      ? "generating"
      : "reconciling",
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
      Authorization: `Bearer ${openAiApiKey}`,
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
  return providerResponseFromEnvelope(data);
}

function completedOutput(response: StudyGenerationProviderResponse) {
  if (response.status !== "completed") {
    throw new SafeGenerationError("provider_terminal_failed");
  }
  const text = extractResponseText(response.envelope);
  const usage = responseUsage(response.envelope);
  if (!text || usage.inputTokens === 0 || usage.outputTokens === 0) {
    throw new SafeGenerationError("response_parse_failed");
  }
  return { text, ...usage };
}

function clientFor(jwt: string) {
  return createClient(supabaseUrl, publicKey, {
    global: { headers: { Authorization: `Bearer ${jwt}` } },
  });
}

function requireTrusted() {
  if (!trustedClient) {
    throw new SafeGenerationError("configuration_unavailable");
  }
}

function ensureConfigured() {
  requireTrusted();
  if (!openAiApiKey || model !== defaultModel) {
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
  if (message.includes("generation_operation_conflict")) {
    return new SafeGenerationError("generation_operation_conflict", 409);
  }
  return new SafeGenerationError("database_write_failed");
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
