import { PDFDocument, rgb, StandardFonts } from "pdf-lib";

const transparentPng = Uint8Array.from(
  atob(
    "iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR42mNk+M/wHwAF/gL+X8oJ5AAAAABJRU5ErkJggg==",
  ),
  (char) => char.charCodeAt(0),
);

export type SyntheticPageKind = "text" | "vector" | "raster";

export async function buildSyntheticPdf(
  kinds: SyntheticPageKind[],
): Promise<Uint8Array> {
  if (kinds.length < 1) throw new Error("fixture_requires_page");
  const document = await PDFDocument.create();
  document.setCreationDate(new Date("2026-01-01T00:00:00.000Z"));
  document.setModificationDate(new Date("2026-01-01T00:00:00.000Z"));
  document.setProducer("AI Study Buddy synthetic fixture");
  const font = await document.embedFont(StandardFonts.Helvetica);
  const png = await document.embedPng(transparentPng);
  for (let index = 0; index < kinds.length; index++) {
    const page = document.addPage([612, 792]);
    const label = `Synthetic original page ${index + 1} ${kinds[index]}`;
    page.drawText(label, { x: 48, y: 744, size: 12, font });
    if (kinds[index] === "text") {
      page.drawText(
        "Selectable study text: integral, matrix, circuit and graph analysis.",
        { x: 48, y: 700, size: 11, font },
      );
    } else if (kinds[index] === "vector") {
      for (let line = 0; line < 80; line++) {
        page.drawLine({
          start: {
            x: 40 + (line % 20) * 25,
            y: 80 + Math.floor(line / 20) * 130,
          },
          end: {
            x: 60 + (line % 20) * 25,
            y: 120 + Math.floor(line / 20) * 130,
          },
          thickness: 1,
          color: rgb(0.1, 0.2, 0.7),
        });
      }
    } else {
      page.drawImage(png, { x: 48, y: 120, width: 500, height: 500 });
    }
  }
  return await document.save({
    useObjectStreams: false,
    addDefaultPage: false,
  });
}
