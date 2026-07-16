import { FakeOpenAiBoundary, FakeSupabaseBoundary } from "./contracts.ts";

export class InMemoryFakeOpenAi implements FakeOpenAiBoundary {
  readonly submissions: Array<{
    fingerprint: string;
    operation: string;
    payload: unknown;
  }> = [];
  readonly retrieved: string[] = [];
  readonly deletedFiles: string[] = [];

  constructor(
    private readonly result: unknown = { ok: true },
    private readonly responseId = "fake_response_id",
  ) {}

  submit(input: {
    fingerprint: string;
    operation: string;
    payload: unknown;
  }): Promise<{ responseId: string; result: unknown }> {
    this.submissions.push(structuredClone(input));
    return Promise.resolve({
      responseId: this.responseId,
      result: this.result,
    });
  }

  retrieve(responseId: string): Promise<{ status: string; result?: unknown }> {
    this.retrieved.push(responseId);
    return Promise.resolve({ status: "completed", result: this.result });
  }

  deleteFile(fileId: string): Promise<boolean> {
    this.deletedFiles.push(fileId);
    return Promise.resolve(true);
  }
}

export class InMemoryFakeSupabase implements FakeSupabaseBoundary {
  readonly rpcCalls: Array<{ name: string; args: Record<string, unknown> }> =
    [];

  constructor(private readonly materials = new Map<string, unknown>()) {}

  loadOwnedMaterial(principalId: string, materialId: string): Promise<unknown> {
    return Promise.resolve(
      this.materials.get(`${principalId}:${materialId}`) ?? null,
    );
  }

  callTrustedRpc(
    name: string,
    args: Record<string, unknown>,
  ): Promise<unknown> {
    this.rpcCalls.push({ name, args: structuredClone(args) });
    return Promise.resolve({ ok: true });
  }
}
