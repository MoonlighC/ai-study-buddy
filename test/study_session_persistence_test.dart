import 'dart:convert';

import 'package:ai_study_buddy/app/app_preferences.dart';
import 'package:ai_study_buddy/app/app_state.dart';
import 'package:ai_study_buddy/core/models/material.dart';
import 'package:ai_study_buddy/core/models/study_session.dart';
import 'package:ai_study_buddy/core/models/subject.dart';
import 'package:ai_study_buddy/features/auth/auth_models.dart';
import 'package:ai_study_buddy/features/materials/material_repository.dart';
import 'package:ai_study_buddy/features/subjects/subject_repository.dart';
import 'package:flutter_test/flutter_test.dart';

const _user = AuthUser(id: 'user-a', email: 'a@example.test');
const _otherUser = AuthUser(id: 'user-b', email: 'b@example.test');
const _subject = Subject(
  id: 'subject-a',
  name: 'Biology',
  description: 'Test subject',
  colorValue: 0xFF3366CC,
);
const _material = StudyMaterial(
  id: 'material-a',
  subjectId: 'subject-a',
  title: 'Photosynthesis',
  kind: MaterialKind.pastedText,
  content:
      'Photosynthesis transforms light energy into chemical energy while plants use water and carbon dioxide to produce glucose and oxygen.',
  createdLabel: 'Today',
);

void main() {
  test('active session restores its exact answer index and score', () async {
    final store = MemoryAppPreferencesStore();
    final original = _state(store);
    await original.loadSyncedWorkspaceFor(_user);
    final created = original.createStudySession(
      subject: _subject,
      confidence: LectureConfidence.mostly,
      materialId: _material.id,
    )!;
    original.answerQuiz(
      sessionId: created.id,
      answer: created.quizQuestion.correctAnswer,
    );
    await original.studySessionPersistenceIdle;

    final restored = _state(store);
    await restored.loadSyncedWorkspaceFor(_user);
    await restored.studySessionRestorationIdle;

    expect(restored.latestStudySession?.id, created.id);
    expect(
      restored.latestStudySession?.selectedAnswer,
      created.quizQuestion.correctAnswer,
    );
    expect(restored.latestStudySession?.quizScorePercent, 100);
    expect(restored.latestStudySession?.currentItemIndex, 1);
    expect(restored.latestStudySession?.completedItemIds, ['quick_quiz']);
  });

  test('completing a session clears its persisted snapshot', () async {
    final store = MemoryAppPreferencesStore();
    final state = _state(store);
    await state.loadSyncedWorkspaceFor(_user);
    final session = _create(state);
    await state.studySessionPersistenceIdle;

    state.completeStudySession(session.id);
    await state.studySessionPersistenceIdle;

    expect(state.latestStudySession, isNull);
    expect(store.activeStudySessionFor(_user.id), isNull);
    final restored = _state(store);
    await restored.loadSyncedWorkspaceFor(_user);
    await restored.studySessionRestorationIdle;
    expect(restored.latestStudySession, isNull);
  });

  test('explicit exit clears its persisted snapshot', () async {
    final store = MemoryAppPreferencesStore();
    final state = _state(store);
    await state.loadSyncedWorkspaceFor(_user);
    final session = _create(state);
    await state.studySessionPersistenceIdle;

    state.exitStudySession(session.id);
    await state.studySessionPersistenceIdle;

    expect(store.activeStudySessionFor(_user.id), isNull);
    expect(state.latestStudySession, isNull);
  });

  test('user switch cannot inherit another user session', () async {
    final store = MemoryAppPreferencesStore();
    final first = _state(store);
    await first.loadSyncedWorkspaceFor(_user);
    _create(first);
    await first.studySessionPersistenceIdle;

    final second = _state(store);
    await second.loadSyncedWorkspaceFor(_otherUser);
    await second.studySessionRestorationIdle;

    expect(second.latestStudySession, isNull);
    expect(store.activeStudySessionFor(_user.id), isNotNull);
    expect(store.activeStudySessionFor(_otherUser.id), isNull);
  });

  test('sign out clears the current user snapshot', () async {
    final store = MemoryAppPreferencesStore();
    final state = _state(store);
    await state.loadSyncedWorkspaceFor(_user);
    _create(state);
    await state.studySessionPersistenceIdle;

    state.clearSyncedWorkspaceForSignOut();
    await state.studySessionPersistenceIdle;

    expect(state.latestStudySession, isNull);
    expect(store.activeStudySessionFor(_user.id), isNull);
  });

  test('deleting the source material invalidates the snapshot', () async {
    final store = MemoryAppPreferencesStore();
    final state = _state(store);
    await state.loadSyncedWorkspaceFor(_user);
    _create(state);
    await state.studySessionPersistenceIdle;

    expect(await state.deleteMaterialFor(_user, _material.id), isTrue);
    await state.studySessionPersistenceIdle;

    expect(store.activeStudySessionFor(_user.id), isNull);
    expect(state.latestStudySession?.materialId, isNot(_material.id));
  });

  test('corrupt and old schemas are discarded safely', () async {
    for (final snapshot in [
      '{not-json',
      jsonEncode({
        'version': 0,
        'session_type': 'material_review',
        'session_id': 'local-session-1',
        'subject_id': _subject.id,
        'material_id': _material.id,
        'confidence': 'mostly',
        'current_item_index': 0,
        'completed_item_ids': <String>[],
        'selected_answer': null,
        'quiz_score_percent': null,
        'updated_at': DateTime.utc(2026).toIso8601String(),
      }),
    ]) {
      final store = MemoryAppPreferencesStore(
        activeStudySessions: {_user.id: snapshot},
      );
      final state = _state(store);

      await state.loadSyncedWorkspaceFor(_user);
      await state.studySessionRestorationIdle;
      await state.studySessionPersistenceIdle;

      expect(state.latestStudySession, isNull);
      expect(store.activeStudySessionFor(_user.id), isNull);
    }
  });

  test('answering twice replaces progress without double scoring', () async {
    final store = MemoryAppPreferencesStore();
    final state = _state(store);
    await state.loadSyncedWorkspaceFor(_user);
    final session = _create(state);
    final correct = session.quizQuestion.correctAnswer;

    state.answerQuiz(sessionId: session.id, answer: correct);
    state.answerQuiz(sessionId: session.id, answer: correct);
    await state.studySessionPersistenceIdle;

    expect(state.latestStudySession?.quizScorePercent, 100);
    expect(state.latestStudySession?.completedItemIds, ['quick_quiz']);
    expect(state.latestStudySession?.currentItemIndex, 1);
  });
}

AppState _state(MemoryAppPreferencesStore store) => AppState(
  preferencesStore: store,
  subjectRepository: MockSubjectRepository(initialSubjects: const [_subject]),
  materialRepository: MockMaterialRepository(
    initialMaterials: const [_material],
  ),
);

StudySession _create(AppState state) => state.createStudySession(
  subject: _subject,
  confidence: LectureConfidence.mostly,
  materialId: _material.id,
)!;
