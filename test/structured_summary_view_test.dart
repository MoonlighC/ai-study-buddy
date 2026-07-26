import 'package:ai_study_buddy/app/app_state.dart';
import 'package:ai_study_buddy/app/routes.dart';
import 'package:ai_study_buddy/core/models/material.dart';
import 'package:ai_study_buddy/features/auth/auth_controller.dart';
import 'package:ai_study_buddy/features/auth/auth_models.dart';
import 'package:ai_study_buddy/features/auth/auth_repository.dart';
import 'package:ai_study_buddy/features/materials/material_viewer_screen.dart';
import 'package:ai_study_buddy/features/materials/structured_summary.dart';
import 'package:ai_study_buddy/features/materials/structured_summary_view.dart';
import 'package:ai_study_buddy/l10n/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

const _user = AuthUser(
  id: '11111111-1111-4111-8111-111111111111',
  email: 'student@example.test',
);
const _materialId = '22222222-2222-4222-8222-222222222222';

void main() {
  testWidgets('equation and warning actions use their exact own PDF pages', (
    tester,
  ) async {
    final opened = <MaterialViewerArgs>[];
    await _pump(tester, material: _material(MaterialKind.pdf), opened: opened);
    await _expandDetails(tester);

    await tester.tap(find.widgetWithText(ActionChip, 'Source page 2'));
    await tester.pumpAndSettle();
    expect(opened.single.materialId, _materialId);
    expect(opened.single.kind, MaterialKind.pdf);
    expect(opened.single.initialPage, 2);
    tester.state<NavigatorState>(find.byType(Navigator)).pop();
    await tester.pumpAndSettle();

    expect(find.text('Warning source page 2'), findsOneWidget);
    expect(find.text('Warning source page 3'), findsOneWidget);
    await tester.ensureVisible(
      find.widgetWithText(ActionChip, 'Warning source page 3'),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(ActionChip, 'Warning source page 3'));
    await tester.pumpAndSettle();
    expect(opened.last.initialPage, 3);
  });

  testWidgets('image equation source always opens page one', (tester) async {
    final opened = <MaterialViewerArgs>[];
    await _pump(
      tester,
      material: _material(MaterialKind.image),
      opened: opened,
    );
    await _expandDetails(tester);
    await tester.tap(find.widgetWithText(ActionChip, 'Source page 2'));
    await tester.pumpAndSettle();
    expect(opened.single.materialId, _materialId);
    expect(opened.single.kind, MaterialKind.image);
    expect(opened.single.initialPage, 1);
  });

  testWidgets(
    'validated copy writes exact LaTeX and gives localized feedback',
    (tester) async {
      Object? clipboardArguments;
      tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        SystemChannels.platform,
        (call) async {
          if (call.method == 'Clipboard.setData') {
            clipboardArguments = call.arguments;
          }
          return null;
        },
      );
      addTearDown(
        () => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
          SystemChannels.platform,
          null,
        ),
      );
      await _pump(tester, material: _material(MaterialKind.pdf), opened: []);
      await _expandDetails(tester);
      await tester.tap(find.byTooltip('Copy formula'));
      await tester.pump();
      expect(clipboardArguments, {'text': r'\frac{a}{b}'});
      expect(find.text('Formula copied'), findsOneWidget);
      expect(find.bySemanticsLabel(RegExp(r'^Equation:')), findsOneWidget);
    },
  );

  testWidgets('valid summary with no equations renders without formula UI', (
    tester,
  ) async {
    await _pump(
      tester,
      material: _material(MaterialKind.pdf),
      opened: [],
      summary: _summaryWithoutEquations(),
    );
    await _expandDetails(tester);
    expect(find.text('Section'), findsOneWidget);
    expect(find.byTooltip('Copy formula'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'compact overview is primary and detailed provenance stays collapsed',
    (tester) async {
      await _pump(tester, material: _material(MaterialKind.pdf), opened: []);
      expect(
        find.text('This lecture covers sequential digital circuits.'),
        findsOneWidget,
      );
      expect(find.text('State machines'), findsOneWidget);
      expect(find.text('Section'), findsNothing);
      expect(find.textContaining('90'), findsNothing);

      await _expandDetails(tester);
      expect(find.text('Section'), findsOneWidget);
      expect(find.textContaining('Confidence:'), findsWidgets);
      expect(find.text('90%'), findsNothing);
    },
  );
}

Future<void> _expandDetails(WidgetTester tester) async {
  await tester.tap(find.byKey(const ValueKey('analysis-details')));
  await tester.pumpAndSettle();
}

Future<void> _pump(
  WidgetTester tester, {
  required StudyMaterial material,
  required List<MaterialViewerArgs> opened,
  StructuredSummary? summary,
}) async {
  final auth = AuthController(
    authRepository: MockAuthRepository(initialUser: _user),
    profileRepository: NoopProfileRepository(),
  );
  await auth.initialize();
  addTearDown(auth.dispose);
  final state = AppState();
  addTearDown(state.dispose);
  await tester.pumpWidget(
    AppStateScope(
      state: state,
      child: AuthScope(
        controller: auth,
        child: MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          onGenerateRoute: (settings) {
            if (settings.name == AppRoutes.materialViewer) {
              opened.add(settings.arguments! as MaterialViewerArgs);
              return MaterialPageRoute<void>(
                settings: settings,
                builder: (_) => const Scaffold(body: Text('viewer')),
              );
            }
            return null;
          },
          home: Scaffold(
            body: SingleChildScrollView(
              child: StructuredSummaryView(
                summary: summary ?? _summary(),
                material: material,
              ),
            ),
          ),
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

StudyMaterial _material(MaterialKind kind) => StudyMaterial(
  id: _materialId,
  subjectId: 'subject',
  title: 'Material',
  kind: kind,
  content: '',
  createdLabel: 'Now',
  sourceKind: MaterialSourceKind.upload,
  storageBucket: kind == MaterialKind.pdf ? 'study-materials' : 'study-images',
  storagePath:
      '${_user.id}/$_materialId/${kind == MaterialKind.pdf ? 'file.pdf' : 'file.png'}',
  mimeType: kind == MaterialKind.pdf ? 'application/pdf' : 'image/png',
  fileSizeBytes: 10,
  processingStatus: MaterialProcessingStatus.ready,
);

StructuredSummary _summary() => StructuredSummary(
  schemaVersion: 1,
  language: 'en',
  overviewMarkdown:
      'This lecture covers sequential digital circuits.\n\nIt connects state machines, registers, and counters.',
  topicTitles: const ['State machines', 'Registers', 'Counters'],
  sections: const [
    StructuredSection(
      id: 'section',
      title: 'Section',
      blocks: [
        EquationBlock(equationId: 'eq_one', display: SummaryDisplay.block),
      ],
      sourcePages: [1],
      confidence: 0.9,
    ),
  ],
  keyConcepts: const [],
  equations: const [
    Equation(
      id: 'eq_one',
      latex: r'\frac{a}{b}',
      explanationMarkdown: '',
      sourcePage: 2,
      display: SummaryDisplay.block,
      confidence: 0.9,
      uncertainty: false,
    ),
  ],
  warnings: const [
    AnalysisWarning(
      code: 'check_page',
      detail: 'Check source',
      sourcePages: [3, 2, 3],
    ),
  ],
  partialExtraction: const PartialExtraction(
    isPartial: false,
    analyzedPages: [1, 2, 3],
    partialPages: [],
    missingPages: [],
    pageModes: [
      PageMode(page: 1, mode: PageModeKind.text),
      PageMode(page: 2, mode: PageModeKind.visual),
      PageMode(page: 3, mode: PageModeKind.text),
    ],
  ),
);

StructuredSummary _summaryWithoutEquations() => StructuredSummary(
  schemaVersion: 1,
  language: 'en',
  overviewMarkdown:
      'This is a compact document overview.\n\nIt connects the main ideas.',
  topicTitles: const ['Overview', 'Foundations', 'Applications'],
  sections: const [
    StructuredSection(
      id: 'section',
      title: 'Section',
      blocks: [
        ProseBlock(markdown: 'Safe summary.', display: SummaryDisplay.block),
      ],
      sourcePages: [1],
      confidence: 0.9,
    ),
  ],
  keyConcepts: const [],
  equations: const [],
  warnings: const [],
  partialExtraction: const PartialExtraction(
    isPartial: false,
    analyzedPages: [1],
    partialPages: [],
    missingPages: [],
    pageModes: [PageMode(page: 1, mode: PageModeKind.text)],
  ),
);
