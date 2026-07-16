import { PDFDocument } from "pdf-lib";
import { sha256Hex } from "./fingerprints_retry.ts";

export interface MiniPdfResult {
  bytes: Uint8Array;
  originalPageNumbers: number[];
  normalizedFingerprint: string;
}

const fixedDate = new Date("2026-01-01T00:00:00.000Z");

export async function createMiniPdf(
  sourceBytes: Uint8Array,
  originalPageNumbers: number[],
): Promise<MiniPdfResult> {
  if (originalPageNumbers.length < 1 || originalPageNumbers.length > 5) {
    throw new Error("mini_pdf_page_limit");
  }
  if (
    new Set(originalPageNumbers).size !== originalPageNumbers.length ||
    originalPageNumbers.some((page) => !Number.isInteger(page) || page < 1)
  ) {
    throw new Error("mini_pdf_page_mapping_invalid");
  }
  const source = await PDFDocument.load(sourceBytes, {
    ignoreEncryption: false,
    updateMetadata: false,
  });
  if (originalPageNumbers.some((page) => page > source.getPageCount())) {
    throw new Error("mini_pdf_page_out_of_range");
  }
  const output = await PDFDocument.create();
  output.setTitle("AI Study Buddy visual page batch");
  output.setAuthor("AI Study Buddy");
  output.setProducer("AI Study Buddy Phase C");
  output.setCreator("AI Study Buddy Phase C");
  output.setCreationDate(fixedDate);
  output.setModificationDate(fixedDate);
  output.setSubject(`Original pages: ${originalPageNumbers.join(",")}`);
  const copied = await output.copyPages(
    source,
    originalPageNumbers.map((page) => page - 1),
  );
  copied.forEach((page) => output.addPage(page));
  const bytes = await output.save({
    addDefaultPage: false,
    useObjectStreams: false,
    objectsPerTick: 50,
  });
  const normalizedFingerprint = await sha256Hex(bytes);
  return {
    bytes,
    originalPageNumbers: [...originalPageNumbers],
    normalizedFingerprint,
  };
}
