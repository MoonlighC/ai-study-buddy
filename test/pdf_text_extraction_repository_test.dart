import 'package:ai_study_buddy/features/auth/auth_models.dart';
import 'package:ai_study_buddy/features/materials/pdf_text_extraction_repository.dart';
import 'package:flutter_test/flutter_test.dart';

const user = AuthUser(
  id: '11111111-1111-4111-8111-111111111111',
  email: 'student@example.test',
  displayName: 'Student',
);

void main() {
  test(
    'Supabase extraction sends only material id and maps authoritative row',
    () async {
      final source = _FakeSource(<String, Object?>{
        'ok': true,
        'material': _row(),
      });
      final repository = SupabasePdfTextExtractionRepository(source);

      final result = await repository.extractPdfText(
        user: user,
        materialId: '22222222-2222-4222-8222-222222222222',
      );

      expect(source.materialIds, ['22222222-2222-4222-8222-222222222222']);
      expect(result.material.content, 'Extracted text');
      expect(result.material.pdfExtraction?.pageCount, 2);
    },
  );

  test(
    'known failure returns authoritative failed material and safe copy',
    () async {
      final row = _row()..['processing_status'] = 'failed';
      final repository = SupabasePdfTextExtractionRepository(
        _FakeSource(<String, Object?>{
          'ok': false,
          'material': row,
          'error': <String, String>{
            'code': 'no_selectable_text',
            'message': noSelectablePdfTextMessage,
          },
        }),
      );

      final result = await repository.extractPdfText(
        user: user,
        materialId: '22222222-2222-4222-8222-222222222222',
      );

      expect(result.succeeded, isFalse);
      expect(result.errorMessage, noSelectablePdfTextMessage);
      expect(result.material.processingStatus.name, 'failed');
    },
  );
}

class _FakeSource implements PdfTextExtractionDataSource {
  _FakeSource(this.response);
  final Object? response;
  final List<String> materialIds = [];

  @override
  Future<Object?> invoke(String materialId) async {
    materialIds.add(materialId);
    return response;
  }
}

Map<String, dynamic> _row() => <String, dynamic>{
  'id': '22222222-2222-4222-8222-222222222222',
  'subject_id': 'biology',
  'title': 'lecture.pdf',
  'kind': 'pdf',
  'source_kind': 'upload',
  'content_text': 'Extracted text',
  'summary': null,
  'storage_bucket': 'study-materials',
  'storage_path': '${user.id}/22222222-2222-4222-8222-222222222222/lecture.pdf',
  'mime_type': 'application/pdf',
  'file_size_bytes': 1024,
  'processing_status': 'ready',
  'created_at': '2026-07-10T10:00:00Z',
  'metadata': <String, Object?>{
    'pdf_extraction': <String, Object?>{
      'extracted_at': '2026-07-10T10:00:00Z',
      'character_count': 14,
      'page_count': 2,
      'truncated': false,
      'extraction_version': 'pdf-text-v1',
    },
  },
};
