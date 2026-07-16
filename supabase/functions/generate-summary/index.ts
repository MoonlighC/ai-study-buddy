import { serve } from "https://deno.land/std@0.224.0/http/server.ts";
import { createClient } from "https://esm.sh/@supabase/supabase-js@2.45.4";

import {
  buildSummaryRequestBody,
  isPastedSummaryMaterial,
  isPhaseCUpload,
} from "./summary_prompt.ts";
import {
  generationLog,
  providerSafeCode,
  resolveProjectKeys,
  SafeConfigurationError,
  safeDatabaseFailure,
  safeProviderToken,
} from "../_shared/generation_runtime.ts";

const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers":
    "authorization, x-client-info, apikey, content-type",
  "Access-Control-Allow-Methods": "POST, OPTIONS",
};

const maxInputChars = 12000;
const minSummaryInputChars = 80;
const shortInputMessage = "Add more lecture text before generating a summary.";
const defaultModel = "gpt-4.1-mini";

export type SummaryHandlerDependencies = {
  env(name: string): string;
  verifyUser(input: {
    jwt: string;
    supabaseUrl: string;
    publicKey: string;
  }): Promise<string | null>;
  loadMaterial(input: {
    jwt: string;
    supabaseUrl: string;
    publicKey: string;
    userId: string;
    materialId: string;
  }): Promise<Record<string, unknown> | null>;
  saveSummary(input: {
    supabaseUrl: string;
    trustedKey: string;
    userId: string;
    materialId: string;
    summary: string;
  }): Promise<boolean>;
  generate(apiKey: string, model: string, text: string): Promise<string>;
};

export function createGenerateSummaryHandler(deps: SummaryHandlerDependencies) {
  return async (request: Request) => {
    logStage("request_received", { method: request.method });
    if (request.method === "OPTIONS") {
      return new Response("ok", { headers: corsHeaders });
    }
    if (request.method !== "POST") {
      return jsonResponse({ error: "Method not allowed." }, 405);
    }

    const authorization = request.headers.get("Authorization") ?? "";
    const jwt = authorization.startsWith("Bearer ")
      ? authorization.substring("Bearer ".length).trim()
      : "";
    if (jwt.length === 0) {
      logKnownFailure("auth_missing");
      return jsonResponse({ error: "Authentication required." }, 401);
    }

    const supabaseUrl = deps.env("SUPABASE_URL");
    let supabaseAnonKey = "";
    let serviceRoleKey = "";
    let trustedSource = "";
    try {
      ({
        publicKey: supabaseAnonKey,
        trustedKey: serviceRoleKey,
        trustedSource,
      } = resolveProjectKeys((name) => deps.env(name)));
    } catch (error) {
      if (!(error instanceof SafeConfigurationError)) throw error;
    }
    const openAiApiKey = deps.env("OPENAI_API_KEY");
    const model = deps.env("OPENAI_MODEL") || defaultModel;
    if (
      supabaseUrl.length === 0 || supabaseAnonKey.length === 0 ||
      serviceRoleKey.length === 0
    ) {
      logKnownFailure("supabase_env_missing");
      return jsonResponse({ error: "Summary generation is unavailable." }, 500);
    }

    let materialId = "";
    try {
      const body = await request.json();
      materialId = typeof body.material_id === "string"
        ? body.material_id.trim()
        : "";
    } catch (_) {
      logKnownFailure("invalid_json");
      return jsonResponse({ error: "Invalid request." }, 400);
    }
    if (materialId.length === 0) {
      logKnownFailure("material_id_missing");
      return jsonResponse({ error: "Invalid request." }, 400);
    }

    const userId = await deps.verifyUser({
      jwt,
      supabaseUrl,
      publicKey: supabaseAnonKey,
    });
    if (!userId) {
      logKnownFailure("auth_invalid");
      return jsonResponse({ error: "Authentication required." }, 401);
    }
    logStage("auth_verified", { reason: trustedSource });

    const material = await deps.loadMaterial({
      jwt,
      supabaseUrl,
      publicKey: supabaseAnonKey,
      userId,
      materialId,
    });

    const contentText = typeof material?.content_text === "string"
      ? material.content_text.trim()
      : "";
    if (material === null) {
      logKnownFailure("material_unavailable");
      return jsonResponse({ error: "Material unavailable." }, 404);
    }
    if (isPhaseCUpload(material)) {
      logKnownFailure("phase_c_processing_required");
      return jsonResponse(
        { error: "Use material analysis for uploaded files." },
        409,
      );
    }
    if (!isPastedSummaryMaterial(material, contentText)) {
      logKnownFailure("material_unavailable");
      return jsonResponse({ error: "Material unavailable." }, 404);
    }
    logStage("material_loaded", { content_length: contentText.length });
    if (contentText.length < minSummaryInputChars) {
      logKnownFailure("material_content_too_short", {
        content_length: contentText.length,
      });
      return jsonResponse({ error: shortInputMessage }, 400);
    }
    if (openAiApiKey.length === 0) {
      logKnownFailure("openai_key_missing");
      return jsonResponse({ error: "Summary generation is unavailable." }, 500);
    }

    try {
      // TODO: Enforce daily_usage_limits server-side before making this request.
      // Phase 9B.1 intentionally summarizes only the current capped input.
      const summary = await deps.generate(
        openAiApiKey,
        model,
        contentText.slice(0, maxInputChars),
      );
      logStage("parsed");
      logStage("database_write_started");
      const saved = await deps.saveSummary({
        supabaseUrl,
        trustedKey: serviceRoleKey,
        userId,
        materialId,
        summary,
      });
      if (!saved) {
        logKnownFailure(
          "database_write_failed",
          safeDatabaseFailure(null),
        );
        return jsonResponse({
          error: "Could not save summary.",
          code: "database_write_failed",
        }, 500);
      }
      logStage("completed");

      return jsonResponse({ material_id: materialId, summary });
    } catch (error) {
      const reason = error instanceof SafeFunctionError
        ? error.reason
        : "unexpected_generation_failure";
      logKnownFailure(reason);
      return jsonResponse(
        { error: "Could not generate summary.", code: reason },
        500,
      );
    }
  };
}

