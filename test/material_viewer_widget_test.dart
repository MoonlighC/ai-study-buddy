import 'dart:async';
import 'dart:convert';

import 'package:ai_study_buddy/app/app.dart';
import 'package:ai_study_buddy/app/routes.dart';
import 'package:ai_study_buddy/core/models/material.dart';
import 'package:ai_study_buddy/features/auth/auth_models.dart';
import 'package:ai_study_buddy/features/auth/auth_repository.dart';
import 'package:ai_study_buddy/features/materials/material_viewer_screen.dart';
import 'package:ai_study_buddy/features/materials/material_repository.dart';
import 'package:ai_study_buddy/features/materials/original_material_repository.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pdfrx/pdfrx.dart';

const _user = AuthUser(
  id: '11111111-1111-4111-8111-111111111111',
  email: 'student@example.test',
  displayName: 'Student',
);

void main() {
  const pathProviderChannel = MethodChannel('plugins.flutter.io/path_provider');
  setUpAll(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(pathProviderChannel, (call) async => '.');
  });
  tearDownAll(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(pathProviderChannel, null);
  });

  testWidgets('PDF viewer is constructed only from authenticated bytes', (
    tester,
  ) async {
    final repository = MockOriginalMaterialRepository(
      pdfs: {'pdf': Uint8List.fromList('%PDF-1.7'.codeUnits)},
    );
    await tester.pumpWidget(
      StudyBuddyApp(
        authRepository: MockAuthRepository(initialUser: _user),
        originalMaterialRepository: repository,
      ),
    );
    await tester.pumpAndSettle();
    _push(
      tester,
      const MaterialViewerArgs(
        materialId: 'pdf',
        kind: MaterialKind.pdf,
        initialPage: 999,
      ),
    );
    await tester.pump();
    await tester.pump();
    expect(find.byType(PdfViewer), findsOneWidget);
    expect(find.textContaining('OCR'), findsNothing);
  });

  testWidgets('image viewer uses memory image and InteractiveViewer', (
    tester,
  ) async {
    final repository = MockOriginalMaterialRepository(
      images: {
        'image': Uint8List.fromList(const [
          0x89,
          0x50,
          0x4E,
          0x47,
          0x0D,
          0x0A,
          0x1A,
          0x0A,
        ]),
      },
    );
    await tester.pumpWidget(
      StudyBuddyApp(
        authRepository: MockAuthRepository(initialUser: _user),
        originalMaterialRepository: repository,
      ),
    );
    await tester.pumpAndSettle();
    _push(
      tester,
      const MaterialViewerArgs(materialId: 'image', kind: MaterialKind.image),
    );
    await tester.pump();
    await tester.pump();
    expect(find.byType(InteractiveViewer), findsOneWidget);
    expect(find.byType(Image), findsOneWidget);
  });

  testWidgets('route kind mismatch is rejected safely', (tester) async {
    final repository = MockOriginalMaterialRepository(
      pdfs: {'pdf': Uint8List.fromList('%PDF-1.7'.codeUnits)},
    );
    await tester.pumpWidget(
      StudyBuddyApp(
        authRepository: MockAuthRepository(initialUser: _user),
        originalMaterialRepository: repository,
      ),
    );
    await tester.pumpAndSettle();
    _push(
      tester,
      const MaterialViewerArgs(materialId: 'pdf', kind: MaterialKind.image),
    );
    await _pumpUntil(tester, find.text('Preview unavailable.'));
    expect(find.text('Preview unavailable.'), findsOneWidget);
    expect(find.byType(PdfViewer), findsNothing);
    expect(find.byType(InteractiveViewer), findsNothing);
  });

  testWidgets('View original requires canonical authoritative metadata', (
    tester,
  ) async {
    await tester.pumpWidget(
      StudyBuddyApp(authRepository: MockAuthRepository(initialUser: _user)),
    );
    await tester.pumpAndSettle();
    const valid = StudyMaterial(
      id: 'material',
      subjectId: 'biology',
      title: 'notes.pdf',
      kind: MaterialKind.pdf,
      content: '',
      createdLabel: 'Today',
      sourceKind: MaterialSourceKind.upload,
      storageBucket: 'study-materials',
      storagePath: '11111111-1111-4111-8111-111111111111/material/notes.pdf',
      mimeType: 'application/pdf',
      fileSizeBytes: 8,
      processingStatus: MaterialProcessingStatus.pending,
    );
    final navigator = tester.state<NavigatorState>(find.byType(Navigator));
    navigator.pushNamed(AppRoutes.materialDetail, arguments: valid);
    await tester.pumpAndSettle();
    expect(find.text('View original'), findsOneWidget);
    navigator.pop();
    await tester.pumpAndSettle();
    navigator.pushNamed(
      AppRoutes.materialDetail,
      arguments: valid.copyWith(storagePath: 'wrong/material/notes.pdf'),
    );
    await tester.pumpAndSettle();
    expect(find.text('View original'), findsNothing);
  });

  testWidgets('retry releases prior bytes before pending replacement load', (
    tester,
  ) async {
    final repository = _ControlledOriginalRepository();
    await _pumpApp(tester, repository);
    _push(
      tester,
      const MaterialViewerArgs(materialId: 'image', kind: MaterialKind.image),
    );
    await tester.pump();
    final first = OriginalMaterialSuccess.fromTrustedBytes(
      kind: MaterialKind.image,
      bytes: Uint8List.fromList(const [0x89, 0x50, 0x4E, 0x47]),
    );
    repository.complete(0, first);
    await _pumpUntil(tester, find.text('Preview unavailable.'));
    expect(find.text('Preview unavailable.'), findsOneWidget);
    await tester.tap(find.text('Retry'));
    await tester.pump();
    expect(first.handle.isReleased, isTrue);
    expect(
      find.byKey(const ValueKey('material-preview-loading')),
      findsOneWidget,
    );
    repository.complete(
      1,
      const OriginalMaterialFailure(OriginalMaterialFailureCode.networkFailure),
    );
    await _pumpUntil(tester, find.text('Preview unavailable.'));
  });

  testWidgets('disposed screen releases late preview result', (tester) async {
    final repository = _ControlledOriginalRepository();
    await _pumpApp(tester, repository);
    _push(
      tester,
      const MaterialViewerArgs(materialId: 'image', kind: MaterialKind.image),
    );
    await tester.pump();
    tester.state<NavigatorState>(find.byType(Navigator)).pop();
    await tester.pumpAndSettle();
    final late = OriginalMaterialSuccess.fromTrustedBytes(
      kind: MaterialKind.image,
      bytes: _validPng(),
    );
    repository.complete(0, late);
    await tester.pump();
    expect(late.handle.isReleased, isTrue);
    expect(tester.takeException(), isNull);
  });

  testWidgets('older retry completion cannot overwrite newer request', (
    tester,
  ) async {
    final repository = _ControlledOriginalRepository();
    await _pumpApp(tester, repository);
    _push(
      tester,
      const MaterialViewerArgs(materialId: 'image', kind: MaterialKind.image),
    );
    await tester.pump();
    repository.complete(
      0,
      const OriginalMaterialFailure(OriginalMaterialFailureCode.networkFailure),
    );
    await tester.pumpAndSettle();
    final retry = tester.widget<FilledButton>(
      find.widgetWithText(FilledButton, 'Retry'),
    );
    retry.onPressed!();
    retry.onPressed!();
    await tester.pump();
    final newest = OriginalMaterialSuccess.fromTrustedBytes(
      kind: MaterialKind.image,
      bytes: _validPng(),
    );
    repository.complete(2, newest);
    await tester.pumpAndSettle();
    expect(find.byType(InteractiveViewer), findsOneWidget);
    repository.complete(
      1,
      const OriginalMaterialFailure(
        OriginalMaterialFailureCode.materialUnavailable,
      ),
    );
    await tester.pumpAndSettle();
    expect(find.byType(InteractiveViewer), findsOneWidget);
    expect(newest.handle.isReleased, isFalse);
  });

  testWidgets('corrupt PDF and image become safe localized failures', (
    tester,
  ) async {
    final pdfRepository = _ControlledOriginalRepository();
    await _pumpApp(tester, pdfRepository);
    _push(
      tester,
      const MaterialViewerArgs(materialId: 'pdf', kind: MaterialKind.pdf),
    );
    await tester.pump();
    pdfRepository.complete(
      0,
      OriginalMaterialSuccess.fromTrustedBytes(
        kind: MaterialKind.pdf,
        bytes: Uint8List.fromList('%PDF-corrupt'.codeUnits),
      ),
    );
    await tester.pump();
    final pdfViewer = tester.widget<PdfViewer>(find.byType(PdfViewer));
    pdfViewer.params.onDocumentLoadFinished!(pdfViewer.documentRef, false);
    await tester.pump();
    expect(find.text('Preview unavailable.'), findsOneWidget);
    expect(find.textContaining('OCR'), findsNothing);

    await tester.pumpWidget(const SizedBox());
    final imageRepository = _ControlledOriginalRepository();
    await _pumpApp(tester, imageRepository);
    _push(
      tester,
      const MaterialViewerArgs(materialId: 'image', kind: MaterialKind.image),
    );
    await tester.pump();
    imageRepository.complete(
      0,
      OriginalMaterialSuccess.fromTrustedBytes(
        kind: MaterialKind.image,
        bytes: Uint8List.fromList(const [0x89, 0x50, 0x4E, 0x47]),
      ),
    );
    await _pumpUntil(tester, find.text('Preview unavailable.'));
    expect(find.text('Preview unavailable.'), findsOneWidget);
  });

  test('valid multipage PDF clamps initial page and bounds controls', () {
    final bytes = _twoPagePdf();
    expect(latin1.decode(bytes), contains('/Count 2'));
    expect(clampMaterialInitialPage(999, 2), 2);
    expect(clampMaterialInitialPage(-20, 2), 1);
    expect(clampMaterialInitialPage(null, 2), 1);
    expect(materialPdfCanGoPrevious(1), isFalse);
    expect(materialPdfCanGoPrevious(2), isTrue);
    expect(materialPdfCanGoNext(1, 2), isTrue);
    expect(materialPdfCanGoNext(2, 2), isFalse);
  });

  testWidgets('PDF links stay disabled and resources release on pop', (
    tester,
  ) async {
    final repository = _ControlledOriginalRepository();
    await _pumpApp(tester, repository);
    _push(
      tester,
      const MaterialViewerArgs(materialId: 'pdf', kind: MaterialKind.pdf),
    );
    await tester.pump();
    final result = OriginalMaterialSuccess.fromTrustedBytes(
      kind: MaterialKind.pdf,
      bytes: _twoPagePdf(),
    );
    repository.complete(0, result);
    await _pumpUntil(tester, find.byType(PdfViewer));
    final viewer = tester.widget<PdfViewer>(find.byType(PdfViewer));
    expect(viewer.params.linkHandlerParams, isNull);
    expect(viewer.params.linkWidgetBuilder, isNull);
    tester.state<NavigatorState>(find.byType(Navigator)).pop();
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));
    expect(result.handle.isReleased, isTrue);
    expect(find.byType(PdfViewer), findsNothing);
  });

  testWidgets('PDF return repaints detail and favorite remains interactive', (
    tester,
  ) async {
    const material = StudyMaterial(
      id: 'pdf',
      subjectId: 'biology',
      title: 'Private notes.pdf',
      kind: MaterialKind.pdf,
      content: '',
      createdLabel: 'Today',
      sourceKind: MaterialSourceKind.upload,
      storageBucket: 'study-materials',
      storagePath:
          '11111111-1111-4111-8111-111111111111/pdf/private-notes.pdf',
      mimeType: 'application/pdf',
      fileSizeBytes: 1024,
      processingStatus: MaterialProcessingStatus.pending,
    );
    await tester.pumpWidget(
      StudyBuddyApp(
        authRepository: MockAuthRepository(initialUser: _user),
        materialRepository: MockMaterialRepository(
          initialMaterials: const [material],
        ),
        originalMaterialRepository: MockOriginalMaterialRepository(
          pdfs: {'pdf': _twoPagePdf()},
        ),
      ),
    );
    await tester.pumpAndSettle();
    tester
        .state<NavigatorState>(find.byType(Navigator))
        .pushNamed(AppRoutes.materialDetail, arguments: material);
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const ValueKey('view-original-material')));
    await _pumpUntil(tester, find.byType(PdfViewer));
    tester.state<NavigatorState>(find.byType(Navigator)).pop();
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));

    expect(find.byKey(const ValueKey('material-hero')), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('material-favorite-action')));
    await tester.pumpAndSettle();
    expect(find.byTooltip('Unfavorite material'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  test('opaque preview handle and public route metadata expose no bytes', () {
    final result = OriginalMaterialSuccess.fromTrustedBytes(
      kind: MaterialKind.pdf,
      bytes: Uint8List.fromList('%PDF-1.7'.codeUnits),
    );
    expect(result.toString(), isNot(contains('%PDF')));
    expect(result.handle.toString(), isNot(contains('%PDF')));
    const args = MaterialViewerArgs(
      materialId: 'exact',
      kind: MaterialKind.pdf,
    );
    expect(args.materialId, 'exact');
    expect(args.kind, MaterialKind.pdf);
  });
}

Future<void> _pumpUntil(
  WidgetTester tester,
  Finder finder, {
  int attempts = 80,
}) async {
  for (var attempt = 0; attempt < attempts; attempt++) {
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 20)),
    );
    await tester.pump(const Duration(milliseconds: 50));
    if (finder.evaluate().isNotEmpty) return;
  }
  fail('Timed out waiting for the expected widget.');
}

