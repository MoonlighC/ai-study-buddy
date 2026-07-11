import { serve } from "https://deno.land/std@0.224.0/http/server.ts";
import { createClient, SupabaseClient } from "https://esm.sh/@supabase/supabase-js@2.45.4";
import { createExtractImageTextHandler, MaterialRow } from "./handler.ts";
import { defaultImageOcrModel, requestImageOcr } from "./ocr_adapter.ts";

const materialColumns = "id,user_id,subject_id,title,kind,source_kind,content_text,summary," +
  "storage_bucket,storage_path,mime_type,file_size_bytes,processing_status,metadata,created_at";

serve(async (request) => {
  const url = Deno.env.get("SUPABASE_URL") ?? "";
  const anonKey = Deno.env.get("SUPABASE_ANON_KEY") ?? "";
  const serviceKey = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY") ?? "";
  const apiKey = Deno.env.get("OPENAI_API_KEY") ?? "";
  const model = Deno.env.get("IMAGE_OCR_MODEL") ?? defaultImageOcrModel;
  if (!url || !anonKey || !serviceKey || !apiKey) {
    return response({ error: "Image text extraction is unavailable." }, 500);
  }
  let authenticatedClient: SupabaseClient | null = null;
  const trustedClient = createClient(url, serviceKey, { auth: { persistSession: false, autoRefreshToken: false } });
  const handler = createExtractImageTextHandler({
    async verifyJwt(jwt) {
      authenticatedClient = createClient(url, anonKey, {
        global: { headers: { Authorization: `Bearer ${jwt}` } },
        auth: { persistSession: false, autoRefreshToken: false },
      });
      const { data, error } = await authenticatedClient.auth.getUser(jwt);
      return error ? null : data.user?.id ?? null;
    },
    async loadOwnedMaterial(userId, materialId) {
      if (!authenticatedClient) return null;
      const { data, error } = await authenticatedClient.from("materials").select(materialColumns)
        .eq("id", materialId).eq("user_id", userId).is("deleted_at", null).maybeSingle();
      return error || !data ? null : data as MaterialRow;
    },
    async claim(material, token) {
      const metadata = { ...record(material.metadata), image_ocr_claim: { token, claimed_at: new Date().toISOString() } };
      const { data, error } = await trustedClient.from("materials")
        .update({ processing_status: "processing", metadata }).eq("id", material.id)
        .eq("user_id", material.user_id).is("deleted_at", null)
        .in("processing_status", ["pending", "failed"]).or("content_text.is.null,content_text.eq.")
        .select(materialColumns).maybeSingle();
      return error || !data ? null : data as MaterialRow;
    },
    async restoreReady(material) {
      const { data, error } = await trustedClient.from("materials").update({ processing_status: "ready" })
        .eq("id", material.id).eq("user_id", material.user_id).is("deleted_at", null)
        .in("processing_status", ["pending", "failed"]).select(materialColumns).maybeSingle();
      return error || !data ? null : data as MaterialRow;
    },
    async download(material) {
      if (!authenticatedClient || !material.storage_bucket || !material.storage_path) throw new Error("download_unavailable");
      const { data, error } = await authenticatedClient.storage.from(material.storage_bucket).download(material.storage_path);
      if (error || !data) throw new Error("download_failed");
      return new Uint8Array(await data.arrayBuffer());
    },
    ocr: ({ bytes, mime }) => requestImageOcr({ apiKey, model, bytes, mime }),
    async succeed({ material, token, text, metadata: extraction }) {
      const metadata = omit(material.metadata, ["image_ocr_claim", "image_ocr_error"]);
      metadata.image_ocr = extraction;
      const { data, error } = await trustedClient.from("materials")
        .update({ content_text: text, processing_status: "ready", metadata })
        .eq("id", material.id).eq("user_id", material.user_id).is("deleted_at", null)
        .eq("processing_status", "processing").or("content_text.is.null,content_text.eq.")
        .contains("metadata", { image_ocr_claim: { token } }).select(materialColumns).maybeSingle();
      return error || !data ? null : data as MaterialRow;
    },
    async fail({ material, token, code, message }) {
      const metadata = omit(material.metadata, ["image_ocr_claim"]);
      metadata.image_ocr_error = { code, message };
      const { data, error } = await trustedClient.from("materials")
        .update({ processing_status: "failed", metadata }).eq("id", material.id)
        .eq("user_id", material.user_id).is("deleted_at", null).eq("processing_status", "processing")
        .contains("metadata", { image_ocr_claim: { token } }).select(materialColumns).maybeSingle();
      return error || !data ? null : data as MaterialRow;
    },
    token: () => crypto.randomUUID(), now: () => new Date().toISOString(), provider: "openai", model,
  });
  return handler(request);
});

function record(value: unknown): Record<string, unknown> {
  return typeof value === "object" && value !== null && !Array.isArray(value) ? { ...(value as Record<string, unknown>) } : {};
}
function omit(value: unknown, keys: string[]) { const result = record(value); for (const key of keys) delete result[key]; return result; }
function response(body: Record<string, unknown>, status: number) { return new Response(JSON.stringify(body), { status, headers: { "Content-Type": "application/json" } }); }
