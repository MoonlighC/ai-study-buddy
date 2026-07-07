import 'package:ai_study_buddy/app/app.dart';
import 'package:ai_study_buddy/app/app_config.dart';
import 'package:ai_study_buddy/app/routes.dart';
import 'package:ai_study_buddy/features/auth/auth_models.dart';
import 'package:ai_study_buddy/features/auth/auth_repository.dart';
import 'package:ai_study_buddy/mock/mock_data.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('shows login shell and enters dashboard', (tester) async {
    await tester.pumpWidget(const StudyBuddyApp());
    await tester.pumpAndSettle();

    expect(find.text('AI Study Buddy'), findsOneWidget);
    expect(find.text('Continue with email'), findsOneWidget);
    expect(find.text('Google coming later'), findsOneWidget);
    expect(find.text('Apple coming later'), findsOneWidget);

    await tester.tap(find.text('Continue with email'));
    await tester.pumpAndSettle();

    expect(find.text('What do you want to do today?'), findsOneWidget);
    expect(find.text('After Lecture'), findsOneWidget);
    expect(find.text('Prepare for Exam'), findsOneWidget);
    expect(find.text('Continue Studying'), findsOneWidget);
  });

  testWidgets('adds pasted material to subject detail', (tester) async {
    await _enterDashboard(tester);

    await _pushRoute(
      tester,
      AppRoutes.subjectDetail,
      arguments: MockData.subjects.first,
    );
    await tester.tap(find.text('Add pasted text'));
    await tester.pumpAndSettle();

    await tester.enterText(
      find.widgetWithText(TextField, 'Material title'),
      'Cell respiration notes',
    );
    await tester.enterText(
      find.widgetWithText(TextField, 'Paste lecture text'),
      'Cells release energy from glucose during respiration.',
    );
    await tester.tap(find.text('Save mock material'));
    await tester.pumpAndSettle();
    await tester.pump(const Duration(seconds: 4));
    await tester.pumpAndSettle();

    expect(find.text('Cell respiration notes'), findsOneWidget);
    expect(find.text('Just now - pasted text'), findsOneWidget);

    await tester.tap(find.text('Cell respiration notes'));
    await tester.pumpAndSettle();

    expect(find.text('Pasted text'), findsOneWidget);
    expect(
      find.text('Cells release energy from glucose during respiration.'),
      findsOneWidget,
    );
    expect(
      find.text(
        'Real AI generation from this material will be connected later.',
      ),
      findsOneWidget,
    );
  });

  testWidgets('favorite toggle updates favorites screen', (tester) async {
    await _enterDashboard(tester);
    await _pushRoute(
      tester,
      AppRoutes.flashcards,
      arguments: MockData.subjects.first,
    );

    await tester.tap(find.byTooltip('Favorite').first);
    await tester.pumpAndSettle();
    await _pushRoute(tester, AppRoutes.favorites);

    expect(find.text('Where does photosynthesis happen?'), findsOneWidget);
  });

  testWidgets('favorites can unfavorite and remove a card', (tester) async {
    await _enterDashboard(tester);
    await _pushRoute(tester, AppRoutes.favorites);

    expect(find.text('What is photosynthesis?'), findsOneWidget);

    final favoriteTile = find.ancestor(
      of: find.text('What is photosynthesis?'),
      matching: find.byType(ListTile),
    );
    await tester.tap(
      find.descendant(of: favoriteTile, matching: find.byTooltip('Unfavorite')),
    );
    await tester.pumpAndSettle();

    expect(find.text('What is photosynthesis?'), findsNothing);
  });

  testWidgets('material detail creates a source-specific study session', (
    tester,
  ) async {
    await _enterDashboard(tester);
    await _pushRoute(
      tester,
      AppRoutes.materialDetail,
      arguments: MockData.materials.first,
    );

    expect(find.text('Photosynthesis lecture notes'), findsOneWidget);
    expect(
      find.text(
        'Plants convert light, water, and carbon dioxide into glucose.',
      ),
      findsOneWidget,
    );
    expect(
      find.text(
        'Real AI generation from this material will be connected later.',
      ),
      findsOneWidget,
    );

    await tester.tap(find.text('Create study session'));
    await tester.pumpAndSettle();

    expect(find.text('Study Session'), findsOneWidget);
    expect(
      find.text('Generated from: Photosynthesis lecture notes'),
      findsOneWidget,
    );
    expect(find.textContaining('Normal review'), findsOneWidget);
    expect(
      find.textContaining('Source "Photosynthesis lecture notes" says'),
      findsOneWidget,
    );
    await _scrollTo(
      tester,
      find.text('Which source did this study session use?'),
    );
    expect(
      find.text('Which source did this study session use?'),
      findsOneWidget,
    );
  });

  testWidgets('bottom navigation opens core routes', (tester) async {
    await _enterDashboard(tester);

    await tester.tap(find.text('Subjects').last);
    await tester.pumpAndSettle();

    expect(find.text('Study Workspace'), findsOneWidget);

    await tester.tap(find.text('Progress').last);
    await tester.pumpAndSettle();

    expect(find.text('Knowledge scores'), findsOneWidget);

    await tester.tap(find.text('Settings').last);
    await tester.pumpAndSettle();

    expect(
      find.text('Mock preferences for the local prototype.'),
      findsOneWidget,
    );
  });

  testWidgets('settings renders required mock sections and planned limits', (
    tester,
  ) async {
    await _enterDashboard(tester);
    await _pushRoute(tester, AppRoutes.settings);

    expect(find.text('Account'), findsOneWidget);
    expect(find.text('Alex Student'), findsOneWidget);
    expect(find.text('Edit name'), findsNothing);
    expect(find.text('Language'), findsOneWidget);
    expect(find.text('System default'), findsOneWidget);

    await _scrollTo(tester, find.text('Study Preferences'));

    expect(find.text('Study Preferences'), findsOneWidget);

    await _scrollTo(tester, find.text('Usage & Limits'));

    expect(find.text('120/day'), findsOneWidget);
    expect(find.text('80/day'), findsOneWidget);
    expect(find.text('3/day'), findsOneWidget);
    expect(find.text(r'$0.25/day'), findsOneWidget);

    await _scrollTo(tester, find.text('Support'));

    expect(find.text('Report a bug placeholder'), findsOneWidget);
    expect(find.text('Contact support placeholder'), findsOneWidget);
    expect(find.text('Send feedback placeholder'), findsOneWidget);

    await _scrollTo(tester, find.text('About / Debug'));

    expect(find.text('0.1.0 placeholder'), findsOneWidget);
    expect(find.text('mock'), findsOneWidget);
    expect(
      find.text('No server secrets or OpenAI key in Flutter.'),
      findsOneWidget,
    );
  });

  testWidgets(
    'settings updates local preferences and flashcards default size',
    (tester) async {
      await _enterDashboard(tester);
      await _pushRoute(tester, AppRoutes.settings);

      await tester.tap(find.text('Deutsch'));
      await tester.pumpAndSettle();
      _expectChoiceSelected(tester, 'Deutsch');

      await _scrollTo(tester, find.text('Default flashcard session size'));
      await tester.tap(find.widgetWithText(ChoiceChip, '10'));
      await tester.pumpAndSettle();
      _expectChoiceSelected(tester, '10');

      await _scrollTo(tester, find.text('Daily study goal'));
      await tester.tap(find.text('30 min'));
      await tester.pumpAndSettle();
      _expectChoiceSelected(tester, '30 min');

      await _scrollTo(tester, find.text('Default difficulty'));
      await tester.tap(find.text('exam'));
      await tester.pumpAndSettle();
      _expectChoiceSelected(tester, 'exam');

      await _pushRoute(
        tester,
        AppRoutes.flashcards,
        arguments: MockData.subjects.first,
      );

      _expectChoiceSelected(tester, '10');
    },
  );

  testWidgets('mock settings logout returns to login screen', (tester) async {
    await _enterDashboard(tester);
    await _pushRoute(tester, AppRoutes.settings);

    await tester.tap(find.text('Log out'));
    await tester.pumpAndSettle();

    expect(find.text('Continue with email'), findsOneWidget);
    expect(find.text('What do you want to do today?'), findsNothing);
  });

  testWidgets('supabase auth UI renders email form and placeholders', (
    tester,
  ) async {
    await tester.pumpWidget(
      StudyBuddyApp(
        config: _supabaseConfig(),
        authRepository: _RecordingAuthRepository(),
        profileRepository: _RecordingProfileRepository(),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Email'), findsOneWidget);
    expect(find.text('Password'), findsOneWidget);
    expect(find.text('Log in'), findsOneWidget);
    expect(find.text('Create account'), findsOneWidget);
    expect(find.text('Forgot password?'), findsOneWidget);
    expect(find.text('Continue with email'), findsNothing);
    expect(find.text('Google coming later'), findsOneWidget);
    expect(find.text('Apple coming later'), findsOneWidget);
  });

  testWidgets('supabase login Create account navigates to signup', (
    tester,
  ) async {
    await tester.pumpWidget(
      StudyBuddyApp(
        config: _supabaseConfig(),
        authRepository: _RecordingAuthRepository(),
        profileRepository: _RecordingProfileRepository(),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.widgetWithText(OutlinedButton, 'Create account'));
    await tester.pumpAndSettle();

    expect(find.text('Set up your study profile.'), findsOneWidget);
    expect(find.text('Name'), findsOneWidget);
    expect(find.text('Email'), findsOneWidget);
    expect(find.text('Password'), findsOneWidget);
  });

  testWidgets('signup screen renders name email and password fields', (
    tester,
  ) async {
    await tester.pumpWidget(
      StudyBuddyApp(
        config: _supabaseConfig(),
        authRepository: _RecordingAuthRepository(),
        profileRepository: _RecordingProfileRepository(),
      ),
    );
    await tester.pumpAndSettle();
    await _pushRoute(tester, AppRoutes.signup);

    expect(find.text('Create account'), findsWidgets);
    expect(find.text('Name'), findsOneWidget);
    expect(find.text('Email'), findsOneWidget);
    expect(find.text('Password'), findsOneWidget);
  });

  testWidgets('signup missing name prevents repository call', (tester) async {
    final authRepository = _RecordingAuthRepository();

    await tester.pumpWidget(
      StudyBuddyApp(
        config: _supabaseConfig(),
        authRepository: authRepository,
        profileRepository: _RecordingProfileRepository(),
      ),
    );
    await tester.pumpAndSettle();
    await _pushRoute(tester, AppRoutes.signup);

    await tester.enterText(
      find.widgetWithText(TextField, 'Email'),
      'casey@example.test',
    );
    await tester.enterText(
      find.widgetWithText(TextField, 'Password'),
      'secret1',
    );
    await tester.tap(find.widgetWithText(FilledButton, 'Create account'));
    await tester.pumpAndSettle();

    expect(find.text('Enter your name.'), findsOneWidget);
    expect(authRepository.signUpCount, 0);
  });

  testWidgets('signup forwards display name and ensures profile with it', (
    tester,
  ) async {
    final authRepository = _RecordingAuthRepository();
    final profileRepository = _RecordingProfileRepository();

    await tester.pumpWidget(
      StudyBuddyApp(
        config: _supabaseConfig(),
        authRepository: authRepository,
        profileRepository: profileRepository,
      ),
    );
    await tester.pumpAndSettle();
    await _pushRoute(tester, AppRoutes.signup);

    await tester.enterText(
      find.widgetWithText(TextField, 'Name'),
      'Casey Student',
    );
    await tester.enterText(
      find.widgetWithText(TextField, 'Email'),
      'casey@example.test',
    );
    await tester.enterText(
      find.widgetWithText(TextField, 'Password'),
      'secret1',
    );
    await tester.tap(find.widgetWithText(FilledButton, 'Create account'));
    await tester.pumpAndSettle();

    expect(authRepository.signUpDisplayNames, ['Casey Student']);
    expect(profileRepository.ensuredUsers.single.displayName, 'Casey Student');
    expect(find.text('What do you want to do today?'), findsOneWidget);
  });

  testWidgets('supabase settings shows profile display name', (tester) async {
    await tester.pumpWidget(
      StudyBuddyApp(
        config: _supabaseConfig(),
        authRepository: _RecordingAuthRepository(
          initialUser: const AuthUser(
            id: 'supabase-user',
            email: 'learner@example.test',
            displayName: 'Metadata Learner',
          ),
        ),
        profileRepository: _RecordingProfileRepository(
          profile: const AuthProfile(
            id: 'supabase-user',
            email: 'learner@example.test',
            displayName: 'Profile Learner',
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await _pushRoute(tester, AppRoutes.settings);

    expect(find.text('Profile Learner'), findsOneWidget);
    expect(find.text('Metadata Learner'), findsNothing);
    expect(find.text('learner@example.test'), findsOneWidget);
  });

  testWidgets('edit name dialog rejects blank value', (tester) async {
    final profileRepository = _RecordingProfileRepository(
      profile: const AuthProfile(
        id: 'supabase-user',
        email: 'learner@example.test',
        displayName: 'Profile Learner',
      ),
    );

    await tester.pumpWidget(
      StudyBuddyApp(
        config: _supabaseConfig(),
        authRepository: _RecordingAuthRepository(
          initialUser: const AuthUser(
            id: 'supabase-user',
            email: 'learner@example.test',
            displayName: 'Metadata Learner',
          ),
        ),
        profileRepository: profileRepository,
      ),
    );
    await tester.pumpAndSettle();
    await _pushRoute(tester, AppRoutes.settings);

    await tester.tap(find.text('Edit name'));
    await tester.pumpAndSettle();
    await tester.enterText(find.widgetWithText(TextField, 'Name'), '   ');
    await tester.tap(find.widgetWithText(FilledButton, 'Save'));
    await tester.pumpAndSettle();

    expect(find.text('Enter your name.'), findsOneWidget);
    expect(profileRepository.updatedDisplayNames, isEmpty);
  });

  testWidgets('edit name saves and updates visible Account name', (
    tester,
  ) async {
    final profileRepository = _RecordingProfileRepository(
      profile: const AuthProfile(
        id: 'supabase-user',
        email: 'learner@example.test',
        displayName: 'Profile Learner',
      ),
    );

    await tester.pumpWidget(
      StudyBuddyApp(
        config: _supabaseConfig(),
        authRepository: _RecordingAuthRepository(
          initialUser: const AuthUser(
            id: 'supabase-user',
            email: 'learner@example.test',
            displayName: 'Metadata Learner',
          ),
        ),
        profileRepository: profileRepository,
      ),
    );
    await tester.pumpAndSettle();
    await _pushRoute(tester, AppRoutes.settings);

    await tester.tap(find.text('Edit name'));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.widgetWithText(TextField, 'Name'),
      'Updated Learner',
    );
    await tester.tap(find.widgetWithText(FilledButton, 'Save'));
    await tester.pumpAndSettle();

    expect(profileRepository.updatedDisplayNames, ['Updated Learner']);
    expect(find.text('Updated Learner'), findsOneWidget);
    expect(find.text('Profile Learner'), findsNothing);
  });

  testWidgets('supabase settings logout calls auth repository', (tester) async {
    final authRepository = _RecordingAuthRepository(
      initialUser: const AuthUser(
        id: 'supabase-user',
        email: 'learner@example.test',
      ),
    );

    await tester.pumpWidget(
      StudyBuddyApp(
        config: _supabaseConfig(),
        authRepository: authRepository,
        profileRepository: _RecordingProfileRepository(),
      ),
    );
    await tester.pumpAndSettle();
    await _pushRoute(tester, AppRoutes.settings);

    expect(find.text('learner@example.test'), findsOneWidget);

    await tester.tap(find.text('Log out'));
    await tester.pumpAndSettle();

    expect(authRepository.signOutCount, 1);
    expect(find.text('Log in'), findsOneWidget);
    expect(find.text('What do you want to do today?'), findsNothing);
  });

  testWidgets('top quick actions open search and home', (tester) async {
    await _enterDashboard(tester);
    await _pushRoute(
      tester,
      AppRoutes.subjectDetail,
      arguments: MockData.subjects.first,
    );

    await tester.tap(find.byTooltip('Search'));
    await tester.pumpAndSettle();

    expect(find.text('Search'), findsOneWidget);

    await tester.tap(find.byIcon(Icons.home_outlined).first);
    await tester.pumpAndSettle();

    expect(find.text('What do you want to do today?'), findsOneWidget);
  });

  testWidgets('scenario screens expose shared navigation actions', (
    tester,
  ) async {
    await _enterDashboard(tester);
    await _pushRoute(tester, AppRoutes.afterLecture);

    expect(find.byTooltip('Search'), findsOneWidget);
    expect(find.byTooltip('Favorites'), findsWidgets);
    expect(find.byTooltip('Home'), findsWidgets);
    expect(find.text('Subjects'), findsOneWidget);

    await _pushRoute(tester, AppRoutes.examPrep);

    expect(find.byTooltip('Search'), findsOneWidget);
    expect(find.byTooltip('Favorites'), findsWidgets);
    expect(find.byTooltip('Home'), findsWidgets);
    expect(find.text('Progress'), findsOneWidget);
  });

  testWidgets('local search finds material and opens detail', (tester) async {
    await _enterDashboard(tester);

    await tester.tap(find.byTooltip('Search'));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.widgetWithText(TextField, 'Search study workspace'),
      'Photosynthesis',
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('Photosynthesis lecture notes'));
    await tester.pumpAndSettle();

    expect(find.text('Pasted text'), findsOneWidget);
    expect(
      find.text(
        'Plants convert light, water, and carbon dioxide into glucose.',
      ),
      findsOneWidget,
    );
  });

  testWidgets('after lecture creates local session and quiz result', (
    tester,
  ) async {
    await _enterDashboard(tester);

    await _pushRoute(tester, AppRoutes.afterLecture);
    await _tapVisible(tester, find.text('I am completely lost'));
    await tester.pumpAndSettle();
    await _tapVisible(tester, find.text('Create study session'));
    await tester.pumpAndSettle();

    expect(find.textContaining('Simple explanation'), findsWidgets);
    expect(find.text('45 min'), findsOneWidget);

    await _scrollTo(tester, find.text('A generic Biology fallback'));
    await tester.tap(find.text('A generic Biology fallback'));
    await tester.pumpAndSettle();

    expect(find.text('A generic Biology fallback - incorrect'), findsOneWidget);
    expect(
      find.text(
        'Incorrect. Review the explanation, then retry the flashcards.',
      ),
      findsOneWidget,
    );
    expect(
      find.textContaining('You chose "A generic Biology fallback"'),
      findsOneWidget,
    );
  });

  testWidgets('continue studying reads latest local session', (tester) async {
    await _enterDashboard(tester);

    await _pushRoute(tester, AppRoutes.afterLecture);
    await _tapVisible(tester, find.text('I am completely lost'));
    await tester.pumpAndSettle();
    await _tapVisible(tester, find.text('Create study session'));
    await tester.pumpAndSettle();
    await _scrollTo(tester, find.text('A generic Biology fallback'));
    await tester.tap(find.text('A generic Biology fallback'));
    await tester.pumpAndSettle();

    await _pushRoute(tester, AppRoutes.continueStudying);

    expect(find.text('Biology review'), findsOneWidget);
    expect(find.textContaining('Simple explanation'), findsOneWidget);
    expect(find.text('Biology quick quiz: 0%'), findsOneWidget);
  });
}

Future<void> _enterDashboard(WidgetTester tester) async {
  await tester.pumpWidget(const StudyBuddyApp());
  await tester.pumpAndSettle();
  await tester.tap(find.text('Continue with email'));
  await tester.pumpAndSettle();
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

Future<void> _tapVisible(WidgetTester tester, Finder finder) async {
  await tester.ensureVisible(finder);
  await tester.pumpAndSettle();
  await tester.tap(finder);
}

Future<void> _scrollTo(WidgetTester tester, Finder finder) async {
  await tester.scrollUntilVisible(
    finder,
    240,
    scrollable: find.byType(Scrollable).last,
  );
  await tester.pumpAndSettle();
}

void _expectChoiceSelected(WidgetTester tester, String label) {
  final chip = tester.widget<ChoiceChip>(
    find.widgetWithText(ChoiceChip, label),
  );
  expect(chip.selected, isTrue);
}

AppConfig _supabaseConfig() {
  return AppConfig.fromValues(
    backendModeValue: 'supabase',
    supabaseUrl: 'https://example.supabase.co',
    supabaseAnonKey: 'placeholder-anon-key',
  );
}

class _RecordingAuthRepository implements AuthRepository {
  _RecordingAuthRepository({AuthUser? initialUser}) : _user = initialUser;

  AuthUser? _user;
  int signUpCount = 0;
  int signOutCount = 0;
  final List<String> signUpDisplayNames = [];

  @override
  Future<AuthUser?> currentUser() async {
    return _user;
  }

  @override
  Future<AuthResult> signInWithEmail({
    required String email,
    required String password,
  }) async {
    _user = AuthUser(
      id: 'signed-in-user',
      email: email.trim(),
      displayName: 'Supabase Student',
    );
    return AuthResult.signedIn(_user!);
  }

  @override
  Future<AuthResult> signUpWithEmail({
    required String displayName,
    required String email,
    required String password,
  }) async {
    signUpCount += 1;
    signUpDisplayNames.add(displayName);
    _user = AuthUser(
      id: 'signed-up-user',
      email: email.trim(),
      displayName: displayName.trim(),
    );
    return AuthResult.signedIn(_user!);
  }

  @override
  Future<void> sendPasswordResetEmail(String email) async {}

  @override
  Future<void> signOut() async {
    signOutCount += 1;
    _user = null;
  }
}

class _RecordingProfileRepository implements ProfileRepository {
  _RecordingProfileRepository({this.profile});

  AuthProfile? profile;
  final List<AuthUser> fetchedUsers = [];
  final List<AuthUser> ensuredUsers = [];
  final List<AuthUser> updateUsers = [];
  final List<String> updatedDisplayNames = [];

  @override
  Future<AuthProfile?> fetchProfile(AuthUser user) async {
    fetchedUsers.add(user);
    return profile;
  }

  @override
  Future<AuthProfile> ensureProfile(AuthUser user) async {
    ensuredUsers.add(user);
    final ensuredProfile = AuthProfile(
      id: user.id,
      email: user.email,
      displayName: user.displayName,
    );
    profile = ensuredProfile;
    return ensuredProfile;
  }

  @override
  Future<AuthProfile> updateDisplayName({
    required AuthUser user,
    required String displayName,
  }) async {
    updateUsers.add(user);
    updatedDisplayNames.add(displayName);
    final updatedProfile = AuthProfile(
      id: user.id,
      email: user.email,
      displayName: displayName,
    );
    profile = updatedProfile;
    return updatedProfile;
  }
}
