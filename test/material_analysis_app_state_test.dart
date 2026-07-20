import 'dart:async';

import 'package:ai_study_buddy/app/app_config.dart';
import 'package:ai_study_buddy/app/app_state.dart';
import 'package:ai_study_buddy/core/models/material.dart';
import 'package:ai_study_buddy/features/auth/auth_models.dart';
import 'package:ai_study_buddy/features/materials/material_analysis_repository.dart';
import 'package:ai_study_buddy/features/materials/material_repository.dart';
import 'package:ai_study_buddy/features/materials/structured_summary.dart';
import 'package:flutter_test/flutter_test.dart';

const _user = AuthUser(
  id: '11111111-1111-4111-8111-111111111111',
  email: 'a@example.test',
);
const _nextUser = AuthUser(
  id: '55555555-5555-4555-8555-555555555555',
  email: 'b@example.test',
);
const _ids = [
  '22222222-2222-4222-8222-222222222222',
  '33333333-3333-4333-8333-333333333333',
  '44444444-4444-4444-8444-444444444444',
];
const _supabaseConfig = AppConfig(
  environment: AppEnvironment.staging,
  backendMode: AppBackendMode.supabase,
  supabaseUrl: 'https://project.supabase.co',
  supabaseAnonKey: 'sb_publishable_test',
);
const _pendingUpload = StudyMaterial(
  id: '22222222-2222-4222-8222-222222222222',
  subjectId: 'subject',
  title: 'fixture.pdf',
  kind: MaterialKind.pdf,
  content: '',
  createdLabel: 'Just now',
  sourceKind: MaterialSourceKind.upload,
  storageBucket: 'study-materials',
  storagePath:
      '11111111-1111-4111-8111-111111111111/'
      '22222222-2222-4222-8222-222222222222/fixture.pdf',
  mimeType: 'application/pdf',
  fileSizeBytes: 1024,
  processingStatus: MaterialProcessingStatus.pending,
);
const _summary = StructuredSummary(
  schemaVersion: 1,
  language: 'en',
  sections: [
    StructuredSection(
      id: 'overview',
      title: 'Overview',
      blocks: [
        ProseBlock(
          markdown: 'Completed summary.',
          display: SummaryDisplay.block,
        ),
      ],
      sourcePages: [1],
      confidence: 1,
    ),
  ],
  keyConcepts: [],
  equations: [],
  warnings: [],
  partialExtraction: PartialExtraction(
    isPartial: false,
    analyzedPages: [1],
    partialPages: [],
    missingPages: [],
    pageModes: [PageMode(page: 1, mode: PageModeKind.visual)],
  ),
);

