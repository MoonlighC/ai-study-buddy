import 'package:ai_study_buddy/features/auth/auth_models.dart';
import 'package:ai_study_buddy/features/materials/scanned_pdf_ocr_repository.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('maps authoritative scanned PDF OCR metadata', () async {
    final source = _Source({
      'ok': true,
      'material': {
        'id': 'material-id',
        'subject_id': 'subject-id',
        'title': 'Scan',
        'kind': 'pdf',
        'source_kind': 'upload',
        'content_text': '--- Page 1 ---\n\nUseful OCR study text',
        'processing_status': 'ready',
        'metadata': {
          'scanned_pdf_ocr': {
            'extracted_at': '2026-07-11T12:00:00Z',
            'processed_pages': [1],
            'total_pages': 2,
            'failed_pages': [2],
            'partial': true,
            'character_count': 42,
            'warning_codes': ['page_unreadable'],
          },
        },
      },
    });
    final result = await SupabaseScannedPdfOcrRepository(source).scan(
      user: const AuthUser(id: 'user', email: 'a@example.test'),
      materialId: 'material-id',
    );
    expect(source.materialId, 'material-id');
    expect(result.material.scannedPdfOcr?.processedPages, [1]);
    expect(result.material.scannedPdfOcr?.failedPages, [2]);
    expect(result.material.scannedPdfOcr?.partial, isTrue);
  });
}

class _Source implements ScannedPdfOcrDataSource {
  _Source(this.response);
  final Object? response;
  String? materialId;
  @override
  Future<Object?> invoke(String materialId) async {
    this.materialId = materialId;
    return response;
  }
}
