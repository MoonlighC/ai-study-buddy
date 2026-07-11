import 'package:flutter/material.dart';

import '../../app/app_config.dart';
import '../../app/app_state.dart';
import '../../app/routes.dart';
import '../../l10n/l10n_extensions.dart';
import '../auth/auth_controller.dart';
import '../../shared/widgets/glass_components.dart';
import '../../shared/widgets/responsive_app_scaffold.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

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
              'Mock preferences for the local prototype.',
              style: Theme.of(context).textTheme.bodyMedium,
            ),
            const SizedBox(height: 16),
            _SettingsSection(
              icon: Icons.person_outline,
              title: 'Account',
              subtitle: isSupabaseMode
                  ? 'Supabase account'
                  : 'Local mock profile',
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _InfoRow(label: 'Name', value: accountName),
                  _InfoRow(label: 'Email', value: accountEmail),
                  const SizedBox(height: 12),
                  if (isSupabaseMode) ...[
                    OutlinedButton.icon(
                      onPressed: auth.isLoading || auth.user == null
                          ? null
                          : () => _editName(context),
                      icon: const Icon(Icons.edit_outlined),
                      label: const Text('Edit name'),
                    ),
                    const SizedBox(height: 8),
                  ],
                  FilledButton.tonalIcon(
                    onPressed: auth.isLoading ? null : () => _logOut(context),
                    icon: const Icon(Icons.logout),
                    label: const Text('Log out'),
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
              title: 'Study Preferences',
              subtitle: 'Stored in local AppState only',
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const _PreferenceLabel('Default flashcard session size'),
                  _PreferenceChips<int>(
                    values: const [5, 10, 20],
                    selected: state.defaultFlashcardSessionSize,
                    labelFor: (value) => '$value',
                    onSelected: state.setDefaultFlashcardSessionSize,
                  ),
                  const SizedBox(height: 14),
                  const _PreferenceLabel('Daily study goal'),
                  _PreferenceChips<int>(
                    values: const [10, 20, 30],
                    selected: state.dailyStudyGoalMinutes,
                    labelFor: (value) => '$value min',
                    onSelected: state.setDailyStudyGoalMinutes,
                  ),
                  const SizedBox(height: 14),
                  const _PreferenceLabel('Default difficulty'),
                  _PreferenceChips<StudyDifficultyPreference>(
                    values: StudyDifficultyPreference.values,
                    selected: state.defaultDifficulty,
                    labelFor: (value) => value.label,
                    onSelected: state.setDefaultDifficulty,
                  ),
                ],
              ),
            ),
            _SettingsSection(
              icon: Icons.palette_outlined,
              title: 'App preferences',
              subtitle: 'Appearance options are planned',
              child: ListTile(
                enabled: false,
                contentPadding: EdgeInsets.zero,
                leading: const Icon(Icons.dark_mode_outlined),
                title: const Text('Appearance'),
                subtitle: Text(l10n.settingsAppearanceUnavailable),
              ),
            ),
            _SettingsSection(
              icon: Icons.speed_outlined,
              title: 'Usage & Limits',
              subtitle: l10n.settingsUsageUnavailable,
              child: ListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('View usage information'),
                subtitle: const Text('Limits and enforcement are planned.'),
                trailing: const Icon(Icons.chevron_right),
                onTap: () => Navigator.pushNamed(context, AppRoutes.usage),
              ),
            ),
            _SettingsSection(
              icon: Icons.support_agent_outlined,
              title: 'Support',
              subtitle: 'No email or network integration yet',
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  OutlinedButton.icon(
                    onPressed: null,
                    icon: const Icon(Icons.bug_report_outlined),
                    label: const Text('Report a bug placeholder'),
                  ),
                  const SizedBox(height: 8),
                  OutlinedButton.icon(
                    onPressed: null,
                    icon: const Icon(Icons.contact_support_outlined),
                    label: const Text('Contact support placeholder'),
                  ),
                  const SizedBox(height: 8),
                  OutlinedButton.icon(
                    onPressed: null,
                    icon: const Icon(Icons.feedback_outlined),
                    label: const Text('Send feedback placeholder'),
                  ),
                ],
              ),
            ),
            _SettingsSection(
              icon: Icons.info_outline,
              title: 'About / Debug',
              subtitle: 'Prototype diagnostics',
              child: Column(
                children: [
                  _InfoRow(
                    label: 'Backend mode',
                    value: _backendModeLabel(state.config.effectiveBackendMode),
                  ),
                  const _InfoRow(
                    label: 'Security note',
                    value: 'No server secrets or OpenAI key in Flutter.',
                  ),
                ],
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
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  Future<void> _logOut(BuildContext context) async {
    final signedOut = await AuthScope.read(context).signOut();
    if (!context.mounted) {
      return;
    }
    if (!signedOut) {
      final message =
          AuthScope.read(context).errorMessage ?? 'Could not log out.';
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(message)));
      return;
    }
    AppStateScope.read(context).clearSyncedWorkspaceForSignOut();
    Navigator.pushNamedAndRemoveUntil(
      context,
      AppRoutes.login,
      (route) => false,
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
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text('Edit name', style: Theme.of(context).textTheme.titleLarge),
        const SizedBox(height: 16),
        TextField(
          controller: _controller,
          autofocus: true,
          textInputAction: TextInputAction.done,
          decoration: InputDecoration(labelText: 'Name', errorText: _errorText),
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
              child: const Text('Cancel'),
            ),
            FilledButton(onPressed: _save, child: const Text('Save')),
          ],
        ),
      ],
    );
  }

  void _save() {
    final trimmedName = _controller.text.trim();
    if (trimmedName.isEmpty) {
      setState(() {
        _errorText = 'Enter your name.';
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
            onSelected: (_) => onSelected(value),
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
