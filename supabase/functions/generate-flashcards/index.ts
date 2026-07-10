import { serve } from "https://deno.land/std@0.224.0/http/server.ts";
import { createClient } from "https://esm.sh/@supabase/supabase-js@2.45.4";

import {
  buildOpenAiRequestBody,
  createGenerateFlashcardsHandler,
  extractResponseText,
  FlashcardInsert,
} from "./handler.ts";

const defaultModel = "gpt-4.1-mini";
const supabaseUrl = Deno.env.get("SUPABASE_URL") ?? "";
const supabaseAnonKey = Deno.env.get("SUPABASE_ANON_KEY") ?? "";
const openAiApiKey = Deno.env.get("OPENAI_API_KEY") ?? "";
const model = Deno.env.get("OPENAI_MODEL") ?? defaultModel;

serve(createGenerateFlashcardsHandler({
  async verifyJwt(jwt) {
    if (!supabaseUrl || !supabaseAnonKey) return null;
    const client = clientFor(jwt);
    const { data, error } = await client.auth.getUser(jwt);
    return error || !data.user ? null : data.user.id;
  },
  async loadOwnedMaterial(userId, materialId, jwt) {
    const { data, error } = await clientFor(jwt)
      .from("materials")
      .select("id,user_id,subject_id,kind,source_kind,content_text,processing_status")
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
    if (!openAiApiKey) throw new Error("openai_key_missing");
    const response = await fetch("https://api.openai.com/v1/responses", {
      method: "POST",
      headers: {
        Authorization: `Bearer ${openAiApiKey}`,
        "Content-Type": "application/json",
      },
      body: JSON.stringify(buildOpenAiRequestBody(model, input.text, input.count)),
    });
    let data: unknown;
    try {
      data = await response.json();
    } catch (_) {
      data = null;
    }
    if (!response.ok) throw new Error("openai_request_failed");
    return extractResponseText(data);
  },
  async insertCards(rows: FlashcardInsert[], jwt) {
    if (rows.length === 0) return [];
    const { data, error } = await clientFor(jwt)
      .from("flashcards")
      .insert(rows)
      .select("id,subject_id,material_id,front,back,topic,difficulty");
    if (error || !Array.isArray(data)) throw new Error("flashcard_insert_failed");
    return data;
  },
  model,
}));

function clientFor(jwt: string) {
  return createClient(supabaseUrl, supabaseAnonKey, {
    global: { headers: { Authorization: `Bearer ${jwt}` } },
  });
}
