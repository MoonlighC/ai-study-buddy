import 'package:ai_study_buddy/app/app.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('shows login shell and enters workspace', (tester) async {
    await tester.pumpWidget(const StudyBuddyApp());

    expect(find.text('AI Study Buddy'), findsOneWidget);
    expect(find.text('Continue with email'), findsOneWidget);

    await tester.tap(find.text('Continue with email'));
    await tester.pumpAndSettle();

    expect(find.text('Study Workspace'), findsOneWidget);
    expect(find.text('Biology'), findsOneWidget);
    expect(find.text('Exam Prep'), findsOneWidget);
  });
}
