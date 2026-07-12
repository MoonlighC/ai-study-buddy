import { serve } from "https://deno.land/std@0.224.0/http/server.ts";
import { createClient } from "https://esm.sh/@supabase/supabase-js@2.45.4";
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
const minQuizInputChars = 80;
const shortInputMessage = "Add more lecture text before generating a quiz.";
const defaultModel = "gpt-4.1-mini";
const retryableOpenAiStatuses = new Set([500, 502, 503, 504]);
const openAiRetryBackoffsMs = [500, 1200];

type QuizDraft = {
  title: string;
  questions: QuizQuestionDraft[];
};

type QuizQuestionDraft = {
  question: string;
  options: string[];
  correct_answer: string;
  explanation: string;
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
  let supabaseAnonKey = "";
  let supabaseServiceRoleKey = "";
  let trustedSource = "";
  try {
    ({
      publicKey: supabaseAnonKey,
      trustedKey: supabaseServiceRoleKey,
      trustedSource,
    } = resolveProjectKeys(Deno.env.get));
  } catch (error) {
    if (!(error instanceof SafeConfigurationError)) throw error;
  }
  const openAiApiKey = Deno.env.get("OPENAI_API_KEY") ?? "";
  const model = Deno.env.get("OPENAI_MODEL") ?? defaultModel;
  if (supabaseUrl.length === 0 || supabaseAnonKey.length === 0) {
    logKnownFailure("supabase_env_missing");
    return jsonResponse({ error: "Quiz generation is unavailable." }, 500);
  }

  let materialId = "";
  let requestedCount = 5;
  try {
    const body = await request.json();
    materialId = typeof body.material_id === "string"
      ? body.material_id.trim()
      : "";
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
  const { data: userData, error: userError } = await supabaseClient.auth
    .getUser(
      jwt,
    );
  const user = userData.user;
  if (userError || user === null) {
    logKnownFailure("auth_invalid");
    return jsonResponse({ error: "Authentication required." }, 401);
  }
  logStage("auth_verified", { reason: trustedSource });

  const { data: material, error: materialError } = await supabaseClient
    .from("materials")
    .select(
      "id,user_id,subject_id,title,kind,source_kind,content_text,processing_status",
    )
    .eq("id", materialId)
    .eq("user_id", user.id)
    .is("deleted_at", null)
    .maybeSingle();

  const contentText = typeof material?.content_text === "string"
    ? material.content_text.trim()
    : "";
  const materialOwnerId = typeof material?.user_id === "string"
    ? material.user_id
    : "";
  if (
    materialError ||
    material === null ||
    materialOwnerId !== user.id ||
    !isEligibleAiMaterial(material, contentText)
  ) {
    logKnownFailure("material_unavailable");
    return jsonResponse({ error: "Material unavailable." }, 404);
  }
  if (contentText.length < minQuizInputChars) {
    logKnownFailure("material_content_too_short", {
      content_length: contentText.length,
    });
    return jsonResponse({ error: shortInputMessage }, 400);
  }
  logStage("material_loaded", {
    content_length: contentText.length,
    requested_count: requestedCount,
  });

  const existingQuiz = await loadExistingQuiz(
    supabaseClient,
    user.id,
    materialId,
    requestedCount,
  );
  if (existingQuiz !== null) {
    logStage("completed", { created_count: existingQuiz.questions.length });
    return jsonResponse(existingQuiz);
  }

  if (openAiApiKey.length === 0) {
    logKnownFailure("openai_key_missing");
    return jsonResponse({ error: "Quiz generation is unavailable." }, 500);
  }
  if (supabaseServiceRoleKey.length === 0) {
    logKnownFailure("trusted_database_credential_missing");
    return jsonResponse({ error: "Quiz generation is unavailable." }, 500);
  }

  const trustedWriteClient = createClient(
    supabaseUrl,
    supabaseServiceRoleKey,
    { auth: { persistSession: false, autoRefreshToken: false } },
  );

  try {
    // TODO: Enforce daily_usage_limits server-side before making this request.
    const materialTitle = typeof material.title === "string"
      ? material.title.trim()
      : "Generated quiz";
    const draft = await generateQuiz(
      openAiApiKey,
      model,
      contentText.slice(0, maxInputChars),
      requestedCount,
      materialTitle,
    );
    logStage("parsed", { created_count: draft.questions.length });

    const subjectId = typeof material.subject_id === "string"
      ? material.subject_id
      : null;
    const { data: activeMaterial, error: activeMaterialError } =
      await supabaseClient
        .from("materials")
        .select("id")
        .eq("id", materialId)
        .eq("user_id", user.id)
        .is("deleted_at", null)
        .maybeSingle();
    if (activeMaterialError || activeMaterial === null) {
      logKnownFailure("material_inactive_before_write");
      return jsonResponse({ error: "Material unavailable." }, 404);
    }
    logStage("database_write_started", { requested_count: requestedCount });
    const { data: insertedQuiz, error: quizInsertError } =
      await trustedWriteClient
        .from("quizzes")
        .insert({
          user_id: user.id,
          subject_id: subjectId,
          material_id: materialId,
          title: draft.title,
          quiz_type: "practice",
          question_count: draft.questions.length,
          metadata: { source: "generate-quiz", model },
        })
        .select("id,material_id,title")
        .single();
    if (quizInsertError || insertedQuiz === null) {
      logKnownFailure(
        "database_write_failed",
        safeDatabaseFailure(quizInsertError),
      );
      return jsonResponse({
        error: "Could not save quiz.",
        code: "database_write_failed",
      }, 500);
    }

    const quizId = typeof insertedQuiz.id === "string" ? insertedQuiz.id : "";
    const rows = draft.questions.map((question, index) => ({
      user_id: user.id,
      quiz_id: quizId,
      subject_id: subjectId,
      material_id: materialId,
      question: question.question,
      options: question.options,
      correct_answer: question.correct_answer,
      explanation: question.explanation,
      topic: question.topic,
      difficulty: question.difficulty,
      sort_order: index,
      metadata: { source: "generate-quiz", model },
    }));
    const { data: insertedQuestions, error: questionInsertError } =
      await trustedWriteClient
        .from("quiz_questions")
        .insert(rows)
        .select(
          "id,quiz_id,subject_id,material_id,question,options,correct_answer,explanation,topic,difficulty,sort_order",
        )
        .order("sort_order", { ascending: true });
    if (questionInsertError || !Array.isArray(insertedQuestions)) {
      logKnownFailure(
        "database_write_failed",
        safeDatabaseFailure(questionInsertError),
      );
      await trustedWriteClient
        .from("quizzes")
        .delete()
        .eq("id", quizId)
        .eq("user_id", user.id);
      return jsonResponse({
        error: "Could not save quiz questions.",
        code: "database_write_failed",
      }, 500);
    }
    logStage("completed", { created_count: insertedQuestions.length });

    return jsonResponse({
      quiz_id: quizId,
      material_id: materialId,
      title: draft.title,
      questions: insertedQuestions,
    });
  } catch (error) {
    const reason = error instanceof SafeFunctionError
      ? error.reason
      : "unexpected_generation_failure";
    logKnownFailure(reason);
    return jsonResponse(
      { error: "Could not generate quiz.", code: reason },
      500,
    );
  }
});

