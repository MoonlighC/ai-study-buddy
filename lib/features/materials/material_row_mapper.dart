import '../../core/models/material.dart';

const materialSelectColumns =
    'id,subject_id,title,kind,source_kind,content_text,summary,'
    'storage_bucket,storage_path,mime_type,file_size_bytes,'
    'processing_status,metadata,created_at';

StudyMaterial mapMaterialRow(Map<String, dynamic> row) {
  return StudyMaterial(
    id: _string(row['id']) ?? '',
    subjectId: _string(row['subject_id']) ?? '',
    title: _string(row['title']) ?? 'Untitled material',
    kind: switch (_string(row['kind'])) {
      'pdf' => MaterialKind.pdf,
      'image' => MaterialKind.image,
      _ => MaterialKind.pastedText,
    },
    content: _string(row['content_text']) ?? '',
    createdLabel: _createdLabel(_string(row['created_at'])),
    createdAt: DateTime.tryParse(_string(row['created_at']) ?? ''),
    summary: _string(row['summary']),
    sourceKind: switch (_string(row['source_kind'])) {
      'upload' => MaterialSourceKind.upload,
      'generated' => MaterialSourceKind.generated,
      _ => MaterialSourceKind.manual,
    },
    storageBucket: _string(row['storage_bucket']),
    storagePath: _string(row['storage_path']),
    mimeType: _string(row['mime_type']),
    fileSizeBytes: _int(row['file_size_bytes']),
    processingStatus: switch (_string(row['processing_status'])) {
      'pending' => MaterialProcessingStatus.pending,
      'processing' => MaterialProcessingStatus.processing,
      'failed' => MaterialProcessingStatus.failed,
      _ => MaterialProcessingStatus.ready,
    },
    pdfExtraction: _pdfExtraction(row['metadata']),
    imageOcr: _imageOcr(row['metadata']),
    scannedPdfOcr: _scannedPdfOcr(row['metadata']),
  );
}

ImageOcrMetadata? _imageOcr(Object? rawMetadata) {
  if (rawMetadata is! Map) return null;
  final metadata = Map<String, dynamic>.from(rawMetadata);
  final successRaw = metadata['image_ocr'];
  final errorRaw = metadata['image_ocr_error'];
  final success = successRaw is Map
      ? Map<String, dynamic>.from(successRaw)
      : const <String, dynamic>{};
  final error = errorRaw is Map
      ? Map<String, dynamic>.from(errorRaw)
      : const <String, dynamic>{};
  if (success.isEmpty && error.isEmpty) return null;
  final warnings = success['warning_codes'];
  return ImageOcrMetadata(
    extractedAt: DateTime.tryParse(_string(success['extracted_at']) ?? ''),
    characterCount: _int(success['character_count']),
    detectedLanguage: _string(success['detected_language']),
    handwritingDetected: success['handwriting_detected'] == true,
    warningCodes: warnings is List
        ? warnings.whereType<String>().toList(growable: false)
        : const [],
    truncated: success['truncated'] == true,
    extractionVersion: _string(success['extraction_version']),
    provider: _string(success['provider']),
    model: _string(success['model']),
    failureCode: _string(error['code']),
    failureMessage: _string(error['message']),
  );
}

ScannedPdfOcrMetadata? _scannedPdfOcr(Object? rawMetadata) {
  if (rawMetadata is! Map) return null;
  final metadata = Map<String, dynamic>.from(rawMetadata);
  final success = metadata['scanned_pdf_ocr'] is Map ? Map<String, dynamic>.from(metadata['scanned_pdf_ocr'] as Map) : const <String, dynamic>{};
  final error = metadata['scanned_pdf_ocr_error'] is Map ? Map<String, dynamic>.from(metadata['scanned_pdf_ocr_error'] as Map) : const <String, dynamic>{};
  if (success.isEmpty && error.isEmpty) return null;
  return ScannedPdfOcrMetadata(extractedAt: DateTime.tryParse(_string(success['extracted_at']) ?? ''), processedPages: _ints(success['processed_pages']), totalPages: _int(success['total_pages']), failedPages: _ints(success['failed_pages']), partial: success['partial'] == true, truncated: success['truncated'] == true, characterCount: _int(success['character_count']), detectedLanguages: (success['detected_languages'] is List ? success['detected_languages'] as List : const []).whereType<String>().toList(growable: false), handwritingDetected: success['handwriting_detected'] == true, warningCodes: (success['warning_codes'] is List ? success['warning_codes'] as List : const []).whereType<String>().toList(growable: false), extractionVersion: _string(success['extraction_version']), provider: _string(success['provider']), model: _string(success['model']), failureCode: _string(error['code']), failureMessage: _string(error['message']));
}

List<int> _ints(Object? value) => value is List ? value.whereType<num>().map((value) => value.toInt()).toList(growable: false) : const [];

PdfExtractionMetadata? _pdfExtraction(Object? rawMetadata) {
  if (rawMetadata is! Map) return null;
  final metadata = Map<String, dynamic>.from(rawMetadata);
  final successRaw = metadata['pdf_extraction'];
  final errorRaw = metadata['pdf_extraction_error'];
  final success = successRaw is Map
      ? Map<String, dynamic>.from(successRaw)
      : const <String, dynamic>{};
  final error = errorRaw is Map
      ? Map<String, dynamic>.from(errorRaw)
      : const <String, dynamic>{};
  if (success.isEmpty && error.isEmpty) return null;
  return PdfExtractionMetadata(
    extractedAt: DateTime.tryParse(_string(success['extracted_at']) ?? ''),
    characterCount: _int(success['character_count']),
    pageCount: _int(success['page_count']),
    truncated: success['truncated'] == true,
    extractionVersion: _string(success['extraction_version']),
    failureCode: _string(error['code']),
    failureMessage: _string(error['message']),
    classification: _string(success['classification']),
    usefulPages: _ints(success['useful_pages']),
    ocrCandidatePages: _ints(success['ocr_candidate_pages']),
  );
}

String? _string(Object? value) {
  if (value is! String || value.trim().isEmpty) return null;
  return value.trim();
}

int? _int(Object? value) => value is num ? value.toInt() : null;

String _createdLabel(String? value) {
  if (value == null || value.length < 10) return 'Synced';
  return value.substring(0, 10);
}
