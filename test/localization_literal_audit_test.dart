import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import 'support/localization_audit_allowlist.dart';
import 'support/localization_literal_audit.dart';

void main() {
  test('user-facing literal audit has no new or stale entries', () {
    final result = auditLocalizationLiterals(
      root: Directory.current,
      allowlist: localizationAuditAllowlist,
    );
    expect(result.unallowlisted, isEmpty, reason: result.unallowlisted.join('\n'));
    expect(
      result.staleAllowlist,
      isEmpty,
      reason: 'Remove or update stale localization audit allowlist entries.',
    );
  });

  test('audit detects display literals and honors narrow exclusions', () {
    final root = Directory.systemTemp.createTempSync('l10n-audit-');
    addTearDown(() => root.deleteSync(recursive: true));
    final file = File('${root.path}/lib/features/example.dart')
      ..createSync(recursive: true)
      ..writeAsStringSync("Text('Visible copy');\n");

    final detected = auditLocalizationLiterals(root: root, allowlist: const []);
    expect(detected.unallowlisted.single.literal, 'Visible copy');

    final allowed = auditLocalizationLiterals(
      root: root,
      allowlist: const [
        LocalizationAuditAllowlistEntry(
          pathPattern: r'^lib/features/example\.dart$',
          literalPattern: r'^Visible copy$',
          category: 'fixture',
          reason: 'Synthetic audit fixture.',
        ),
      ],
    );
    expect(allowed.unallowlisted, isEmpty);
    expect(allowed.staleAllowlist, isEmpty);

    file.writeAsStringSync("Text('Changed copy');\n");
    final stale = auditLocalizationLiterals(
      root: root,
      allowlist: const [
        LocalizationAuditAllowlistEntry(
          pathPattern: r'^lib/features/example\.dart$',
          literalPattern: r'^Visible copy$',
          category: 'fixture',
          reason: 'Synthetic audit fixture.',
        ),
      ],
    );
    expect(stale.unallowlisted.single.literal, 'Changed copy');
    expect(stale.staleAllowlist, hasLength(1));
  });
}
