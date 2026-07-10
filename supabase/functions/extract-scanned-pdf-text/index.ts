import { serve } from "https://deno.land/std@0.224.0/http/server.ts";
import { createClient, SupabaseClient } from "https://esm.sh/@supabase/supabase-js@2.45.4";
import { getDocumentProxy } from "unpdf";
import { createHandler, MaterialRow } from "./handler.ts";
import { defaultScannedPdfOcrModel, requestPdfOcr } from "./pdf_ocr_adapter.ts";

const columns = "id,user_id,subject_id,title,kind,source_kind,content_text,summary,storage_bucket,storage_path,mime_type,file_size_bytes,processing_status,metadata,created_at";
serve(async (request) => {
  const url = Deno.env.get("SUPABASE_URL") ?? "", anon = Deno.env.get("SUPABASE_ANON_KEY") ?? "", service = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY") ?? "", apiKey = Deno.env.get("OPENAI_API_KEY") ?? "";
  if (!url || !anon || !service || !apiKey) return new Response(JSON.stringify({ error: "Scanned PDF OCR is unavailable." }), { status: 500, headers: { "Content-Type": "application/json" } });
  const model = Deno.env.get("SCANNED_PDF_OCR_MODEL")?.trim() || defaultScannedPdfOcrModel;
  let authenticated: SupabaseClient | null = null;
  const trusted = createClient(url, service, { auth: { persistSession: false, autoRefreshToken: false } });
  return createHandler({
    async verifyJwt(jwt) { authenticated = createClient(url, anon, { global: { headers: { Authorization: `Bearer ${jwt}` } }, auth: { persistSession: false, autoRefreshToken: false } }); const { data, error } = await authenticated.auth.getUser(jwt); return error ? null : data.user?.id ?? null; },
    async loadOwnedMaterial(userId, materialId) { if (!authenticated) return null; const { data, error } = await authenticated.from("materials").select(columns).eq("id", materialId).eq("user_id", userId).is("deleted_at", null).maybeSingle(); return error || !data ? null : data as MaterialRow; },
    async claim(material, token, claimedAt) { const metadata = { ...record(material.metadata), scanned_pdf_ocr_claim: { token, claimed_at: claimedAt } }; const pdf = record(record(material.metadata).pdf_extraction); const { data, error } = await trusted.from("materials").update({ processing_status: "processing", metadata }).eq("id", material.id).eq("user_id", material.user_id).is("deleted_at", null).eq("processing_status", "failed").or("content_text.is.null,content_text.eq.").contains("metadata", { pdf_extraction: { classification: pdf.classification } }).select(columns).maybeSingle(); return error || !data ? null : data as MaterialRow; },
    async download(material) { if (!authenticated || !material.storage_bucket || !material.storage_path) throw new Error(); const { data, error } = await authenticated.storage.from(material.storage_bucket).download(material.storage_path); if (error || !data) throw new Error(); return new Uint8Array(await data.arrayBuffer()); },
    async pageCount(bytes) { const document = await getDocumentProxy(bytes); return document.numPages; },
    ocr: (bytes, candidates) => requestPdfOcr({ apiKey, model, bytes, candidates }),
    async succeed({ material, token, text, metadata: extraction }) { const metadata = without(material.metadata, ["scanned_pdf_ocr_claim", "scanned_pdf_ocr_error"]); metadata.scanned_pdf_ocr = extraction; const { data, error } = await trusted.from("materials").update({ content_text: text, processing_status: "ready", metadata }).eq("id", material.id).eq("user_id", material.user_id).is("deleted_at", null).eq("processing_status", "processing").or("content_text.is.null,content_text.eq.").contains("metadata", { scanned_pdf_ocr_claim: { token } }).select(columns).maybeSingle(); return error || !data ? null : data as MaterialRow; },
    async fail({ material, token, code, message }) { const metadata = without(material.metadata, ["scanned_pdf_ocr_claim"]); metadata.scanned_pdf_ocr_error = { code, message }; const { data, error } = await trusted.from("materials").update({ processing_status: "failed", metadata }).eq("id", material.id).eq("user_id", material.user_id).is("deleted_at", null).eq("processing_status", "processing").contains("metadata", { scanned_pdf_ocr_claim: { token } }).select(columns).maybeSingle(); return error || !data ? null : data as MaterialRow; },
    token: () => crypto.randomUUID(), now: () => new Date().toISOString(), provider: "openai", model,
  })(request);
});
function record(v: unknown): Record<string, unknown> { return typeof v === "object" && v !== null && !Array.isArray(v) ? { ...(v as Record<string, unknown>) } : {}; }
function without(v: unknown, keys: string[]) { const result = record(v); for (const key of keys) delete result[key]; return result; }
