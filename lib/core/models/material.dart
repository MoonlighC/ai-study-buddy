class StudyMaterial {
  const StudyMaterial({
    required this.id,
    required this.subjectId,
    required this.title,
    required this.kind,
    required this.content,
    required this.createdLabel,
    this.createdAt,
    this.summary,
    this.sourceKind = MaterialSourceKind.manual,
    this.storageBucket,
    this.storagePath,
    this.mimeType,
    this.fileSizeBytes,
    this.processingStatus = MaterialProcessingStatus.ready,
    this.pdfExtraction,
    this.imageOcr,
    this.scannedPdfOcr,
  });

  final String id;
  final String subjectId;
  final String title;
  final MaterialKind kind;
  final String content;
  final String createdLabel;
  final DateTime? createdAt;
  final String? summary;
  final MaterialSourceKind sourceKind;
  final String? storageBucket;
  final String? storagePath;
  final String? mimeType;
  final int? fileSizeBytes;
  final MaterialProcessingStatus processingStatus;
  final PdfExtractionMetadata? pdfExtraction;
  final ImageOcrMetadata? imageOcr;
  final ScannedPdfOcrMetadata? scannedPdfOcr;

  bool get hasContentText => content.trim().isNotEmpty;

  StudyMaterial copyWith({
    String? id,
    String? subjectId,
    String? title,
    MaterialKind? kind,
    String? content,
    String? createdLabel,
    DateTime? createdAt,
    String? summary,
    MaterialSourceKind? sourceKind,
    String? storageBucket,
    String? storagePath,
    String? mimeType,
    int? fileSizeBytes,
    MaterialProcessingStatus? processingStatus,
    PdfExtractionMetadata? pdfExtraction,
    ImageOcrMetadata? imageOcr,
    ScannedPdfOcrMetadata? scannedPdfOcr,
  }) {
    return StudyMaterial(
      id: id ?? this.id,
      subjectId: subjectId ?? this.subjectId,
      title: title ?? this.title,
      kind: kind ?? this.kind,
      content: content ?? this.content,
      createdLabel: createdLabel ?? this.createdLabel,
      createdAt: createdAt ?? this.createdAt,
      summary: summary ?? this.summary,
      sourceKind: sourceKind ?? this.sourceKind,
      storageBucket: storageBucket ?? this.storageBucket,
      storagePath: storagePath ?? this.storagePath,
      mimeType: mimeType ?? this.mimeType,
      fileSizeBytes: fileSizeBytes ?? this.fileSizeBytes,
      processingStatus: processingStatus ?? this.processingStatus,
      pdfExtraction: pdfExtraction ?? this.pdfExtraction,
      imageOcr: imageOcr ?? this.imageOcr,
      scannedPdfOcr: scannedPdfOcr ?? this.scannedPdfOcr,
    );
  }
}

class ImageOcrMetadata {
  const ImageOcrMetadata({
    this.extractedAt,
    this.characterCount,
    this.detectedLanguage,
    this.handwritingDetected = false,
    this.warningCodes = const [],
    this.truncated = false,
    this.extractionVersion,
    this.provider,
    this.model,
    this.failureCode,
    this.failureMessage,
  });

  final DateTime? extractedAt;
  final int? characterCount;
  final String? detectedLanguage;
  final bool handwritingDetected;
  final List<String> warningCodes;
  final bool truncated;
  final String? extractionVersion;
  final String? provider;
  final String? model;
  final String? failureCode;
  final String? failureMessage;
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
    this.classification,
    this.usefulPages = const [],
    this.ocrCandidatePages = const [],
  });

  final DateTime? extractedAt;
  final int? characterCount;
  final int? pageCount;
  final bool truncated;
  final String? extractionVersion;
  final String? failureCode;
  final String? failureMessage;
  final String? classification;
  final List<int> usefulPages;
  final List<int> ocrCandidatePages;
}

class ScannedPdfOcrMetadata {
  const ScannedPdfOcrMetadata({this.extractedAt, this.processedPages = const [], this.totalPages, this.failedPages = const [], this.partial = false, this.truncated = false, this.characterCount, this.detectedLanguages = const [], this.handwritingDetected = false, this.warningCodes = const [], this.extractionVersion, this.provider, this.model, this.failureCode, this.failureMessage});
  final DateTime? extractedAt; final List<int> processedPages; final int? totalPages; final List<int> failedPages;
  final bool partial; final bool truncated; final int? characterCount; final List<String> detectedLanguages;
  final bool handwritingDetected; final List<String> warningCodes; final String? extractionVersion;
  final String? provider; final String? model; final String? failureCode; final String? failureMessage;
}