async function loadExistingQuiz(
  supabaseClient: ReturnType<typeof createClient>,
  userId: string,
  materialId: string,
  count: number,
): Promise<Record<string, unknown> | null> {
  const { data: quiz, error: quizError } = await supabaseClient
    .from("quizzes")
    .select("id,material_id,title")
    .eq("user_id", userId)
    .eq("material_id", materialId)
    .is("deleted_at", null)
    .order("created_at", { ascending: false })
    .limit(1)
    .maybeSingle();
  if (quizError || quiz === null || typeof quiz.id !== "string") {
    return null;
  }

  const { data: questions, error: questionsError } = await supabaseClient
    .from("quiz_questions")
    .select(
      "id,quiz_id,subject_id,material_id,question,options,correct_answer,explanation,topic,difficulty,sort_order",
    )
    .eq("user_id", userId)
    .eq("quiz_id", quiz.id)
    .is("deleted_at", null)
    .order("sort_order", { ascending: true });
  if (questionsError || !Array.isArray(questions) || questions.length === 0) {
    return null;
  }

  return {
    quiz_id: quiz.id,
    material_id: materialId,
    title: typeof quiz.title === "string" ? quiz.title : "Generated quiz",
    questions: questions.slice(0, count),
  };
}

async function generateQuiz(
  apiKey: string,
  model: string,
  inputText: string,
  count: number,
  materialTitle: string,
): Promise<QuizDraft> {
  const data = await fetchOpenAiResponseWithRetry(
    apiKey,
    model,
    inputText,
    count,
  );
  const text = extractResponseText(data);
  return parseQuiz(text, count, materialTitle);
}