Future<void> _pumpApp(
  WidgetTester tester,
  OriginalMaterialRepository repository,
) async {
  await tester.pumpWidget(
    StudyBuddyApp(
      authRepository: MockAuthRepository(initialUser: _user),
      originalMaterialRepository: repository,
    ),
  );
  await tester.pumpAndSettle();
}

void _push(WidgetTester tester, MaterialViewerArgs args) {
  tester
      .state<NavigatorState>(find.byType(Navigator))
      .pushNamed(AppRoutes.materialViewer, arguments: args);
}

class _ControlledOriginalRepository implements OriginalMaterialRepository {
  final List<Completer<OriginalMaterialLoadResult>> requests = [];

  @override
  Future<OriginalMaterialLoadResult> load({
    required AuthUser expectedUser,
    required String materialId,
    required MaterialKind expectedKind,
  }) {
    final completer = Completer<OriginalMaterialLoadResult>();
    requests.add(completer);
    return completer.future;
  }

  void complete(int index, OriginalMaterialLoadResult result) =>
      requests[index].complete(result);
}

Uint8List _validPng() => base64Decode(
  'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwC'
  'AAAAC0lEQVR42mNk+A8AAQUBAScY42YAAAAASUVORK5CYII=',
);

Uint8List _twoPagePdf() {
  final buffer = StringBuffer('%PDF-1.4\n');
  final offsets = <int>[0];
  var length = buffer.toString().codeUnits.length;

  void object(int number, String body) {
    offsets.add(length);
    final value = '$number 0 obj\n$body\nendobj\n';
    buffer.write(value);
    length += value.codeUnits.length;
  }

  object(1, '<< /Type /Catalog /Pages 2 0 R >>');
  object(2, '<< /Type /Pages /Kids [3 0 R 5 0 R] /Count 2 >>');
  object(
    3,
    '<< /Type /Page /Parent 2 0 R /MediaBox [0 0 200 200] '
    '/Contents 4 0 R /Resources << >> >>',
  );
  object(4, '<< /Length 0 >>\nstream\n\nendstream');
  object(
    5,
    '<< /Type /Page /Parent 2 0 R /MediaBox [0 0 200 200] '
    '/Contents 6 0 R /Resources << >> >>',
  );
  object(6, '<< /Length 0 >>\nstream\n\nendstream');
  final xref = length;
  buffer
    ..write('xref\n0 7\n')
    ..write('0000000000 65535 f \n');
  for (final offset in offsets.skip(1)) {
    buffer.write('${offset.toString().padLeft(10, '0')} 00000 n \n');
  }
  buffer
    ..write('trailer\n<< /Size 7 /Root 1 0 R >>\n')
    ..write('startxref\n$xref\n%%EOF\n');
  return Uint8List.fromList(latin1.encode(buffer.toString()));
}
