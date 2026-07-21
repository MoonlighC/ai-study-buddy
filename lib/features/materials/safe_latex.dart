import 'package:flutter/material.dart';
import 'package:flutter_math_fork/flutter_math.dart';

import 'structured_summary.dart';

class LatexValidationResult {
  const LatexValidationResult(this.valid, this.description);

  final bool valid;
  final String description;
}

class SafeLatexValidator {
  const SafeLatexValidator();

  static const allowedCommands = {
    'frac',
    'sqrt',
    'sum',
    'prod',
    'int',
    'iint',
    'iiint',
    'lim',
    'infty',
    'partial',
    'nabla',
    'cdot',
    'times',
    'div',
    'pm',
    'mp',
    'le',
    'ge',
    'ne',
    'approx',
    'equiv',
    'to',
    'rightarrow',
    'leftarrow',
    'leftrightarrow',
    'vec',
    'hat',
    'bar',
    'overline',
    'underline',
    'mathrm',
    'mathbf',
    'mathit',
    'mathbb',
    'mathcal',
    'text',
    'sin',
    'cos',
    'tan',
    'log',
    'ln',
    'exp',
    'min',
    'max',
    'det',
    'left',
    'right',
    'quad',
    'qquad',
    'ldots',
    'cdots',
    'alpha',
    'beta',
    'gamma',
    'delta',
    'epsilon',
    'varepsilon',
    'zeta',
    'eta',
    'theta',
    'vartheta',
    'iota',
    'kappa',
    'lambda',
    'mu',
    'nu',
    'xi',
    'pi',
    'rho',
    'sigma',
    'tau',
    'upsilon',
    'phi',
    'varphi',
    'chi',
    'psi',
    'omega',
    'Gamma',
    'Delta',
    'Theta',
    'Lambda',
    'Xi',
    'Pi',
    'Sigma',
    'Upsilon',
    'Phi',
    'Psi',
    'Omega',
  };
  static const allowedEnvironments = {
    'matrix',
    'pmatrix',
    'bmatrix',
    'cases',
    'aligned',
  };
  static final _forbiddenUnicode = RegExp(
    r'[\u202A-\u202E\u2066-\u2069\uFEFF\uFF3C\u2216\u29F5\uFE68]',
    unicode: true,
  );

