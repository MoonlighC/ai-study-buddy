import 'package:flutter/material.dart';

import '../../app/app_config.dart';
import '../../app/app_state.dart';
import '../../app/routes.dart';
import '../../l10n/l10n_extensions.dart';
import '../auth/auth_controller.dart';
import '../deletion/deletion_models.dart';
import '../../shared/widgets/glass_components.dart';
import '../../shared/widgets/responsive_app_scaffold.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});
  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  bool _checkedReauthIntent = false;

  @override
  Widget build(BuildContext context) {
    final state = AppStateScope.watch(context);
    final auth = AuthScope.watch(context);
    final isSupabaseMode =
        state.config.effectiveBackendMode == AppBackendMode.supabase;
    final l10n = context.l10n;
    final accountEmail = auth.user?.email ?? 'alex.student@example.test';
    final accountName = isSupabaseMode
        ? auth.effectiveDisplayName
        : 'Alex Student';
    if (!_checkedReauthIntent &&
        auth.pendingAccountDeletionReauth &&
        auth.isAuthenticated) {
      _checkedReauthIntent = true;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        AuthScope.read(context).consumeAccountDeletionReauthIntent();
        _deleteAccount(context);
      });
    }

    return ResponsiveAppScaffold(
      title: l10n.settingsTitle,
      activeRoute: AppRoutes.settings,
      body: ResponsiveContent(
        width: ResponsiveContentWidth.wide,
        child: ListView(
          key: const ValueKey('settings-scroll-view'),
          children: [
            Text(
              l10n.settingsTitle,
              style: Theme.of(context).textTheme.headlineSmall,
            ),
            const SizedBox(height: 8),
            Text(
              l10n.settingsIntro,
              style: Theme.of(context).textTheme.bodyMedium,
            ),
            const SizedBox(height: 16),
            _SettingsSection(
              icon: Icons.person_outline,
              title: l10n.settingsAccountTitle,
              subtitle: isSupabaseMode
                  ? l10n.settingsSupabaseAccount
                  : l10n.settingsLocalMockProfile,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _InfoRow(label: l10n.commonName, value: accountName),
                  _InfoRow(label: l10n.commonEmail, value: accountEmail),
                  const SizedBox(height: 12),
                  if (isSupabaseMode) ...[
                    OutlinedButton.icon(
                      onPressed: auth.isLoading || auth.user == null
                          ? null
                          : () => _editName(context),
                      icon: const Icon(Icons.edit_outlined),
                      label: Text(l10n.settingsEditName),
                    ),
                    const SizedBox(height: 8),
                  ],
                  FilledButton.tonalIcon(
                    onPressed: auth.isLoading ? null : () => _logOut(context),
                    icon: const Icon(Icons.logout),
                    label: Text(l10n.settingsLogOut),
                  ),
                ],
              ),
            ),
            _SettingsSection(
              icon: Icons.language_outlined,
              title: l10n.settingsLanguageTitle,
              subtitle: l10n.settingsDisplayLanguage,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _PreferenceChips<AppLanguagePreference>(
                    values: AppLanguagePreference.values,
                    selected: state.languagePreference,
                    labelFor: (value) => _languageLabel(context, value),
                    onSelected: state.setLanguagePreference,
                  ),
                  const SizedBox(height: 10),
                  Text(
                    l10n.settingsDisplayLanguageDescription,
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ],
              ),
            ),
            _SettingsSection(
              icon: Icons.tune_outlined,
              title: l10n.settingsStudyPreferencesTitle,
              subtitle: l10n.settingsStudyPreferencesSubtitle,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _PreferenceLabel(l10n.settingsDefaultFlashcardSessionSize),
                  _PreferenceChips<int>(
                    values: const [5, 10, 20],
                    selected: state.defaultFlashcardSessionSize,
                    labelFor: (value) => '$value',
                    onSelected: state.setDefaultFlashcardSessionSize,
                  ),
                  const SizedBox(height: 14),
                  _PreferenceLabel(l10n.settingsDailyStudyGoal),
                  _PreferenceChips<int>(
                    values: const [10, 20, 30],
                    selected: state.dailyStudyGoalMinutes,
                    labelFor: (value) => l10n.settingsMinutesShort(value),
                    onSelected: state.setDailyStudyGoalMinutes,
                  ),
                  const SizedBox(height: 14),
                  _PreferenceLabel(l10n.settingsDefaultDifficulty),
                  _PreferenceChips<StudyDifficultyPreference>(
                    values: StudyDifficultyPreference.values,
                    selected: state.defaultDifficulty,
                    labelFor: (value) => _difficultyLabel(context, value),
                    onSelected: state.setDefaultDifficulty,
                  ),
                ],
              ),
            ),
            _SettingsSection(
              icon: Icons.palette_outlined,
              title: l10n.settingsAppPreferencesTitle,
              subtitle: l10n.settingsAppearanceDescription,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _PreferenceLabel(l10n.settingsAppearance),
                  _PreferenceChips<AppAppearancePreference>(
                    values: AppAppearancePreference.values,
                    selected: state.appearancePreference,
                    labelFor: (value) => _appearanceLabel(context, value),
                    onSelected: state.setAppearancePreference,
                  ),
                ],
              ),
            ),
            _SettingsSection(
              icon: Icons.speed_outlined,
              title: l10n.settingsUsageTitle,
              subtitle: l10n.settingsUsageUnavailable,
              child: ListTile(
                contentPadding: EdgeInsets.zero,
                title: Text(l10n.settingsViewUsage),
                subtitle: Text(l10n.settingsUsagePlanned),
                trailing: const Icon(Icons.chevron_right),
                onTap: () => Navigator.pushNamed(context, AppRoutes.usage),
              ),
            ),
            _SettingsSection(
              icon: Icons.support_agent_outlined,
              title: l10n.settingsSupportTitle,
              subtitle: l10n.settingsSupportSubtitle,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  OutlinedButton.icon(
                    onPressed: null,
                    icon: const Icon(Icons.bug_report_outlined),
                    label: Text(l10n.settingsReportBugPlaceholder),
                  ),
                  const SizedBox(height: 8),
                  OutlinedButton.icon(
                    onPressed: null,
                    icon: const Icon(Icons.contact_support_outlined),
                    label: Text(l10n.settingsContactSupportPlaceholder),
                  ),
                  const SizedBox(height: 8),
                  OutlinedButton.icon(
                    onPressed: null,
                    icon: const Icon(Icons.feedback_outlined),
                    label: Text(l10n.settingsSendFeedbackPlaceholder),
                  ),
                ],
              ),
            ),
            _SettingsSection(
              icon: Icons.info_outline,
              title: l10n.settingsAboutDebugTitle,
              subtitle: l10n.settingsAboutDebugSubtitle,
              child: Column(
                children: [
                  if (state.config.environment == AppEnvironment.staging)
                    Semantics(
                      key: const ValueKey('staging-build-indicator'),
                      label: l10n.settingsStagingBuildSemantics,
                      readOnly: true,
                      child: Chip(
                        avatar: const Icon(Icons.science_outlined, size: 18),
                        label: Text(l10n.settingsStagingBuildLabel),
                      ),
                    ),
                  if (state.config.environment == AppEnvironment.staging)
                    const SizedBox(height: 8),
                  _InfoRow(
                    label: l10n.settingsBackendMode,
                    value: _backendModeLabel(state.config.effectiveBackendMode),
                  ),
                  _InfoRow(
                    label: l10n.settingsSecurityNote,
                    value: l10n.settingsSecurityNoteValue,
                  ),
                ],
              ),
            ),
            if (isSupabaseMode)
              _SettingsSection(
                icon: Icons.warning_amber_rounded,
                title: l10n.accountDangerTitle,
                subtitle: l10n.accountDangerSubtitle,
                child: Semantics(
                  liveRegion: true,
                  child: OutlinedButton.icon(
                    key: const ValueKey('account-delete-action'),
                    onPressed: auth.isDeletingAccount || auth.user == null
                        ? null
                        : () => _deleteAccount(context),
                    icon: auth.isDeletingAccount
                        ? const SizedBox.square(
                            dimension: 20,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.delete_forever_outlined),
                    label: Text(
                      auth.isDeletingAccount
                          ? l10n.accountDeleting
                          : l10n.accountDeleteAction,
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  String _backendModeLabel(AppBackendMode mode) {
    return switch (mode) {
      AppBackendMode.mock => 'mock',
      AppBackendMode.supabase => 'supabase',
    };
  }

  String _languageLabel(BuildContext context, AppLanguagePreference value) {
    final l10n = context.l10n;
    return switch (value) {
      AppLanguagePreference.system => l10n.languageSystem,
      AppLanguagePreference.english => l10n.languageEnglish,
      AppLanguagePreference.german => l10n.languageGerman,
      AppLanguagePreference.russian => l10n.languageRussian,
    };
  }

  String _difficultyLabel(
    BuildContext context,
    StudyDifficultyPreference value,
  ) {
    final l10n = context.l10n;
    return switch (value) {
      StudyDifficultyPreference.easy => l10n.settingsDifficultyEasy,
      StudyDifficultyPreference.medium => l10n.settingsDifficultyMedium,
      StudyDifficultyPreference.exam => l10n.settingsDifficultyExam,
    };
  }

  String _appearanceLabel(
    BuildContext context,
    AppAppearancePreference value,
  ) => switch (value) {
    AppAppearancePreference.system => context.l10n.appearanceSystem,
    AppAppearancePreference.light => context.l10n.appearanceLight,
    AppAppearancePreference.dark => context.l10n.appearanceDark,
  };

  String _editableName(AuthController auth) {
    final profileName = _cleanName(auth.profile?.displayName);
    if (profileName != null) {
      return profileName;
    }
    return _cleanName(auth.user?.displayName) ?? '';
  }

  String? _cleanName(String? displayName) {
    final trimmedName = displayName?.trim();
    if (trimmedName != null && trimmedName.isNotEmpty) {
      return trimmedName;
    }
    return null;
  }

  Future<void> _editName(BuildContext context) async {
    final auth = AuthScope.read(context);
    final updatedName = await showDialog<String>(
      context: context,
      builder: (_) =>
          GlassDialog(child: _EditNameDialog(initialName: _editableName(auth))),
    );
    if (!context.mounted || updatedName == null) {
      return;
    }
    final saved = await AuthScope.read(context).updateDisplayName(updatedName);
    if (!context.mounted || saved) {
      return;
    }
    final message =
        AuthScope.read(context).errorMessage ??
        'Could not update the account profile.';
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(context.localizedSafeMessage(message))),
    );
  }

  Future<void> _logOut(BuildContext context) async {
    final signedOut = await AuthScope.read(context).signOut();
    if (!context.mounted) {
      return;
    }
    if (!signedOut) {
      final message =
          AuthScope.read(context).errorMessage ?? 'Could not log out.';
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(context.localizedSafeMessage(message))),
      );
      return;
    }
    AppStateScope.read(context).clearSyncedWorkspaceForSignOut();
    Navigator.pushNamedAndRemoveUntil(
      context,
      AppRoutes.login,
      (route) => false,
    );
  }

  Future<void> _deleteAccount(BuildContext context) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => const _DeleteAccountDialog(),
    );
    if (confirmed != true || !context.mounted) return;
    final deleted = await AuthScope.read(context).deleteAccount();
    if (!context.mounted) return;
    final auth = AuthScope.read(context);
    if (deleted) {
      AppStateScope.read(context).clearSyncedWorkspaceForSignOut();
      Navigator.pushNamedAndRemoveUntil(context, AppRoutes.login, (_) => false);
      return;
    }
    if (auth.pendingAccountDeletionReauth) {
      AppStateScope.read(context).clearSyncedWorkspaceForSignOut();
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(context.l10n.accountDeleteReauth)));
      Navigator.pushNamedAndRemoveUntil(context, AppRoutes.login, (_) => false);
      return;
    }
    final code = auth.accountDeletionError ?? DeletionSafeCode.unknown;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(_deletionMessage(context, code))));
  }

  String _deletionMessage(
    BuildContext context,
    DeletionSafeCode code,
  ) => switch (code) {
    DeletionSafeCode.deletionInProgress => context.l10n.deletionErrorInProgress,
    DeletionSafeCode.storageCleanupFailed => context.l10n.deletionErrorStorage,
    DeletionSafeCode.databaseCleanupFailed =>
      context.l10n.deletionErrorDatabase,
    DeletionSafeCode.authCleanupFailed => context.l10n.deletionErrorAuth,
    DeletionSafeCode.recentAuthRequired => context.l10n.deletionErrorRecentAuth,
    DeletionSafeCode.recentAuthVerificationFailed =>
      context.l10n.deletionErrorRecentAuthVerificationFailed,
    DeletionSafeCode.unauthorized => context.l10n.deletionErrorUnauthorized,
    DeletionSafeCode.retryLater => context.l10n.deletionErrorRetry,
    DeletionSafeCode.unknown => context.l10n.deletionErrorUnknown,
  };
}

