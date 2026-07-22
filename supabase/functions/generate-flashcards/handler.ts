export const maxInputChars = 12_000;
export const minFlashcardInputChars = 80;
export const maxRequestedNewCount = 30;
export const shortInputMessage =
  "Add more lecture text before generating flashcards.";

export type FlashcardDraft = {
  front: string;
  back: string;
  topic: string;
  difficulty: "easy" | "medium" | "exam";
};

export type FlashcardInsert = FlashcardDraft & {
  user_id: string;
  subject_id: string | null;
  material_id: string;
  metadata: Record<string, unknown>;
};

export type GeneratedCandidates = {
  text: string;
  inputTokens: number;
  outputTokens: number;
};

export type GenerationReservation = {
  status: "reserved" | "succeeded" | "failed";
};

type MaterialRow = Record<string, unknown>;
type FlashcardRow = Record<string, unknown>;

export type GenerateFlashcardsDependencies = {
  verifyJwt(jwt: string): Promise<string | null>;
  loadOwnedMaterial(
    userId: string,
    materialId: string,
    jwt: string,
  ): Promise<MaterialRow | null>;
  loadExistingCards(
    userId: string,
    materialId: string,
    jwt: string,
  ): Promise<FlashcardRow[]>;
  generateCandidates(
    input: { text: string; count: number },
  ): Promise<GeneratedCandidates>;
  reserveOperation(input: {
    userId: string;
    operationId: string;
    materialId: string;
    requestHash: string;
    count: number;
  }): Promise<GenerationReservation>;
  claimProvider(userId: string, operationId: string): Promise<boolean>;
  awaitOperation(userId: string, operationId: string): Promise<FlashcardRow[]>;
  completeOperation(input: {
    userId: string;
    operationId: string;
    materialId: string;
    cards: FlashcardDraft[];
    inputTokens: number;
    outputTokens: number;
  }): Promise<FlashcardRow[]>;
  failOperation(
    userId: string,
    operationId: string,
    code: string,
    retainReservedCost: boolean,
  ): Promise<void>;
  canonicalSource(material: MaterialRow): { kind: string; text: string };
  model: string;
  log?: (stage: string, details?: Record<string, unknown>) => void;
};

const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers":
    "authorization, x-client-info, apikey, content-type",
  "Access-Control-Allow-Methods": "POST, OPTIONS",
};

