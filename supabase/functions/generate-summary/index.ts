import { serve } from "https://deno.land/std@0.224.0/http/server.ts";
import { createClient } from "https://esm.sh/@supabase/supabase-js@2.45.4";

const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type",
  "Access-Control-Allow-Methods": "POST, OPTIONS",
};

const maxInputChars = 12000;
const defaultModel = "gpt-4.1-mini";

serve(async (request) => {
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

  const supabaseUrl = Deno.env.get("SUPABASE_URL") ?? "";
  const supabaseAnonKey = Deno.env.get("SUPABASE_ANON_KEY") ?? "";
  const openAiApiKey = Deno.env.get("OPENAI_API_KEY") ?? "";
  const model = Deno.env.get("OPENAI_MODEL") ?? defaultModel;
  if (supabaseUrl.length === 0 || supabaseAnonKey.length === 0) {
    logKnownFailure("supabase_env_missing");
    return jsonResponse({ error: "Summary generation is unavailable." }, 500);
  }

  let materialId = "";
  try {
    const body = await request.json();
    materialId = typeof body.material_id === "string" ? body.material_id.trim() : "";
  } catch (_) {
    logKnownFailure("invalid_json");
    return jsonResponse({ error: "Invalid request." }, 400);
  }
  if (materialId.length === 0) {
    logKnownFailure("material_id_missing");
    return jsonResponse({ error: "Invalid request." }, 400);
  }

  const supabaseClient = createClient(supabaseUrl, supabaseAnonKey, {
    global: { headers: { Authorization: `Bearer ${jwt}` } },
  });
  const { data: userData, error: userError } = await supabaseClient.auth.getUser(
    jwt,
  );
  const user = userData.user;
  if (userError || user === null) {
    logKnownFailure("auth_invalid");
    return jsonResponse({ error: "Authentication required." }, 401);
  }
  logStage("auth_verified", { user_id: user.id });

  const { data: material, error: materialError } = await supabaseClient
    .from("materials")
    .select("id,user_id,kind,source_kind,content_text")
    .eq("id", materialId)
    .eq("user_id", user.id)
    .eq("kind", "pasted_text")
    .eq("source_kind", "manual")
    .is("deleted_at", null)
    .maybeSingle();

  const contentText = typeof material?.content_text === "string"
    ? material.content_text.trim()
    : "";
  if (materialError || material === null || contentText.length === 0) {
    logKnownFailure("material_unavailable");
    return jsonResponse({ error: "Material unavailable." }, 404);
  }
  logStage("material_loaded", {
    material_id: materialId,
    content_length: contentText.length,
  });
  if (openAiApiKey.length === 0) {
    await markMaterialFailed(supabaseClient, materialId, user.id);
    logKnownFailure("openai_key_missing");
    return jsonResponse({ error: "Summary generation is unavailable." }, 500);
  }

  await supabaseClient
    .from("materials")
    .update({ processing_status: "processing" })
    .eq("id", materialId)
    .eq("user_id", user.id);

  try {
    // TODO: Enforce daily_usage_limits server-side before making this request.
    const summary = await generateSummary(
      openAiApiKey,
      model,
      contentText.slice(0, maxInputChars),
    );
    logStage("summary_parsed", { material_id: materialId });
    const { error: updateError } = await supabaseClient
      .from("materials")
      .update({ summary, processing_status: "ready" })
      .eq("id", materialId)
      .eq("user_id", user.id);
    if (updateError) {
      await markMaterialFailed(supabaseClient, materialId, user.id);
      logKnownFailure("material_update_failed");
      return jsonResponse({ error: "Could not save summary." }, 500);
    }
    logStage("material_updated", { material_id: materialId });

    return jsonResponse({ material_id: materialId, summary });
  } catch (error) {
    await markMaterialFailed(supabaseClient, materialId, user.id);
    const reason = error instanceof SafeFunctionError
      ? error.reason
      : "unexpected_generation_failure";
    logKnownFailure(reason);
    return jsonResponse({ error: "Could not generate summary." }, 500);
  }
});

async function generateSummary(
  apiKey: string,
  model: string,
  inputText: string,
): Promise<string> {
  logStage("openai_request_started", { model });
  const response = await fetch("https://api.openai.com/v1/responses", {
    method: "POST",
    headers: {
      Authorization: `Bearer ${apiKey}`,
      "Content-Type": "application/json",
    },
    body: JSON.stringify({
      model,
      instructions:
        "Create a concise study summary for a student. Focus only on the provided material. Use 4 to 6 sentences. Do not add flashcards, quiz questions, or unrelated advice.",
      input: inputText,
      max_output_tokens: 220,
    }),
  });
  let data: unknown;
  try {
    data = await response.json();
  } catch (_) {
    data = null;
  }
  logOpenAiResponse(response.status, data);
  if (!response.ok) {
    throw new SafeFunctionError("openai_request_failed");
  }
  const summary = extractSummaryText(data);
  if (summary.length === 0) {
    throw new SafeFunctionError("summary_parse_failed");
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

async function markMaterialFailed(
  supabaseClient: ReturnType<typeof createClient>,
  materialId: string,
  userId: string,
) {
  await supabaseClient
    .from("materials")
    .update({ processing_status: "failed" })
    .eq("id", materialId)
    .eq("user_id", userId);
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
  console.log(JSON.stringify({ stage, ...details }));
}

function logKnownFailure(reason: string) {
  logStage("known_failure", { reason });
}

function logOpenAiResponse(status: number, data: unknown) {
  const error = isRecord(data) && isRecord(data.error) ? data.error : null;
  logStage("openai_response_received", {
    status,
    error_type: typeof error?.type === "string" ? error.type : undefined,
    error_message: safeErrorMessage(error?.message),
  });
}

function safeErrorMessage(value: unknown): string | undefined {
  if (typeof value !== "string") {
    return undefined;
  }
  return value.replace(/\s+/g, " ").slice(0, 160);
}

function isRecord(value: unknown): value is Record<string, unknown> {
  return typeof value === "object" && value !== null;
}
