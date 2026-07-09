import { serve } from "https://deno.land/std@0.224.0/http/server.ts";
import { createClient } from "https://esm.sh/@supabase/supabase-js@2.45.4";

const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type",
  "Access-Control-Allow-Methods": "POST, OPTIONS",
};

const maxInputChars = 12000;
const minFlashcardInputChars = 80;
const shortInputMessage = "Add more lecture text before generating flashcards.";
const defaultModel = "gpt-4.1-mini";

type FlashcardDraft = {
  front: string;
  back: string;
  topic: string;
  difficulty: "easy" | "medium" | "exam";
};

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
    return jsonResponse({ error: "Flashcard generation is unavailable." }, 500);
  }

  let materialId = "";
  let requestedCount = 10;
  try {
    const body = await request.json();
    materialId = typeof body.material_id === "string" ? body.material_id.trim() : "";
    requestedCount = clampCount(body.count);
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
    .select("id,user_id,subject_id,kind,source_kind,content_text")
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
  if (contentText.length < minFlashcardInputChars) {
    logKnownFailure("material_content_too_short", {
      content_length: contentText.length,
    });
    return jsonResponse({ error: shortInputMessage }, 400);
  }

  const { data: existingCards, error: existingCardsError } = await supabaseClient
    .from("flashcards")
    .select("id,subject_id,material_id,front,back,topic,difficulty")
    .eq("user_id", user.id)
    .eq("material_id", materialId)
    .is("deleted_at", null)
    .order("created_at", { ascending: true });
  if (!existingCardsError && Array.isArray(existingCards) && existingCards.length > 0) {
    logStage("existing_flashcards_returned", {
      material_id: materialId,
      count: existingCards.length,
    });
    return jsonResponse({
      material_id: materialId,
      flashcards: existingCards.slice(0, requestedCount),
    });
  }

  if (openAiApiKey.length === 0) {
    logKnownFailure("openai_key_missing");
    return jsonResponse({ error: "Flashcard generation is unavailable." }, 500);
  }

  try {
    // TODO: Enforce daily_usage_limits server-side before making this request.
    const drafts = await generateFlashcards(
      openAiApiKey,
      model,
      contentText.slice(0, maxInputChars),
      requestedCount,
    );
    logStage("flashcards_parsed", {
      material_id: materialId,
      count: drafts.length,
    });

    const subjectId = typeof material.subject_id === "string"
      ? material.subject_id
      : null;
    const rows = drafts.map((card) => ({
      user_id: user.id,
      subject_id: subjectId,
      material_id: materialId,
      front: card.front,
      back: card.back,
      topic: card.topic,
      difficulty: card.difficulty,
      metadata: { source: "generate-flashcards", model },
    }));
    const { data: insertedCards, error: insertError } = await supabaseClient
      .from("flashcards")
      .insert(rows)
      .select("id,subject_id,material_id,front,back,topic,difficulty");
    if (insertError || !Array.isArray(insertedCards)) {
      logKnownFailure("flashcards_insert_failed");
      return jsonResponse({ error: "Could not save flashcards." }, 500);
    }
    logStage("flashcards_inserted", {
      material_id: materialId,
      count: insertedCards.length,
    });

    return jsonResponse({ material_id: materialId, flashcards: insertedCards });
  } catch (error) {
    const reason = error instanceof SafeFunctionError
      ? error.reason
      : "unexpected_generation_failure";
    logKnownFailure(reason);
    return jsonResponse({ error: "Could not generate flashcards." }, 500);
  }
});

async function generateFlashcards(
  apiKey: string,
  model: string,
  inputText: string,
  count: number,
): Promise<FlashcardDraft[]> {
  logStage("openai_request_started", { model, count });
  const response = await fetch("https://api.openai.com/v1/responses", {
    method: "POST",
    headers: {
      Authorization: `Bearer ${apiKey}`,
      "Content-Type": "application/json",
    },
    body: JSON.stringify({
      model,
      instructions:
        `Create ${count} study flashcards from only the provided material. Return strict JSON only in this shape: {"flashcards":[{"front":"...","back":"...","topic":"...","difficulty":"easy|medium|exam"}]}. Do not include markdown, explanations, quiz questions, or outside facts.`,
      input: inputText,
      max_output_tokens: 1300,
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
  const text = extractResponseText(data);
  const cards = parseFlashcards(text, count);
  if (cards.length === 0) {
    throw new SafeFunctionError("flashcards_parse_failed");
  }
  return cards;
}

function parseFlashcards(text: string, count: number): FlashcardDraft[] {
  let parsed: unknown;
  try {
    parsed = JSON.parse(text);
  } catch (_) {
    throw new SafeFunctionError("flashcards_json_invalid");
  }
  if (!isRecord(parsed) || !Array.isArray(parsed.flashcards)) {
    throw new SafeFunctionError("flashcards_shape_invalid");
  }

  const cards: FlashcardDraft[] = [];
  for (const item of parsed.flashcards) {
    if (!isRecord(item)) {
      continue;
    }
    const front = stringValue(item.front);
    const back = stringValue(item.back);
    if (front.length === 0 || back.length === 0) {
      continue;
    }
    cards.push({
      front,
      back,
      topic: stringValue(item.topic) || "General",
      difficulty: difficultyValue(item.difficulty),
    });
    if (cards.length >= count) {
      break;
    }
  }
  return cards;
}

function extractResponseText(data: unknown): string {
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

function clampCount(value: unknown): number {
  if (typeof value !== "number" || !Number.isFinite(value)) {
    return 10;
  }
  return Math.max(1, Math.min(20, Math.floor(value)));
}

function stringValue(value: unknown): string {
  return typeof value === "string" ? value.trim() : "";
}

function difficultyValue(value: unknown): "easy" | "medium" | "exam" {
  return value === "easy" || value === "exam" || value === "medium"
    ? value
    : "medium";
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

function logKnownFailure(reason: string, details: Record<string, unknown> = {}) {
  logStage("known_failure", { reason, ...details });
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
