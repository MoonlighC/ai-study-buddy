import 'package:flutter/material.dart';

import '../core/models/material.dart';
import '../core/models/subject.dart';
import '../features/auth/auth_gate_screen.dart';
import '../features/auth/login_screen.dart';
import '../features/auth/signup_screen.dart';
import '../features/dashboard/dashboard_screen.dart';
import '../features/favorites/favorites_screen.dart';
import '../features/flashcards/flashcards_screen.dart';
import '../features/generation/generated_outputs_screen.dart';
import '../features/materials/add_material_screen.dart';
import '../features/materials/material_detail_screen.dart';
import '../features/progress/progress_screen.dart';
import '../features/search/search_screen.dart';
import '../features/settings/settings_screen.dart';
import '../features/study_modes/after_lecture_screen.dart';
import '../features/study_modes/exam_prep_screen.dart';
import '../features/study_sessions/ai_teacher_screen.dart';
import '../features/study_sessions/continue_studying_screen.dart';
import '../features/study_sessions/study_session_result_screen.dart';
import '../features/subjects/subject_detail_screen.dart';
import '../features/subjects/subjects_screen.dart';
import '../features/usage/usage_limits_screen.dart';

class AppRoutes {
  static const authGate = '/auth';
  static const login = '/';
  static const signup = '/signup';
  static const dashboard = '/dashboard';
  static const subjects = '/subjects';
  static const subjectDetail = '/subjects/detail';
  static const addMaterial = '/materials/add';
  static const materialDetail = '/materials/detail';
  static const generatedOutputs = '/generation/outputs';
  static const flashcards = '/flashcards';
  static const favorites = '/favorites';
  static const afterLecture = '/study/after-lecture';
  static const examPrep = '/study/exam-prep';
  static const continueStudying = '/study/continue';
  static const studySessionResult = '/study/session-result';
  static const aiTeacher = '/study/ai-teacher';
  static const progress = '/progress';
  static const usage = '/usage';
  static const search = '/search';
  static const settings = '/settings';
  static const _fallbackSubject = Subject(
    id: 'missing-subject',
    name: 'Subject',
    description: 'Subject unavailable.',
    colorValue: 0xFF64748B,
  );
  static const _fallbackMaterial = StudyMaterial(
    id: 'missing-material',
    subjectId: 'missing-subject',
    title: 'Material unavailable',
    kind: MaterialKind.pastedText,
    content: '',
    createdLabel: 'Not synced',
  );

  static Route<void> onGenerateRoute(RouteSettings routeSettings) {
    final subject = routeSettings.arguments is Subject
        ? routeSettings.arguments! as Subject
        : _fallbackSubject;
    final material = routeSettings.arguments is StudyMaterial
        ? routeSettings.arguments! as StudyMaterial
        : _fallbackMaterial;

    final widget = switch (routeSettings.name) {
      authGate => const AuthGateScreen(),
      login => const LoginScreen(),
      signup => const SignupScreen(),
      dashboard => const DashboardScreen(),
      subjects => const SubjectsScreen(),
      subjectDetail => SubjectDetailScreen(subject: subject),
      addMaterial => AddMaterialScreen(subject: subject),
      materialDetail => MaterialDetailScreen(material: material),
      generatedOutputs => GeneratedOutputsScreen(subject: subject),
      flashcards => FlashcardsScreen(subject: subject),
      favorites => const FavoritesScreen(),
      afterLecture => const AfterLectureScreen(),
      examPrep => const ExamPrepScreen(),
      continueStudying => const ContinueStudyingScreen(),
      studySessionResult => StudySessionResultScreen(subject: subject),
      aiTeacher => AiTeacherScreen(subject: subject),
      progress => const ProgressScreen(),
      usage => const UsageLimitsScreen(),
      search => const SearchScreen(),
      settings => const SettingsScreen(),
      _ => const LoginScreen(),
    };

    return MaterialPageRoute<void>(
      builder: (_) => widget,
      settings: routeSettings,
    );
  }
}
