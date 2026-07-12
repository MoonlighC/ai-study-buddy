import { serve } from "https://deno.land/std@0.224.0/http/server.ts";
import { createClient } from "https://esm.sh/@supabase/supabase-js@2.45.4";

import {
  buildOpenAiRequestBody,
  createGenerateFlashcardsHandler,
  extractResponseText,
  FlashcardInsert,
  SafeGenerationError,
} from "./handler.ts";
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
  async loadOwnedMaterial(userId, materialId, jwt) {
    const { data, error } = await clientFor(jwt)
      .from("materials")
      .select(
        "id,user_id,subject_id,kind,source_kind,content_text,processing_status",
      )
      .eq("id", materialId)
      .eq("user_id", userId)
      .is("deleted_at", null)
      .maybeSingle();
    if (error) throw new Error("material_load_failed");
    return data;
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
    return text;
  },
  async recheckActiveMaterial(userId, materialId, jwt) {
    const { data, error } = await clientFor(jwt).from("materials").select("id")
      .eq("id", materialId).eq("user_id", userId).is("deleted_at", null)
      .maybeSingle();
    return !error && data !== null;
  },
  async insertCards(rows: FlashcardInsert[]) {
    if (rows.length === 0) return [];
    if (!trustedClient) {
      throw new SafeGenerationError("configuration_unavailable");
    }
    const { data, error } = await trustedClient
      .from("flashcards")
      .insert(rows)
      .select("id,subject_id,material_id,front,back,topic,difficulty");
    if (error || !Array.isArray(data)) {
      generationLog("generate-flashcards", "known_failure", {
        reason: "database_write_failed",
        ...safeDatabaseFailure(error),
      });
      throw new SafeGenerationError("database_write_failed");
    }
    return data;
  },
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
