import 'dart:io';

class LocalizationAuditFinding {
  const LocalizationAuditFinding({
    required this.path,
    required this.line,
    required this.literal,
  });

  final String path;
  final int line;
  final String literal;

  @override
  String toString() => '$path:$line: $literal';
}

class LocalizationAuditAllowlistEntry {
  const LocalizationAuditAllowlistEntry({
    required this.pathPattern,
    required this.literalPattern,
    required this.category,
    required this.reason,
  });

  final String pathPattern;
  final String literalPattern;
  final String category;
  final String reason;

  bool matches(LocalizationAuditFinding finding) =>
      RegExp(pathPattern).hasMatch(finding.path) &&
      RegExp(literalPattern).hasMatch(finding.literal);
}

class LocalizationAuditResult {
  const LocalizationAuditResult({
    required this.findings,
    required this.unallowlisted,
    required this.staleAllowlist,
  });

  final List<LocalizationAuditFinding> findings;
  final List<LocalizationAuditFinding> unallowlisted;
  final List<LocalizationAuditAllowlistEntry> staleAllowlist;
}

LocalizationAuditResult auditLocalizationLiterals({
  required Directory root,
  required List<LocalizationAuditAllowlistEntry> allowlist,
}) {
  final findings = <LocalizationAuditFinding>[];
  final roots = ['lib/app', 'lib/shared', 'lib/features'];
  final context = RegExp(
    r'''(?:Text|Tooltip)\s*\(|(?:tooltip|semanticLabel|labelText|hintText|helperText|errorText)\s*:''',
  );
  final literal = RegExp(r'''(['"])([^'"\n]*[A-Za-z][^'"\n]*)\1''');

  for (final relativeRoot in roots) {
    final directory = Directory('${root.path}/$relativeRoot');
    if (!directory.existsSync()) continue;
    for (final entity in directory.listSync(recursive: true)) {
      if (entity is! File || !entity.path.endsWith('.dart')) continue;
      final relativePath = entity.path
          .substring(root.path.length + 1)
          .replaceAll('\\', '/');
      var inBlockComment = false;
      final lines = entity.readAsLinesSync();
      for (var index = 0; index < lines.length; index += 1) {
        var line = lines[index];
        if (inBlockComment) {
          final end = line.indexOf('*/');
          if (end < 0) continue;
          line = line.substring(end + 2);
          inBlockComment = false;
        }
        while (line.contains('/*')) {
          final start = line.indexOf('/*');
          final end = line.indexOf('*/', start + 2);
          if (end < 0) {
            line = line.substring(0, start);
            inBlockComment = true;
            break;
          }
          line = line.replaceRange(start, end + 2, ' ');
        }
        final comment = line.indexOf('//');
        if (comment >= 0) line = line.substring(0, comment);
        if (!context.hasMatch(line)) continue;
        for (final match in literal.allMatches(line)) {
          findings.add(
            LocalizationAuditFinding(
              path: relativePath,
              line: index + 1,
              literal: match.group(2)!,
            ),
          );
        }
      }
    }
  }

  final matchedEntries = <LocalizationAuditAllowlistEntry>{};
  final unallowlisted = <LocalizationAuditFinding>[];
  for (final finding in findings) {
    final matches = allowlist.where((entry) => entry.matches(finding)).toList();
    if (matches.isEmpty) {
      unallowlisted.add(finding);
    } else {
      matchedEntries.addAll(matches);
    }
  }
  return LocalizationAuditResult(
    findings: findings,
    unallowlisted: unallowlisted,
    staleAllowlist: allowlist
        .where((entry) => !matchedEntries.contains(entry))
        .toList(growable: false),
  );
}
