import 'dart:async';

import 'package:ai_study_buddy/app/app_config.dart';
import 'package:ai_study_buddy/app/app_state.dart';
import 'package:ai_study_buddy/core/models/material.dart';
import 'package:ai_study_buddy/features/auth/auth_controller.dart';
import 'package:ai_study_buddy/features/auth/auth_models.dart';
import 'package:ai_study_buddy/features/auth/auth_repository.dart';
import 'package:ai_study_buddy/features/materials/material_analysis_repository.dart';
import 'package:ai_study_buddy/features/materials/material_detail_screen.dart';
import 'package:ai_study_buddy/features/materials/material_repository.dart';
import 'package:ai_study_buddy/features/materials/structured_summary.dart';
import 'package:ai_study_buddy/l10n/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

const _user = AuthUser(
  id: '11111111-1111-4111-8111-111111111111',
  email: 'student@example.test',
);
const _material = StudyMaterial(
  id: '22222222-2222-4222-8222-222222222222',
  subjectId: 'subject',
  title: 'lecture.pdf',
  kind: MaterialKind.pdf,
  content: '',
  createdLabel: 'Today',
  sourceKind: MaterialSourceKind.upload,
  storageBucket: 'study-materials',
  storagePath:
      '11111111-1111-4111-8111-111111111111/22222222-2222-4222-8222-222222222222/lecture.pdf',
  mimeType: 'application/pdf',
  fileSizeBytes: 1024,
  processingStatus: MaterialProcessingStatus.pending,
);

