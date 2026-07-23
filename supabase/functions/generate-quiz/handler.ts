export const maxInputChars = 12_000;
export const minQuizInputChars = 80;
export const maxRequestedQuestionCount = 20;
export const shortInputMessage =
  "Add more lecture text before generating a quiz.";

export type QuizQuestionDraft = {
  question: string;
  options: string[];
  correct_answer: string;
  explanation: string;
  topic: string;
  difficulty: "easy" | "medium" | "exam";
};

export type QuizDraft = { title: string; questions: QuizQuestionDraft[] };
export type QuizResult = {
  quiz_id: string;
  material_id: string;
  title: string;
  questions: Record<string, unknown>[];
};

type Row = Record<string, unknown>;

export type GenerateQuizDependencies = {
  verifyJwt(jwt: string): Promise<string | null>;
  loadOwnedMaterial(userId: string, materialId: string): Promise<Row | null>;
  loadExistingQuiz(
    userId: string,
    materialId: string,
    count: number,
  ): Promise<QuizResult | null>;
  canonicalSource(material: Row): { kind: string; text: string };
  reserveOperation(
    input: {
      userId: string;
      operationId: string;
      materialId: string;
      requestHash: string;
      count: number;
    },
  ): Promise<{
    status:
      | "reserved"
      | "provider_claimed"
      | "reconciliation_required"
      | "persisting"
      | "succeeded"
      | "failed"
      | "failed_before_provider"
      | "failed_after_provider";
  }>;
  executeOperation(input: {
    userId: string;
    operationId: string;
    materialId: string;
    sourceText: string;
    count: number;
  }): Promise<QuizResult>;
  log?: (stage: string, details?: Record<string, unknown>) => void;
};

const headers = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers":
    "authorization, x-client-info, apikey, content-type",
  "Access-Control-Allow-Methods": "POST, OPTIONS",
};

export function createGenerateQuizHandler(deps: GenerateQuizDependencies) {
  return async (request: Request): Promise<Response> => {
    const log = deps.log ?? (() => {});
    if (request.method === "OPTIONS") return new Response("ok", { headers });
    if (request.method !== "POST") {
      return json({ error: "Method not allowed." }, 405);
    }
    const authorization = request.headers.get("Authorization") ?? "";
    const jwt = authorization.startsWith("Bearer ")
      ? authorization.slice(7).trim()
      : "";
    const userId = jwt ? await deps.verifyJwt(jwt) : null;
    if (!userId) return json({ error: "Authentication required." }, 401);

    let materialId = "";
    let operationId = "";
    let count = 0;
    try {
      const body: unknown = await request.json();
      if (
        !isRecord(body) || Object.keys(body).length !== 3 ||
        typeof body.material_id !== "string" ||
        typeof body.operation_id !== "string" ||
        typeof body.count !== "number" || !Number.isInteger(body.count) ||
        body.count < 1 || body.count > maxRequestedQuestionCount
      ) {
        return json({ error: "Invalid request." }, 400);
      }
      materialId = body.material_id.trim();
      operationId = body.operation_id.trim();
      count = body.count;
    } catch (_) {
      return json({ error: "Invalid request." }, 400);
    }
    if (!materialId || !uuidPattern.test(operationId)) {
      return json({ error: "Invalid request." }, 400);
    }

    try {
      const material = await deps.loadOwnedMaterial(userId, materialId);
      if (!material) return json({ error: "Material unavailable." }, 404);
      let source: { kind: string; text: string };
      try {
        source = deps.canonicalSource(material);
      } catch (_) {
        return json({ error: "Material unavailable." }, 404);
      }
      if (
        source.kind === "extracted_text" &&
        source.text.length < minQuizInputChars
      ) {
        return json({ error: shortInputMessage }, 400);
      }
      const existing = await deps.loadExistingQuiz(userId, materialId, count);
      if (existing) return json(existing);

      const requestHash = await sha256(
        `generate_quiz_questions\n${materialId}\n${count}`,
      );
      const reservation = await deps.reserveOperation({
        userId,
        operationId,
        materialId,
        requestHash,
        count,
      });
      if (
        reservation.status === "failed" ||
        reservation.status === "failed_before_provider" ||
        reservation.status === "failed_after_provider"
      ) {
        throw new SafeQuizGenerationError("generation_failed");
      }
      const result = await deps.executeOperation({
        userId,
        operationId,
        materialId,
        sourceText: source.text.slice(0, maxInputChars),
        count,
      });
      log("completed", { created_count: result.questions.length });
      return json(result);
    } catch (error) {
      const code = error instanceof SafeQuizGenerationError
        ? error.code
        : isRecord(error) && typeof error.safeCode === "string"
        ? error.safeCode
        : "generation_failed";
      return json(
        {
          error: "Could not generate quiz.",
          code,
          ...safeClientStatus(error),
        },
        error instanceof SafeQuizGenerationError && error.status
          ? error.status
          : isRecord(error) &&
              (error.clientStatus === "generating" ||
                error.clientStatus === "reconciling")
          ? 409
          : 500,
      );
    }
  };
}

