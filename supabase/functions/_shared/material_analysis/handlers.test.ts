import {
  AnalysisDependencies,
  createAdvanceMaterialAnalysisHandler,
  createPrepareMaterialAnalysisHandler,
  createRetryMaterialAnalysisHandler,
  InternalWorkUnit,
} from "./handlers.ts";
import { TrustedOpenAiAdapter } from "./openai_adapter.ts";
import { buildSyntheticPdf } from "./synthetic_pdf_fixtures.ts";

const owner = crypto.randomUUID();
const materialId = crypto.randomUUID();
const otherOwner = crypto.randomUUID();
const jobId = crypto.randomUUID();
const batchId = crypto.randomUUID();
const leaseId = crypto.randomUUID();
const artifactId = crypto.randomUUID();
const retryAuthorizationId = crypto.randomUUID();
const runtimeAuthFixture = ["fixture", crypto.randomUUID()].join("_");
const runtimeApiFixture = ["safe", "mock", crypto.randomUUID()].join("_");

Deno.test("C2 prepare owner succeeds with exact 1..P manifest", async () => {
  const pdf = await buildSyntheticPdf(["text", "text"]);
  const fake = fakeDependencies(pdf);
  const response = await createPrepareMaterialAnalysisHandler(fake.deps)(
    request({
      material_id: materialId,
      processing_mode: "recommended",
      confirm_large_document: false,
    }),
  );
  equal(response.status, 200);
  equal(fake.preparations.length, 1);
  equal(fake.preparations[0].page_count, 2);
  equal(
    (fake.preparations[0].page_plans as Array<Record<string, unknown>>).map(
      (page) => page.page_number,
    ),
    [1, 2],
  );
  equal(fake.providerRequests, 0);
});

Deno.test("C2 prepare denies cross-user and malformed requests", async () => {
  const pdf = await buildSyntheticPdf(["text"]);
  const fake = fakeDependencies(pdf);
  fake.source.user_id = otherOwner;
  const denied = await createPrepareMaterialAnalysisHandler(fake.deps)(request({
    material_id: materialId,
    processing_mode: "recommended",
    confirm_large_document: false,
  }));
  equal(denied.status, 404);
  const malformed = await createPrepareMaterialAnalysisHandler(fake.deps)(
    request({
      material_id: materialId,
      processing_mode: "recommended",
      confirm_large_document: false,
      model: "attacker-model",
    }),
  );
  equal(malformed.status, 400);
  equal(fake.preparations.length, 0);
});

Deno.test("C2 21 through 100 pages require confirmation without paid activity", async () => {
  const pdf = await buildSyntheticPdf(Array(21).fill("text"));
  const fake = fakeDependencies(pdf);
  fake.status.state = "awaiting_confirmation";
  fake.status.confirmation_required = true;
  const response = await createPrepareMaterialAnalysisHandler(fake.deps)(
    request({
      material_id: materialId,
      processing_mode: "economy",
      confirm_large_document: false,
    }),
  );
  equal(response.status, 200);
  equal((await response.json()).confirmation_required, true);
  equal(fake.preparations.length, 1);
  equal(fake.providerRequests, 0);
});

Deno.test("C2 page 101 rejects before job budget upload or OpenAI", async () => {
  const pdf = await buildSyntheticPdf(Array(101).fill("text"));
  const fake = fakeDependencies(pdf);
  const response = await createPrepareMaterialAnalysisHandler(fake.deps)(
    request({
      material_id: materialId,
      processing_mode: "recommended",
      confirm_large_document: true,
    }),
  );
  equal(response.status, 422);
  equal(fake.preparations.length, 0);
  equal(fake.providerRequests, 0);
});

Deno.test("C2 image above 8 MiB rejects before budget upload or response", async () => {
  const fake = fakeDependencies(pngBytes(), "image");
  fake.source.file_size_bytes = 8 * 1024 * 1024 + 1;
  const response = await createPrepareMaterialAnalysisHandler(fake.deps)(
    request({
      material_id: materialId,
      processing_mode: "recommended",
      confirm_large_document: false,
    }),
  );
  equal(response.status, 422);
  equal(fake.preparations.length, 0);
  equal(fake.fileIntents, 0);
  equal(fake.uploadRequests, 0);
  equal(fake.providerRequests, 0);
  equal(fake.submissions, 0);
});