void main() {
  for (final (stage, text) in [
    (AnalysisPublicStage.preparingDocument, 'Preparing document'),
    (AnalysisPublicStage.analyzingPages, 'Analyzing pages 2 of 4'),
    (
      AnalysisPublicStage.recognizingFormulasAndDiagrams,
      'Recognizing formulas and diagrams',
    ),
    (AnalysisPublicStage.combiningResults, 'Combining results'),
    (AnalysisPublicStage.creatingSummary, 'Creating summary'),
  ]) {
    testWidgets('renders exact public stage ${stage.name}', (tester) async {
      final advance = Completer<MaterialAnalysisStatus>();
      await _pump(
        tester,
        _UiRepo(
          status: _status(stage: stage),
          onAdvance: () => advance.future,
        ),
      );
      expect(find.text(text), findsWidgets);
      if (stage == AnalysisPublicStage.analyzingPages) {
        final progress = tester.widget<LinearProgressIndicator>(
          find.byType(LinearProgressIndicator).last,
        );
        expect(progress.value, closeTo(0.3, 0.000001));
        expect(progress.semanticsLabel, 'Analyzing pages 2 of 4');
      }
      if (stage == AnalysisPublicStage.recognizingFormulasAndDiagrams) {
        expect(find.text('Pages processed: 2 of 4'), findsOneWidget);
        expect(
          find.textContaining('Recognizing formulas and diagrams 2'),
          findsNothing,
        );
      }
      expect(
        tester
            .widget<LinearProgressIndicator>(
              find.byType(LinearProgressIndicator).last,
            )
            .value,
        lessThan(1),
      );
      advance.complete(
        _status(
          stage: AnalysisPublicStage.creatingSummary,
          state: AnalysisState.completed,
          completedPages: 4,
        ),
      );
    });
  }

  testWidgets('confirmation action disables synchronously and sends once', (
    tester,
  ) async {
    final prepare = Completer<MaterialAnalysisStatus>();
    final repo = _UiRepo(
      status: _status(
        stage: AnalysisPublicStage.preparingDocument,
        state: AnalysisState.awaitingConfirmation,
        pageCount: 21,
        completedPages: 0,
        confirmationRequired: true,
      ),
      onPrepare: () => prepare.future,
    );
    await _pump(tester, repo);
    final action = find.text('Continue analysis');
    expect(action, findsOneWidget);
    await tester.tap(action);
    await tester.pump();
    expect(repo.prepares, 1);
    final inkWell = tester.widget<InkWell>(
      find.ancestor(of: action, matching: find.byType(InkWell)),
    );
    expect(inkWell.onTap, isNull);
    prepare.complete(
      _status(
        stage: AnalysisPublicStage.analyzingPages,
        pageCount: 21,
        completedPages: 0,
      ),
    );
  });

  testWidgets(
    'completed warnings and partial/missing pages survive dark large text',
    (tester) async {
      await _pump(
        tester,
        _UiRepo(
          status: _status(
            stage: AnalysisPublicStage.creatingSummary,
            state: AnalysisState.completedWithWarnings,
            completedPages: 4,
            summary: _summary(),
          ),
        ),
        dark: true,
        textScale: 2,
      );
      await tester.scrollUntilVisible(
        find.text('Partial pages'),
        200,
        scrollable: find.byType(Scrollable).first,
      );
      expect(find.text('Completed with warnings'), findsWidgets);
      expect(find.text('Partial pages'), findsOneWidget);
      expect(find.text('Missing pages'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('completed analysis labels header and progress consistently', (
    tester,
  ) async {
    await _pump(
      tester,
      _UiRepo(
        status: _status(
          stage: AnalysisPublicStage.creatingSummary,
          state: AnalysisState.completed,
          completedPages: 4,
          summary: _summary(),
        ),
      ),
    );

    expect(find.text('Completed'), findsWidgets);
    expect(find.text('Ready'), findsNothing);
    expect(find.text('Text extracted'), findsNothing);
    expect(find.byType(LinearProgressIndicator), findsNothing);
    await tester.scrollUntilVisible(
      find.byKey(const Key('flashcards-section')),
      400,
      scrollable: find.byType(Scrollable).first,
    );
    expect(find.byKey(const Key('flashcards-section')), findsOneWidget);
    expect(find.text('Generate flashcards'), findsOneWidget);
  });

  testWidgets('forced reconciliation replaces stale stage without navigation', (
    tester,
  ) async {
    final advance = Completer<MaterialAnalysisStatus>();
    var fetches = 0;
    final repo = _UiRepo(
      status: _status(
        stage: AnalysisPublicStage.recognizingFormulasAndDiagrams,
      ),
      onFetch: () {
        fetches += 1;
        return Future.value(
          fetches == 1
              ? _status(
                  stage: AnalysisPublicStage.recognizingFormulasAndDiagrams,
                )
              : _status(
                  stage: AnalysisPublicStage.creatingSummary,
                  state: AnalysisState.failed,
                ),
        );
      },
      onAdvance: () => advance.future,
    );
    final state = await _pump(tester, repo);
    expect(find.text('Recognizing formulas and diagrams'), findsWidgets);
    expect(find.text('Pages processed: 2 of 4'), findsOneWidget);

    final reconciliation = state.observeMaterialAnalysis(
      _user,
      _material.id,
      force: true,
    );
    await tester.pump();
    expect(fetches, 1, reason: 'the in-flight advance finishes first');
    advance.complete(
      _status(stage: AnalysisPublicStage.recognizingFormulasAndDiagrams),
    );
    await reconciliation;
    await tester.pump();

    expect(find.text('Failed'), findsWidgets);
    expect(
      find.text('The document is invalid, damaged, or unsupported.'),
      findsOneWidget,
    );
    expect(find.text('Recognizing formulas and diagrams'), findsNothing);
    expect(find.text('Pages processed: 2 of 4'), findsNothing);
    expect(find.text('Creating summary'), findsNothing);
    expect(repo.advances, 1);
  });

  testWidgets('terminal failure updates header and progress card together', (
    tester,
  ) async {
    await _pump(
      tester,
      _UiRepo(
        status: _status(
          stage: AnalysisPublicStage.recognizingFormulasAndDiagrams,
          state: AnalysisState.failed,
        ),
      ),
    );

    expect(find.text('Failed'), findsWidgets);
    expect(
      find.text('The document is invalid, damaged, or unsupported.'),
      findsOneWidget,
    );
    expect(find.text('Recognizing formulas and diagrams'), findsNothing);
    expect(
      find.text('Processing can resume when you reopen the app.'),
      findsNothing,
    );
  });

  testWidgets(
    'terminal structured-output failure is specific and stops progress',
    (tester) async {
      final failed = _status(
        stage: AnalysisPublicStage.creatingSummary,
        state: AnalysisState.failed,
        safeErrorCode: 'structured_output_invalid',
        canAnalyzeAgain: true,
      );
      final repo = _UiRepo(
        status: failed,
        onAnalyzeAgain: () => Future.value(failed),
      );
      await _pump(tester, repo);

      expect(
        find.text(
          'The analysis finished, but the result could not be processed. '
          'Analyze again to create a new analysis from the stored file.',
        ),
        findsOneWidget,
      );
      expect(find.byType(LinearProgressIndicator), findsNothing);
      expect(find.byType(CircularProgressIndicator), findsNothing);
      expect(find.text('Analyze again'), findsOneWidget);
      await tester.tap(find.text('Analyze again'));
      await tester.pumpAndSettle();
      expect(repo.analysesAgain, 1);
    },
  );

  testWidgets(
    'structured-output failure without eligibility promises no new analysis',
    (tester) async {
      await _pump(
        tester,
        _UiRepo(
          status: _status(
            stage: AnalysisPublicStage.creatingSummary,
            state: AnalysisState.failed,
            safeErrorCode: 'structured_output_invalid',
            canAnalyzeAgain: false,
          ),
        ),
      );

      expect(
        find.text(
          'The analysis finished, but the result could not be processed. '
          'A new analysis is currently unavailable.',
        ),
        findsOneWidget,
      );
      expect(find.text('Analyze again'), findsNothing);
      expect(
        find.text('The document is invalid, damaged, or unsupported.'),
        findsNothing,
      );
    },
  );

  for (final completed in [10, 25]) {
    testWidgets('$completed of 50 is explicitly described as page progress', (
      tester,
    ) async {
      final advance = Completer<MaterialAnalysisStatus>();
      await _pump(
        tester,
        _UiRepo(
          status: _status(
            stage: AnalysisPublicStage.recognizingFormulasAndDiagrams,
            pageCount: 50,
            completedPages: completed,
          ),
          onAdvance: () => advance.future,
        ),
      );
      expect(find.text('Recognizing formulas and diagrams'), findsWidgets);
      expect(find.text('Pages processed: $completed of 50'), findsOneWidget);
      advance.complete(
        _status(
          stage: AnalysisPublicStage.creatingSummary,
          state: AnalysisState.failed,
          pageCount: 50,
          completedPages: completed,
        ),
      );
    });
  }

  testWidgets('completed reconciliation renders terminal card and summary', (
    tester,
  ) async {
    await _pump(
      tester,
      _UiRepo(
        status: _status(
          stage: AnalysisPublicStage.creatingSummary,
          state: AnalysisState.completed,
          completedPages: 4,
          summary: _summary(),
        ),
      ),
    );

    expect(find.text('Completed'), findsWidgets);
    expect(find.text('Section'), findsOneWidget);
    expect(find.text('Creating summary'), findsNothing);
    expect(find.byType(LinearProgressIndicator), findsNothing);
  });

  testWidgets('request failed publishes a bounded recoverable panel', (
    tester,
  ) async {
    final repo = _UiRepo(
      status: _status(stage: AnalysisPublicStage.analyzingPages),
      onAdvance: () => Future.error(
        const MaterialAnalysisException(AnalysisErrorCode.requestFailed),
      ),
    );

    await _pump(tester, repo);
    await tester.pump();

    expect(repo.advances, 1);
    expect(
      find.text(
        'Document analysis is temporarily unavailable. Try again later.',
      ),
      findsOneWidget,
    );
    await tester.pump(const Duration(seconds: 2));
    expect(repo.advances, 1);
  });
}

Future<AppState> _pump(
  WidgetTester tester,
  _UiRepo repo, {
  bool dark = false,
  double textScale = 1,
}) async {
  final auth = AuthController(
    authRepository: MockAuthRepository(initialUser: _user),
    profileRepository: NoopProfileRepository(),
  );
  await auth.initialize();
  final state = AppState(
    config: const AppConfig(
      backendMode: AppBackendMode.supabase,
      supabaseUrl: 'https://example.supabase.co',
      supabaseAnonKey: 'sb_publishable_test-client-key',
    ),
    materialRepository: MockMaterialRepository(
      initialMaterials: const [_material],
    ),
    materialAnalysisRepository: repo,
  );
  await state.loadMaterialsFor(_user);
  addTearDown(auth.dispose);
  addTearDown(state.dispose);
  await tester.pumpWidget(
    MediaQuery(
      data: MediaQueryData(textScaler: TextScaler.linear(textScale)),
      child: AppStateScope(
        state: state,
        child: AuthScope(
          controller: auth,
          child: MaterialApp(
            theme: ThemeData.light(),
            darkTheme: ThemeData.dark(),
            themeMode: dark ? ThemeMode.dark : ThemeMode.light,
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: const MaterialDetailScreen(material: _material),
          ),
        ),
      ),
    ),
  );
  await tester.pump();
  await tester.pump();
  await tester.pump();
  return state;
}

class _UiRepo implements MaterialAnalysisRepository {
  _UiRepo({
    required this.status,
    this.onFetch,
    this.onAdvance,
    this.onPrepare,
    this.onAnalyzeAgain,
  });

  final MaterialAnalysisStatus status;
  final Future<MaterialAnalysisStatus> Function()? onFetch,
      onAdvance,
      onPrepare,
      onAnalyzeAgain;
  int prepares = 0, advances = 0, analysesAgain = 0;
  @override
  Future<MaterialAnalysisStatus> fetchStatus({
    required AuthUser user,
    required String materialId,
  }) => onFetch?.call() ?? Future.value(status);
  @override
  Future<MaterialAnalysisStatus> advance({
    required AuthUser user,
    required String materialId,
  }) {
    advances += 1;
    return onAdvance?.call() ?? Future.value(status);
  }

  @override
  Future<MaterialAnalysisStatus> prepare({
    required AuthUser user,
    required String materialId,
    required AnalysisProcessingMode mode,
    required bool confirmLargeDocument,
  }) {
    prepares += 1;
    return onPrepare?.call() ?? Future.value(status);
  }

  @override
  Future<MaterialAnalysisStatus> retry({
    required AuthUser user,
    required String materialId,
  }) async => status;
  @override
  Future<MaterialAnalysisStatus> analyzeAgain({
    required AuthUser user,
    required String materialId,
    required AnalysisProcessingMode mode,
  }) {
    analysesAgain += 1;
    return onAnalyzeAgain?.call() ?? Future.value(status);
  }
}

MaterialAnalysisStatus _status({
  required AnalysisPublicStage stage,
  AnalysisState state = AnalysisState.processing,
  int pageCount = 4,
  int completedPages = 2,
  bool confirmationRequired = false,
  StructuredSummary? summary,
  String? safeErrorCode,
  bool canAnalyzeAgain = false,
}) => MaterialAnalysisStatus(
  materialId: _material.id,
  processingMode: AnalysisProcessingMode.recommended,
  state: state,
  publicStage: stage,
  pageCount: pageCount,
  completedPages: completedPages,
  confirmationRequired: confirmationRequired,
  canRetry: false,
  canAnalyzeAgain: canAnalyzeAgain,
  retryAfterSeconds: null,
  warnings: const [],
  summarySchemaVersion: summary == null ? null : 1,
  summary: summary,
  structuredSummaryMalformed: false,
  safeErrorCode: safeErrorCode,
);

StructuredSummary _summary() => const StructuredSummary(
  schemaVersion: 1,
  language: 'en',
  sections: [
    StructuredSection(
      id: 'section',
      title: 'Section',
      blocks: [ProseBlock(markdown: 'Text', display: SummaryDisplay.block)],
      sourcePages: [1],
      confidence: 0.8,
    ),
  ],
  keyConcepts: [],
  equations: [],
  warnings: [],
  partialExtraction: PartialExtraction(
    isPartial: true,
    analyzedPages: [1, 4],
    partialPages: [2],
    missingPages: [3],
    pageModes: [
      PageMode(page: 1, mode: PageModeKind.text),
      PageMode(page: 2, mode: PageModeKind.visual),
      PageMode(page: 3, mode: PageModeKind.visual),
      PageMode(page: 4, mode: PageModeKind.text),
    ],
  ),
);