void main() {
  test('large document gates are exact', () {
    expect(analysisDocumentGate(20), AnalysisDocumentGate.automatic);
    expect(analysisDocumentGate(21), AnalysisDocumentGate.confirmation);
    expect(analysisDocumentGate(100), AnalysisDocumentGate.confirmation);
    expect(analysisDocumentGate(101), AnalysisDocumentGate.rejected);
  });

  test(
    'user retry required never auto-advances and explicit retry is once',
    () async {
      final retry = Completer<MaterialAnalysisStatus>();
      final repo = _Repo(
        onFetch: (id) async =>
            _status(id, state: AnalysisState.userRetryRequired, canRetry: true),
        onRetry: (_) => retry.future,
      );
      final state = AppState(materialAnalysisRepository: repo);
      await state.observeMaterialAnalysis(_user, _ids.first);
      await Future<void>.delayed(const Duration(milliseconds: 20));
      expect(repo.advances, 0);
      final first = state.retryMaterialAnalysis(_user, _ids.first);
      final second = state.retryMaterialAnalysis(_user, _ids.first);
      expect(repo.retries, 1);
      expect(await second, isFalse);
      retry.complete(_status(_ids.first, state: AnalysisState.completed));
      expect(await first, isTrue);
      expect(state.isMaterialAnalysisActionInFlight(_ids.first), isFalse);
    },
  );

  test(
    'confirmation double tap sends one request and failure releases guard',
    () async {
      final firstPrepare = Completer<MaterialAnalysisStatus>();
      var failNext = false;
      final repo = _Repo(
        onFetch: (id) async => _status(
          id,
          pageCount: 21,
          state: AnalysisState.awaitingConfirmation,
          confirmationRequired: true,
        ),
        onPrepare: (id, _, confirmed) {
          if (failNext) {
            return Future.error(
              const MaterialAnalysisException(AnalysisErrorCode.network),
            );
          }
          return firstPrepare.future;
        },
      );
      final state = AppState(materialAnalysisRepository: repo);
      await state.observeMaterialAnalysis(_user, _ids.first);
      final first = state.confirmLargeMaterialAnalysis(_user, _ids.first);
      final duplicate = state.confirmLargeMaterialAnalysis(_user, _ids.first);
      expect(state.isMaterialAnalysisActionInFlight(_ids.first), isTrue);
      expect(repo.prepares, 1);
      expect(await duplicate, isFalse);
      firstPrepare.complete(
        _status(_ids.first, state: AnalysisState.completed),
      );
      expect(await first, isTrue);

      await state.observeMaterialAnalysis(_user, _ids.first, force: true);
      failNext = true;
      expect(
        await state.confirmLargeMaterialAnalysis(_user, _ids.first),
        isFalse,
      );
      expect(state.isMaterialAnalysisActionInFlight(_ids.first), isFalse);
    },
  );

  test(
    'logout during active advance invalidates completion and clears state',
    () async {
      final advance = Completer<MaterialAnalysisStatus>();
      final repo = _Repo(
        onFetch: (id) async => _status(id),
        onAdvance: (_) => advance.future,
      );
      final state = AppState(materialAnalysisRepository: repo);
      await state.observeMaterialAnalysis(_user, _ids.first);
      await _waitFor(() => repo.advances == 1);
      state.clearSyncedWorkspaceForSignOut();
      expect(state.activeAnalysisLoopCount, 0);
      expect(state.analysisStatusFor(_ids.first), isNull);
      advance.complete(_status(_ids.first, state: AnalysisState.completed));
      await Future<void>.delayed(Duration.zero);
      expect(state.analysisStatusFor(_ids.first), isNull);
    },
  );

  test(
    'logout releases an explicit action guard and ignores completion',
    () async {
      final prepare = Completer<MaterialAnalysisStatus>();
      final repo = _Repo(
        onFetch: (id) async => _status(
          id,
          pageCount: 21,
          state: AnalysisState.awaitingConfirmation,
          confirmationRequired: true,
        ),
        onPrepare: (_, _, _) => prepare.future,
      );
      final state = AppState(materialAnalysisRepository: repo);
      await state.observeMaterialAnalysis(_user, _ids.first);
      final action = state.confirmLargeMaterialAnalysis(_user, _ids.first);
      expect(state.isMaterialAnalysisActionInFlight(_ids.first), isTrue);
      state.clearSyncedWorkspaceForSignOut();
      expect(state.isMaterialAnalysisActionInFlight(_ids.first), isFalse);
      prepare.complete(_status(_ids.first, state: AnalysisState.completed));
      expect(await action, isFalse);
      expect(state.analysisStatusFor(_ids.first), isNull);
    },
  );

  test(
    'user replacement invalidates polling and old action cannot clear new',
    () async {
      final oldPrepare = Completer<MaterialAnalysisStatus>();
      final newPrepare = Completer<MaterialAnalysisStatus>();
      final repo = _Repo(
        onFetch: (id) async => _status(
          id,
          pageCount: 21,
          state: AnalysisState.awaitingConfirmation,
          confirmationRequired: true,
        ),
        onPrepare: (id, user, _) =>
            user.id == _user.id ? oldPrepare.future : newPrepare.future,
      );
      final state = AppState(materialAnalysisRepository: repo);
      await state.observeMaterialAnalysis(_user, _ids.first);
      final oldAction = state.confirmLargeMaterialAnalysis(_user, _ids.first);
      await state.observeMaterialAnalysis(_nextUser, _ids.first, force: true);
      final newAction = state.confirmLargeMaterialAnalysis(
        _nextUser,
        _ids.first,
      );
      oldPrepare.complete(_status(_ids.first));
      expect(await oldAction, isFalse);
      expect(state.isMaterialAnalysisActionInFlight(_ids.first), isTrue);
      newPrepare.complete(_status(_ids.first, state: AnalysisState.completed));
      expect(await newAction, isTrue);
      expect(state.isMaterialAnalysisActionInFlight(_ids.first), isFalse);
    },
  );

  test('pause stops advancement and resume fetches before advancing', () async {
    final firstAdvance = Completer<MaterialAnalysisStatus>();
    final events = <String>[];
    final repo = _Repo(
      onFetch: (id) async {
        events.add('fetch');
        return _status(id);
      },
      onAdvance: (id) {
        events.add('advance');
        if (!firstAdvance.isCompleted) return firstAdvance.future;
        return Future.value(_status(id, state: AnalysisState.completed));
      },
    );
    final state = AppState(materialAnalysisRepository: repo);
    await state.observeMaterialAnalysis(_user, _ids.first);
    await _waitFor(() => repo.advances == 1);
    state.setAnalysisLifecycleForegrounded(false);
    firstAdvance.complete(_status(_ids.first));
    await Future<void>.delayed(const Duration(milliseconds: 20));
    expect(repo.advances, 1);
    events.clear();
    state.setAnalysisLifecycleForegrounded(true);
    await _waitFor(() => repo.advances == 2);
    expect(events.take(2), ['fetch', 'advance']);
    await _waitFor(() => state.activeAnalysisLoopCount == 0);
  });

  test(
    'two loops cap the supervisor and third releases after terminal',
    () async {
      final waits = {
        for (final id in _ids) id: Completer<MaterialAnalysisStatus>(),
      };
      final repo = _Repo(
        onFetch: (id) async => _status(id),
        onAdvance: (id) => waits[id]!.future,
      );
      final state = AppState(materialAnalysisRepository: repo);
      await Future.wait(
        _ids.map((id) => state.observeMaterialAnalysis(_user, id)),
      );
      await _waitFor(() => repo.advanceIds.length == 2);
      expect(repo.advanceIds, isNot(contains(_ids.last)));
      waits[_ids.first]!.complete(
        _status(_ids.first, state: AnalysisState.completed),
      );
      await _waitFor(() => repo.advanceIds.contains(_ids.last));
      for (final entry in waits.entries) {
        if (!entry.value.isCompleted) {
          entry.value.complete(
            _status(entry.key, state: AnalysisState.completed),
          );
        }
      }
      await _waitFor(() => state.activeAnalysisLoopCount == 0);
    },
  );

  test('duplicate observe and delayed loop never overlap advance', () async {
    final advance = Completer<MaterialAnalysisStatus>();
    final fetch = Completer<MaterialAnalysisStatus>();
    final repo = _Repo(
      onFetch: (_) => fetch.future,
      onAdvance: (_) => advance.future,
    );
    final state = AppState(materialAnalysisRepository: repo);
    final first = state.observeMaterialAnalysis(_user, _ids.first);
    final second = state.observeMaterialAnalysis(_user, _ids.first);
    expect(repo.fetches, 1);
    fetch.complete(_status(_ids.first));
    await Future.wait([first, second]);
    await _waitFor(() => repo.advances == 1);
    await Future<void>.delayed(const Duration(milliseconds: 750));
    expect(repo.advances, 1);
    advance.complete(_status(_ids.first, state: AnalysisState.completed));
    await _waitFor(() => state.activeAnalysisLoopCount == 0);
  });

  test('stale old-session error cannot replace newer success', () async {
    final oldFetch = Completer<MaterialAnalysisStatus>();
    final repo = _Repo(
      onFetchWithUser: (id, user) => user.id == _user.id
          ? oldFetch.future
          : Future.value(_status(id, state: AnalysisState.completed)),
    );
    final state = AppState(materialAnalysisRepository: repo);
    final old = state.observeMaterialAnalysis(_user, _ids.first);
    await state.observeMaterialAnalysis(_nextUser, _ids.first, force: true);
    oldFetch.completeError(
      const MaterialAnalysisException(AnalysisErrorCode.network),
    );
    await old;
    expect(state.analysisStatusFor(_ids.first)?.state, AnalysisState.completed);
    expect(state.analysisErrorFor(_ids.first), isNull);
  });

  test(
    'missing status preflight covers 20, 21, 100, 101 and corrupt',
    () async {
      for (final pageCount in [20, 21, 100]) {
        final repo = _Repo(
          onFetch: (_) => Future.error(
            const MaterialAnalysisException(AnalysisErrorCode.statusNotFound),
          ),
          onPrepare: (id, _, _) async => _status(
            id,
            pageCount: pageCount,
            state: pageCount == 20
                ? AnalysisState.completed
                : AnalysisState.awaitingConfirmation,
            confirmationRequired: pageCount >= 21,
          ),
        );
        final state = AppState(materialAnalysisRepository: repo);
        await state.observeMaterialAnalysis(_user, _ids.first);
        expect(repo.prepares, 1);
        expect(state.analysisStatusFor(_ids.first)?.pageCount, pageCount);
        expect(repo.advances, 0);
      }

      for (final error in [
        AnalysisErrorCode.documentTooLarge,
        AnalysisErrorCode.corruptDocument,
      ]) {
        final repo = _Repo(
          onFetch: (_) => Future.error(
            const MaterialAnalysisException(AnalysisErrorCode.statusNotFound),
          ),
          onPrepare: (_, _, _) =>
              Future.error(MaterialAnalysisException(error)),
        );
        final state = AppState(materialAnalysisRepository: repo);
        await state.observeMaterialAnalysis(_user, _ids.first);
        expect(state.analysisErrorFor(_ids.first), error);
        expect(repo.advances, 0);
        await state.observeMaterialAnalysis(_user, _ids.first);
        expect(repo.prepares, 1, reason: 'navigation must not storm preflight');

        final restarted = AppState(materialAnalysisRepository: repo);
        await restarted.observeMaterialAnalysis(_user, _ids.first);
        expect(restarted.analysisErrorFor(_ids.first), error);
        expect(
          repo.prepares,
          2,
          reason: 'restart deterministically rediscovers',
        );
      }
    },
  );

  test(
    'cold workspace restore publishes an authoritative failed job',
    () async {
      final repo = _Repo(
        onFetch: (id) async => _status(
          id,
          state: AnalysisState.failed,
          publicStage: AnalysisPublicStage.creatingSummary,
        ),
      );
      final state = _restoredState(repo);

      await state.loadSyncedWorkspaceFor(_user);

      expect(state.analysisStatusFor(_ids.first)?.state, AnalysisState.failed);
      expect(repo.fetches, 1);
      expect(repo.advances, 0);
      expect(state.activeAnalysisLoopCount, 0);
    },
  );

  test(
    'cold workspace restore publishes a completed structured summary',
    () async {
      final repo = _Repo(
        onFetch: (id) async =>
            _status(id, state: AnalysisState.completed, summary: _summary),
      );
      final state = _restoredState(repo);

      await state.loadSyncedWorkspaceFor(_user);

      final restored = state.analysisStatusFor(_ids.first);
      expect(restored?.state, AnalysisState.completed);
      expect(restored?.summary, same(_summary));
      expect(repo.fetches, 1);
      expect(repo.advances, 0);
    },
  );

  test('restored nonterminal job owns exactly one polling loop', () async {
    final advance = Completer<MaterialAnalysisStatus>();
    final repo = _Repo(
      onFetch: (id) async => _status(id),
      onAdvance: (_) => advance.future,
    );
    final state = _restoredState(repo);

    await state.loadSyncedWorkspaceFor(_user);
    await _waitFor(() => repo.advances == 1);
    await state.observeMaterialAnalysis(_user, _ids.first);

    expect(repo.fetches, 1);
    expect(repo.advances, 1);
    expect(state.activeAnalysisLoopCount, 1);
    advance.complete(_status(_ids.first, state: AnalysisState.completed));
    await _waitFor(() => state.activeAnalysisLoopCount == 0);
    expect(repo.advances, 1);
  });

  test(
    'prepared failed visual state advances once to create recovery work',
    () async {
      final clock = _FakeAnalysisClock();
      final recovery = Completer<MaterialAnalysisStatus>();
      final repo = _Repo(
        onFetch: (id) async => _status(
          id,
          publicStage: AnalysisPublicStage.recognizingFormulasAndDiagrams,
        ),
        onAdvance: (_) => recovery.future,
      );
      final state = _restoredState(repo, clock: clock);

      await state.loadSyncedWorkspaceFor(_user);
      await _waitFor(() => repo.advances == 1);

      expect(repo.advances, 1);
      expect(state.activeAnalysisLoopCount, 1);
      recovery.complete(
        _status(
          _ids.first,
          publicStage: AnalysisPublicStage.recognizingFormulasAndDiagrams,
        ),
      );
      await _waitFor(() => clock.pending == 1);
      expect(repo.advances, 1, reason: 'recovery polling waits for its tick');
      state.stopObservingMaterialAnalysis(_ids.first);
      clock.elapseOne();
    },
  );

  test(
    'cold restored prepared visual state starts one recovery advance',
    () async {
      final advance = Completer<MaterialAnalysisStatus>();
      var fetches = 0;
      final repo = _Repo(
        onFetch: (id) async {
          fetches += 1;
          return fetches == 1
              ? _status(
                  id,
                  publicStage:
                      AnalysisPublicStage.recognizingFormulasAndDiagrams,
                )
              : _status(id, state: AnalysisState.failed);
        },
        onAdvance: (_) => advance.future,
      );
      final state = _restoredState(repo);

      await state.loadSyncedWorkspaceFor(_user);
      await _waitFor(() => repo.advances == 1);
      final restoredAgain = state.loadSyncedWorkspaceFor(_user);
      await Future<void>.delayed(Duration.zero);

      expect(repo.advances, 1);
      advance.complete(_status(_ids.first, state: AnalysisState.failed));
      await restoredAgain;
      await _waitFor(() => state.activeAnalysisLoopCount == 0);
      expect(repo.advances, 1);
    },
  );

  test(
    'foreground reconciliation waits for in-flight advance before refetch',
    () async {
      final events = <String>[];
      final advance = Completer<MaterialAnalysisStatus>();
      var fetches = 0;
      final repo = _Repo(
        onFetch: (id) async {
          events.add('fetch');
          fetches += 1;
          return fetches == 1
              ? _status(id)
              : _status(id, state: AnalysisState.failed);
        },
        onAdvance: (id) {
          events.add('advance');
          return advance.future;
        },
      );
      final state = _restoredState(repo);

      await state.loadSyncedWorkspaceFor(_user);
      await _waitFor(() => repo.advances == 1);
      final resumed = state.resumeMaterialAnalyses(_user);
      await Future<void>.delayed(Duration.zero);
      expect(repo.advances, 1);
      expect(repo.fetches, 1);

      advance.complete(_status(_ids.first, state: AnalysisState.failed));
      await resumed;
      expect(events, ['fetch', 'advance', 'fetch']);
      expect(repo.advances, 1);
      expect(state.analysisStatusFor(_ids.first)?.state, AnalysisState.failed);
    },
  );

  test(
    'server-declared recovery failure is terminal and never advances',
    () async {
      final repo = _Repo(
        onFetch: (id) async => _status(
          id,
          state: AnalysisState.failed,
          publicStage: AnalysisPublicStage.recognizingFormulasAndDiagrams,
        ),
      );
      final state = _restoredState(repo);

      await state.loadSyncedWorkspaceFor(_user);

      expect(repo.advances, 0);
      expect(state.activeAnalysisLoopCount, 0);
      expect(state.analysisStatusFor(_ids.first)?.state, AnalysisState.failed);
    },
  );

  test(
    'recovery creation keeps one loop and continues on the next tick',
    () async {
      final clock = _FakeAnalysisClock();
      var advances = 0;
      final repo = _Repo(
        onFetch: (id) async => _status(id),
        onAdvance: (id) async {
          advances += 1;
          return advances == 1
              ? _status(
                  id,
                  publicStage:
                      AnalysisPublicStage.recognizingFormulasAndDiagrams,
                )
              : _status(id, state: AnalysisState.completed, summary: _summary);
        },
      );
      final state = _restoredState(repo, clock: clock);

      await state.loadSyncedWorkspaceFor(_user);
      await _waitFor(() => clock.pending == 1);
      expect(repo.advances, 1);
      clock.elapseOne();
      await _waitFor(() => repo.advances == 2);
      await _waitFor(() => state.activeAnalysisLoopCount == 0);

      expect(
        state.analysisStatusFor(_ids.first)?.state,
        AnalysisState.completed,
      );
      expect(repo.advances, 2);
    },
  );

  test('request failed stops supervision after one advance', () async {
    final clock = _FakeAnalysisClock();
    final repo = _Repo(
      onFetch: (id) async => _status(id),
      onAdvance: (_) => Future.error(
        const MaterialAnalysisException(AnalysisErrorCode.requestFailed),
      ),
    );
    final state = _restoredState(repo, clock: clock);

    await state.loadSyncedWorkspaceFor(_user);
    await _waitFor(() => state.activeAnalysisLoopCount == 0);

    expect(repo.advances, 1);
    expect(state.analysisErrorFor(_ids.first), AnalysisErrorCode.requestFailed);
    expect(clock.pending, 0);
  });

  test('lifecycle retry observes cooldown and fetches first', () async {
    final clock = _FakeAnalysisClock();
    final events = <String>[];
    var advances = 0;
    final repo = _Repo(
      onFetch: (id) async {
        events.add('fetch');
        return _status(id);
      },
      onAdvance: (id) async {
        advances += 1;
        events.add('advance');
        if (advances == 1) {
          throw const MaterialAnalysisException(
            AnalysisErrorCode.requestFailed,
          );
        }
        return _status(id, state: AnalysisState.failed);
      },
    );
    final state = _restoredState(repo, clock: clock);

    await state.loadSyncedWorkspaceFor(_user);
    await _waitFor(() => state.activeAnalysisLoopCount == 0);
    await Future.wait([
      state.resumeMaterialAnalyses(_user),
      state.resumeMaterialAnalyses(_user),
    ]);
    expect(repo.advances, 1);

    clock.advance(const Duration(seconds: 30));
    final beforeRetry = events.length;
    await state.resumeMaterialAnalyses(_user);
    await _waitFor(() => repo.advances == 2);

    expect(events.sublist(beforeRetry).take(2), ['fetch', 'advance']);
    expect(repo.advances, 2);
  });

  test('transient transport retries stop at the finite cap', () async {
    final clock = _FakeAnalysisClock();
    final repo = _Repo(
      onFetch: (id) async => _status(id),
      onAdvance: (_) => Future.error(
        const MaterialAnalysisException(AnalysisErrorCode.network),
      ),
    );
    final state = _restoredState(repo, clock: clock);

    await state.loadSyncedWorkspaceFor(_user);
    await _waitFor(() => repo.advances == 1 && clock.pending == 1);
    clock.elapseOne();
    await _waitFor(() => repo.advances == 2 && clock.pending == 1);
    clock.elapseOne();
    await _waitFor(() => repo.advances == 3);
    await _waitFor(() => state.activeAnalysisLoopCount == 0);

    expect(repo.advances, 3);
    expect(repo.fetches, 3, reason: 'initial plus two status refreshes');
    expect(clock.pending, 0);
  });

  test('durable progress resets the transient retry guard', () async {
    final clock = _FakeAnalysisClock();
    var advances = 0;
    final repo = _Repo(
      onFetch: (id) async => _status(id),
      onAdvance: (id) async {
        advances += 1;
        if (advances == 1) {
          throw const MaterialAnalysisException(AnalysisErrorCode.network);
        }
        return _status(id);
      },
    );
    final state = _restoredState(repo, clock: clock);

    await state.loadSyncedWorkspaceFor(_user);
    await _waitFor(() => clock.pending == 1);
    clock.elapseOne();
    await _waitFor(() => repo.advances == 2);

    expect(state.analysisErrorFor(_ids.first), isNull);
    state.stopObservingMaterialAnalysis(_ids.first);
    await _waitFor(() => clock.pending == 1);
    clock.elapseOne();
  });

  test('terminal refresh cancels a pending transient retry', () async {
    final clock = _FakeAnalysisClock();
    var fetches = 0;
    final repo = _Repo(
      onFetch: (id) async {
        fetches += 1;
        return fetches == 1
            ? _status(id)
            : _status(id, state: AnalysisState.failed);
      },
      onAdvance: (_) => Future.error(
        const MaterialAnalysisException(AnalysisErrorCode.network),
      ),
    );
    final state = _restoredState(repo, clock: clock);

    await state.loadSyncedWorkspaceFor(_user);
    await _waitFor(() => clock.pending == 1);
    await state.resumeMaterialAnalyses(_user);
    expect(state.analysisStatusFor(_ids.first)?.state, AnalysisState.failed);
    clock.elapseOne();
    await Future<void>.delayed(Duration.zero);

    expect(repo.advances, 1);
    expect(state.activeAnalysisLoopCount, 0);
  });

  test(
    'foreground resume refreshes and reconciles with an empty status cache',
    () async {
      final repo = _Repo(
        onFetch: (id) async => _status(id, state: AnalysisState.failed),
      );
      final materials = _MaterialRepo([_pendingUpload]);
      final state = _restoredState(repo, materials: materials);
      state.setAnalysisLifecycleForegrounded(false);

      await state.resumeMaterialAnalyses(_user);

      expect(materials.loads, 1);
      expect(repo.fetches, 1);
      expect(state.analysisStatusFor(_ids.first)?.state, AnalysisState.failed);
      expect(repo.advances, 0);
    },
  );

  test(
    'forced reconciliation follows a stale observation with one fresh fetch',
    () async {
      final stale = Completer<MaterialAnalysisStatus>();
      var fetch = 0;
      final repo = _Repo(
        onFetch: (id) {
          fetch += 1;
          return fetch == 1
              ? stale.future
              : Future.value(_status(id, state: AnalysisState.failed));
        },
      );
      final state = _restoredState(repo);
      state.setAnalysisLifecycleForegrounded(false);
      final first = state.observeMaterialAnalysis(_user, _ids.first);
      final resumed = state.resumeMaterialAnalyses(_user);
      stale.complete(_status(_ids.first));

      await Future.wait([first, resumed]);

      expect(repo.fetches, 2);
      expect(state.analysisStatusFor(_ids.first)?.state, AnalysisState.failed);
      expect(repo.advances, 0);
      expect(state.activeAnalysisLoopCount, 0);
    },
  );

  test(
    'fake clock keeps a nonterminal poll from duplicating submission',
    () async {
      final clock = _FakeAnalysisClock();
      var advance = 0;
      final repo = _Repo(
        onFetch: (id) async => _status(id),
        onAdvance: (id) async {
          advance += 1;
          return advance == 1
              ? _status(id)
              : _status(id, state: AnalysisState.completed);
        },
      );
      final state = _restoredState(repo, clock: clock);

      await state.loadSyncedWorkspaceFor(_user);
      await _waitFor(() => repo.advances == 1);
      await state.observeMaterialAnalysis(_user, _ids.first, force: true);

      expect(repo.advances, 1);
      expect(clock.pending, 1);
      clock.elapseOne();
      await _waitFor(() => repo.advances == 2);
      await _waitFor(() => state.activeAnalysisLoopCount == 0);
      expect(repo.advances, 2);
    },
  );

  test('initial missing status still prepares exactly once', () async {
    final repo = _Repo(
      onFetch: (_) => Future.error(
        const MaterialAnalysisException(AnalysisErrorCode.statusNotFound),
      ),
      onPrepare: (id, _, _) async =>
          _status(id, state: AnalysisState.completed),
    );
    final state = _restoredState(repo);

    await state.loadSyncedWorkspaceFor(_user);

    expect(repo.fetches, 1);
    expect(repo.prepares, 1);
    expect(repo.advances, 0);
    expect(state.analysisStatusFor(_ids.first)?.state, AnalysisState.completed);
  });
}

