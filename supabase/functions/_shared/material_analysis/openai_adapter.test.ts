import {
  parseRetryAfter,
  ProviderBoundaryError,
  ProviderRequest,
  TrustedOpenAiAdapter,
} from "./openai_adapter.ts";
import {
  createReductionGroups,
  projectSummaryToSafeMarkdown,
} from "./engine.ts";
import { StructuredSummary } from "./contracts.ts";
import { buildSyntheticPdf } from "./synthetic_pdf_fixtures.ts";
import { finalSummaryPartitionOverlapFixture } from "./final_summary_canonicalization_fixture.ts";

Deno.test("C2 adapter keeps model detail schema and background server-only", async () => {
  const calls: Array<{ url: string; init: RequestInit }> = [];
  const adapter = adapterWith((input, init) => {
    calls.push({ url: String(input), init: init ?? {} });
    return Promise.resolve(jsonResponse(completedResponse(pageBatch())));
  });
  const original = pngBytes();
  await adapter.execute(imageRequest(original));
  equal(calls.length, 1);
  const body = JSON.parse(String(calls[0].init.body));
  equal(body.model, "server-model");
  equal(body.background, false);
  equal(body.text.format.type, "json_schema");
  equal(body.text.format.strict, true);
  equal(body.input[0].content[1].detail, "high");
  equal(
    body.input[0].content[1].image_url,
    `data:image/png;base64,${toBase64(original)}`,
  );
  equal("user_id" in body, false);
  equal("routing" in body, false);
});

Deno.test("C2 adapter uploads named mini PDF then uses only persisted file ID", async () => {
  const pdf = await buildSyntheticPdf(["text"]);
  const calls: Array<{ url: string; init: RequestInit }> = [];
  const adapter = adapterWith(async (input, init) => {
    const url = String(input);
    calls.push({ url, init: init ?? {} });
    if (url.endsWith("/files") && init?.method === "POST") {
      const form = init.body as FormData;
      equal(form.get("purpose"), "user_data");
      const file = form.get("file") as File;
      equal(new Uint8Array(await file.arrayBuffer()), pdf);
      return Promise.resolve(jsonResponse({ id: "file_12345678" }));
    }
    if (url.includes("/responses")) {
      const body = JSON.parse(String(init?.body));
      equal(body.input[0].content[1], {
        type: "input_file",
        file_id: "file_12345678",
      });
      return Promise.resolve(jsonResponse(completedResponse(pageBatch())));
    }
    return jsonResponse({ deleted: true });
  });
  const artifactId = "11111111-1111-4111-8111-111111111111";
  const fileId = await adapter.uploadPdf(pdf, artifactId);
  const result = await adapter.execute(
    {
      ...baseRequest(),
      operation: "page_visual",
      input: { kind: "pdf", bytes: pdf, pageNumbers: [1] },
    },
    undefined,
    fileId,
  );
  equal(result.responseId, "resp_12345678");
  equal(calls.filter((call) => call.url.includes("/responses")).length, 1);
  equal(calls.filter((call) => call.init.method === "DELETE").length, 0);
  const upload = calls.find((call) => call.url.endsWith("/files"));
  const form = upload?.init.body as FormData;
  equal((form.get("file") as File).name, `analysis-${artifactId}.pdf`);
});

