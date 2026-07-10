import 'dart:async';

import 'package:ai_study_buddy/app/app_state.dart';
import 'package:ai_study_buddy/core/models/material.dart';
import 'package:ai_study_buddy/features/auth/auth_models.dart';
import 'package:ai_study_buddy/features/materials/material_repository.dart';
import 'package:ai_study_buddy/features/materials/pdf_text_extraction_repository.dart';
import 'package:flutter_test/flutter_test.dart';

const user = AuthUser(
  id: 'user',
  email: 'student@example.test',
  displayName: 'Student',
);
const pending = StudyMaterial(
  id: 'pdf-1',
  subjectId: 'biology',
  title: 'lecture.pdf',
  kind: MaterialKind.pdf,
  content: '',
  createdLabel: 'Today',
  sourceKind: MaterialSourceKind.upload,
  storageBucket: 'study-materials',
  storagePath: 'user/pdf-1/lecture.pdf',
  mimeType: 'application/pdf',
  fileSizeBytes: 100,
  processingStatus: MaterialProcessingStatus.pending,
);

void main() {
  test('authoritative extraction replaces material and enables AI', () async {
    final repository = _ExtractionRepository();
    final state = AppState(
      materialRepository: MockMaterialRepository(
        initialMaterials: const [pending],
      ),
      pdfTextExtractionRepository: repository,
    );
    await state.loadMaterialsFor(null);

    expect(await state.extractPdfTextFor(null, pending.id), isTrue);
    final material = state.materialById(pending.id)!;
    expect(material.processingStatus, MaterialProcessingStatus.ready);
    expect(state.canGenerateSummaryForMaterial(material), isTrue);
  });

  test('duplicate extraction call is blocked', () async {
    final repository = _ExtractionRepository(block: true);
    final state = AppState(
      materialRepository: MockMaterialRepository(
        initialMaterials: const [pending],
      ),
      pdfTextExtractionRepository: repository,
    );
    await state.loadMaterialsFor(null);

    final first = state.extractPdfTextFor(null, pending.id);
    expect(state.isExtractingPdf(pending.id), isTrue);
    expect(await state.extractPdfTextFor(null, pending.id), isFalse);
    repository.release();
    expect(await first, isTrue);
    expect(repository.calls, 1);
  });

  test('known failure replaces status and exposes only safe error', () async {
    final repository = _ExtractionRepository(fail: true);
    final state = AppState(
      materialRepository: MockMaterialRepository(
        initialMaterials: const [pending],
      ),
      pdfTextExtractionRepository: repository,
    );
    await state.loadMaterialsFor(null);

    expect(await state.extractPdfTextFor(null, pending.id), isFalse);
    expect(
      state.materialById(pending.id)?.processingStatus,
      MaterialProcessingStatus.failed,
    );
    expect(state.pdfExtractionErrorFor(pending.id), noSelectablePdfTextMessage);
  });

  test('images and pending PDFs remain AI-ineligible', () {
    final state = AppState();
    const image = StudyMaterial(
      id: 'image',
      subjectId: 'biology',
      title: 'image.png',
      kind: MaterialKind.image,
      content: 'forged content',
      createdLabel: 'Today',
      sourceKind: MaterialSourceKind.upload,
      processingStatus: MaterialProcessingStatus.ready,
    );
    expect(state.canGenerateQuizForMaterial(pending), isFalse);
    expect(state.canGenerateQuizForMaterial(image), isFalse);
  });
}

class _ExtractionRepository implements PdfTextExtractionRepository {
  _ExtractionRepository({this.block = false, this.fail = false});
  final bool block;
  final bool fail;
  final Completer<void> _gate = Completer<void>();
  int calls = 0;
  void release() {
    if (!_gate.isCompleted) _gate.complete();
  }

  @override
  Future<PdfTextExtractionResult> extractPdfText({
    required AuthUser user,
    required String materialId,
  }) async {
    calls += 1;
    if (block) await _gate.future;
    if (fail) {
      return PdfTextExtractionResult(
        material: pending.copyWith(
          processingStatus: MaterialProcessingStatus.failed,
          pdfExtraction: const PdfExtractionMetadata(
            failureCode: 'no_selectable_text',
            failureMessage: noSelectablePdfTextMessage,
          ),
        ),
        errorMessage: noSelectablePdfTextMessage,
      );
    }
    return PdfTextExtractionResult(
      material: pending.copyWith(
        content:
            'Extracted PDF content with enough detail to generate summaries, flashcards, quizzes, and focused study sessions.',
        processingStatus: MaterialProcessingStatus.ready,
        pdfExtraction: const PdfExtractionMetadata(
          characterCount: 116,
          pageCount: 2,
          extractionVersion: 'pdf-text-v1',
        ),
      ),
    );
  }
}