Deno.test("C2 duplicate preparation delegates idempotency without provider work", async () => {
  const pdf = await buildSyntheticPdf(["text"]);
  const fake = fakeDependencies(pdf);
  const handler = createPrepareMaterialAnalysisHandler(fake.deps);
  for (let index = 0; index < 2; index++) {
    const response = await handler(request({
      material_id: materialId,
      processing_mode: "recommended",
      confirm_large_document: false,
    }));
    equal(response.status, 200);
  }
  equal(fake.preparations.length, 2);
  equal(fake.providerRequests, 0);
});

Deno.test("C2 advance performs one bounded operation with exact original image bytes", async () => {
  const bytes = pngBytes();
  const fake = fakeDependencies(bytes, "image");
  fake.work = {
    kind: "page_visual",
    material_id: materialId,
    job_id: jobId,
    batch_id: batchId,
    lease_token: leaseId,
    page_count: 1,
    page_numbers: [1],
  };
  const response = await createAdvanceMaterialAnalysisHandler(fake.deps)(
    request({ material_id: materialId }),
  );
  equal(response.status, 200);
  equal(fake.claims, 1);
  equal(fake.providerRequests, 1);
  equal(fake.observedImageBytes, bytes);
  equal(fake.submissions, 1);
  equal(fake.completions, 1);
});

Deno.test("C2 another worker lease returns status without provider request", async () => {
  const pdf = await buildSyntheticPdf(["text"]);
  const fake = fakeDependencies(pdf);
  fake.work = { kind: "none", material_id: materialId };
  const response = await createAdvanceMaterialAnalysisHandler(fake.deps)(
    request({ material_id: materialId }),
  );
  equal(response.status, 200);
  equal(fake.claims, 1);
  equal(fake.providerRequests, 0);
});

Deno.test("C2 after-dispatch failure without response ID requires explicit user retry", async () => {
  const bytes = pngBytes();
  const fake = fakeDependencies(bytes, "image", "network_failure");
  fake.work = workUnit();
  const response = await createAdvanceMaterialAnalysisHandler(fake.deps)(
    request({ material_id: materialId }),
  );
  equal(response.status, 200);
  equal(fake.failures[0].failure_class, "user_retry_required");
  equal(fake.submissions, 1);
  equal(fake.completions, 0);
});

Deno.test("C2 proven pre-dispatch upload failure backs off without consuming an attempt", async () => {
  const pdf = await buildSyntheticPdf(["text"]);
  const fake = fakeDependencies(pdf, "pdf", "upload_failure");
  fake.work = workUnit();
  const response = await createAdvanceMaterialAnalysisHandler(fake.deps)(
    request({ material_id: materialId }),
  );
  equal(response.status, 200);
  equal(fake.failures[0].failure_class, "pre_dispatch_retryable");
  equal(fake.failures[0].retry_after_seconds, 5);
  equal(fake.submissions, 0);
  equal(fake.providerRequests, 0);
});

Deno.test("C2 file-ID persistence failure deletes immediately without paid response", async () => {
  const pdf = await buildSyntheticPdf(["text"]);
  const fake = fakeDependencies(pdf, "pdf", "file_persistence_failure");
  fake.work = workUnit();
  const response = await createAdvanceMaterialAnalysisHandler(fake.deps)(
    request({ material_id: materialId }),
  );
  equal(response.status, 200);
  equal(fake.fileIntents, 1);
  equal(fake.uploadRequests, 1);
  equal(fake.deleteRequests, 1);
  equal(fake.fileRecoveries, 1);
  equal(fake.providerRequests, 0);
  equal(fake.submissions, 0);
  equal(fake.failures[0].failure_class, "pre_dispatch_retryable");
});

Deno.test("C2 transient DB failure after response retries without another paid call", async () => {
  const fake = fakeDependencies(
    pngBytes(),
    "image",
    "response_persistence_transient",
  );
  fake.work = workUnit();
  const response = await createAdvanceMaterialAnalysisHandler(fake.deps)(
    request({ material_id: materialId }),
  );
  equal(response.status, 200);
  equal(fake.providerRequests, 1);
  equal(fake.responsePersistenceAttempts, 2);
  equal(fake.completions, 1);
});

Deno.test("C2 DB failure after known PDF response retains file for reconciliation", async () => {
  const pdf = await buildSyntheticPdf(["text"]);
  const fake = fakeDependencies(pdf, "pdf", "completion_failure");
  fake.work = workUnit();
  const response = await createAdvanceMaterialAnalysisHandler(fake.deps)(
    request({ material_id: materialId }),
  );
  equal(response.status, 500);
  equal(fake.providerRequests, 1);
  equal(fake.responsePersistenceAttempts, 1);
  equal(fake.deleteRequests, 0);
  equal(fake.completions, 1);
});