Deno.test("visual STEM page request states the strict Markdown and LaTeX contract", async () => {
  const pdf = await buildSyntheticPdf(["text"]);
  let responseCreates = 0;
  const adapter = adapterWith((input, init) => {
    const url = String(input);
    if (url.endsWith("/files")) {
      return Promise.resolve(jsonResponse({ id: "file_12345678" }));
    }
    if (url.includes("/responses")) {
      responseCreates++;
      const body = JSON.parse(String(init?.body));
      const content = body.input[0].content;
      const prompt = content[0].text as string;
      equal(body.text.format.name, "phase_c_page_visual_v3");
      equal(prompt.includes("hardened Markdown"), true);
      equal(prompt.includes("dollar-delimited mathematics"), true);
      equal(prompt.includes("control-spacing commands"), true);
      equal(prompt.includes("Preserve equation provenance"), true);
      equal(prompt.includes("page_content_partial"), true);
      equal(prompt.includes("page_content_missing"), true);
      equal(prompt.includes("source_metadata_omitted"), true);
      equal(prompt.includes("page_missing"), true);
      equal(prompt.includes("invalid_equation_latex"), true);
      equal(prompt.includes("Source code must never appear"), true);
      equal(content[1], { type: "input_file", file_id: "file_12345678" });
      equal("detail" in content[1], false);
      return Promise.resolve(jsonResponse(completedResponse(stemPageBatch())));
    }
    throw new Error("unexpected provider endpoint");
  });
  const artifactId = "22222222-2222-4222-8222-222222222222";
  const fileId = await adapter.uploadPdf(pdf, artifactId);
  const result = await adapter.execute(
    {
      ...baseRequest(),
      operation: "page_visual",
      input: { kind: "pdf", bytes: pdf, pageNumbers: [1] },
    },
    undefined,
    fileId,
  );
  equal(result.result, stemPageBatch());
  equal(responseCreates, 1);
});

Deno.test("page recovery is one high-detail page and fails closed on wrong provenance", async () => {
  const pdf = await buildSyntheticPdf(["text"]);
  let calls = 0;
  const adapter = adapterWith((input, init) => {
    if (String(input).includes("/responses")) {
      calls++;
      const body = JSON.parse(String(init?.body));
      const prompt = body.input[0].content[0].text as string;
      equal(body.text.format.name, "phase_c_page_recovery_v3");
      equal(prompt.includes("single-page recovery pass"), true);
      equal(prompt.includes(JSON.stringify("Authoritative page text.")), true);
      return Promise.resolve(
        jsonResponse(completedResponse({
          pages: [{ ...pageBatch().pages[0], page_number: 2 }],
        })),
      );
    }
    throw new Error("unexpected provider endpoint");
  });
  const error = await caught(() =>
    adapter.execute(
      {
        ...baseRequest(),
        operation: "page_recovery",
        input: {
          kind: "pdf",
          bytes: pdf,
          pageNumbers: [1],
          authoritativeText: "Authoritative page text.",
          renderDetail: "high",
        },
      },
      undefined,
      "file_12345678",
    )
  );
  equal(error instanceof ProviderBoundaryError, true);
  equal(calls, 1);
});

Deno.test("page recovery rejects multiple pages before provider dispatch", async () => {
  let calls = 0;
  const adapter = adapterWith(() => {
    calls++;
    return Promise.resolve(jsonResponse(completedResponse(pageBatch())));
  });
  const error = await caught(() =>
    adapter.execute(
      {
        ...baseRequest(),
        operation: "page_recovery",
        expectedPages: [1, 2],
        pageCount: 2,
        input: {
          kind: "pdf",
          bytes: new Uint8Array([1]),
          pageNumbers: [1, 2],
          authoritativeText: "",
          renderDetail: "high",
        },
      },
      undefined,
      "file_12345678",
    )
  );
  equal(error.message, "invalid_page_recovery_request");
  equal(calls, 0);
});

Deno.test("page recovery rejects non-PDF input before provider dispatch", async () => {
  let calls = 0;
  const adapter = adapterWith(() => {
    calls++;
    return Promise.resolve(jsonResponse(completedResponse(pageBatch())));
  });
  const error = await caught(() =>
    adapter.execute({
      ...baseRequest(),
      operation: "page_recovery",
      input: {
        kind: "image",
        bytes: new Uint8Array([1]),
        mimeType: "image/png",
      },
    })
  );
  equal(error.message, "invalid_page_recovery_request");
  equal(calls, 0);
});

Deno.test("C2 PDF execution refuses an unpersisted file identity before dispatch", async () => {
  let calls = 0;
  const adapter = adapterWith(() => {
    calls++;
    return Promise.resolve(jsonResponse(completedResponse(pageBatch())));
  });
  const error = await caught(() =>
    adapter.execute({
      ...baseRequest(),
      operation: "page_visual",
      input: { kind: "pdf", bytes: new Uint8Array([1]), pageNumbers: [1] },
    })
  );
  equal(error.message, "persisted_pdf_file_id_required");
  equal(calls, 0);
});

