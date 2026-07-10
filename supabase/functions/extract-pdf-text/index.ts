import { serve } from "https://deno.land/std@0.224.0/http/server.ts";
import { createClient, SupabaseClient } from "https://esm.sh/@supabase/supabase-js@2.45.4";
import {
  createExtractPdfTextHandler,
  MaterialRow,
} from "./handler.ts";
import { parseSelectablePdfText } from "./pdf_parser.ts";

const materialColumns =
  "id,user_id,subject_id,title,kind,source_kind,content_text,summary," +
  "storage_bucket,storage_path,mime_type,file_size_bytes,processing_status," +
  "metadata,created_at";

serve(async (request) => {
  const supabaseUrl = Deno.env.get("SUPABASE_URL") ?? "";
  const anonKey = Deno.env.get("SUPABASE_ANON_KEY") ?? "";
  const serviceRoleKey = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY") ?? "";
  if (!supabaseUrl || !anonKey || !serviceRoleKey) {
    return new Response(JSON.stringify({ error: "PDF extraction is unavailable." }), {
      status: 500,
      headers: { "Content-Type": "application/json" },
    });
  }

  let authenticatedClient: SupabaseClient | null = null;
  const trustedClient = createClient(supabaseUrl, serviceRoleKey, {
    auth: { persistSession: false, autoRefreshToken: false },
  });

  const handler = createExtractPdfTextHandler({
    async verifyJwt(jwt) {
      authenticatedClient = createClient(supabaseUrl, anonKey, {
        global: { headers: { Authorization: `Bearer ${jwt}` } },
        auth: { persistSession: false, autoRefreshToken: false },
      });
      const { data, error } = await authenticatedClient.auth.getUser(jwt);
      return error ? null : data.user?.id ?? null;
    },
    async loadOwnedMaterial(userId, materialId) {
      if (!authenticatedClient) return null;
      const { data, error } = await authenticatedClient.from("materials")
        .select(materialColumns)
        .eq("id", materialId)
        .eq("user_id", userId)
        .is("deleted_at", null)
        .maybeSingle();
      return error || !data ? null : data as MaterialRow;
    },
    async claim(material, token) {
      const metadata = { ...asRecord(material.metadata), pdf_extraction_claim: token };
      const { data, error } = await trustedClient.from("materials")
        .update({ processing_status: "processing", metadata })
        .eq("id", material.id)
        .eq("user_id", material.user_id)
        .is("deleted_at", null)
        .in("processing_status", ["pending", "failed"])
        .or("content_text.is.null,content_text.eq.")
        .select(materialColumns)
        .maybeSingle();
      return error || !data ? null : data as MaterialRow;
    },
    async restoreReady(material) {
      const { data, error } = await trustedClient.from("materials")
        .update({ processing_status: "ready" })
        .eq("id", material.id)
        .eq("user_id", material.user_id)
        .is("deleted_at", null)
        .in("processing_status", ["pending", "failed"])
        .select(materialColumns)
        .maybeSingle();
      return error || !data ? null : data as MaterialRow;
    },
    async download(material) {
      if (!authenticatedClient || !material.storage_bucket || !material.storage_path) {
        throw new Error("download_unavailable");
      }
      const { data, error } = await authenticatedClient.storage
        .from(material.storage_bucket)
        .download(material.storage_path);
      if (error || !data) throw new Error("download_failed");
      return new Uint8Array(await data.arrayBuffer());
    },
    parse: parseSelectablePdfText,
    async succeed({ material, token, text, metadata: extraction }) {
      const metadata = withoutKeys(material.metadata, [
        "pdf_extraction_claim",
        "pdf_extraction_error",
      ]);
      metadata.pdf_extraction = extraction;
      const { data, error } = await trustedClient.from("materials")
        .update({ content_text: text, processing_status: "ready", metadata })
        .eq("id", material.id)
        .eq("user_id", material.user_id)
        .is("deleted_at", null)
        .eq("processing_status", "processing")
        .or("content_text.is.null,content_text.eq.")
        .contains("metadata", { pdf_extraction_claim: token })
        .select(materialColumns)
        .maybeSingle();
      return error || !data ? null : data as MaterialRow;
    },
    async fail({ material, token, code, message, metadata: extraction }) {
      const metadata = withoutKeys(material.metadata, ["pdf_extraction_claim"]);
      if (extraction) metadata.pdf_extraction = extraction;
      metadata.pdf_extraction_error = { code, message };
      const { data, error } = await trustedClient.from("materials")
        .update({ processing_status: "failed", metadata })
        .eq("id", material.id)
        .eq("user_id", material.user_id)
        .is("deleted_at", null)
        .eq("processing_status", "processing")
        .contains("metadata", { pdf_extraction_claim: token })
        .select(materialColumns)
        .maybeSingle();
      return error || !data ? null : data as MaterialRow;
    },
    token: () => crypto.randomUUID(),
    now: () => new Date().toISOString(),
  });
  return handler(request);
});

function asRecord(value: unknown): Record<string, unknown> {
  return typeof value === "object" && value !== null && !Array.isArray(value)
    ? { ...(value as Record<string, unknown>) }
    : {};
}

function withoutKeys(value: unknown, keys: string[]) {
  const result = asRecord(value);
  for (const key of keys) delete result[key];
  return result;
}