Deno.test("C2 explicit 429 uses persisted retry policy", async () => {
  const bytes = pngBytes();
  const fake = fakeDependencies(bytes, "image", "http_429");
  fake.work = workUnit();
  const response = await createAdvanceMaterialAnalysisHandler(fake.deps)(
    request({ material_id: materialId }),
  );
  equal(response.status, 200);
  equal(fake.failures[0].failure_class, "user_retry_required");
  equal(fake.failures[0].retry_after_seconds, undefined);
  equal(fake.submissions, 1);
});

Deno.test("C2 explicit retry authorizes then consumes without accepting attempt IDs", async () => {
  const pdf = await buildSyntheticPdf(["text"]);
  const fake = fakeDependencies(pdf);
  fake.status.state = "user_retry_required";
  fake.status.can_retry = true;
  const response = await createRetryMaterialAnalysisHandler(fake.deps)(
    request({ material_id: materialId }),
  );
  equal(response.status, 200);
  equal(fake.retryAuthorizations, 1);
  equal(fake.retryConsumptions, 1);
  const rejected = await createRetryMaterialAnalysisHandler(fake.deps)(request({
    material_id: materialId,
    attempt_id: "attacker",
  }));
  equal(rejected.status, 400);
});

function fakeDependencies(
  bytes: Uint8Array,
  kind: "pdf" | "image" = "pdf",
  providerMode:
    | "success"
    | "network_failure"
    | "upload_failure"
    | "file_persistence_failure"
    | "response_persistence_transient"
    | "completion_failure"
    | "http_429" = "success",
) {
  const state = {
    source: source(bytes, kind) as Record<string, unknown>,
    preparations: [] as Array<{
      page_count: number;
      page_plans: unknown[];
      [key: string]: unknown;
    }>,
    status: publicStatus() as Record<string, unknown>,
    work: { kind: "none", material_id: materialId } as InternalWorkUnit,
    claims: 0,
    submissions: 0,
    completions: 0,
    failures: [] as Array<Record<string, unknown>>,
    retryAuthorizations: 0,
    retryConsumptions: 0,
    providerRequests: 0,
    uploadRequests: 0,
    deleteRequests: 0,
    fileIntents: 0,
    fileRecoveries: 0,
    responsePersistenceAttempts: 0,
    observedImageBytes: new Uint8Array(),
  };
  const provider = new TrustedOpenAiAdapter({
    apiKey: runtimeApiFixture,
    model: "server-model",
    fetcher: async (input, init) => {
      await Promise.resolve();
      if (String(input).endsWith("/files")) {
        state.uploadRequests++;
        if (providerMode === "upload_failure") throw new TypeError("network");
        return new Response(JSON.stringify({ id: "file_12345678" }), {
          status: 200,
          headers: { "Content-Type": "application/json" },
        });
      }
      if (String(input).includes("/files/")) {
        state.deleteRequests++;
        return new Response(JSON.stringify({ deleted: true }), { status: 200 });
      }
      if (!String(input).includes("/responses")) {
        throw new Error("unexpected provider endpoint");
      }
      state.providerRequests++;
      const body = JSON.parse(String(init?.body));
      const dataUrl = body.input[0].content.find((
        item: Record<string, unknown>,
      ) => item.type === "input_image")?.image_url;
      if (typeof dataUrl === "string") {
        state.observedImageBytes = fromBase64(dataUrl.split(",")[1]);
      }
      if (providerMode === "network_failure") throw new TypeError("network");
      if (providerMode === "http_429") {
        return new Response(JSON.stringify({ error: "private" }), {
          status: 429,
          headers: { "Content-Type": "application/json", "Retry-After": "17" },
        });
      }
      return new Response(
        JSON.stringify(completedResponse(pageBatch())),
        { status: 200, headers: { "Content-Type": "application/json" } },
      );
    },
  });
  const deps: AnalysisDependencies = {
    verifyJwt: (jwt) =>
      Promise.resolve(jwt === runtimeAuthFixture ? owner : null),
    loadSource: () => Promise.resolve(state.source),
    downloadPrivate: () => Promise.resolve(Uint8Array.from(bytes)),
    prepareInternal: (input) => {
      state.preparations.push(structuredClone(input));
      return Promise.resolve("job");
    },
    claimNext: () => {
      state.claims++;
      return Promise.resolve(state.work);
    },
    markSubmitted: () => {
      state.submissions++;
      return Promise.resolve({ idempotency_key: "a".repeat(64) });
    },
    createFileIntent: () => {
      state.fileIntents++;
      return Promise.resolve({
        artifact_id: artifactId,
      });
    },
    recordFileUploaded: () =>
      providerMode === "file_persistence_failure"
        ? Promise.reject(new Error("trusted_rpc_failed"))
        : Promise.resolve(),
    recordFileRecovery: () => {
      state.fileRecoveries++;
      return Promise.resolve();
    },
    markResponseKnown: () => {
      state.responsePersistenceAttempts++;
      if (
        providerMode === "response_persistence_transient" &&
        state.responsePersistenceAttempts === 1
      ) return Promise.reject(new Error("trusted_rpc_failed"));
      return Promise.resolve();
    },
    markDispatchUnknown: () => Promise.resolve(),
    completeOperation: () => {
      state.completions++;
      return providerMode === "completion_failure"
        ? Promise.reject(new Error("trusted_rpc_failed"))
        : Promise.resolve();
    },
    failOperation: (input) => {
      state.failures.push(structuredClone(input));
      return Promise.resolve();
    },
    reconcileOperation: () => Promise.resolve(),
    persistCleanup: () => Promise.resolve(),
    authorizeRetry: () => {
      state.retryAuthorizations++;
      return Promise.resolve(retryAuthorizationId);
    },
    consumeRetry: () => {
      state.retryConsumptions++;
      return Promise.resolve();
    },
    getStatus: () => Promise.resolve(state.status),
    provider,
    jitter: () => 0,
  };
  return Object.assign(state, { deps });
}

