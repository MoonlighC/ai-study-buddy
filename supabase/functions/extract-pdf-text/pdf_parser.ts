import { extractText, getDocumentProxy } from "unpdf";

export async function parseSelectablePdfText(
  bytes: Uint8Array,
): Promise<{ pages: string[]; pageCount: number }> {
  const document = await getDocumentProxy(bytes);
  const result = await extractText(document, { mergePages: false });
  return { pages: result.text, pageCount: result.totalPages };
}
