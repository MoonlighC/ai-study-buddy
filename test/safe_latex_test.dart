import 'package:ai_study_buddy/features/materials/safe_latex.dart';
import 'package:ai_study_buddy/features/materials/structured_summary.dart';
import 'package:flutter/material.dart';
import 'package:flutter_math_fork/flutter_math.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const validator = SafeLatexValidator();

  test('matches the C1 accepted study-math subset', () {
    for (final value in [
      r'\frac{a}{b}',
      r'\sqrt{x}',
      r'\sum_{i=1}^{n}i',
      r'\int_0^1 x dx',
      r'\alpha+\beta',
      r'A \vee B \wedge C',
      r'A \land B \lor \neg C',
      r'A \oplus B',
      r'\begin{bmatrix}1&2\\3&4\end{bmatrix}',
      r'\begin {matrix}1&2\\3&4\end {matrix}',
      r'\begin{cases}x&\begin{matrix}a&b\\c&d\end{matrix}\\y&z\end{cases}',
      r'\begin{matrix}1\end{matrix}+\begin{matrix}2\end{matrix}',
    ]) {
      expect(validator.validate(value).valid, isTrue, reason: value);
    }
  });

  testWidgets('flutter_math_fork renders every approved Boolean command', (
    tester,
  ) async {
    for (final command in ['vee', 'wedge', 'land', 'lor', 'neg', 'oplus']) {
      await tester.pumpWidget(
        MaterialApp(home: Scaffold(body: Math.tex('A \\$command B'))),
      );
      expect(tester.takeException(), isNull, reason: command);
      expect(find.byType(Math), findsOneWidget);
    }
  });

  test('rejects every audited C1 parity bypass', () {
    final oversizedRow = List.filled(13, '1').join('&');
    for (final value in [
      '',
      ' \t\r\n',
      r'$x$',
      r'$$x$$',
      r'x\\y',
      r'\begin{matrix}\begin{cases}x\end{matrix}\end{cases}',
      '\\begin {matrix}$oversizedRow\\end {matrix}',
      r'\subset',
      r'\begin{vmatrix}1\end{vmatrix}',
      r'\begin{Vmatrix}1\end{Vmatrix}',
      'x\u202E+y',
      'x\u2066+y',
      'x\u2216input',
      'x\u29F5input',
      'x\uFF3Cinput',
      'x\uFE68input',
      r'x% hidden',
      r'x^^41',
      r'\csname input\endcsname',
      r'\newcommand{\x}{y}',
      r'\href{https://x.test}{x}',
      r'\input{file}',
      r'\usepackage{x}',
      r'\html{x}',
      '{x',
      '${List.filled(17, '{').join()}x${List.filled(17, '}').join()}',
    ]) {
      expect(validator.validate(value).valid, isFalse, reason: value);
    }
  });

  test('matrix limits are independent and exact', () {
    final twelveColumns = List.filled(12, '1').join('&');
    final thirteenColumns = List.filled(13, '1').join('&');
    final twelveRows = List.filled(12, '1').join(r'\\');
    final thirteenRows = List.filled(13, '1').join(r'\\');
    expect(
      validator
          .validate(
            '\\begin{matrix}$twelveColumns\\end{matrix}+'
            '\\begin {matrix}$twelveRows\\end {matrix}',
          )
          .valid,
      isTrue,
    );
    expect(
      validator.validate('\\begin{matrix}$thirteenColumns\\end{matrix}').valid,
      isFalse,
    );
    expect(
      validator.validate('\\begin {matrix}$thirteenRows\\end {matrix}').valid,
      isFalse,
    );
  });

  testWidgets(
    'validated Math.tex is non-selectable, scrollable, semantic, and copyable',
    (tester) async {
      var copied = false;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SafeLatex(
              equation: _equation(),
              sourcePage: 1,
              uncertainLabel: 'Unsichere Formel',
              sourcePageText: 'Quellseite 1',
              copyLabel: 'Formel kopieren',
              semanticsLabel: (description) =>
                  'Gleichung: $description. Quellseite 1.',
              onCopy: () async {
                copied = true;
              },
            ),
          ),
        ),
      );
      expect(find.byType(Math), findsOneWidget);
      expect(find.byType(SelectableMath), findsNothing);
      expect(find.byType(SelectableText), findsNothing);
      expect(find.byType(SingleChildScrollView), findsOneWidget);
      expect(find.bySemanticsLabel(RegExp('Gleichung:')), findsOneWidget);
      await tester.tap(find.byTooltip('Formel kopieren'));
      expect(copied, isTrue);
    },
  );

  testWidgets('uncertain or invalid equations are plain and never copyable', (
    tester,
  ) async {
    for (final equation in [
      _equation(uncertainty: true),
      _equation(latex: r'$x$'),
    ]) {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SafeLatex(
              equation: equation,
              sourcePage: 1,
              uncertainLabel: 'Uncertain formula',
              sourcePageText: 'Source page 1',
              copyLabel: 'Copy formula',
              semanticsLabel: (description) => description,
              onCopy: () async {
                fail('invalid equation exposed copy');
              },
            ),
          ),
        ),
      );
      expect(find.byType(Math), findsNothing);
      expect(find.byType(SelectableText), findsOneWidget);
      expect(find.byTooltip('Copy formula'), findsNothing);
    }
  });

  testWidgets('long equations remain scrollable at large text scale', (
    tester,
  ) async {
    final longLatex = '${List.filled(80, 'x+').join()}x';
    await tester.pumpWidget(
      MediaQuery(
        data: const MediaQueryData(textScaler: TextScaler.linear(2)),
        child: MaterialApp(
          home: Scaffold(
            body: SafeLatex(
              equation: _equation(latex: longLatex),
              sourcePage: 1,
              uncertainLabel: 'Uncertain formula',
              sourcePageText: 'Source page 1',
              copyLabel: 'Copy formula',
              semanticsLabel: (description) => description,
            ),
          ),
        ),
      ),
    );
    expect(find.byType(SingleChildScrollView), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}

Equation _equation({String latex = r'\frac{a}{b}', bool uncertainty = false}) =>
    Equation(
      id: 'eq_one',
      latex: latex,
      explanationMarkdown: 'fraction',
      sourcePage: 1,
      display: SummaryDisplay.block,
      confidence: 1,
      uncertainty: uncertainty,
    );