class _Repo implements MaterialAnalysisRepository {
  _Repo({
    this.onFetch,
    this.onFetchWithUser,
    this.onAdvance,
    this.onPrepare,
    this.onRetry,
  });

  final Future<MaterialAnalysisStatus> Function(String)? onFetch;
  final Future<MaterialAnalysisStatus> Function(String, AuthUser)?
  onFetchWithUser;
  final Future<MaterialAnalysisStatus> Function(String)? onAdvance;
  final Future<MaterialAnalysisStatus> Function(String, AuthUser, bool)?
  onPrepare;
  final Future<MaterialAnalysisStatus> Function(String)? onRetry;
  int fetches = 0, advances = 0, prepares = 0, retries = 0;
  final advanceIds = <String>[];

  @override
  Future<MaterialAnalysisStatus> fetchStatus({
    required AuthUser user,
    required String materialId,
  }) {
    fetches += 1;
    return onFetchWithUser?.call(materialId, user) ??
        onFetch?.call(materialId) ??
        Future.value(_status(materialId));
  }

  @override
  Future<MaterialAnalysisStatus> advance({
    required AuthUser user,
    required String materialId,
  }) {
    advances += 1;
    advanceIds.add(materialId);
    return onAdvance?.call(materialId) ??
        Future.value(_status(materialId, state: AnalysisState.completed));
  }

