import 'package:flutter/material.dart';

import '../core/models/flashcard.dart';
import '../core/models/material.dart';
import '../core/models/study_session.dart';
import '../core/models/study_time_block.dart';
import '../core/models/subject.dart';
import '../core/models/weak_topic.dart';
import '../mock/mock_ai_service.dart';
import '../mock/mock_data.dart';

class AppState extends ChangeNotifier {
  AppState()
    : subjects = List<Subject>.of(MockData.subjects),
      _materials = List<StudyMaterial>.of(MockData.materials),
      _flashcards = List<Flashcard>.of(MockData.flashcards);

  static const _ai = MockAiService();

  final List<Subject> subjects;
  final List<StudyMaterial> _materials;
  List<Flashcard> _flashcards;
  final List<StudySession> _studySessions = [];
  int _materialCounter = 0;
  int _sessionCounter = 0;

  List<StudyMaterial> materialsFor(String subjectId) {
    return _materials
        .where((material) => material.subjectId == subjectId)
        .toList();
  }

  StudyMaterial? materialById(String materialId) {
    for (final material in _materials) {
      if (material.id == materialId) {
        return material;
      }
    }
    return null;
  }

  Subject subjectFor(String subjectId) {
    return _subjectFor(subjectId);
  }

  List<Flashcard> flashcardsFor(String subjectId) {
    return _flashcards
        .where((flashcard) => flashcard.subjectId == subjectId)
        .toList();
  }

  List<Flashcard> get favoriteFlashcards {
    return _flashcards.where((flashcard) => flashcard.isFavorite).toList();
  }

  StudySession? get latestStudySession {
    if (_studySessions.isEmpty) {
      return null;
    }
    return _studySessions.last;
  }

  StudySession? sessionFor(String sessionId) {
    for (final session in _studySessions.reversed) {
      if (session.id == sessionId) {
        return session;
      }
    }
    return null;
  }

  List<WeakTopic> weakTopicsFor(String subjectId) {
    final session = latestStudySession;
    if (session != null && session.subjectId == subjectId) {
      return session.weakTopics;
    }
    return _ai.weakTopicsFor(_subjectFor(subjectId));
  }

  List<Flashcard> get dueFlashcards {
    final session = latestStudySession;
    if (session != null) {
      return session.flashcards;
    }
    return flashcardsFor(subjects.first.id);
  }

  List<LocalSearchResult> search(String query) {
    final normalized = query.trim().toLowerCase();
    if (normalized.isEmpty) {
      return const [];
    }

    final results = <LocalSearchResult>[];
    for (final subject in subjects) {
      if (subject.name.toLowerCase().contains(normalized)) {
        results.add(
          LocalSearchResult(
            kind: LocalSearchResultKind.subject,
            title: subject.name,
            subtitle: subject.description,
            subject: subject,
          ),
        );
      }
    }
    for (final material in _materials) {
      if (material.title.toLowerCase().contains(normalized)) {
        final subject = _subjectFor(material.subjectId);
        results.add(
          LocalSearchResult(
            kind: LocalSearchResultKind.material,
            title: material.title,
            subtitle: '${subject.name} - ${material.createdLabel}',
            subject: subject,
            material: material,
          ),
        );
      }
    }
    for (final card in _flashcards) {
      if (card.front.toLowerCase().contains(normalized)) {
        final subject = _subjectFor(card.subjectId);
        results.add(
          LocalSearchResult(
            kind: LocalSearchResultKind.flashcard,
            title: card.front,
            subtitle: '${subject.name} flashcard - ${card.topic}',
            subject: subject,
          ),
        );
      }
    }
    return results;
  }

  void addMaterial({
    required String subjectId,
    required String title,
    required String content,
  }) {
    final cleanTitle = title.trim();
    final cleanContent = content.trim();
    if (cleanTitle.isEmpty || cleanContent.isEmpty) {
      return;
    }

    _materialCounter += 1;
    _materials.insert(
      0,
      StudyMaterial(
        id: 'local-material-$_materialCounter',
        subjectId: subjectId,
        title: cleanTitle,
        kind: MaterialKind.pastedText,
        content: cleanContent,
        createdLabel: 'Just now',
      ),
    );
    notifyListeners();
  }

  void toggleFavorite(String cardId) {
    _flashcards = [
      for (final card in _flashcards)
        card.id == cardId ? card.copyWith(isFavorite: !card.isFavorite) : card,
    ];
    notifyListeners();
  }

  StudySession createStudySession({
    required Subject subject,
    required LectureConfidence confidence,
    String? materialId,
  }) {
    final materials = materialsFor(subject.id);
    final selectedMaterialId = materialId ?? materials.firstOrNull?.id ?? '';
    final question = _ai.quizFor(subject).first;
    final session = StudySession(
      id: 'local-session-${++_sessionCounter}',
      subjectId: subject.id,
      materialId: selectedMaterialId,
      confidence: confidence,
      summary: _summaryFor(subject, confidence),
      studyTimeBlocks: _timeBlocksFor(confidence),
      flashcards: _cardsFor(subject, confidence),
      quizQuestion: question,
      weakTopics: _initialWeakTopicsFor(subject, confidence),
    );
    _studySessions.add(session);
    notifyListeners();
    return session;
  }

