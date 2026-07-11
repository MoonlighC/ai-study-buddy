import { serve } from "https://deno.land/std@0.224.0/http/server.ts";
import { createClient, SupabaseClient } from "https://esm.sh/@supabase/supabase-js@2.45.4";
import { createDeleteMaterialHandler } from "./handler.ts";

const url = Deno.env.get("SUPABASE_URL") ?? "";
const anonKey = Deno.env.get("SUPABASE_ANON_KEY") ?? "";
const serviceRoleKey = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY") ?? "";
serve(async (request) => {
  if (!url || !anonKey || !serviceRoleKey) return new Response(JSON.stringify({ error: "Material deletion is unavailable." }), { status: 500 });
  let trustedClient: SupabaseClient | null = null;
  return createDeleteMaterialHandler({
    async verifyJwt(jwt) {
      const authenticatedClient = createClient(url, anonKey, { global: { headers: { Authorization: `Bearer ${jwt}` } }, auth: { persistSession: false, autoRefreshToken: false } });
      const { data, error } = await authenticatedClient.auth.getUser(jwt);
      const userId = error ? null : data.user?.id ?? null;
      if (userId) trustedClient = createClient(url, serviceRoleKey, { auth: { persistSession: false, autoRefreshToken: false } });
      return userId;
    },
    async begin(userId, id) { const { data, error } = await trustedClient!.rpc("begin_material_deletion_internal", { p_user_id: userId, p_material_id: id }).maybeSingle(); return error ? null : data; },
    async remove(bucket, path) { const { error } = await trustedClient!.storage.from(bucket).remove([path]); return { error: error !== null }; },
    async mark(userId, id, outcome, code) { const { error } = await trustedClient!.rpc("mark_material_storage_cleanup_internal", { p_user_id: userId, p_material_id: id, p_outcome: outcome, p_safe_error_code: code ?? null }); return !error; },
    async finalize(userId, id) { const { error } = await trustedClient!.rpc("finalize_material_deletion_internal", { p_user_id: userId, p_material_id: id }); return !error; },
    operationId: () => crypto.randomUUID(),
    log(stage, operationId, status, errorClass) { console.log(JSON.stringify({ stage, operation_id: operationId, status, ...(errorClass ? { error_class: errorClass } : {}) })); },
  })(request);
});