Deno.test("final summary accepts bounded 20 21 22 and 100 page hierarchies", async () => {
  for (const pageCount of [20, 21, 22, 100]) {
    const pages = Array.from({ length: pageCount }, (_, index) => index + 1);
    const hierarchy = reductionHierarchy(pages);
    equal(
      hierarchy.every((level) =>
        level.every((inputCount) => inputCount >= 1 && inputCount <= 10)
      ),
      true,
    );
    equal(hierarchy[0].length, Math.ceil(pageCount / 10));
    equal(hierarchy.at(-1)?.length, 1);
    if (pageCount === 21) equal(hierarchy.map((level) => level.length), [3, 1]);

    const summary = summaryForPages(pages);
    const projection = projectSummaryToSafeMarkdown(summary);
    equal(
      new TextEncoder().encode(JSON.stringify(summary)).length < 1024 * 1024,
      true,
    );
    equal(projection.length <= 100000, true);

    let calls = 0;
    const adapter = adapterWith((_input, init) => {
      calls++;
      const body = JSON.parse(String(init?.body));
      equal(body.text.format.name, "phase_c_final_summary_v3");
      equal(
        body.text.format.schema.properties.equations.items.properties.latex,
        { type: "string", pattern: "\\S" },
      );
      const prompt = body.input[0].content[0].text as string;
      equal(
        prompt.includes("only for a validated mathematical expression"),
        true,
      );
      equal(
        prompt.includes(
          "omit both when no valid mathematical equation exists",
        ),
        true,
      );
      equal(
        prompt.includes(
          "Never place source code, prose, placeholders, or null values in LaTeX",
        ),
        true,
      );
      equal(
        prompt.includes(
          "completed pages belong only in analyzed_pages, partial pages belong only in partial_pages, and missing pages belong only in missing_pages",
        ),
        true,
      );
      equal(prompt.toLowerCase().includes("never invent a formula"), true);
      return Promise.resolve(jsonResponse(completedResponse(summary)));
    });
    const result = await adapter.execute(finalSummaryRequest(pages));
    equal(result.result, summary);
    equal(calls, 1);
  }
});

Deno.test("21-page parent reduction permits three bounded inputs", async () => {
  const pages = Array.from({ length: 21 }, (_, index) => index + 1);
  const reduction = reductionForPages(pages);
  let calls = 0;
  const adapter = adapterWith(() => {
    calls++;
    return Promise.resolve(jsonResponse(completedResponse(reduction)));
  });
  const result = await adapter.execute({
    operation: "reduction",
    input: {
      kind: "text",
      text: JSON.stringify({
        inputs: [
          reductionForPages(pages.slice(0, 10)),
          reductionForPages(pages.slice(10, 20)),
          reductionForPages(pages.slice(20)),
        ],
        equation_ids: [[], [], []],
      }),
    },
    expectedPages: pages,
    allowedEquationIds: [],
    pageCount: pages.length,
    idempotencyKey: "c".repeat(64),
  });
  equal(result.result, reduction);
  equal(calls, 1);
});

Deno.test("parent reduction rejects more than ten inputs before dispatch", async () => {
  const pages = Array.from({ length: 100 }, (_, index) => index + 1);
  let calls = 0;
  const adapter = adapterWith(() => {
    calls++;
    return Promise.resolve(
      jsonResponse(completedResponse(reductionForPages(pages))),
    );
  });
  const error = await caught(() =>
    adapter.execute({
      operation: "reduction",
      input: {
        kind: "text",
        text: JSON.stringify({
          inputs: Array.from({ length: 11 }, () => reductionForPages([1])),
          equation_ids: Array.from({ length: 11 }, () => []),
        }),
      },
      expectedPages: pages,
      allowedEquationIds: [],
      pageCount: pages.length,
      idempotencyKey: "d".repeat(64),
    })
  );
  equal(error.message, "invalid_reduction_request");
  equal(calls, 0);
});

