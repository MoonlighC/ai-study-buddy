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
  );
}

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
