import 'package:ai_study_buddy/features/materials/summary_document_view.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('renders supported Markdown without raw emphasis markers', (
    tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: SummaryDocumentView(
            markdown:
                '# Overview\n\n**Key concepts**\n\n- First idea\n- *Second idea*\n\n1. Review',
          ),
        ),
      ),
    );

    expect(find.text('**Key concepts**'), findsNothing);
    expect(find.text('Key concepts'), findsOneWidget);
    expect(find.text('Overview'), findsOneWidget);
    expect(find.text('First idea'), findsOneWidget);
  });

  testWidgets('does not create widgets from arbitrary HTML', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: SummaryDocumentView(
            markdown: '<script>unsafe()</script>\n\nSafe paragraph.',
          ),
        ),
      ),
    );

    expect(find.byType(HtmlElementView), findsNothing);
    expect(find.text('Safe paragraph.'), findsOneWidget);
  });

  testWidgets('does not create image widgets or providers for image syntax', (
    tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: SummaryDocumentView(
            markdown: '''
Normal selectable summary text.

![external](https://example.com/tracker.png)
![data](data:image/png;base64,...)
![file](file:///private/summary.png)
![asset](asset.png)
''',
          ),
        ),
      ),
    );
    await tester.pump();

    expect(find.byType(Image), findsNothing);
    expect(find.byType(RawImage), findsNothing);
    expect(find.text('Normal selectable summary text.'), findsOneWidget);
    expect(find.byType(SelectableText), findsWidgets);
    expect(tester.takeException(), isNull);
  });
}
