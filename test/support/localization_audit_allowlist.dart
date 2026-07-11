import 'localization_literal_audit.dart';

// Every exception is intentionally narrow and must remain exercised by the
// audit. Removing its matching source literal makes the audit fail as stale.
const localizationAuditAllowlist = <LocalizationAuditAllowlistEntry>[
  LocalizationAuditAllowlistEntry(
    pathPattern: r'^lib/shared/widgets/study_components\.dart$',
    literalPattern: r'^\$current / \$total$',
    category: 'numeric presentation',
    reason: 'Locale-neutral progress values supplied by localized semantics.',
  ),
  LocalizationAuditAllowlistEntry(
    pathPattern: r'^lib/features/auth/auth_layout\.dart$',
    literalPattern: r'^AI Study Buddy$',
    category: 'product name',
    reason: 'Registered product name is intentionally invariant.',
  ),
  LocalizationAuditAllowlistEntry(
    pathPattern: r'^lib/features/flashcards/flashcards_screen\.dart$',
    literalPattern: r'^\$size$',
    category: 'numeric presentation',
    reason: 'Locale-neutral integer session-size choice.',
  ),
  LocalizationAuditAllowlistEntry(
    pathPattern: r'^lib/features/flashcards/flashcard_generation_dialog\.dart$',
    literalPattern: r'^\$count$',
    category: 'numeric presentation',
    reason: 'Locale-neutral integer generation-count choice.',
  ),
  LocalizationAuditAllowlistEntry(
    pathPattern: r'^lib/features/materials/material_presentation\.dart$',
    literalPattern: r'^\$\{row\.\$1\}: \$\{row\.\$2\}$',
    category: 'localized composition',
    reason: 'Both metadata label and value are supplied presentation strings.',
  ),
];