export function createGenerateFlashcardsHandler(
  deps: GenerateFlashcardsDependencies,
) {
  return async (request: Request): Promise<Response> => {
    const log = deps.log ?? (() => {});
    log("request_received");
    if (request.method === "OPTIONS") {
      return new Response("ok", { headers: corsHeaders });
    }
    if (request.method !== "POST") {
      return json({ error: "Method not allowed." }, 405);
    }

    const authorization = request.headers.get("Authorization") ?? "";
    const jwt = authorization.startsWith("Bearer ")
      ? authorization.slice("Bearer ".length).trim()
      : "";
    if (!jwt) return json({ error: "Authentication required." }, 401);

    const userId = await deps.verifyJwt(jwt);
    if (!userId) return json({ error: "Authentication required." }, 401);
    log("auth_verified");

    let materialId = "";
    let requestedNewCount = 0;
    let operationId = "";
    try {
      const body: unknown = await request.json();
      if (
        !isRecord(body) || Object.keys(body).length !== 3 ||
        typeof body.material_id !== "string" ||
        typeof body.operation_id !== "string" ||
        typeof body.count !== "number" || !Number.isFinite(body.count) ||
        !Number.isInteger(body.count) || body.count < 1 ||
        body.count > maxRequestedNewCount
      ) {
        return json({ error: "Invalid request." }, 400);
      }
      materialId = body.material_id.trim();
      operationId = body.operation_id.trim();
      requestedNewCount = body.count;
    } catch (_) {
      return json({ error: "Invalid request." }, 400);
    }
    if (!materialId || !uuidPattern.test(operationId)) {
      return json({ error: "Invalid request." }, 400);
    }

    let ownsProvider = false;
    let providerSubmitted = false;
    try {
      const material = await deps.loadOwnedMaterial(userId, materialId, jwt);
      if (!material) {
        return json({ error: "Material unavailable." }, 404);
      }
      let source: { kind: string; text: string };
      try {
        source = deps.canonicalSource(material);
      } catch (_) {
        return json({ error: "Material unavailable." }, 404);
      }
      log("material_loaded", {
        source_kind: source.kind,
        content_length: source.text.length,
        requested_count: requestedNewCount,
      });
      if (
        source.kind === "extracted_text" &&
        source.text.length < minFlashcardInputChars
      ) {
        return json({ error: shortInputMessage }, 400);
      }

      const existingCards = await deps.loadExistingCards(
        userId,
        materialId,
        jwt,
      );
      const existingKeys = new Set(existingCards.map(duplicateKeyForRow));
      const requestHash = await sha256(
        `generate_flashcards\n${materialId}\n${requestedNewCount}`,
      );
      const reservation = await deps.reserveOperation({
        userId,
        operationId,
        materialId,
        requestHash,
        count: requestedNewCount,
      });
      if (reservation.status === "failed") {
        throw new SafeGenerationError("generation_failed");
      }
      ownsProvider = await deps.claimProvider(userId, operationId);
      if (!ownsProvider) {
        const joined = await deps.awaitOperation(userId, operationId);
        return success(materialId, requestedNewCount, joined);
      }
      log("openai_request_started", {
        model: deps.model,
        requested_count: requestedNewCount,
      });
      providerSubmitted = true;
      const generated = await deps.generateCandidates({
        text: source.text.slice(0, maxInputChars),
        count: requestedNewCount,
      });
      log("openai_response_received");
      const parsed = parseFlashcardCandidates(
        generated.text,
        requestedNewCount,
      );
      log("parsed", { requested_count: requestedNewCount });
      const uniqueKeys = new Set<string>();
      const uniqueDrafts = parsed.filter((card) => {
        const key = duplicateKey(card.front, card.back);
        if (existingKeys.has(key) || uniqueKeys.has(key)) return false;
        uniqueKeys.add(key);
        return true;
      });

      log("database_write_started", {
        requested_count: requestedNewCount,
        created_count: uniqueDrafts.length,
      });
      const insertedCards = await deps.completeOperation({
        userId,
        operationId,
        materialId,
        cards: uniqueDrafts,
        inputTokens: generated.inputTokens,
        outputTokens: generated.outputTokens,
      });
      if (insertedCards.length !== uniqueDrafts.length) {
        throw new Error("flashcard_insert_count_mismatch");
      }
      log("completed", {
        requested_count: requestedNewCount,
        created_count: insertedCards.length,
      });
      return success(materialId, requestedNewCount, insertedCards);
    } catch (error) {
      const code = error instanceof SafeGenerationError
        ? error.code
        : "generation_failed";
      log("known_failure", {
        code,
        status: error instanceof SafeGenerationError ? error.status : undefined,
      });
      if (ownsProvider) {
        try {
          await deps.failOperation(
            userId,
            operationId,
            code,
            providerSubmitted,
          );
        } catch (_) {
          log("operation_failure_finalize_failed", { code });
        }
      }
      return json(
        { error: "Could not generate flashcards.", code },
        error instanceof SafeGenerationError && error.status
          ? error.status
          : 500,
      );
    }
  };
}

function success(materialId: string, count: number, cards: FlashcardRow[]) {
  return json({
    material_id: materialId,
    requested_count: count,
    created_count: cards.length,
    flashcards: cards,
  });
}

async function sha256(value: string) {
  const bytes = new TextEncoder().encode(value);
  const digest = await crypto.subtle.digest("SHA-256", bytes);
  return [...new Uint8Array(digest)].map((byte) =>
    byte.toString(16).padStart(2, "0")
  ).join("");
}

export class SafeGenerationError extends Error {
  constructor(readonly code: string, readonly status?: number) {
    super(code);
  }
}