class _DeleteAccountDialog extends StatefulWidget {
  const _DeleteAccountDialog();
  @override
  State<_DeleteAccountDialog> createState() => _DeleteAccountDialogState();
}

class _DeleteAccountDialogState extends State<_DeleteAccountDialog> {
  final _controller = TextEditingController();
  final _focus = FocusNode();
  @override
  void dispose() {
    _controller.dispose();
    _focus.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final valid = _controller.text.trim() == 'DELETE';
    return AlertDialog(
      scrollable: true,
      title: Text(l.accountDeleteTitle),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(l.accountDeleteBody),
          const SizedBox(height: 12),
          Text(l.accountDeleteRecentAuth),
          const SizedBox(height: 16),
          Text(l.accountDeleteTypePrompt),
          const SizedBox(height: 8),
          TextField(
            key: const ValueKey('account-delete-confirmation'),
            controller: _controller,
            focusNode: _focus,
            autofocus: true,
            textInputAction: TextInputAction.done,
            decoration: InputDecoration(
              labelText: l.accountDeleteConfirmationLabel,
            ),
            onChanged: (_) => setState(() {}),
            onSubmitted: (_) {
              if (valid) Navigator.pop(context, true);
            },
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context, false),
          child: Text(l.actionCancel),
        ),
        FilledButton(
          key: const ValueKey('account-delete-confirm'),
          onPressed: valid ? () => Navigator.pop(context, true) : null,
          child: Text(l.accountDeleteAction),
        ),
      ],
    );
  }
}