const runtimeDependencies: SummaryHandlerDependencies = {
  env: (name) => Deno.env.get(name) ?? "",
  async verifyUser(input) {
    const client = createClient(input.supabaseUrl, input.publicKey, {
      global: { headers: { Authorization: `Bearer ${input.jwt}` } },
    });
    const { data, error } = await client.auth.getUser(input.jwt);
    return error || !data.user ? null : data.user.id;
  },
  async loadMaterial(input) {
    const client = createClient(input.supabaseUrl, input.publicKey, {
      global: { headers: { Authorization: `Bearer ${input.jwt}` } },
    });
    const { data, error } = await client.from("materials")
      .select("id,user_id,kind,source_kind,content_text,processing_status")
      .eq("id", input.materialId)
      .eq("user_id", input.userId)
      .is("deleted_at", null)
      .maybeSingle();
    return error || !data ? null : data as Record<string, unknown>;
  },
  async saveSummary(input) {
    const client = createClient(input.supabaseUrl, input.trustedKey, {
      auth: { persistSession: false, autoRefreshToken: false },
    });
    const { data, error } = await client.from("materials")
      .update({ summary: input.summary })
      .eq("id", input.materialId)
      .eq("user_id", input.userId)
      .is("deleted_at", null)
      .select("id");
    return !error && Array.isArray(data) && data.length === 1;
  },
  generate: (apiKey, model, text) =>
    generateSummary(apiKey, model, text, false),
};

if (import.meta.main) serve(createGenerateSummaryHandler(runtimeDependencies));

async function generateSummary(
  apiKey: string,
  model: string,
  inputText: string,
  isReadyUpload: boolean,
): Promise<string> {
  logStage("openai_request_started", { model });
  const response = await fetch("https://api.openai.com/v1/responses", {
    method: "POST",
    headers: {
      Authorization: `Bearer ${apiKey}`,
      "Content-Type": "application/json",
    },
    body: JSON.stringify(
      buildSummaryRequestBody(model, inputText, isReadyUpload),
    ),
  });
  let data: unknown;
  try {
    data = await response.json();
  } catch (_) {
    data = null;
  }
  logOpenAiResponse(response.status, data);
  if (!response.ok) {
    throw new SafeFunctionError(providerSafeCode(response.status));
  }
  const summary = extractSummaryText(data);
  if (summary.length === 0) {
    throw new SafeFunctionError("response_parse_failed");
  }
  return summary;
}

function extractSummaryText(data: unknown): string {
  if (!isRecord(data)) {
    return "";
  }
  const outputText = data.output_text;
  if (typeof outputText === "string" && outputText.trim().length > 0) {
    return outputText.trim();
  }

  const textParts: string[] = [];
  const output = data.output;
  if (Array.isArray(output)) {
    for (const outputItem of output) {
      collectResponseText(outputItem, textParts);
    }
  }
  return textParts.join("\n\n").trim();
}

function collectResponseText(value: unknown, textParts: string[]) {
  if (typeof value === "string") {
    const trimmedValue = value.trim();
    if (trimmedValue.length > 0) {
      textParts.push(trimmedValue);
    }
    return;
  }
  if (!isRecord(value)) {
    return;
  }

  const text = value.text;
  if (typeof text === "string" && text.trim().length > 0) {
    textParts.push(text.trim());
  }

  const content = value.content;
  if (Array.isArray(content)) {
    for (const contentItem of content) {
      collectResponseText(contentItem, textParts);
    }
  }
}

function jsonResponse(body: Record<string, unknown>, status = 200) {
  return new Response(JSON.stringify(body), {
    status,
    headers: {
      ...corsHeaders,
      "Content-Type": "application/json",
    },
  });
}

class SafeFunctionError extends Error {
  constructor(readonly reason: string) {
    super(reason);
  }
}

function logStage(stage: string, details: Record<string, unknown> = {}) {
  generationLog("generate-summary", stage, details);
}

function logKnownFailure(
  reason: string,
  details: Record<string, unknown> = {},
) {
  logStage("known_failure", { reason, ...details });
}

function logOpenAiResponse(status: number, data: unknown) {
  const error = isRecord(data) && isRecord(data.error) ? data.error : null;
  logStage("openai_response_received", {
    status,
    code: safeProviderToken(error?.code) ?? providerSafeCode(status),
    reason: safeProviderToken(error?.type),
  });
}

function isRecord(value: unknown): value is Record<string, unknown> {
  return typeof value === "object" && value !== null;
}