export function buildOpenAiRequestBody(
  model: string,
  inputText: string,
  requestedNewCount: number,
) {
  return {
    model,
    instructions:
      `Create exactly ${requestedNewCount} candidate new study flashcards from only the provided material. Each card must test a distinct useful fact or concept. Return no outside facts, markdown, explanations, or quiz questions.`,
    input: inputText,
    max_output_tokens: Math.min(
      6_000,
      Math.max(1_300, 400 + requestedNewCount * 180),
    ),
    text: {
      format: {
        type: "json_schema",
        name: "flashcard_batch",
        strict: true,
        schema: {
          type: "object",
          properties: {
            flashcards: {
              type: "array",
              minItems: requestedNewCount,
              maxItems: requestedNewCount,
              items: {
                type: "object",
                properties: {
                  front: { type: "string" },
                  back: { type: "string" },
                  topic: { type: "string" },
                  difficulty: {
                    type: "string",
                    enum: ["easy", "medium", "exam"],
                  },
                },
                required: ["front", "back", "topic", "difficulty"],
                additionalProperties: false,
              },
            },
          },
          required: ["flashcards"],
          additionalProperties: false,
        },
      },
    },
  };
}

export function parseFlashcardCandidates(
  text: string,
  requestedNewCount: number,
): FlashcardDraft[] {
  let parsed: unknown;
  try {
    parsed = JSON.parse(text);
  } catch (_) {
    throw new SafeGenerationError("response_parse_failed");
  }
  if (!isRecord(parsed) || !Array.isArray(parsed.flashcards)) {
    throw new SafeGenerationError("response_parse_failed");
  }

  const cards: FlashcardDraft[] = [];
  let inspected = 0;
  for (const item of parsed.flashcards) {
    if (inspected >= requestedNewCount) break;
    inspected += 1;
    if (!isRecord(item)) continue;
    const front = stringValue(item.front);
    const back = stringValue(item.back);
    const difficulty = difficultyValue(item.difficulty);
    if (!front || !back || !difficulty) continue;
    cards.push({
      front,
      back,
      topic: stringValue(item.topic) || "General",
      difficulty,
    });
  }
  return cards;
}

export function extractResponseText(data: unknown): string {
  if (!isRecord(data)) return "";
  if (typeof data.output_text === "string" && data.output_text.trim()) {
    return data.output_text.trim();
  }
  const parts: string[] = [];
  collectResponseText(data.output, parts);
  return parts.join("\n\n").trim();
}

function collectResponseText(value: unknown, parts: string[]) {
  if (typeof value === "string") {
    if (value.trim()) parts.push(value.trim());
    return;
  }
  if (Array.isArray(value)) {
    for (const item of value) collectResponseText(item, parts);
    return;
  }
  if (!isRecord(value)) return;
  if (typeof value.text === "string" && value.text.trim()) {
    parts.push(value.text.trim());
  }
  collectResponseText(value.content, parts);
}

function duplicateKeyForRow(row: FlashcardRow) {
  return duplicateKey(stringValue(row.front), stringValue(row.back));
}

function duplicateKey(front: string, back: string) {
  return `${normalizeForDuplicate(front)}\u0000${normalizeForDuplicate(back)}`;
}

function normalizeForDuplicate(value: string) {
  return value.normalize("NFC").replace(/\s+/g, " ").trim().toLowerCase();
}

function difficultyValue(
  value: unknown,
): "easy" | "medium" | "exam" | null {
  return value === "easy" || value === "exam" || value === "medium"
    ? value
    : null;
}

function stringValue(value: unknown) {
  return typeof value === "string" ? value.trim() : "";
}

const uuidPattern =
  /^[0-9a-f]{8}-[0-9a-f]{4}-4[0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$/iu;

function isRecord(value: unknown): value is Record<string, unknown> {
  return typeof value === "object" && value !== null && !Array.isArray(value);
}

function json(body: Record<string, unknown>, status = 200) {
  return new Response(JSON.stringify(body), {
    status,
    headers: { ...corsHeaders, "Content-Type": "application/json" },
  });
}
