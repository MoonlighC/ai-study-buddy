import 'package:ai_study_buddy/features/auth/auth_models.dart';
import 'package:ai_study_buddy/features/materials/image_text_extraction_repository.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test(
    'Flutter sends only material_id and maps authoritative material',
    () async {
      final source = _Source();
      final result = await SupabaseImageTextExtractionRepository(source)
          .extractImageText(
            user: const AuthUser(
              id: 'user',
              email: 'a@b.test',
              displayName: 'A',
            ),
            materialId: 'image-id',
          );
      expect(source.materialId, 'image-id');
      expect(result.material.content, contains('authoritative'));
      expect(result.succeeded, isTrue);
    },
  );
}

class _Source implements ImageTextExtractionDataSource {
  String? materialId;
  @override
  Future<Object?> invoke(String materialId) async {
    this.materialId = materialId;
    return {
      'ok': true,
      'material': {
        'id': materialId,
        'subject_id': 'subject',
        'title': 'image.png',
        'kind': 'image',
        'source_kind': 'upload',
        'content_text':
            'authoritative OCR text with enough useful study detail for all existing generation flows.',
        'storage_bucket': 'study-images',
        'storage_path': 'user/$materialId/image.png',
        'mime_type': 'image/png',
        'file_size_bytes': 100,
        'processing_status': 'ready',
        'metadata': {
          'image_ocr': {
            'warning_codes': ['blur_detected'],
            'character_count': 90,
          },
        },
      },
    };
  }
}
