import {
  diagnoseFinalSummaryLatex,
  SafeLatexDiagnostic,
} from "../_shared/material_analysis/latex_diagnostic.ts";

type RpcClient = {
  rpc(name: string, args?: Record<string, unknown>): PromiseLike<{
    data: unknown;
    error: { message?: string } | null;
  }>;
};

type Dependencies = {
  operatorKey: string;
  openAiKey: string;
  database: RpcClient;
  fetcher?: typeof fetch;
};

export function createLatexDiagnosticHandler(deps: Dependencies) {
  const fetcher = deps.fetcher ?? fetch;
  return async (request: Request): Promise<Response> => {
    if (request.method !== "POST") {
      return safeResponse(405, "method_not_allowed");
    }
    if (request.headers.has("authorization")) {
      return safeResponse(401, "authorization_forbidden");
    }
    const supplied = request.headers.get("apikey")?.trim() ?? "";
    if (!constantTimeEqual(supplied, deps.operatorKey)) {
      return safeResponse(401, "operator_authentication_failed");
    }
    if ((await request.text()).trim().length !== 0) {
      return safeResponse(400, "request_body_forbidden");
    }
    try {
      const target = validateTarget(
        await rpcOne(
          deps.database,
          "claim_material_analysis_latex_diagnostic_internal",
        ),
      );
      const metadata = await retrieveLatexDiagnostic({
        responseId: target.response_id,
        openAiKey: deps.openAiKey,
        fetcher,
      });
      await rpcVoid(
        deps.database,
        "record_material_analysis_latex_diagnostic_internal",
        { p_metadata: metadata },
      );
      safeLog(metadata);
      return new Response(JSON.stringify(metadata), {
        status: 200,
        headers: { "content-type": "application/json" },
      });
    } catch (_) {
      safeLog(null);
      return safeResponse(500, "latex_diagnostic_failed");
    }
  };
}

export async function retrieveLatexDiagnostic(input: {
  responseId: string;
  openAiKey: string;
  fetcher?: typeof fetch;
}): Promise<SafeLatexDiagnostic> {
  if (!/^[A-Za-z0-9_.-]{8,200}$/.test(input.responseId)) {
    throw new Error("invalid_diagnostic_target");
  }
  const response = await (input.fetcher ?? fetch)(
    `https://api.openai.com/v1/responses/${
      encodeURIComponent(input.responseId)
    }`,
    {
      method: "GET",
      headers: { authorization: `Bearer ${input.openAiKey}` },
    },
  );
  if (!response.ok) throw new Error("provider_retrieval_failed");
  const envelope: unknown = await response.json();
  if (!isRecord(envelope) || envelope.status !== "completed") {
    throw new Error("provider_response_not_completed");
  }
  const output = Array.isArray(envelope.output) ? envelope.output : [];
  const candidates: string[] = [];
  for (const item of output.slice(0, 100)) {
    if (!isRecord(item) || !Array.isArray(item.content)) continue;
    for (const content of item.content.slice(0, 100)) {
      if (
        isRecord(content) && content.type === "output_text" &&
        typeof content.text === "string"
      ) candidates.push(content.text);
    }
  }
  if (output.length !== 1 || candidates.length !== 1) {
    throw new Error("provider_output_ambiguous");
  }
  let parsed: unknown;
  try {
    parsed = JSON.parse(candidates[0]);
  } catch (_) {
    throw new Error("provider_json_invalid");
  }
  if (
    !isRecord(parsed) || !Array.isArray(parsed.equations) ||
    parsed.equations.length > 100
  ) throw new Error("summary_shape_invalid");
  const equations = parsed.equations.map((equation) => {
    if (!isRecord(equation) || typeof equation.latex !== "string") {
      throw new Error("summary_shape_invalid");
    }
    return { latex: equation.latex };
  });
  return diagnoseFinalSummaryLatex(equations);
}

function validateTarget(value: unknown) {
  if (
    !isRecord(value) ||
    Object.keys(value).sort().join() !== "page_count,response_id" ||
    typeof value.response_id !== "string" ||
    !Number.isInteger(value.page_count) || value.page_count < 1 ||
    value.page_count > 100
  ) {
    throw new Error("invalid_diagnostic_target");
  }
  return value as { response_id: string; page_count: number };
}

async function rpcOne(
  database: RpcClient,
  name: string,
  args?: Record<string, unknown>,
) {
  const { data, error } = await database.rpc(name, args);
  if (error || data === null || data === undefined) {
    throw new Error("database_unavailable");
  }
  return data;
}

async function rpcVoid(
  database: RpcClient,
  name: string,
  args?: Record<string, unknown>,
) {
  const { error } = await database.rpc(name, args);
  if (error) throw new Error("database_unavailable");
}

function constantTimeEqual(left: string, right: string) {
  const a = new TextEncoder().encode(left);
  const b = new TextEncoder().encode(right);
  let difference = a.length ^ b.length;
  const length = Math.max(a.length, b.length);
  for (let index = 0; index < length; index++) {
    difference |= (a[index] ?? 0) ^ (b[index] ?? 0);
  }
  return difference === 0 && a.length > 31;
}

function safeResponse(status: number, code: string) {
  return new Response(JSON.stringify({ error: code }), {
    status,
    headers: { "content-type": "application/json" },
  });
}

function safeLog(metadata: SafeLatexDiagnostic | null) {
  console.log(JSON.stringify(
    metadata
      ? {
        operation: "latex_diagnostic",
        stage: "recorded",
        equation_index: metadata.equation_index,
        validator_rule_code: metadata.validator_rule_code,
        category: metadata.category,
        equations_passing_before_failure:
          metadata.equations_passing_before_failure,
        total_equation_count: metadata.total_equation_count,
      }
      : { operation: "latex_diagnostic", stage: "failed" },
  ));
}

function isRecord(value: unknown): value is Record<string, any> {
  return typeof value === "object" && value !== null && !Array.isArray(value);
}