  @override
  Future<MaterialAnalysisStatus> retry({
    required AuthUser user,
    required String materialId,
  }) {
    retries += 1;
    return onRetry?.call(materialId) ??
        Future.value(_status(materialId, state: AnalysisState.completed));
  }

  @override
  Future<MaterialAnalysisStatus> prepare({
    required AuthUser user,
    required String materialId,
    required AnalysisProcessingMode mode,
    required bool confirmLargeDocument,
  }) {
    prepares += 1;
    return onPrepare?.call(materialId, user, confirmLargeDocument) ??
        Future.value(_status(materialId, state: AnalysisState.completed));
  }
}

AppState _restoredState(
  _Repo repository, {
  _MaterialRepo? materials,
  _FakeAnalysisClock? clock,
}) => AppState(
  config: _supabaseConfig,
  materialRepository: materials ?? _MaterialRepo([_pendingUpload]),
  materialAnalysisRepository: repository,
  analysisDelay: clock?.delay,
  analysisNow: clock?.now,
);

class _MaterialRepo implements MaterialRepository {
  _MaterialRepo(this.materials);

  final List<StudyMaterial> materials;
  int loads = 0;

  @override
  Future<List<StudyMaterial>> loadMaterials(AuthUser user) async {
    loads += 1;
    return List<StudyMaterial>.of(materials);
  }