Deno.test("final summary rejects malformed manifests before dispatch", async () => {
  const pages = Array.from({ length: 21 }, (_, index) => index + 1);
  for (
    const mutate of [
      (payload: Record<string, any>) => payload.manifest.pop(),
      (payload: Record<string, any>) =>
        payload.manifest.push(payload.manifest[0]),
      (payload: Record<string, any>) => payload.manifest[20].page_number = 22,
      (payload: Record<string, any>) => payload.unexpected = true,
    ]
  ) {
    let calls = 0;
    const adapter = adapterWith(() => {
      calls++;
      return Promise.resolve(
        jsonResponse(completedResponse(summaryForPages(pages))),
      );
    });
    const request = finalSummaryRequest(pages);
    const payload = JSON.parse(request.input.text);
    mutate(payload);
    request.input.text = JSON.stringify(payload);
    const error = await caught(() => adapter.execute(request));
    equal(error.message, "invalid_final_summary_request");
    equal(calls, 0);
  }
});

Deno.test("final summary accepts an exact 21-page terminal partition with missing pages", async () => {
  const allPages = Array.from({ length: 21 }, (_, index) => index + 1);
  const missingPages = [7, 19];
  const partialPages = [13];
  const authoritativePages = allPages.filter((page) =>
    !missingPages.includes(page)
  );
  const analyzedPages = authoritativePages.filter((page) =>
    !partialPages.includes(page)
  );
  const request = finalSummaryRequest(authoritativePages);
  request.pageCount = allPages.length;
  const payload = JSON.parse(request.input.text);
  payload.manifest = allPages.map((page) => ({
    page_number: page,
    status: missingPages.includes(page)
      ? "missing"
      : partialPages.includes(page)
      ? "partial"
      : "completed",
    route: "text",
    warnings: missingPages.includes(page) ? [{ code: "page_missing" }] : [],
  }));
  request.input.text = JSON.stringify(payload);
  const summary = summaryForPages(authoritativePages);
  summary.partial_extraction = {
    is_partial: true,
    analyzed_pages: analyzedPages,
    partial_pages: partialPages,
    missing_pages: missingPages,
    page_modes: allPages.map((page) => ({ page, mode: "text" })),
  };
  let calls = 0;
  const adapter = adapterWith(() => {
    calls++;
    return Promise.resolve(jsonResponse(completedResponse(summary)));
  });
  const result = await adapter.execute(request);
  equal(result.result, summary);
  equal(calls, 1);
});

Deno.test("final summary rejects reduction provenance that includes a missing page", async () => {
  const allPages = Array.from({ length: 21 }, (_, index) => index + 1);
  const request = finalSummaryRequest(allPages);
  const payload = JSON.parse(request.input.text);
  payload.manifest[6].status = "missing";
  request.input.text = JSON.stringify(payload);
  let calls = 0;
  const adapter = adapterWith(() => {
    calls++;
    return Promise.resolve(
      jsonResponse(completedResponse(summaryForPages(allPages))),
    );
  });
  const error = await caught(() => adapter.execute(request));
  equal(error.message, "invalid_final_summary_request");
  equal(calls, 0);
});

Deno.test("C2 file DELETE treats provider 404 as idempotent cleanup success", async () => {
  let deletes = 0;
  const adapter = adapterWith((_input, init) => {
    equal(init?.method, "DELETE");
    deletes++;
    return Promise.resolve(jsonResponse({ error: "already gone" }, 404));
  });
  equal(await adapter.deleteFile("file_12345678"), true);
  equal(await adapter.deleteFile("file_12345678"), true);
  equal(deletes, 2);
});

Deno.test("C2 adapter classifies after-dispatch network ambiguity without response ID", async () => {
  const adapter = adapterWith(() =>
    Promise.reject(new TypeError("network details must stay private"))
  );
  const error = await caught(() => adapter.execute(imageRequest(pngBytes())));
  equal(error instanceof ProviderBoundaryError, true);
  equal((error as ProviderBoundaryError).dispatched, true);
  equal((error as ProviderBoundaryError).responseId, undefined);
  equal(error.message.includes("private"), false);
});