function source(bytes: Uint8Array, kind: "pdf" | "image") {
  return {
    id: materialId,
    user_id: owner,
    kind,
    source_kind: "upload",
    storage_bucket: kind === "pdf" ? "study-materials" : "study-images",
    storage_path: `${owner}/${materialId}/notes.${
      kind === "pdf" ? "pdf" : "png"
    }`,
    mime_type: kind === "pdf" ? "application/pdf" : "image/png",
    file_size_bytes: bytes.length,
    processing_status: "ready",
    deleted_at: null,
    metadata: {},
  };
}

function workUnit(): InternalWorkUnit {
  return {
    kind: "page_visual",
    material_id: materialId,
    job_id: jobId,
    batch_id: batchId,
    lease_token: leaseId,
    page_count: 1,
    page_numbers: [1],
  };
}

function pageBatch() {
  return {
    pages: [{
      page_number: 1,
      summary_markdown: "Safe summary.",
      key_concepts: [],
      equations: [],
      confidence: 0.9,
      warnings: [],
      trustworthy: true,
    }],
  };
}

function completedResponse(value: unknown) {
  return {
    id: "resp_12345678",
    object: "response",
    status: "completed",
    error: null,
    incomplete_details: null,
    output: [{
      type: "message",
      content: [{ type: "output_text", text: JSON.stringify(value) }],
    }],
  };
}

function publicStatus() {
  return {
    material_id: materialId,
    processing_mode: "recommended",
    state: "processing",
    public_stage: "analyzing_pages",
    page_count: 1,
    completed_pages: 0,
    confirmation_required: false,
    can_retry: false,
    retry_after_seconds: null,
    warnings: [],
    summary_schema_version: null,
    summary_payload: null,
  };
}

function request(body: Record<string, unknown>) {
  return new Request("https://example.test", {
    method: "POST",
    headers: {
      Authorization: ["Bearer", runtimeAuthFixture].join(" "),
      "Content-Type": "application/json",
    },
    body: JSON.stringify(body),
  });
}

function pngBytes() {
  return Uint8Array.from([
    0x89,
    0x50,
    0x4e,
    0x47,
    0x0d,
    0x0a,
    0x1a,
    0x0a,
    1,
    2,
    3,
  ]);
}

function fromBase64(value: string) {
  return Uint8Array.from(atob(value), (character) => character.charCodeAt(0));
}

function equal(actual: unknown, expected: unknown) {
  if (actual instanceof Uint8Array && expected instanceof Uint8Array) {
    if (
      actual.length === expected.length &&
      actual.every((value, index) => value === expected[index])
    ) return;
  } else if (JSON.stringify(actual) === JSON.stringify(expected)) return;
  throw new Error(
    `Expected ${JSON.stringify(expected)}, got ${JSON.stringify(actual)}`,
  );
}
