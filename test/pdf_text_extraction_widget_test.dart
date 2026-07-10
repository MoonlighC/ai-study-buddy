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

  testWidgets('ready PDF shows preview metadata and AI actions', (
    tester,
  ) async {
    final material = _pending.copyWith(
      content:
          'Ready extracted PDF text with enough information for every existing AI study action and a study session.',
      processingStatus: MaterialProcessingStatus.ready,
      pdfExtraction: const PdfExtractionMetadata(
        characterCount: 103,
        pageCount: 3,
        truncated: true,
        extractionVersion: 'pdf-text-v1',
      ),
    );
    await _pumpDetail(tester, material);
    expect(find.text('Extracted text'), findsOneWidget);
    expect(find.text('Pages: 3'), findsOneWidget);
    expect(
      find.text('Text was truncated to the safe storage limit.'),
      findsOneWidget,
    );
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
}

Future<void> _pumpDetail(WidgetTester tester, StudyMaterial material) async {
  await tester.pumpWidget(
    StudyBuddyApp(
      authRepository: MockAuthRepository(initialUser: user),
      materialRepository: MockMaterialRepository(initialMaterials: [material]),
    ),
  );
  await tester.pumpAndSettle();
  final navigator = tester.state<NavigatorState>(find.byType(Navigator));
  navigator.pushNamed(AppRoutes.materialDetail, arguments: material);
  await tester.pumpAndSettle();
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