Deno.test("C2 adapter preserves explicit retryable HTTP status without raw body", async () => {
  const adapter = adapterWith(() =>
    Promise.resolve(
      jsonResponse({ secret: "provider body" }, 429, { "retry-after": "17" }),
    )
  );
  const error = await caught(() => adapter.execute(imageRequest(pngBytes())));
  equal(error instanceof ProviderBoundaryError, true);
  equal((error as ProviderBoundaryError).status, 429);
  equal((error as ProviderBoundaryError).retryAfterSeconds, 17);
  equal(error.message.includes("provider body"), false);
});

for (const status of [408, 429, 500]) {
  Deno.test(`C2 HTTP ${status} never treats x-request-id as a response ID`, async () => {
    const adapter = adapterWith(() =>
      Promise.resolve(jsonResponse(
        { error: { message: "private" } },
        status,
        { "x-request-id": "req_header_12345678" },
      ))
    );
    const error = await caught(() => adapter.execute(imageRequest(pngBytes())));
    equal((error as ProviderBoundaryError).responseId, undefined);
  });
}

Deno.test("C2 HTTP error accepts only a documented response body ID", async () => {
  const adapter = adapterWith(() =>
    Promise.resolve(jsonResponse(
      { object: "response", id: "resp_body_12345678", status: "failed" },
      500,
      { "x-request-id": "req_header_12345678" },
    ))
  );
  const error = await caught(() => adapter.execute(imageRequest(pngBytes())));
  equal((error as ProviderBoundaryError).responseId, "resp_body_12345678");
});

Deno.test("C2 invalid provider output with response ID becomes reconciliation evidence", async () => {
  const adapter = adapterWith(() =>
    Promise.resolve(jsonResponse(completedResponse({
      pages: [{ ...pageBatch().pages[0], page_number: 2 }],
    })))
  );
  const error = await caught(() => adapter.execute(imageRequest(pngBytes())));
  equal(error instanceof ProviderBoundaryError, true);
  equal((error as ProviderBoundaryError).responseId, "resp_12345678");
});

Deno.test("C2 retrieval validates reconciled output and never resubmits", async () => {
  let requests = 0;
  const adapter = adapterWith((input) => {
    const url = String(input);
    if (url.includes("/responses/")) {
      requests++;
      return Promise.resolve(jsonResponse(completedResponse(pageBatch())));
    }
    throw new Error("unexpected resubmission");
  });
  const result = await adapter.retrieve({
    responseId: "resp_12345678",
    request: imageRequest(pngBytes()),
  });
  equal(result.status, "completed");
  equal(requests, 1);
});

Deno.test("final-summary reconciliation canonicalizes the authoritative partition with one GET", async () => {
  const methods: string[] = [];
  const request = finalSummaryRequest([1]);
  const input = JSON.parse(request.input.text);
  input.manifest = structuredClone(
    finalSummaryPartitionOverlapFixture.manifest,
  );
  request.input.text = JSON.stringify(input);
  const adapter = adapterWith((_input, init) => {
    methods.push(init?.method ?? "GET");
    return Promise.resolve(jsonResponse(completedResponse(
      finalSummaryPartitionOverlapFixture.providerResult,
    )));
  });

  const result = await adapter.retrieve({
    responseId: "resp_12345678",
    request,
  });

  equal(methods, ["GET"]);
  equal(result.status, "completed");
  equal(
    (result.result as StructuredSummary).partial_extraction,
    {
      is_partial: true,
      analyzed_pages: [],
      partial_pages: [1],
      missing_pages: [],
      page_modes: [{ page: 1, mode: "visual" }],
    },
  );
});

