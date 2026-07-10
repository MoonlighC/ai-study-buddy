import 'dart:async';
import 'package:ai_study_buddy/app/app_state.dart';
import 'package:ai_study_buddy/core/models/material.dart';
import 'package:ai_study_buddy/features/auth/auth_models.dart';
import 'package:ai_study_buddy/features/materials/image_text_extraction_repository.dart';
import 'package:ai_study_buddy/features/materials/material_repository.dart';
import 'package:flutter_test/flutter_test.dart';

const pendingImage = StudyMaterial(
  id: 'image',
  subjectId: 'biology',
  title: 'note.png',
  kind: MaterialKind.image,
  content: '',
  createdLabel: 'Today',
  sourceKind: MaterialSourceKind.upload,
  storageBucket: 'study-images',
  storagePath: 'user/image/note.png',
  mimeType: 'image/png',
  fileSizeBytes: 100,
  processingStatus: MaterialProcessingStatus.pending,
);

void main() {
  test('authoritative OCR enables AI and duplicate taps invoke once', () async {
    final repository = _Repository();
    final state = AppState(
      materialRepository: MockMaterialRepository(
        initialMaterials: const [pendingImage],
      ),
      imageTextExtractionRepository: repository,
    );
    await state.loadMaterialsFor(null);
    final first = state.extractImageTextFor(null, 'image');
    expect(await state.extractImageTextFor(null, 'image'), isFalse);
    repository.gate.complete();
    expect(await first, isTrue);
    expect(repository.calls, 1);
    expect(
      state.canGenerateSummaryForMaterial(state.materialById('image')!),
      isTrue,
    );
  });
}

class _Repository implements ImageTextExtractionRepository {
  final gate = Completer<void>();
  int calls = 0;
  @override
  Future<ImageTextExtractionResult> extractImageText({
    required AuthUser user,
    required String materialId,
  }) async {
    calls++;
    await gate.future;
    return ImageTextExtractionResult(
      material: pendingImage.copyWith(
        content:
            'Extracted image content with enough reliable study detail for summaries, flashcards, quizzes, and sessions.',
        processingStatus: MaterialProcessingStatus.ready,
        imageOcr: const ImageOcrMetadata(
          characterCount: 110,
          extractionVersion: 'image-ocr-v1',
        ),
      ),
    );
  }
}