class _EditNameDialog extends StatefulWidget {
  const _EditNameDialog({required this.initialName});

  final String initialName;

  @override
  State<_EditNameDialog> createState() => _EditNameDialogState();
}

class _EditNameDialogState extends State<_EditNameDialog> {
  late final TextEditingController _controller = TextEditingController(
    text: widget.initialName,
  );
  String? _errorText;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          l10n.settingsEditName,
          style: Theme.of(context).textTheme.titleLarge,
        ),
        const SizedBox(height: 16),
        TextField(
          controller: _controller,
          autofocus: true,
          textInputAction: TextInputAction.done,
          decoration: InputDecoration(
            labelText: l10n.commonName,
            errorText: _errorText,
          ),
          onChanged: (_) {
            if (_errorText == null) {
              return;
            }
            setState(() {
              _errorText = null;
            });
          },
          onSubmitted: (_) => _save(),
        ),
        const SizedBox(height: 16),
        Wrap(
          alignment: WrapAlignment.end,
          spacing: 8,
          children: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text(l10n.actionCancel),
            ),
            FilledButton(onPressed: _save, child: Text(l10n.actionSave)),
          ],
        ),
      ],
    );
  }

  void _save() {
    final trimmedName = _controller.text.trim();
    if (trimmedName.isEmpty) {
      setState(() {
        _errorText = context.l10n.errorEnterName;
      });
      return;
    }
    Navigator.pop(context, trimmedName);
  }
}