Deno.test("diagnostic retrieval performs one GET and zero POST or file upload calls", async () => {
  const methods: string[] = [];
  const adapter = adapterWith((input, init) => {
    equal(String(input).includes("/responses/resp_12345678"), true);
    methods.push(init?.method ?? "GET");
    return Promise.resolve(jsonResponse(completedResponse(pageBatch())));
  });
  const result = await adapter.diagnoseRetrieved({
    responseId: "resp_12345678",
    request: imageRequest(pngBytes()),
  });
  equal(result.ok, true);
  equal(methods, ["GET"]);
});

Deno.test("final-summary diagnostic performs one GET and zero POST or upload calls", async () => {
  const calls: Array<{ url: string; method: string }> = [];
  const adapter = adapterWith((input, init) => {
    calls.push({ url: String(input), method: init?.method ?? "GET" });
    return Promise.resolve(
      jsonResponse(completedResponse(summaryForPages([1]))),
    );
  });
  const result = await adapter.diagnoseFinalSummaryRetrieved({
    responseId: "resp_12345678",
    pageCount: 1,
  });
  equal(result.ok, true);
  equal(calls.length, 1);
  equal(calls[0].method, "GET");
  equal(calls[0].url.includes("/responses/resp_12345678"), true);
});

for (const status of [404, 429, 500, 503]) {
  Deno.test(`final-summary diagnostic GET ${status} has no fallback`, async () => {
    const methods: string[] = [];
    const adapter = adapterWith((_input, init) => {
      methods.push(init?.method ?? "GET");
      return Promise.resolve(jsonResponse({ error: "private body" }, status));
    });
    const result = await adapter.diagnoseFinalSummaryRetrieved({
      responseId: "resp_12345678",
      pageCount: 1,
    });
    equal(result.ok, false);
    if (!result.ok) {
      equal(result.code, "final_validation_unknown");
      equal(JSON.stringify(result.metadata).includes("private body"), false);
    }
    equal(methods, ["GET"]);
  });
}

for (const status of [404, 429, 500, 503]) {
  Deno.test(`diagnostic GET ${status} becomes content-free validation_unknown`, async () => {
    const methods: string[] = [];
    const adapter = adapterWith((_input, init) => {
      methods.push(init?.method ?? "GET");
      return Promise.resolve(jsonResponse({ error: "private body" }, status));
    });
    const result = await adapter.diagnoseRetrieved({
      responseId: "resp_12345678",
      request: imageRequest(pngBytes()),
    });
    equal(result.ok, false);
    if (!result.ok) {
      equal(result.code, "validation_unknown");
      equal(JSON.stringify(result.metadata).includes("private body"), false);
    }
    equal(methods, ["GET"]);
  });
}

Deno.test("diagnostic GET network failure becomes validation_unknown without fallback", async () => {
  const methods: string[] = [];
  const adapter = adapterWith((_input, init) => {
    methods.push(init?.method ?? "GET");
    return Promise.reject(new TypeError("private network detail"));
  });
  const result = await adapter.diagnoseRetrieved({
    responseId: "resp_12345678",
    request: imageRequest(pngBytes()),
  });
  equal(result.ok, false);
  if (!result.ok) equal(result.code, "validation_unknown");
  equal(methods, ["GET"]);
});

for (const status of ["queued", "in_progress", "incomplete"]) {
  Deno.test(`C2 response status ${status} is reconciliation evidence, never success`, async () => {
    const adapter = adapterWith(() =>
      Promise.resolve(jsonResponse({
        ...completedResponse(pageBatch()),
        status,
        incomplete_details: status === "incomplete"
          ? { reason: "max_output_tokens" }
          : null,
      }))
    );
    const error = await caught(() => adapter.execute(imageRequest(pngBytes())));
    equal((error as ProviderBoundaryError).kind, "response_pending");
    equal((error as ProviderBoundaryError).responseId, "resp_12345678");
  });
}

for (const status of ["cancelled", "failed"]) {
  Deno.test(`C2 terminal ${status} response is never persisted as success`, async () => {
    const adapter = adapterWith(() =>
      Promise.resolve(jsonResponse({
        ...completedResponse(pageBatch()),
        status,
        error: status === "failed" ? { code: "provider_failed" } : null,
      }))
    );
    const error = await caught(() => adapter.execute(imageRequest(pngBytes())));
    equal((error as ProviderBoundaryError).kind, "response_failed");
  });
}