function safeClientStatus(error: unknown) {
  if (
    isRecord(error) &&
    (error.clientStatus === "generating" ||
      error.clientStatus === "reconciling")
  ) {
    return { operation_status: error.clientStatus };
  }
  return {};
}

export class SafeQuizGenerationError extends Error {
  constructor(readonly code: string, readonly status?: number) {
    super(code);
  }
}

export function buildOpenAiRequestBody(
  model: string,
  input: string,
  count: number,
) {
  return {
    model,
    background: true,
    instructions:
      `Create exactly ${count} multiple-choice study questions using only the supplied material.`,
    input,
    max_output_tokens: Math.min(6_000, Math.max(1_500, 450 + count * 300)),
    text: {
      format: {
        type: "json_schema",
        name: "quiz_batch",
        strict: true,
        schema: {
          type: "object",
          properties: {
            title: { type: "string" },
            questions: {
              type: "array",
              minItems: count,
              maxItems: count,
              items: {
                type: "object",
                properties: {
                  question: { type: "string" },
                  options: {
                    type: "array",
                    minItems: 2,
                    maxItems: 8,
                    items: { type: "string" },
                  },
                  correct_answer: { type: "string" },
                  explanation: { type: "string" },
                  topic: { type: "string" },
                  difficulty: {
                    type: "string",
                    enum: ["easy", "medium", "exam"],
                  },
                },
                required: [
                  "question",
                  "options",
                  "correct_answer",
                  "explanation",
                  "topic",
                  "difficulty",
                ],
                additionalProperties: false,
              },
            },
          },
          required: ["title", "questions"],
          additionalProperties: false,
        },
      },
    },
  };
}

export function parseQuiz(text: string, count: number): QuizDraft {
  let parsed: unknown;
  try {
    parsed = JSON.parse(text);
  } catch (_) {
    throw new SafeQuizGenerationError("response_parse_failed");
  }
  if (
    !isRecord(parsed) || typeof parsed.title !== "string" ||
    !parsed.title.trim() ||
    !Array.isArray(parsed.questions) || parsed.questions.length !== count
  ) {
    throw new SafeQuizGenerationError("response_parse_failed");
  }
  const questions: QuizQuestionDraft[] = [];
  for (const value of parsed.questions) {
    if (
      !isRecord(value) ||
      Object.keys(value).sort().join(",") !==
        "correct_answer,difficulty,explanation,options,question,topic"
    ) {
      throw new SafeQuizGenerationError("response_parse_failed");
    }
    const question = stringValue(value.question);
    const answer = stringValue(value.correct_answer);
    const explanation = stringValue(value.explanation);
    const topic = stringValue(value.topic);
    const difficulty = value.difficulty;
    const options = Array.isArray(value.options)
      ? value.options.map(stringValue)
      : [];
    if (
      !question || !answer || !explanation || !topic || options.length < 2 ||
      options.length > 8 ||
      options.some((option) => !option) ||
      new Set(options).size !== options.length || !options.includes(answer) ||
      (difficulty !== "easy" && difficulty !== "medium" &&
        difficulty !== "exam")
    ) {
      throw new SafeQuizGenerationError("response_parse_failed");
    }
    questions.push({
      question,
      options,
      correct_answer: answer,
      explanation,
      topic,
      difficulty,
    });
  }
  return { title: parsed.title.trim(), questions };
}

export function extractResponseText(data: unknown) {
  if (!isRecord(data)) return "";
  if (typeof data.output_text === "string" && data.output_text.trim()) {
    return data.output_text.trim();
  }
  const parts: string[] = [];
  collect(data.output, parts);
  return parts.join("\n").trim();
}
function collect(value: unknown, parts: string[]) {
  if (typeof value === "string") {
    if (value.trim()) parts.push(value.trim());
    return;
  }
  if (Array.isArray(value)) {
    for (const item of value) collect(item, parts);
    return;
  }
  if (!isRecord(value)) return;
  if (typeof value.text === "string" && value.text.trim()) {
    parts.push(value.text.trim());
  }
  collect(value.content, parts);
}
async function sha256(value: string) {
  const digest = await crypto.subtle.digest(
    "SHA-256",
    new TextEncoder().encode(value),
  );
  return [...new Uint8Array(digest)].map((byte) =>
    byte.toString(16).padStart(2, "0")
  ).join("");
}
function stringValue(value: unknown) {
  return typeof value === "string" ? value.trim() : "";
}
function isRecord(value: unknown): value is Record<string, unknown> {
  return typeof value === "object" && value !== null && !Array.isArray(value);
}
const uuidPattern =
  /^[0-9a-f]{8}-[0-9a-f]{4}-4[0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$/iu;
function json(body: Record<string, unknown>, status = 200) {
  return new Response(JSON.stringify(body), {
    status,
    headers: { ...headers, "Content-Type": "application/json" },
  });
}
