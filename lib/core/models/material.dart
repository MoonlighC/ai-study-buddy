class StudyMaterial {
  const StudyMaterial({
    required this.id,
    required this.subjectId,
    required this.title,
    required this.kind,
    required this.content,
    required this.createdLabel,
    this.summary,
    this.sourceKind = MaterialSourceKind.manual,
    this.storageBucket,
    this.storagePath,
    this.mimeType,
    this.fileSizeBytes,
    this.processingStatus = MaterialProcessingStatus.ready,
    this.pdfExtraction,
  });

  final String id;
  final String subjectId;
  final String title;
  final MaterialKind kind;
  final String content;
  final String createdLabel;
  final String? summary;
  final MaterialSourceKind sourceKind;
  final String? storageBucket;
  final String? storagePath;
  final String? mimeType;
  final int? fileSizeBytes;
  final MaterialProcessingStatus processingStatus;
  final PdfExtractionMetadata? pdfExtraction;

  bool get hasContentText => content.trim().isNotEmpty;

  StudyMaterial copyWith({
    String? id,
    String? subjectId,
    String? title,
    MaterialKind? kind,
    String? content,
    String? createdLabel,
    String? summary,
    MaterialSourceKind? sourceKind,
    String? storageBucket,
    String? storagePath,
    String? mimeType,
    int? fileSizeBytes,
    MaterialProcessingStatus? processingStatus,
    PdfExtractionMetadata? pdfExtraction,
  }) {
    return StudyMaterial(
      id: id ?? this.id,
      subjectId: subjectId ?? this.subjectId,
      title: title ?? this.title,
      kind: kind ?? this.kind,
      content: content ?? this.content,
      createdLabel: createdLabel ?? this.createdLabel,
      summary: summary ?? this.summary,
      sourceKind: sourceKind ?? this.sourceKind,
      storageBucket: storageBucket ?? this.storageBucket,
      storagePath: storagePath ?? this.storagePath,
      mimeType: mimeType ?? this.mimeType,
      fileSizeBytes: fileSizeBytes ?? this.fileSizeBytes,
      processingStatus: processingStatus ?? this.processingStatus,
      pdfExtraction: pdfExtraction ?? this.pdfExtraction,
    );
  }
}

enum MaterialKind { pastedText, image, pdf }

enum MaterialSourceKind { manual, upload, generated }

enum MaterialProcessingStatus { ready, pending, processing, failed }

class PdfExtractionMetadata {
  const PdfExtractionMetadata({
    this.extractedAt,
    this.characterCount,
    this.pageCount,
    this.truncated = false,
    this.extractionVersion,
    this.failureCode,
    this.failureMessage,
  });

  final DateTime? extractedAt;
  final int? characterCount;
  final int? pageCount;
  final bool truncated;
  final String? extractionVersion;
  final String? failureCode;
  final String? failureMessage;
}