  @override
  Future<StudyMaterial> createMaterial({
    required AuthUser user,
    required String subjectId,
    required String title,
    required String content,
  }) => throw UnimplementedError();
}

class _FakeAnalysisClock {
  final List<Completer<void>> _delays = [];
  final List<Duration> _durations = [];
  DateTime _current = DateTime.utc(2026, 7, 20);

  int get pending => _delays.where((delay) => !delay.isCompleted).length;

  DateTime now() => _current;

  Future<void> delay(Duration duration) {
    final delay = Completer<void>();
    _delays.add(delay);
    _durations.add(duration);
    return delay.future;
  }

  void elapseOne() {
    final index = _delays.indexWhere((delay) => !delay.isCompleted);
    _current = _current.add(_durations[index]);
    _delays[index].complete();
  }

  void advance(Duration duration) => _current = _current.add(duration);
}

MaterialAnalysisStatus _status(
  String id, {
  AnalysisState state = AnalysisState.processing,
  int pageCount = 1,
  bool confirmationRequired = false,
  bool canRetry = false,
  AnalysisPublicStage? publicStage,
  StructuredSummary? summary,
}) => MaterialAnalysisStatus(
  materialId: id,
  processingMode: AnalysisProcessingMode.recommended,
  state: state,
  publicStage:
      publicStage ??
      (state == AnalysisState.completed
          ? AnalysisPublicStage.creatingSummary
          : AnalysisPublicStage.analyzingPages),
  pageCount: pageCount,
  completedPages: state == AnalysisState.completed ? pageCount : 0,
  confirmationRequired: confirmationRequired,
  canRetry: canRetry,
  retryAfterSeconds: null,
  warnings: const [],
  summarySchemaVersion: summary == null ? null : 1,
  summary: summary,
  structuredSummaryMalformed: false,
);

Future<void> _waitFor(bool Function() condition) async {
  for (var index = 0; index < 200 && !condition(); index += 1) {
    await Future<void>.delayed(const Duration(milliseconds: 5));
  }
  expect(condition(), isTrue);
}