Deno.test("C2 refusal is typed and never parsed as structured success", async () => {
  const adapter = adapterWith(() =>
    Promise.resolve(jsonResponse({
      id: "resp_12345678",
      object: "response",
      status: "completed",
      error: null,
      incomplete_details: null,
      output: [{
        type: "message",
        content: [{ type: "refusal", refusal: "No" }],
      }],
    }))
  );
  const error = await caught(() => adapter.execute(imageRequest(pngBytes())));
  equal((error as ProviderBoundaryError).kind, "refusal");
});

for (
  const [name, output] of [
    ["empty", []],
    ["duplicate", [outputText(pageBatch()), outputText(pageBatch())]],
    ["truncated", [outputText('{"pages":')]],
  ] as const
) {
  Deno.test(`C2 ${name} structured output is invalid`, async () => {
    const adapter = adapterWith(() =>
      Promise.resolve(jsonResponse({
        ...completedResponse(pageBatch()),
        output: [{ type: "message", content: output }],
      }))
    );
    const error = await caught(() => adapter.execute(imageRequest(pngBytes())));
    equal((error as ProviderBoundaryError).kind, "invalid_response");
  });
}

Deno.test("C2 reconciliation treats incomplete as terminal without POST", async () => {
  let reads = 0;
  const adapter = adapterWith(() => {
    reads++;
    return Promise.resolve(
      jsonResponse(
        reads === 1
          ? {
            id: "resp_12345678",
            object: "response",
            status: "incomplete",
            incomplete_details: { reason: "max_output_tokens" },
          }
          : completedResponse(pageBatch()),
      ),
    );
  });
  const first = await adapter.retrieve({
    responseId: "resp_12345678",
    request: imageRequest(pngBytes()),
  });
  const second = await adapter.retrieve({
    responseId: "resp_12345678",
    request: imageRequest(pngBytes()),
  });
  equal(first.status, "incomplete");
  equal(second.status, "completed");
  equal(reads, 2);
});

Deno.test("C2 reconciliation classifies completed invalid output without POST", async () => {
  const methods: string[] = [];
  const adapter = adapterWith((_input, init) => {
    methods.push(init?.method ?? "GET");
    return Promise.resolve(jsonResponse(completedResponse({
      ...pageBatch(),
      unexpected: true,
    })));
  });
  const result = await adapter.retrieve({
    responseId: "resp_12345678",
    request: imageRequest(pngBytes()),
  });
  equal(result.status, "invalid");
  equal(methods, ["GET"]);
});

Deno.test("C2 Retry-After supports seconds and HTTP dates with clamping", () => {
  const now = Date.UTC(2026, 0, 1, 0, 0, 0);
  equal(parseRetryAfter("17", now), 17);
  equal(parseRetryAfter("99999", now), 900);
  equal(parseRetryAfter(new Date(now + 42_000).toUTCString(), now), 42);
  equal(parseRetryAfter(new Date(now - 1_000).toUTCString(), now), 0);
  equal(parseRetryAfter("not-a-date", now), undefined);
});

function adapterWith(fetcher: typeof fetch) {
  return new TrustedOpenAiAdapter({
    apiKey: "test-key-not-real",
    model: "server-model",
    fetcher,
    timeoutMs: 1000,
  });
}

function baseRequest(): ProviderRequest {
  return {
    operation: "page_text",
    input: {
      kind: "text",
      text: '<original_page number="1">Safe text.</original_page>',
    },
    expectedPages: [1],
    pageCount: 1,
    idempotencyKey: "a".repeat(64),
  };
}

function imageRequest(bytes: Uint8Array): ProviderRequest {
  return {
    ...baseRequest(),
    operation: "page_visual",
    input: { kind: "image", bytes, mimeType: "image/png" },
  };
}

