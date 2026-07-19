import { createSupabaseContext } from "supabase-server";
import { TrustedOpenAiAdapter } from "../_shared/material_analysis/openai_adapter.ts";
import {
  DiagnosticCode,
  DiagnosticMetadata,
  diagnosticVersion,
} from "../_shared/material_analysis/response_diagnostics.ts";

const diagnosticKeyName = "material-analysis-diagnostic-staging";
const diagnosticAuthMode = `secret:${diagnosticKeyName}` as const;
const maximumRequestBytes = 1024;
const uuidPattern =
  /^[0-9a-f]{8}-[0-9a-f]{4}-[1-5][0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$/i;

type RpcResult = { data: unknown; error: unknown };
export type DiagnosticRpcClient = {
  rpc(
    name: string,
    args: Record<string, unknown>,
  ): PromiseLike<RpcResult>;
};

type DiagnosticAuthEnvironment = {
  url: string;
  publishableKeys?: Record<string, string>;
  secretKeys?: Record<string, string>;
};

type DiagnosticTarget = {
  batch_id: string;
  operation: "final_summary";
  status: "failed";
  response_id: string;
  page_numbers: number[];
  page_count: number;
  cleanup_state: "not_required" | "pending" | "completed";
};

type DiagnosticExecution = {
  diagnosticCode: DiagnosticCode;
  diagnosticMetadata: DiagnosticMetadata;
  getCount: 1;
};

type SafeLog = {
  operation: "final_response_diagnostic";
  outcome: "recorded" | "failed";
  diagnostic_code: DiagnosticCode;
  elapsed_milliseconds: number;
  get_count: number;
};

type HandlerOptions = {
  authEnvironment?: DiagnosticAuthEnvironment;
  execute?: (
    admin: DiagnosticRpcClient,
    batchId: string,
  ) => Promise<DiagnosticExecution>;
  logger?: (entry: SafeLog) => void;
  now?: () => number;
};

type RuntimeOptions = {
  fetcher?: typeof fetch;
  openAiKey?: string;
  model?: string;
};

class DiagnosticExecutionError extends Error {
  constructor(readonly getCount: number) {
    super("diagnostic_execution_failed");
  }
}

export function createDiagnosticHandler(options: HandlerOptions = {}) {
  const execute = options.execute ??
    ((admin, batchId) => runPreservedFinalResponseDiagnostic(admin, batchId));
  const logger = options.logger ?? safeLog;
  const now = options.now ?? performance.now.bind(performance);

  return async (request: Request): Promise<Response> => {
    if (request.headers.has("Authorization")) return authenticationRequired();
    if (request.method !== "POST") {
      return safeJson({ error: "Method not allowed." }, 405);
    }

    const contextOptions = options.authEnvironment
      ? {
        auth: diagnosticAuthMode,
        cors: false as const,
        env: options.authEnvironment,
      }
      : { auth: diagnosticAuthMode, cors: false as const };
    const { data: context, error } = await createSupabaseContext(
      request,
      contextOptions,
    );
    if (
      error || !context || context.authMode !== "secret" ||
      context.authKeyName !== diagnosticKeyName
    ) return authenticationRequired();

    const batchId = await parseRequest(request);
    if (!batchId) return safeJson({ error: "Invalid request." }, 400);

    const started = now();
    try {
      const result = await execute(
        context.supabaseAdmin as unknown as DiagnosticRpcClient,
        batchId,
      );
      logger({
        operation: "final_response_diagnostic",
        outcome: "recorded",
        diagnostic_code: result.diagnosticCode,
        elapsed_milliseconds: boundedElapsed(now() - started),
        get_count: result.getCount,
      });
      return safeJson({ diagnostic_recorded: true });
    } catch (error) {
      logger({
        operation: "final_response_diagnostic",
        outcome: "failed",
        diagnostic_code: "final_validation_unknown",
        elapsed_milliseconds: boundedElapsed(now() - started),
        get_count: error instanceof DiagnosticExecutionError
          ? error.getCount
          : 0,
      });
      return safeJson(
        { error: "Material analysis is temporarily unavailable." },
        500,
      );
    }
  };
}

export async function runPreservedFinalResponseDiagnostic(
  admin: DiagnosticRpcClient,
  batchId: string,
  options: RuntimeOptions = {},
): Promise<DiagnosticExecution> {
  let getCount = 0;
  try {
    if (!uuidPattern.test(batchId)) throw new Error("invalid_batch_id");
    const target = validateTarget(
      await rpcOne(
        admin,
        "load_material_analysis_diagnostic_target_internal",
        { p_batch_id: batchId },
      ),
      batchId,
    );
    const openAiKey = options.openAiKey ??
      requiredEnvironment("OPENAI_API_KEY");
    const model = options.model ??
      Deno.env.get("MATERIAL_ANALYSIS_MODEL")?.trim() ?? "gpt-5.4-mini";
    const upstreamFetch = options.fetcher ?? fetch;
    const getOnlyFetch: typeof fetch = async (input, init) => {
      const method = (init?.method ?? "GET").toUpperCase();
      if (method !== "GET" || getCount !== 0) {
        throw new Error("diagnostic_provider_boundary");
      }
      getCount++;
      return await upstreamFetch(input, init);
    };
    const provider = new TrustedOpenAiAdapter({
      apiKey: openAiKey,
      model,
      fetcher: getOnlyFetch,
    });
    const result = await provider.diagnoseFinalSummaryRetrieved({
      responseId: target.response_id,
      pageCount: target.page_count,
    });
    if (getCount !== 1) throw new Error("diagnostic_provider_boundary");
    const diagnostic = result.ok
      ? {
        code: "final_summary_persistence_failed" as const,
        metadata: {
          ...result.metadata,
          validator_stage: "persistFinalSummaryEligibility" as const,
        },
      }
      : { code: result.code, metadata: result.metadata };
    await rpcVoid(
      admin,
      "record_material_analysis_diagnostic_internal",
      {
        p_batch_id: target.batch_id,
        p_diagnostic_code: diagnostic.code,
        p_diagnostic_metadata: diagnostic.metadata,
        p_diagnostic_version: diagnosticVersion,
      },
    );
    return {
      diagnosticCode: diagnostic.code,
      diagnosticMetadata: diagnostic.metadata,
      getCount: 1,
    };
  } catch (_) {
    throw new DiagnosticExecutionError(getCount);
  }
}

function validateTarget(value: unknown, batchId: string): DiagnosticTarget {
  if (!isRecord(value)) throw new Error("diagnostic_target_unavailable");
  const pageNumbers = Array.isArray(value.page_numbers)
    ? value.page_numbers
    : [];
  const pageCount = Number.isInteger(value.page_count)
    ? value.page_count as number
    : -1;
  if (
    Object.keys(value).sort().join() !==
      "batch_id,cleanup_state,operation,page_count,page_numbers,response_id,status" ||
    value.batch_id !== batchId || value.operation !== "final_summary" ||
    value.status !== "failed" ||
    typeof value.response_id !== "string" ||
    !/^[A-Za-z0-9_.-]{8,200}$/.test(value.response_id) ||
    pageCount < 1 || pageCount > 100 || pageNumbers.length < 1 ||
    pageNumbers.length > 100 ||
    pageNumbers.some((page, index) =>
      !Number.isInteger(page) || page < 1 || page > pageCount ||
      (index > 0 && page <= pageNumbers[index - 1])
    ) ||
    !["not_required", "pending", "completed"].includes(
      String(value.cleanup_state),
    )
  ) throw new Error("diagnostic_target_unavailable");
  return value as DiagnosticTarget;
}

async function parseRequest(request: Request): Promise<string | null> {
  if (
    request.headers.get("Content-Type")?.split(";", 1)[0].trim()
      .toLowerCase() !==
      "application/json"
  ) return null;
  const contentLength = request.headers.get("Content-Length");
  if (
    contentLength &&
    (!/^\d+$/.test(contentLength) ||
      Number(contentLength) > maximumRequestBytes)
  ) return null;
  try {
    const bytes = new Uint8Array(await request.arrayBuffer());
    if (bytes.byteLength === 0 || bytes.byteLength > maximumRequestBytes) {
      return null;
    }
    const value = JSON.parse(
      new TextDecoder("utf-8", { fatal: true }).decode(bytes),
    );
    if (
      !isRecord(value) || Object.keys(value).join() !== "batch_id" ||
      typeof value.batch_id !== "string" || !uuidPattern.test(value.batch_id)
    ) return null;
    return value.batch_id;
  } catch (_) {
    return null;
  }
}

async function rpcOne(
  admin: DiagnosticRpcClient,
  name: "load_material_analysis_diagnostic_target_internal",
  args: Record<string, unknown>,
) {
  const { data, error } = await admin.rpc(name, args);
  if (error) throw new Error("diagnostic_rpc_failed");
  if (Array.isArray(data)) {
    if (data.length !== 1) throw new Error("diagnostic_rpc_shape");
    return data[0];
  }
  if (data === null || data === undefined) {
    throw new Error("diagnostic_rpc_shape");
  }
  return data;
}

async function rpcVoid(
  admin: DiagnosticRpcClient,
  name: "record_material_analysis_diagnostic_internal",
  args: Record<string, unknown>,
) {
  const { error } = await admin.rpc(name, args);
  if (error) throw new Error("diagnostic_rpc_failed");
}

function requiredEnvironment(name: "OPENAI_API_KEY") {
  const value = Deno.env.get(name)?.trim();
  if (!value) throw new Error("diagnostic_configuration_unavailable");
  return value;
}

function isRecord(value: unknown): value is Record<string, unknown> {
  return value !== null && typeof value === "object" && !Array.isArray(value);
}

function boundedElapsed(value: number) {
  if (!Number.isFinite(value)) return 0;
  return Math.min(3_600_000, Math.max(0, Math.round(value)));
}

function authenticationRequired() {
  return safeJson({ error: "Authentication required." }, 401);
}

function safeJson(body: Record<string, unknown>, status = 200) {
  return new Response(JSON.stringify(body), {
    status,
    headers: {
      "Content-Type": "application/json; charset=utf-8",
      "Cache-Control": "no-store",
    },
  });
}

function safeLog(entry: SafeLog) {
  console.log(JSON.stringify(entry));
}

export default { fetch: createDiagnosticHandler() };
