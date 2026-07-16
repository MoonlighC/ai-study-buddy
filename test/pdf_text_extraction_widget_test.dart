import 'package:ai_study_buddy/app/app.dart';
import 'package:ai_study_buddy/app/routes.dart';
import 'package:ai_study_buddy/core/models/material.dart';
import 'package:ai_study_buddy/features/auth/auth_models.dart';
import 'package:ai_study_buddy/features/auth/auth_repository.dart';
import 'package:ai_study_buddy/features/materials/material_repository.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

const user = AuthUser(
  id: 'user',
  email: 'student@example.test',
  displayName: 'Student',
);

void main() {
  testWidgets('pending PDF shows extraction and hides AI', (tester) async {
    const material = _pending;
    await _pumpDetail(tester, material);
    expect(find.text('Extract text'), findsOneWidget);
    expect(find.text('Summary'), findsNothing);
    expect(find.text('Create study session'), findsNothing);
  });

  testWidgets('processing PDF shows progress and hides AI', (tester) async {
    final material = _pending.copyWith(
      processingStatus: MaterialProcessingStatus.processing,
    );
    await _pumpDetail(tester, material, settleRoute: false);

    expect(find.textContaining('Extracting selectable text'), findsWidgets);
    expect(find.text('Summary'), findsNothing);
  });

  testWidgets('failed PDF shows safe retry and hides AI', (tester) async {
    final material = _pending.copyWith(
      processingStatus: MaterialProcessingStatus.failed,
      pdfExtraction: const PdfExtractionMetadata(
        failureMessage: 'Could not extract text from this PDF.',
      ),
    );
    await _pumpDetail(tester, material);

    expect(find.text('Text extraction failed'), findsOneWidget);
    expect(
      find.text('Something went wrong. Please try again.'),
      findsOneWidget,
    );
    expect(find.text('Retry text extraction'), findsOneWidget);
    expect(find.text('Summary'), findsNothing);
  });

  testWidgets('ready PDF hides raw text and shows safe extraction metadata', (
    tester,
  ) async {
    const rawText =
        'RAW PDF TEXT LAYER formula x?? header footer ordering artifact with enough information for AI generation.';
    final material = _pending.copyWith(
      content: rawText,
      processingStatus: MaterialProcessingStatus.ready,
      pdfExtraction: const PdfExtractionMetadata(
        characterCount: 103,
        pageCount: 3,
        truncated: true,
        extractionVersion: 'pdf-text-v1',
      ),
    );
    await _pumpDetail(tester, material);
    expect(find.text('Text extracted · 3 pages'), findsOneWidget);
    expect(find.text('Extracted text'), findsNothing);
    expect(find.text('View extracted text'), findsNothing);
    expect(find.textContaining('RAW PDF TEXT LAYER'), findsNothing);
    await tester.scrollUntilVisible(
      find.text('Summary'),
      300,
      scrollable: find.byType(Scrollable).last,
    );
    expect(find.text('Summary'), findsOneWidget);
    await tester.scrollUntilVisible(
      find.text('Create study session'),
      300,
      scrollable: find.byType(Scrollable).last,
    );
    expect(find.text('Create study session'), findsOneWidget);
  });

  testWidgets('ready PDF shows Summary before Flashcards and Quiz', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(800, 1400);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final longText = List.filled(250, 'Hidden extracted line').join('\n');
    final material = _pending.copyWith(
      content: longText,
      processingStatus: MaterialProcessingStatus.ready,
      pdfExtraction: PdfExtractionMetadata(
        characterCount: longText.length,
        pageCount: 33,
      ),
    );
    await _pumpDetail(tester, material);

    final summary = find.byKey(const Key('summary-section'));
    final flashcards = find.byKey(const Key('flashcards-section'));
    final quiz = find.byKey(const Key('quiz-section'));
    expect(summary, findsOneWidget);
    expect(flashcards, findsOneWidget);
    expect(quiz, findsOneWidget);
    expect(
      tester.getTopLeft(summary).dy,
      lessThan(tester.getTopLeft(flashcards).dy),
    );
    expect(
      tester.getTopLeft(flashcards).dy,
      lessThan(tester.getTopLeft(quiz).dy),
    );
    expect(find.textContaining('Hidden extracted line'), findsNothing);
  });

  testWidgets('uploaded image remains metadata only', (tester) async {
    const image = StudyMaterial(
      id: 'image-1',
      subjectId: 'biology',
      title: 'diagram.png',
      kind: MaterialKind.image,
      content: '',
      createdLabel: 'Today',
      sourceKind: MaterialSourceKind.upload,
      storageBucket: 'study-images',
      storagePath: 'user/image-1/diagram.png',
      mimeType: 'image/png',
      fileSizeBytes: 100,
      processingStatus: MaterialProcessingStatus.pending,
    );
    await _pumpDetail(tester, image);

    expect(find.text('File metadata'), findsOneWidget);
    expect(find.text('Extracted text'), findsNothing);
    expect(find.text('View extracted text'), findsNothing);
    expect(find.text('Summary'), findsNothing);
    expect(find.text('Extract text from image'), findsOneWidget);
  });

  testWidgets('ready image hides OCR text and exposes AI actions', (
    tester,
  ) async {
    const raw =
        'INTERNAL OCR text with enough reliable study content for summaries, flashcards, quizzes, and study sessions.';
    const image = StudyMaterial(
      id: 'image-ready',
      subjectId: 'biology',
      title: 'notes.png',
      kind: MaterialKind.image,
      content: raw,
      createdLabel: 'Today',
      sourceKind: MaterialSourceKind.upload,
      storageBucket: 'study-images',
      storagePath: 'user/image-ready/notes.png',
      mimeType: 'image/png',
      fileSizeBytes: 100,
      processingStatus: MaterialProcessingStatus.ready,
      imageOcr: ImageOcrMetadata(
        characterCount: 110,
        extractionVersion: 'image-ocr-v1',
      ),
    );
    await _pumpDetail(tester, image);
    expect(find.text('Text extracted'), findsWidgets);
    expect(find.textContaining('INTERNAL OCR'), findsNothing);
    expect(find.text('Summary'), findsOneWidget);
    await tester.scrollUntilVisible(
      find.text('Create study session'),
      300,
      scrollable: find.byType(Scrollable).last,
    );
    expect(find.text('Create study session'), findsOneWidget);
  });

  testWidgets('long PDF summary can be expanded and collapsed', (tester) async {
    final summary = List.filled(
      40,
      'Key concept with readable study guidance.',
    ).join('\n');
    final material = _pending.copyWith(
      content:
          'Internal extracted PDF text with enough content for all existing AI actions while remaining hidden from the user interface.',
      summary: summary,
      processingStatus: MaterialProcessingStatus.ready,
      pdfExtraction: const PdfExtractionMetadata(pageCount: 8),
    );
    await _pumpDetail(tester, material);
    await tester.scrollUntilVisible(
      find.text('Show more'),
      300,
      scrollable: find.byType(Scrollable).last,
    );

    expect(
      find.byKey(const ValueKey('collapsed-summary-markdown')),
      findsOneWidget,
    );
    final showMore = find.widgetWithText(TextButton, 'Show more');
    await tester.ensureVisible(showMore);
    await tester.pumpAndSettle();
    await tester.tap(showMore);
    await tester.pumpAndSettle();
    expect(
      find.byKey(const ValueKey('collapsed-summary-markdown')),
      findsNothing,
    );
    expect(find.text('Show less'), findsOneWidget);
  });
}

Future<void> _pumpDetail(
  WidgetTester tester,
  StudyMaterial material, {
  bool settleRoute = true,
}) async {
  await tester.pumpWidget(
    StudyBuddyApp(
      authRepository: MockAuthRepository(initialUser: user),
      materialRepository: MockMaterialRepository(initialMaterials: [material]),
    ),
  );
  await tester.pumpAndSettle();
  final navigator = tester.state<NavigatorState>(find.byType(Navigator));
  navigator.pushNamed(AppRoutes.materialDetail, arguments: material);
  if (settleRoute) {
    await tester.pumpAndSettle();
  } else {
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));
  }
}

const _pending = StudyMaterial(
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
