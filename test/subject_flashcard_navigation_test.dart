import 'package:ai_study_buddy/app/app_config.dart';
import 'package:ai_study_buddy/app/app_state.dart';
import 'package:ai_study_buddy/app/routes.dart';
import 'package:ai_study_buddy/core/models/material.dart';
import 'package:ai_study_buddy/core/models/subject.dart';
import 'package:ai_study_buddy/features/auth/auth_controller.dart';
import 'package:ai_study_buddy/features/auth/auth_models.dart';
import 'package:ai_study_buddy/features/auth/auth_repository.dart';
import 'package:ai_study_buddy/features/materials/material_repository.dart';
import 'package:ai_study_buddy/features/subjects/subject_detail_screen.dart';
import 'package:ai_study_buddy/features/subjects/subject_repository.dart';
import 'package:ai_study_buddy/l10n/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('subject flashcards action selects and opens the exact material', (
    tester,
  ) async {
    const user = AuthUser(id: 'user-1', email: 'student@example.test');
    const subject = Subject(
      id: 'subject-1',
      name: 'Physics',
      description: '',
      colorValue: 0xFF2563EB,
    );
    const material = StudyMaterial(
      id: 'material-1',
      subjectId: 'subject-1',
      title: 'Lecture A',
      kind: MaterialKind.pastedText,
      content:
          'Material-specific authoritative content long enough for flashcards.',
      createdLabel: 'Today',
    );
    final state = AppState(
      config: const AppConfig(
        backendMode: AppBackendMode.supabase,
        supabaseUrl: 'https://example.supabase.co',
        supabaseAnonKey: 'sb_publishable_test-client-key',
      ),
      subjectRepository: MockSubjectRepository(
        initialSubjects: const [subject],
      ),
      materialRepository: MockMaterialRepository(
        initialMaterials: const [material],
      ),
    );
    await state.loadSubjectsFor(user);
    await state.loadMaterialsFor(user);
    final auth = AuthController(
      authRepository: MockAuthRepository(initialUser: user),
      profileRepository: NoopProfileRepository(),
    );
    await auth.initialize();
    RouteSettings? opened;
    addTearDown(state.dispose);
    addTearDown(auth.dispose);

    await tester.pumpWidget(
      AppStateScope(
        state: state,
        child: AuthScope(
          controller: auth,
          child: MaterialApp(
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: const SubjectDetailScreen(subject: subject),
            onGenerateRoute: (settings) {
              opened = settings;
              return MaterialPageRoute<void>(
                settings: settings,
                builder: (_) => const Scaffold(body: Text('destination')),
              );
            },
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(
      find.byKey(const ValueKey('subject-open-flashcards')),
      300,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.tap(find.byKey(const ValueKey('subject-open-flashcards')));
    await tester.pumpAndSettle();
    expect(find.text('Choose material'), findsOneWidget);
    await tester.tap(find.text('Lecture A').last);
    await tester.pumpAndSettle();

    expect(opened?.name, AppRoutes.materialDetail);
    expect(opened?.arguments, same(material));
    expect(find.text('destination'), findsOneWidget);
  });
}
