import 'package:flutter/material.dart';

import 'app_state.dart';
import 'routes.dart';
import 'theme.dart';

class StudyBuddyApp extends StatefulWidget {
  const StudyBuddyApp({super.key});

  @override
  State<StudyBuddyApp> createState() => _StudyBuddyAppState();
}

class _StudyBuddyAppState extends State<StudyBuddyApp> {
  late final AppState state = AppState();

  @override
  Widget build(BuildContext context) {
    return AppStateScope(
      state: state,
      child: MaterialApp(
        title: 'AI Study Buddy',
        debugShowCheckedModeBanner: false,
        theme: buildAppTheme(),
        initialRoute: AppRoutes.login,
        onGenerateRoute: AppRoutes.onGenerateRoute,
      ),
    );
  }
}
