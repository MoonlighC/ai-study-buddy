import { serve } from "serve";
import { createClient } from "supabase-js";
import { resolveProjectKeys } from "../_shared/generation_runtime.ts";
import { createLatexDiagnosticHandler } from "./handler.ts";

const supabaseUrl = requiredEnv("SUPABASE_URL");
const { trustedKey } = resolveProjectKeys(Deno.env.get);
const handler = createLatexDiagnosticHandler({
  operatorKey: requiredEnv("MATERIAL_ANALYSIS_LATEX_DIAGNOSTIC_KEY"),
  openAiKey: requiredEnv("OPENAI_API_KEY"),
  database: createClient(supabaseUrl, trustedKey, {
    auth: { persistSession: false, autoRefreshToken: false },
  }),
});
serve(handler);

function requiredEnv(name: string) {
  const value = Deno.env.get(name)?.trim();
  if (!value) throw new Error("configuration_unavailable");
  return value;
}
