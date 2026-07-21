import 'dart:typed_data';

import 'package:ai_study_buddy/app/app.dart';
import 'package:ai_study_buddy/app/routes.dart';
import 'package:ai_study_buddy/core/models/material.dart';
import 'package:ai_study_buddy/features/auth/auth_models.dart';
import 'package:ai_study_buddy/features/auth/auth_repository.dart';
import 'package:ai_study_buddy/features/materials/material_file_picker.dart';
import 'package:ai_study_buddy/features/materials/material_upload.dart';
import 'package:ai_study_buddy/features/materials/material_upload_repository.dart';
import 'package:ai_study_buddy/features/materials/upload_material_screen.dart';
import 'package:ai_study_buddy/mock/mock_data.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

const testUser = AuthUser(
  id: '11111111-1111-4111-8111-111111111111',
  email: 'student@example.test',
  displayName: 'Student',
);

void main() {
  testWidgets(
    'Recommended is default and Economy stays collapsed with warning',
    (tester) async {
      tester.platformDispatcher.platformBrightnessTestValue = Brightness.dark;
      tester.platformDispatcher.textScaleFactorTestValue = 2;
      addTearDown(tester.platformDispatcher.clearPlatformBrightnessTestValue);
      addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
      await tester.pumpWidget(
        StudyBuddyApp(
          authRepository: MockAuthRepository(initialUser: testUser),
        ),
      );
      await tester.pumpAndSettle();
      await _pushRoute(
        tester,
        AppRoutes.uploadMaterial,
        arguments: UploadMaterialArgs(
          subject: MockData.subjects.first,
          kind: MaterialKind.pdf,
        ),
      );
      await tester.scrollUntilVisible(
        find.text('Recommended'),
        200,
        scrollable: find.byType(Scrollable).last,
      );
      expect(find.text('Recommended'), findsOneWidget);
      expect(
        find.text('Best for formulas, diagrams, tables, and layout.'),
        findsOneWidget,
      );
      expect(find.text('Economy'), findsNothing);
      await tester.scrollUntilVisible(
        find.text('Advanced settings'),
        200,
        scrollable: find.byType(Scrollable).last,
      );
      await tester.tap(find.text('Advanced settings'));
      await tester.pumpAndSettle();
      expect(find.text('Economy'), findsOneWidget);
      expect(
        find.text(
          'Formulas, diagrams, tables, and layout may be less accurate.',
        ),
        findsOneWidget,
      );
      expect(tester.takeException(), isNull);
    },
  );

  for (final scenario
      in <
        ({
          MaterialKind kind,
          String action,
          String choose,
          String filename,
          List<int> bytes,
        })
      >[
        (
          kind: MaterialKind.pdf,
          action: 'Upload PDF',
          choose: 'Choose PDF',
          filename: 'lecture.pdf',
          bytes: '%PDF-1.7'.codeUnits,
        ),
        (
          kind: MaterialKind.image,
          action: 'Upload image',
          choose: 'Choose image',
          filename: 'diagram.png',
          bytes: const [0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A],
        ),
      ]) {
    testWidgets('${scenario.kind.name} selection and upload flow', (
      tester,
    ) async {
      final picker = _FakePicker(
        SelectedMaterialFile(
          name: scenario.filename,
          reportedSizeBytes: scenario.bytes.length,
          readBytes: () async => Uint8List.fromList(scenario.bytes),
        ),
      );
      await tester.pumpWidget(
        StudyBuddyApp(
          authRepository: MockAuthRepository(initialUser: testUser),
          materialFilePicker: picker,
          materialUploadRepository: MockMaterialUploadRepository(),
          materialIdGenerator: () => '22222222-2222-4222-8222-222222222222',
        ),
      );
      await tester.pumpAndSettle();
      await _pushRoute(
        tester,
        AppRoutes.subjectDetail,
        arguments: MockData.subjects.first,
      );

      await tester.scrollUntilVisible(
        find.text(scenario.action),
        240,
        scrollable: find.byType(Scrollable).last,
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text(scenario.action));
      await tester.pumpAndSettle();
      await tester.tap(find.text(scenario.choose));
      await tester.pumpAndSettle();

      expect(find.text(scenario.filename), findsOneWidget);
      expect(picker.requestedKind, scenario.kind);
      await tester.tap(find.text('Upload material'));
      await tester.pumpAndSettle();

      await tester.scrollUntilVisible(
        find.text(scenario.filename),
        -240,
        scrollable: find.byType(Scrollable).last,
      );
      await tester.pumpAndSettle();
      expect(find.text(scenario.filename), findsOneWidget);
      expect(find.text('Ready'), findsOneWidget);
      expect(find.text('1 uploaded / 0 skipped / 0 failed'), findsOneWidget);
      expect(find.byIcon(Icons.open_in_new), findsOneWidget);
    });
  }

  testWidgets('uploaded material detail hides AI and study actions', (
    tester,
  ) async {
    const upload = StudyMaterial(
      id: 'upload-1',
      subjectId: 'biology',
      title: 'lecture.pdf',
      kind: MaterialKind.pdf,
      content: '',
      createdLabel: 'Today',
      sourceKind: MaterialSourceKind.upload,
      storageBucket: 'study-materials',
      storagePath: 'user/upload-1/lecture.pdf',
      mimeType: 'application/pdf',
      fileSizeBytes: 1024,
      processingStatus: MaterialProcessingStatus.pending,
    );
    await tester.pumpWidget(
      StudyBuddyApp(authRepository: MockAuthRepository(initialUser: testUser)),
    );
    await tester.pumpAndSettle();
    await _pushRoute(tester, AppRoutes.materialDetail, arguments: upload);

    expect(find.text('Extract text'), findsOneWidget);
    expect(find.text('MIME: application/pdf'), findsOneWidget);
    expect(find.text('Summary'), findsNothing);
    expect(find.text('Flashcards'), findsNothing);
    expect(find.text('Quiz'), findsNothing);
    expect(find.text('Create study session'), findsNothing);
  });
}

Future<void> _pushRoute(
  WidgetTester tester,
  String routeName, {
  Object? arguments,
}) async {
  final navigator = tester.state<NavigatorState>(find.byType(Navigator));
  navigator.pushNamed(routeName, arguments: arguments);
  await tester.pumpAndSettle();
}

class _FakePicker implements MaterialFilePicker {
  _FakePicker(this.file);

  final SelectedMaterialFile file;
  MaterialKind? requestedKind;

  @override
  Future<SelectedMaterialFile?> pick(MaterialKind kind) async {
    requestedKind = kind;
    return file;
  }
}
