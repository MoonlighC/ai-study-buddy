import { createClient } from "supabase-js";
import { resolveProjectKeys } from "../generation_runtime.ts";
import { SourceMaterial } from "./engine.ts";
import { AnalysisDependencies, InternalWorkUnit } from "./handlers.ts";
import { TrustedOpenAiAdapter } from "./openai_adapter.ts";

type RpcClient = {
  rpc(
    name: string,
    args: Record<string, unknown>,
  ): PromiseLike<{ data: unknown; error: unknown }>;
};

export function createAnalysisDependencies(jwt: string): AnalysisDependencies {
  const supabaseUrl = requiredEnv("SUPABASE_URL");
  const { publicKey, trustedKey } = resolveProjectKeys(Deno.env.get);
  const openAiKey = requiredEnv("OPENAI_API_KEY");
  const model = Deno.env.get("MATERIAL_ANALYSIS_MODEL")?.trim() ||
    "gpt-5.4-mini";
  const authenticated = createClient(supabaseUrl, publicKey, {
    global: { headers: { Authorization: `Bearer ${jwt}` } },
    auth: { persistSession: false, autoRefreshToken: false },
  });
  const trusted = createClient(supabaseUrl, trustedKey, {
    auth: { persistSession: false, autoRefreshToken: false },
  });
  return {
    async verifyJwt(candidate) {
      if (candidate !== jwt) return null;
      const { data, error } = await authenticated.auth.getUser(candidate);
      return error || !data.user ? null : data.user.id;
    },
    async loadSource(principalId, materialId) {
      const { data, error } = await authenticated.from("materials")
        .select("id")
        .eq("id", materialId)
        .eq("user_id", principalId)
        .is("deleted_at", null)
        .eq("source_kind", "upload")
        .in("kind", ["pdf", "image"])
        .maybeSingle();
      if (error || !data) throw new Error("trusted_rpc_failed");
      return await rpcOne(trusted, "load_material_analysis_source_internal", {
        p_material_id: materialId,
      });
    },
    async downloadPrivate(material: SourceMaterial) {
      const { data, error } = await trusted.storage.from(
        material.storage_bucket,
      )
        .download(material.storage_path);
      if (error || !data) throw new Error("private_download_failed");
      return new Uint8Array(await data.arrayBuffer());
    },
    async prepareInternal(input) {
      return await rpcOne(trusted, "prepare_material_analysis_internal", {
        p_material_id: input.material_id,
        p_processing_mode: input.processing_mode,
        p_confirmation: input.confirm_large_document,
        p_page_count: input.page_count,
        p_source_hash: input.source_hash,
        p_version_contract: input.version_contract,
        p_version_fingerprint: input.version_fingerprint,
        p_page_plans: input.page_plans,
      });
    },
    async claimNext(input) {
      const value = await rpcOne(
        trusted,
        "claim_next_material_analysis_operation_internal",
        {
          p_material_id: input.material_id,
        },
      );
      return value as InternalWorkUnit;
    },
    async markSubmitted(input) {
      return await rpcOne(
        trusted,
        "submit_material_analysis_operation_internal",
        {
          p_batch_id: input.batch_id,
          p_lease_token: input.lease_token,
        },
      ) as { idempotency_key: string };
    },
    async createFileIntent(input) {
      return await rpcOne(
        trusted,
        "create_material_analysis_file_intent_internal",
        {
          p_batch_id: input.batch_id,
          p_lease_token: input.lease_token,
        },
      ) as { artifact_id: string };
    },
    async recordFileUploaded(input) {
      await rpcVoid(
        trusted,
        "record_material_analysis_file_uploaded_internal",
        {
          p_artifact_id: input.artifact_id,
          p_lease_token: input.lease_token,
          p_temporary_file_id: input.temporary_file_id,
        },
      );
    },
    async recordFileRecovery(input) {
      await rpcVoid(
        trusted,
        "record_material_analysis_file_recovery_internal",
        {
          p_artifact_id: input.artifact_id,
          p_lease_token: input.lease_token,
          p_temporary_file_id: input.temporary_file_id,
          p_deleted: input.deleted,
        },
      );
    },
    async markResponseKnown(input) {
      await rpcVoid(trusted, "record_material_analysis_response_internal", {
        p_batch_id: input.batch_id,
        p_lease_token: input.lease_token,
        p_response_id: input.response_id,
        p_temporary_file_id: input.temporary_file_id ?? null,
      });
    },
    async markDispatchUnknown(input) {
      await rpcVoid(
        trusted,
        "mark_material_processing_dispatch_unknown_internal",
        {
          p_batch_id: input.batch_id,
          p_lease_token: input.lease_token,
        },
      );
    },
    async completeOperation(input) {
      await rpcVoid(trusted, "complete_material_analysis_operation_internal", {
        p_batch_id: input.batch_id,
        p_lease_token: input.lease_token,
        p_validated_result: input.result,
        p_validation_version: input.validation_version,
        p_validation_hash: input.validation_hash,
        p_summary_markdown: input.summary_markdown ?? null,
        p_cleanup_complete: input.cleanup_complete,
      });
    },
    async failOperation(input) {
      await rpcVoid(trusted, "fail_material_analysis_operation_internal", {
        p_batch_id: input.batch_id,
        p_lease_token: input.lease_token,
        p_failure_class: input.failure_class,
        p_retry_after_seconds: input.retry_after_seconds ?? null,
        p_temporary_file_id: input.temporary_file_id ?? null,
        p_cleanup_complete: input.cleanup_complete ?? true,
      });
    },
    async reconcileOperation(input) {
      await rpcVoid(trusted, "complete_material_analysis_operation_internal", {
        p_batch_id: input.batch_id,
        p_lease_token: input.lease_token,
        p_validated_result: input.result,
        p_validation_version: input.validation_version,
        p_validation_hash: input.validation_hash,
        p_summary_markdown: null,
        p_cleanup_complete: true,
      });
    },
    async persistCleanup(input) {
      await rpcVoid(trusted, "complete_material_analysis_cleanup_internal", {
        p_artifact_id: input.artifact_id,
        p_lease_token: input.lease_token,
        p_temporary_file_id: input.temporary_file_id,
        p_complete: input.complete,
      });
    },
    async authorizeRetry(_principalId, materialId) {
      const value = await rpcOne(
        authenticated,
        "authorize_material_analysis_retry",
        {
          p_material_id: materialId,
        },
      );
      if (typeof value !== "string") {
        throw new Error("retry_authorization_failed");
      }
      return value;
    },
    async consumeRetry(materialId, authorizationId) {
      await rpcVoid(trusted, "request_material_processing_retry_internal", {
        p_material_id: materialId,
        p_authorization_id: authorizationId,
      });
    },
    async getStatus(_principalId, materialId) {
      return await rpcOne(authenticated, "get_material_analysis_status", {
        p_material_id: materialId,
      });
    },
    provider: new TrustedOpenAiAdapter({ apiKey: openAiKey, model }),
    jitter: Math.random,
  };
}

async function rpcOne(
  client: RpcClient,
  name: string,
  args: Record<string, unknown>,
): Promise<unknown> {
  const { data, error } = await client.rpc(name, args);
  if (error) throw new Error("trusted_rpc_failed");
  if (Array.isArray(data)) {
    if (data.length !== 1) throw new Error("trusted_rpc_shape");
    return data[0];
  }
  if (data === null || data === undefined) throw new Error("trusted_rpc_shape");
  return data;
}

async function rpcVoid(
  client: RpcClient,
  name: string,
  args: Record<string, unknown>,
) {
  const { error } = await client.rpc(name, args);
  if (error) throw new Error("trusted_rpc_failed");
}

function requiredEnv(name: string) {
  const value = Deno.env.get(name)?.trim();
  if (!value) throw new Error("analysis_configuration_unavailable");
  return value;
}