  LatexValidationResult validate(String value) {
    final description = _plainDescription(value);
    if (value.trim().isEmpty ||
        value.length > 512 ||
        value.contains(r'$') ||
        value.contains('%') ||
        value.contains('^^') ||
        _forbiddenUnicode.hasMatch(value)) {
      return LatexValidationResult(false, description);
    }

    var groupDepth = 0;
    var maximumGroupDepth = 0;
    final environments = <_EnvironmentFrame>[];
    for (var index = 0; index < value.length; index += 1) {
      final character = value[index];
      if (character == '{') {
        groupDepth += 1;
        maximumGroupDepth = groupDepth > maximumGroupDepth
            ? groupDepth
            : maximumGroupDepth;
        continue;
      }
      if (character == '}') {
        groupDepth -= 1;
        if (groupDepth < 0) return LatexValidationResult(false, description);
        continue;
      }
      if (character == '&' && environments.isNotEmpty) {
        final frame = environments.last;
        frame.columns += 1;
        if (frame.columns > frame.maximumColumns) {
          frame.maximumColumns = frame.columns;
        }
        continue;
      }
      if (character != r'\') continue;
      if (index + 1 >= value.length) {
        return LatexValidationResult(false, description);
      }
      final next = value[index + 1];
      if (RegExp(r'\s', unicode: true).hasMatch(next)) {
        return LatexValidationResult(false, description);
      }
      if (next == r'\') {
        if (environments.isEmpty) {
          return LatexValidationResult(false, description);
        }
        final frame = environments.last;
        frame.rows += 1;
        frame.columns = 1;
        index += 1;
        continue;
      }
      if (!_asciiLetter(next)) {
        if (!r'{}_#&,^'.contains(next)) {
          return LatexValidationResult(false, description);
        }
        index += 1;
        continue;
      }
      var end = index + 1;
      while (end < value.length && _asciiLetter(value[end])) {
        end += 1;
      }
      final command = value.substring(index + 1, end);
      index = end - 1;
      if (command == 'begin' || command == 'end') {
        final parsed = _parseEnvironment(value, end);
        if (parsed == null || !allowedEnvironments.contains(parsed.name)) {
          return LatexValidationResult(false, description);
        }
        index = parsed.end - 1;
        if (command == 'begin') {
          environments.add(_EnvironmentFrame(parsed.name));
        } else {
          if (environments.isEmpty) {
            return LatexValidationResult(false, description);
          }
          final frame = environments.removeLast();
          if (frame.name != parsed.name ||
              frame.rows > 12 ||
              frame.maximumColumns > 12) {
            return LatexValidationResult(false, description);
          }
        }
        continue;
      }
      if (!allowedCommands.contains(command)) {
        return LatexValidationResult(false, description);
      }
    }
    if (groupDepth != 0 || maximumGroupDepth > 16 || environments.isNotEmpty) {
      return LatexValidationResult(false, description);
    }
    return LatexValidationResult(true, description);
  }

  _ParsedEnvironment? _parseEnvironment(String value, int start) {
    var index = start;
    while (index < value.length && ' \t\r\n'.contains(value[index])) {
      index += 1;
    }
    if (index >= value.length || value[index] != '{') return null;
    final nameStart = ++index;
    while (index < value.length && _asciiLetter(value[index])) {
      index += 1;
    }
    if (index == nameStart || index >= value.length || value[index] != '}') {
      return null;
    }
    return _ParsedEnvironment(value.substring(nameStart, index), index + 1);
  }

  bool _asciiLetter(String value) {
    final unit = value.codeUnitAt(0);
    return (unit >= 0x41 && unit <= 0x5a) || (unit >= 0x61 && unit <= 0x7a);
  }

  String _plainDescription(String value) => value
      .replaceAll(r'\', ' ')
      .replaceAll(RegExp(r'[{}]'), ' ')
      .replaceAll(RegExp(r'\s+'), ' ')
      .trim();
}

class _ParsedEnvironment {
  const _ParsedEnvironment(this.name, this.end);

  final String name;
  final int end;
}

class _EnvironmentFrame {
  _EnvironmentFrame(this.name);

  final String name;
  int rows = 1;
  int columns = 1;
  int maximumColumns = 1;
}

class SafeLatex extends StatelessWidget {
  const SafeLatex({
    required this.equation,
    required this.sourcePage,
    required this.uncertainLabel,
    required this.sourcePageText,
    required this.copyLabel,
    required this.semanticsLabel,
    this.onCopy,
    this.onSourcePage,
    super.key,
  });

  final Equation equation;
  final int sourcePage;
  final String uncertainLabel, sourcePageText, copyLabel;
  final String Function(String description) semanticsLabel;
  final Future<void> Function()? onCopy;
  final VoidCallback? onSourcePage;

  @override
  Widget build(BuildContext context) {
    final validation = const SafeLatexValidator().validate(equation.latex);
    if (!validation.valid || equation.uncertainty) return _plain();
    final math = Math.tex(
      equation.latex,
      mathStyle: equation.display == SummaryDisplay.block
          ? MathStyle.display
          : MathStyle.text,
      textStyle: DefaultTextStyle.of(context).style,
      onErrorFallback: (_) => _plain(),
    );
    return Semantics(
      label: semanticsLabel(validation.description),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SingleChildScrollView(scrollDirection: Axis.horizontal, child: math),
          Wrap(
            spacing: 8,
            runSpacing: 6,
            children: [
              _sourceChip(),
              if (onCopy != null)
                IconButton(
                  tooltip: copyLabel,
                  onPressed: () => onCopy!(),
                  icon: const Icon(Icons.copy_outlined),
                ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _plain() => Semantics(
    label: '$uncertainLabel. $sourcePageText',
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SelectableText(equation.latex),
        Wrap(
          spacing: 8,
          runSpacing: 6,
          children: [
            Chip(
              avatar: const Icon(Icons.warning_amber_rounded, size: 16),
              label: Text(uncertainLabel),
            ),
            _sourceChip(),
          ],
        ),
      ],
    ),
  );

  Widget _sourceChip() => onSourcePage == null
      ? Chip(label: Text(sourcePageText))
      : ActionChip(label: Text(sourcePageText), onPressed: onSourcePage);
}