function finalSummaryRequest(
  pages: number[],
): ProviderRequest & { input: { kind: "text"; text: string } } {
  const payload = {
    operation: "final_summary",
    authoritative_equations: [],
    validated_reduction: {
      source_pages: pages,
      summary_markdown: "Validated reduction.",
      key_concepts: ["Concept"],
      equation_ids: [],
      warnings: [],
      confidence: 0.9,
    },
    manifest: pages.map((page) => ({
      page_number: page,
      status: "completed",
      route: "text",
      warnings: [],
    })),
  };
  return {
    operation: "final_summary",
    input: { kind: "text", text: JSON.stringify(payload) },
    expectedPages: pages,
    allowedEquationIds: [],
    authoritativeEquations: [],
    pageCount: pages.length,
    idempotencyKey: "b".repeat(64),
  };
}

function reductionHierarchy(pages: number[]): number[][] {
  const levels: number[][] = [];
  let current: unknown[] = pages;
  while (current.length > 1) {
    const groups = createReductionGroups(current);
    levels.push(groups.map((group) => group.length));
    current = groups.map((_, index) => index);
  }
  return levels;
}

function summaryForPages(pages: number[]): StructuredSummary {
  return {
    language: "en",
    sections: [{
      id: "section_1",
      title: "Summary",
      blocks: [{
        kind: "prose",
        markdown: "Safe structured summary.",
        display: "block",
      }],
      source_pages: pages,
      confidence: 0.9,
    }],
    key_concepts: [],
    equations: [],
    warnings: [],
    partial_extraction: {
      is_partial: false,
      analyzed_pages: pages,
      partial_pages: [],
      missing_pages: [],
      page_modes: pages.map((page) => ({ page, mode: "text" })),
    },
  };
}

function reductionForPages(pages: number[]) {
  return {
    source_pages: pages,
    summary_markdown: "Validated reduction.",
    key_concepts: ["Concept"],
    equation_ids: [],
    warnings: [],
    confidence: 0.9,
  };
}

function pageBatch() {
  return {
    pages: [{
      page_number: 1,
      content_status: "completed",
      summary_markdown: "Safe summary.",
      key_concepts: ["Concept"],
      equations: [],
      confidence: 0.9,
      warnings: [],
      trustworthy: true,
    }],
  };
}

function stemPageBatch() {
  return {
    pages: [{
      page_number: 1,
      content_status: "completed",
      summary_markdown:
        "The page contains a quadratic formula and an integral.",
      key_concepts: ["Quadratic formula", "Definite integral"],
      equations: [{
        id: "eq_quadratic",
        latex: String.raw`\frac{-b \pm \sqrt{b^2-4ac}}{2a}`,
        explanation_markdown: "A standard quadratic solution.",
        source_page: 1,
        display: "block",
        confidence: 0.95,
        uncertainty: false,
      }, {
        id: "eq_integral",
        latex: String.raw`\int_0^\pi \sin(x) dx = 2`,
        explanation_markdown: "A definite integral identity.",
        source_page: 1,
        display: "block",
        confidence: 0.95,
        uncertainty: false,
      }],
      confidence: 0.95,
      warnings: [],
      trustworthy: true,
    }],
  };
}

function outputText(value: unknown) {
  return {
    type: "output_text",
    text: typeof value === "string" ? value : JSON.stringify(value),
  };
}

function completedResponse(value: unknown) {
  return {
    id: "resp_12345678",
    object: "response",
    status: "completed",
    error: null,
    incomplete_details: null,
    output: [{ type: "message", content: [outputText(value)] }],
  };
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

function jsonResponse(body: unknown, status = 200, headers?: HeadersInit) {
  return new Response(JSON.stringify(body), {
    status,
    headers: { "Content-Type": "application/json", ...headers },
  });
}

function toBase64(bytes: Uint8Array) {
  return btoa(String.fromCharCode(...bytes));
}

async function caught(action: () => Promise<unknown>): Promise<Error> {
  try {
    await action();
  } catch (error) {
    if (error instanceof Error) return error;
  }
  throw new Error("Expected error");
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
