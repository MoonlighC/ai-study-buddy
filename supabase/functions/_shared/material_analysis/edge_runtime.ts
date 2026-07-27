import { createClient } from "supabase-js";
import { resolveProjectKeys } from "../generation_runtime.ts";
import { SafeAnalysisError, SourceMaterial } from "./engine.ts";
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
    async verifyServiceJwt(candidate) {
      return constantTimeEqual(candidate, trustedKey);
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
      requireOwnedMaterial(data, error);
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
        p_analyze_again: input.analyze_again,
      });
    },
    async preparePageRecoveries(input) {
      return await rpcOne(
        trusted,
        "prepare_material_analysis_page_recoveries_internal",
        { p_material_id: input.material_id },
      ) as never;
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
      if (input.failure_class.startsWith("terminal_")) {
        await rpcVoid(
          trusted,
          "terminalize_material_analysis_operation_internal",
          {
            p_batch_id: input.batch_id,
            p_lease_token: input.lease_token,
            p_failure_class: input.failure_class,
          },
        );
        return;
      }
      await rpcVoid(trusted, "fail_material_analysis_operation_internal", {
        p_batch_id: input.batch_id,
        p_lease_token: input.lease_token,
        p_failure_class: input.failure_class,
        p_retry_after_seconds: input.retry_after_seconds ?? null,
        p_temporary_file_id: input.temporary_file_id ?? null,
        p_cleanup_complete: input.cleanup_complete ?? true,
      });
    },
    async recordReductionDiagnostic(input) {
      await rpcVoid(
        trusted,
        "record_material_analysis_reduction_diagnostic_internal",
        {
          p_batch_id: input.batch_id,
          p_lease_token: input.lease_token,
          p_diagnostic_metadata: input.diagnostic_metadata,
          p_diagnostic_version: input.diagnostic_version,
        },
      );
    },
    async loadDiagnosticTarget(batchId) {
      return await rpcOne(
        trusted,
        "load_material_analysis_diagnostic_target_internal",
        { p_batch_id: batchId },
      ) as never;
    },
    async recordDiagnostic(input) {
      await rpcVoid(
        trusted,
        "record_material_analysis_diagnostic_internal",
        {
          p_batch_id: input.batch_id,
          p_diagnostic_code: input.diagnostic_code,
          p_diagnostic_metadata: input.diagnostic_metadata,
          p_diagnostic_version: input.diagnostic_version,
        },
      );
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
      return await rpcStatusWithV1Fallback(authenticated, materialId);
    },
    provider: new TrustedOpenAiAdapter({ apiKey: openAiKey, model }),
    jitter: Math.random,
  };
}

export async function rpcStatusWithV1Fallback(
  client: RpcClient,
  materialId: string,
): Promise<unknown> {
  const args = { p_material_id: materialId };
  const v2 = await client.rpc("get_material_analysis_status_v2", args);
  if (!v2.error) return normalizeStatusRpcResult(v2.data, 2);
  if (!isMissingStatusV2(v2.error)) throw new Error("trusted_rpc_failed");
  const v1 = await client.rpc("get_material_analysis_status", args);
  if (v1.error) throw new Error("trusted_rpc_failed");
  const value = normalizeStatusRpcResult(v1.data, 1) as Record<
    string,
    unknown
  >;
  return { ...value, can_analyze_again: false };
}

function normalizeStatusRpcResult(value: unknown, version: 1 | 2) {
  const row = Array.isArray(value) && value.length === 1 ? value[0] : value;
  const expected = [
    "active_operation",
    ...(version === 2 ? ["can_analyze_again"] : []),
    "can_retry",
    "completed_pages",
    "confirmation_required",
    "material_id",
    "page_count",
    "processing_mode",
    "public_stage",
    "retry_after_seconds",
    "safe_error_code",
    "state",
    "summary_payload",
    "summary_schema_version",
    "warnings",
  ].sort();
  if (
    !isRecord(row) ||
    Object.keys(row).sort().join() !== expected.join()
  ) throw new Error("trusted_rpc_shape");
  return row;
}

function isMissingStatusV2(value: unknown) {
  return isRecord(value) && value.code === "PGRST202" &&
    typeof value.message === "string" &&
    value.message.includes("get_material_analysis_status_v2");
}

function isRecord(value: unknown): value is Record<string, unknown> {
  return typeof value === "object" && value !== null && !Array.isArray(value);
}

async function constantTimeEqual(left: string, right: string) {
  const encoder = new TextEncoder();
  const [leftDigest, rightDigest] = await Promise.all([
    crypto.subtle.digest("SHA-256", encoder.encode(left)),
    crypto.subtle.digest("SHA-256", encoder.encode(right)),
  ]);
  const leftBytes = new Uint8Array(leftDigest);
  const rightBytes = new Uint8Array(rightDigest);
  let difference = 0;
  for (let index = 0; index < leftBytes.length; index++) {
    difference |= leftBytes[index] ^ rightBytes[index];
  }
  return difference === 0;
}

export function requireOwnedMaterial(data: unknown, error: unknown): unknown {
  if (error) throw new Error("owned_material_lookup_failed");
  if (data === null || data === undefined) {
    throw new SafeAnalysisError("material_unavailable", 404);
  }
  return data;
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
