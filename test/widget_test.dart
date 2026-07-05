import 'package:ai_study_buddy/app/app.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('shows login shell and enters dashboard', (tester) async {
    await tester.pumpWidget(const StudyBuddyApp());

    expect(find.text('AI Study Buddy'), findsOneWidget);
    expect(find.text('Continue with email'), findsOneWidget);

    await tester.tap(find.text('Continue with email'));
    await tester.pumpAndSettle();

    expect(find.text('What do you want to do today?'), findsOneWidget);
    expect(find.text('After Lecture'), findsOneWidget);
    expect(find.text('Prepare for Exam'), findsOneWidget);
    expect(find.text('Continue Studying'), findsOneWidget);
  });
}