async function fetchOpenAiResponseWithRetry(
  apiKey: string,
  model: string,
  inputText: string,
  count: number,
): Promise<unknown> {
  const body = JSON.stringify({
    model,
    instructions:
      `Create ${count} multiple-choice study quiz questions from only the provided material. Return strict JSON only in this shape: {"title":"...","questions":[{"question":"...","options":["...","...","...","..."],"correct_answer":"...","explanation":"...","topic":"...","difficulty":"easy|medium|exam"}]}. Each options array must contain exactly 4 strings, and correct_answer must exactly match one option. Do not include markdown, flashcards, summaries, or outside facts.`,
    input: inputText,
    max_output_tokens: 2200,
  });

  for (
    let attempt = 1;
    attempt <= openAiRetryBackoffsMs.length + 1;
    attempt += 1
  ) {
    logStage("openai_request_started", { model, count, attempt });
    const response = await fetch("https://api.openai.com/v1/responses", {
      method: "POST",
      headers: {
        Authorization: `Bearer ${apiKey}`,
        "Content-Type": "application/json",
      },
      body,
    });
    let data: unknown;
    try {
      data = await response.json();
    } catch (_) {
      data = null;
    }
    logOpenAiResponse(response.status, data);
    if (response.ok) {
      return data;
    }

    const backoffMs = openAiRetryBackoffsMs[attempt - 1];
    if (
      retryableOpenAiStatuses.has(response.status) && backoffMs !== undefined
    ) {
      logStage("openai_retry_scheduled", {
        attempt,
        status: response.status,
        backoff_ms: backoffMs,
      });
      await delay(backoffMs);
      continue;
    }

    throw new SafeFunctionError(providerSafeCode(response.status));
  }

  throw new SafeFunctionError("openai_unavailable");
}

function parseQuiz(
  text: string,
  count: number,
  materialTitle: string,
): QuizDraft {
  let parsed: unknown;
  try {
    parsed = JSON.parse(text);
  } catch (_) {
    throw new SafeFunctionError("response_parse_failed");
  }
  if (!isRecord(parsed) || !Array.isArray(parsed.questions)) {
    throw new SafeFunctionError("response_parse_failed");
  }

  const questions: QuizQuestionDraft[] = [];
  for (const item of parsed.questions) {
    if (!isRecord(item)) {
      continue;
    }
    const question = stringValue(item.question);
    const options = Array.isArray(item.options)
      ? item.options.map(stringValue).filter((option) => option.length > 0)
      : [];
    const correctAnswer = stringValue(item.correct_answer);
    const explanation = stringValue(item.explanation);
    if (
      question.length === 0 ||
      options.length !== 4 ||
      correctAnswer.length === 0 ||
      !options.includes(correctAnswer) ||
      explanation.length === 0
    ) {
      continue;
    }
    questions.push({
      question,
      options,
      correct_answer: correctAnswer,
      explanation,
      topic: stringValue(item.topic) || "General",
      difficulty: difficultyValue(item.difficulty),
    });
    if (questions.length >= count) {
      break;
    }
  }
  if (questions.length === 0) {
    throw new SafeFunctionError("response_parse_failed");
  }

  return {
    title: stringValue(parsed.title) || `Quiz: ${materialTitle}`,
    questions,
  };
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
    return 5;
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

function delay(milliseconds: number): Promise<void> {
  return new Promise((resolve) => setTimeout(resolve, milliseconds));
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

function isEligibleAiMaterial(
  material: Record<string, unknown>,
  content: string,
) {
  if (content.length === 0) return false;
  return (material.kind === "pasted_text" &&
    material.source_kind === "manual") ||
    (material.kind === "pdf" && material.source_kind === "upload" &&
      material.processing_status === "ready") ||
    (material.kind === "image" && material.source_kind === "upload" &&
      material.processing_status === "ready");
}

class SafeFunctionError extends Error {
  constructor(readonly reason: string) {
    super(reason);
  }
}

function logStage(stage: string, details: Record<string, unknown> = {}) {
  generationLog("generate-quiz", stage, details);
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
