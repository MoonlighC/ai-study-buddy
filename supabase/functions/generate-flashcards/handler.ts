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
  generateCandidates(input: { text: string; count: number }): Promise<string>;
  insertCards(rows: FlashcardInsert[], jwt: string): Promise<FlashcardRow[]>;
  model: string;
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

    let materialId = "";
    let requestedNewCount = 0;
    try {
      const body: unknown = await request.json();
      if (!isRecord(body) || Object.keys(body).length !== 2 ||
        typeof body.material_id !== "string" ||
        typeof body.count !== "number" || !Number.isFinite(body.count) ||
        !Number.isInteger(body.count) || body.count < 1 ||
        body.count > maxRequestedNewCount) {
        return json({ error: "Invalid request." }, 400);
      }
      materialId = body.material_id.trim();
      requestedNewCount = body.count;
    } catch (_) {
      return json({ error: "Invalid request." }, 400);
    }
    if (!materialId) return json({ error: "Invalid request." }, 400);

    try {
      const material = await deps.loadOwnedMaterial(userId, materialId, jwt);
      const contentText = stringValue(material?.content_text);
      if (!material || !isEligibleAiMaterial(material, contentText)) {
        return json({ error: "Material unavailable." }, 404);
      }
      if (contentText.length < minFlashcardInputChars) {
        return json({ error: shortInputMessage }, 400);
      }

      const existingCards = await deps.loadExistingCards(
        userId,
        materialId,
        jwt,
      );
      const existingKeys = new Set(existingCards.map(duplicateKeyForRow));
      const generatedText = await deps.generateCandidates({
        text: contentText.slice(0, maxInputChars),
        count: requestedNewCount,
      });
      const parsed = parseFlashcardCandidates(generatedText, requestedNewCount);
      const uniqueKeys = new Set<string>();
      const uniqueDrafts = parsed.filter((card) => {
        const key = duplicateKey(card.front, card.back);
        if (existingKeys.has(key) || uniqueKeys.has(key)) return false;
        uniqueKeys.add(key);
        return true;
      });

      const subjectId = typeof material.subject_id === "string"
        ? material.subject_id
        : null;
      const rows: FlashcardInsert[] = uniqueDrafts.map((card) => ({
        user_id: userId,
        subject_id: subjectId,
        material_id: materialId,
        front: card.front,
        back: card.back,
        topic: card.topic,
        difficulty: card.difficulty,
        metadata: { source: "generate-flashcards", model: deps.model },
      }));
      const insertedCards = rows.length === 0
        ? []
        : await deps.insertCards(rows, jwt);
      if (insertedCards.length !== rows.length) {
        throw new Error("flashcard_insert_count_mismatch");
      }

      // TODO: Feed requested_count and created_count into daily_usage_limits
      // and usage_logs when quota enforcement is implemented.
      return json({
        material_id: materialId,
        requested_count: requestedNewCount,
        created_count: insertedCards.length,
        flashcards: insertedCards,
      });
    } catch (_) {
      return json({ error: "Could not generate flashcards." }, 500);
    }
  };
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
    throw new Error("flashcards_json_invalid");
  }
  if (!isRecord(parsed) || !Array.isArray(parsed.flashcards)) {
    throw new Error("flashcards_shape_invalid");
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

function isEligibleAiMaterial(material: MaterialRow, content: string) {
  if (!content) return false;
  return (material.kind === "pasted_text" && material.source_kind === "manual") ||
    (material.kind === "pdf" && material.source_kind === "upload" &&
      material.processing_status === "ready") ||
    (material.kind === "image" && material.source_kind === "upload" &&
      material.processing_status === "ready");
}

function isRecord(value: unknown): value is Record<string, unknown> {
  return typeof value === "object" && value !== null && !Array.isArray(value);
}

function json(body: Record<string, unknown>, status = 200) {
  return new Response(JSON.stringify(body), {
    status,
    headers: { ...corsHeaders, "Content-Type": "application/json" },
  });
}
