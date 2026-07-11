import 'package:ai_study_buddy/app/design_system/tokens.dart';
import 'package:ai_study_buddy/app/theme.dart';
import 'package:ai_study_buddy/shared/widgets/study_buddy_mark.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const sizes = [16.0, 24.0, 32.0, 48.0, 128.0, 512.0];

  testWidgets('all variants paint at every required exact size', (
    tester,
  ) async {
    for (final variant in StudyBuddyMarkVariant.values) {
      for (final size in sizes) {
        await tester.pumpWidget(
          MaterialApp(
            theme: buildAppTheme(),
            home: Center(
              child: StudyBuddyMark(
                key: ValueKey('${variant.name}-$size'),
                size: size,
                variant: variant,
                color: variant == StudyBuddyMarkVariant.monochrome
                    ? Colors.black
                    : null,
              ),
            ),
          ),
        );

        expect(
          tester.getSize(find.byKey(ValueKey('${variant.name}-$size'))),
          Size.square(size),
        );
        expect(tester.takeException(), isNull);
      }
    }
  });

  testWidgets('16 and 24 px marks do not overflow tight constraints', (
    tester,
  ) async {
    for (final size in const [16.0, 24.0]) {
      await tester.pumpWidget(
        MaterialApp(
          home: Center(
            child: SizedBox.square(
              dimension: size,
              child: StudyBuddyMark(size: size),
            ),
          ),
        ),
      );
      expect(find.byType(OverflowBox), findsNothing);
      expect(tester.takeException(), isNull);
    }
  });

  testWidgets('meaningful and decorative semantics are explicit', (
    tester,
  ) async {
    final semantics = tester.ensureSemantics();

    await tester.pumpWidget(
      const MaterialApp(
        home: Column(
          children: [
            StudyBuddyMark(semanticLabel: 'AI Study Buddy brand'),
            StudyBuddyMark(
              key: ValueKey('decorative-mark'),
              semanticLabel: 'Decorative brand mark',
              excludeFromSemantics: true,
            ),
          ],
        ),
      ),
    );

    expect(find.bySemanticsLabel('AI Study Buddy brand'), findsOneWidget);
    expect(find.bySemanticsLabel('Decorative brand mark'), findsNothing);
    semantics.dispose();
  });

  testWidgets('preview renders variants, hosts, and required sizes', (
    tester,
  ) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(1200, 1050);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.view.resetPhysicalSize);

    await tester.pumpWidget(
      MaterialApp(theme: buildAppTheme(), home: const _BrandMarkPreview()),
    );

    expect(find.byKey(const ValueKey('brand-mark-preview')), findsOneWidget);
    expect(find.byKey(const ValueKey('brand-host-light')), findsOneWidget);
    expect(find.byKey(const ValueKey('brand-host-dark')), findsOneWidget);
    expect(find.byType(StudyBuddyMark), findsNWidgets(10));

    final marks = tester.widgetList<StudyBuddyMark>(
      find.byType(StudyBuddyMark),
    );
    expect(
      marks.where((mark) => mark.variant == StudyBuddyMarkVariant.fullColor),
      hasLength(8),
    );
    expect(
      marks.where((mark) => mark.variant == StudyBuddyMarkVariant.flat),
      hasLength(1),
    );
    expect(
      marks.where((mark) => mark.variant == StudyBuddyMarkVariant.monochrome),
      hasLength(1),
    );

    for (final size in sizes) {
      final sample = find.byKey(ValueKey('brand-size-$size'));
      expect(sample, findsOneWidget);
      expect(
        tester.getSize(
          find.descendant(of: sample, matching: find.byType(StudyBuddyMark)),
        ),
        Size.square(size),
      );
    }
    expect(find.byType(OverflowBox), findsNothing);
    expect(find.byType(CustomPaint), findsWidgets);
    expect(tester.takeException(), isNull);
  });
}

class _BrandMarkPreview extends StatelessWidget {
  const _BrandMarkPreview();

  static const sizes = [16.0, 24.0, 32.0, 48.0, 128.0, 512.0];

  @override
  Widget build(BuildContext context) => Scaffold(
    key: const ValueKey('brand-mark-preview'),
    backgroundColor: AppColors.canvas,
    body: SingleChildScrollView(
      padding: const EdgeInsets.all(32),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          const Wrap(
            spacing: 24,
            runSpacing: 24,
            children: [
              _VariantPanel(
                key: ValueKey('brand-host-light'),
                variant: StudyBuddyMarkVariant.fullColor,
                background: Colors.white,
              ),
              _VariantPanel(
                key: ValueKey('brand-host-dark'),
                variant: StudyBuddyMarkVariant.fullColor,
                background: AppColors.textStrong,
              ),
              _VariantPanel(
                variant: StudyBuddyMarkVariant.flat,
                background: Colors.white,
              ),
              _VariantPanel(
                variant: StudyBuddyMarkVariant.monochrome,
                markColor: Colors.white,
                background: AppColors.textStrong,
              ),
            ],
          ),
          const SizedBox(height: 32),
          Wrap(
            crossAxisAlignment: WrapCrossAlignment.end,
            spacing: 24,
            runSpacing: 24,
            children: [
              for (final size in sizes)
                _SizeSample(key: ValueKey('brand-size-$size'), size: size),
            ],
          ),
        ],
      ),
    ),
  );
}

class _VariantPanel extends StatelessWidget {
  const _VariantPanel({
    super.key,
    required this.variant,
    required this.background,
    this.markColor,
  });

  final StudyBuddyMarkVariant variant;
  final Color background;
  final Color? markColor;

  @override
  Widget build(BuildContext context) => Container(
    width: 250,
    height: 180,
    padding: const EdgeInsets.all(16),
    decoration: BoxDecoration(
      color: background,
      borderRadius: BorderRadius.circular(20),
    ),
    child: Center(
      child: StudyBuddyMark(
        size: 132,
        variant: variant,
        color: markColor,
        excludeFromSemantics: true,
      ),
    ),
  );
}

class _SizeSample extends StatelessWidget {
  const _SizeSample({required this.size, super.key});

  final double size;

  @override
  Widget build(BuildContext context) => Container(
    color: Colors.white,
    padding: EdgeInsets.all(size < 48 ? 8 : 12),
    child: StudyBuddyMark(size: size, excludeFromSemantics: true),
  );
}