class _SettingsSection extends StatelessWidget {
  const _SettingsSection({
    required this.icon,
    required this.title,
    required this.child,
    this.subtitle,
  });
  final IconData icon;
  final String title;
  final String? subtitle;
  final Widget child;
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 16),
    child: GlassCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Icon(icon),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  title,
                  style: Theme.of(context).textTheme.titleLarge,
                ),
              ),
            ],
          ),
          if (subtitle != null) ...[
            const SizedBox(height: 4),
            Text(subtitle!, style: Theme.of(context).textTheme.bodySmall),
          ],
          const SizedBox(height: 16),
          child,
        ],
      ),
    ),
  );
}

class _PreferenceChips<T> extends StatelessWidget {
  const _PreferenceChips({
    required this.values,
    required this.selected,
    required this.labelFor,
    required this.onSelected,
  });

  final List<T> values;
  final T selected;
  final String Function(T value) labelFor;
  final ValueChanged<T> onSelected;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        for (final value in values)
          ChoiceChip(
            label: Text(labelFor(value)),
            selected: selected == value,
            onSelected: (isSelected) {
              if (isSelected) onSelected(value);
            },
          ),
      ],
    );
  }
}

class _PreferenceLabel extends StatelessWidget {
  const _PreferenceLabel(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Text(text, style: Theme.of(context).textTheme.labelLarge),
    );
  }
}

class _InfoRow extends StatelessWidget {
  const _InfoRow({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(child: Text(label)),
          const SizedBox(width: 12),
          Flexible(
            child: Text(
              value,
              textAlign: TextAlign.end,
              style: Theme.of(context).textTheme.labelLarge,
            ),
          ),
        ],
      ),
    );
  }
}