  void answerQuiz({required String sessionId, required String answer}) {
    final index = _studySessions.indexWhere(
      (session) => session.id == sessionId,
    );
    if (index == -1) {
      return;
    }

    final session = _studySessions[index];
    final isCorrect = answer == session.quizQuestion.correctAnswer;
    final subject = _subjectFor(session.subjectId);
    final updatedWeakTopics = isCorrect
        ? _ai.weakTopicsFor(subject).take(1).toList()
        : [
            WeakTopic(
              subjectId: subject.id,
              title: session.flashcards.firstOrNull?.topic ?? 'Quick quiz',
              reason:
                  'You chose "$answer"; review why "${session.quizQuestion.correctAnswer}" is correct.',
            ),
            ..._ai.weakTopicsFor(subject).take(2),
          ];

    _studySessions[index] = session.copyWith(
      selectedAnswer: answer,
      quizScorePercent: isCorrect ? 100 : 0,
      weakTopics: updatedWeakTopics,
      feedback: isCorrect
          ? 'Correct. This topic is ready for a lighter review.'
          : 'Incorrect. Review the explanation, then retry the flashcards.',
    );
    notifyListeners();
  }

  Subject _subjectFor(String subjectId) {
    return subjects.firstWhere(
      (subject) => subject.id == subjectId,
      orElse: () => subjects.first,
    );
  }

  String _summaryFor(Subject subject, LectureConfidence confidence) {
    final base = _ai.summaryFor(subject);
    return switch (confidence) {
      LectureConfidence.understoodEverything =>
        'Short review: $base Focus on one quick check and move on.',
      LectureConfidence.mostly =>
        'Normal review: $base Use flashcards, then answer the quick quiz.',
      LectureConfidence.aboutHalf =>
        'Practice review: $base Spend extra time on flashcards and quiz choices.',
      LectureConfidence.completelyLost =>
        'Simple explanation: start with the main idea in ${subject.name}, then connect one example before adding details. Take the longer guided review.',
    };
  }

  List<StudyTimeBlock> _timeBlocksFor(LectureConfidence confidence) {
    return switch (confidence) {
      LectureConfidence.understoodEverything => const [
        StudyTimeBlock(label: 'Summary', minutes: 3),
        StudyTimeBlock(label: 'Flashcards', minutes: 5),
        StudyTimeBlock(label: 'Quiz', minutes: 4),
      ],
      LectureConfidence.mostly => MockData.studyTimeBlocks,
      LectureConfidence.aboutHalf => const [
        StudyTimeBlock(label: 'Summary', minutes: 6),
        StudyTimeBlock(label: 'Flashcards', minutes: 14),
        StudyTimeBlock(label: 'Quiz', minutes: 10),
        StudyTimeBlock(label: 'Review mistakes', minutes: 8),
      ],
      LectureConfidence.completelyLost => const [
        StudyTimeBlock(label: 'Simple explanation', minutes: 10),
        StudyTimeBlock(label: 'Guided flashcards', minutes: 15),
        StudyTimeBlock(label: 'Quick quiz', minutes: 10),
        StudyTimeBlock(label: 'Review mistakes', minutes: 10),
      ],
    };
  }

  List<Flashcard> _cardsFor(Subject subject, LectureConfidence confidence) {
    final cards = flashcardsFor(subject.id);
    if (confidence == LectureConfidence.understoodEverything) {
      return cards.take(1).toList();
    }
    if (confidence == LectureConfidence.aboutHalf ||
        confidence == LectureConfidence.completelyLost) {
      return [...cards, ...cards.take(1)];
    }
    return cards;
  }

  List<WeakTopic> _initialWeakTopicsFor(
    Subject subject,
    LectureConfidence confidence,
  ) {
    final topics = _ai.weakTopicsFor(subject);
    if (confidence == LectureConfidence.understoodEverything) {
      return topics.take(1).toList();
    }
    if (confidence == LectureConfidence.completelyLost) {
      return [
        WeakTopic(
          subjectId: subject.id,
          title: 'Core idea',
          reason: 'Start with a simpler explanation before practicing details.',
        ),
        ...topics,
      ];
    }
    return topics;
  }
}

enum LocalSearchResultKind { subject, material, flashcard }

class LocalSearchResult {
  const LocalSearchResult({
    required this.kind,
    required this.title,
    required this.subtitle,
    required this.subject,
    this.material,
  });

  final LocalSearchResultKind kind;
  final String title;
  final String subtitle;
  final Subject subject;
  final StudyMaterial? material;
}

class AppStateScope extends InheritedNotifier<AppState> {
  const AppStateScope({
    required AppState state,
    required super.child,
    super.key,
  }) : super(notifier: state);

  static AppState watch(BuildContext context) {
    final scope = context.dependOnInheritedWidgetOfExactType<AppStateScope>();
    assert(scope != null, 'No AppStateScope found in context.');
    return scope!.notifier!;
  }

  static AppState read(BuildContext context) {
    final element = context
        .getElementForInheritedWidgetOfExactType<AppStateScope>();
    final scope = element?.widget as AppStateScope?;
    assert(scope != null, 'No AppStateScope found in context.');
    return scope!.notifier!;
  }
}
