import 'package:flutter/material.dart';

import '../../app/app_config.dart';
import '../../app/app_state.dart';
import '../../app/routes.dart';
import '../auth/auth_controller.dart';
import '../../shared/widgets/app_bottom_nav.dart';
import '../../shared/widgets/app_page.dart';
import '../../shared/widgets/app_top_actions.dart';
import '../../shared/widgets/section_card.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final state = AppStateScope.watch(context);
    final auth = AuthScope.watch(context);
    final isSupabaseMode =
        state.config.effectiveBackendMode == AppBackendMode.supabase;
    final accountEmail = auth.user?.email ?? 'alex.student@example.test';
    final accountName = isSupabaseMode
        ? auth.effectiveDisplayName
        : 'Alex Student';

    return Scaffold(
      appBar: AppBar(
        title: const Text('Settings'),
        actions: const [AppTopActions()],
      ),
      body: AppPage(
        children: [
          Text('Settings', style: Theme.of(context).textTheme.headlineSmall),
          const SizedBox(height: 8),
          Text(
            'Mock preferences for the local prototype.',
            style: Theme.of(context).textTheme.bodyMedium,
          ),
          const SizedBox(height: 16),
          SectionCard(
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
          SectionCard(
            icon: Icons.language_outlined,
            title: 'Language',
            subtitle: 'Display preference only',
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _PreferenceChips<AppLanguagePreference>(
                  values: AppLanguagePreference.values,
                  selected: state.languagePreference,
                  labelFor: (value) => value.label,
                  onSelected: state.setLanguagePreference,
                ),
                const SizedBox(height: 10),
                Text(
                  'Full translation comes later.',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ],
            ),
          ),
          SectionCard(
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
          SectionCard(
            icon: Icons.speed_outlined,
            title: 'Usage & Limits',
            subtitle: 'Planned server limits',
            child: const Column(
              children: [
                _InfoRow(label: 'Flashcards', value: '120/day'),
                _InfoRow(label: 'Quiz questions', value: '80/day'),
                _InfoRow(label: 'Uploads', value: '3/day'),
                _InfoRow(label: 'Estimated AI cost', value: r'$0.25/day'),
                SizedBox(height: 8),
                Align(
                  alignment: Alignment.centerLeft,
                  child: Text('Server enforcement is not connected yet.'),
                ),
              ],
            ),
          ),
          SectionCard(
            icon: Icons.support_agent_outlined,
            title: 'Support',
            subtitle: 'No email or network integration yet',
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                OutlinedButton.icon(
                  onPressed: () {},
                  icon: const Icon(Icons.bug_report_outlined),
                  label: const Text('Report a bug placeholder'),
                ),
                const SizedBox(height: 8),
                OutlinedButton.icon(
                  onPressed: () {},
                  icon: const Icon(Icons.contact_support_outlined),
                  label: const Text('Contact support placeholder'),
                ),
                const SizedBox(height: 8),
                OutlinedButton.icon(
                  onPressed: () {},
                  icon: const Icon(Icons.feedback_outlined),
                  label: const Text('Send feedback placeholder'),
                ),
              ],
            ),
          ),
          SectionCard(
            icon: Icons.info_outline,
            title: 'About / Debug',
            subtitle: 'Prototype diagnostics',
            child: Column(
              children: [
                const _InfoRow(
                  label: 'App version',
                  value: '0.1.0 placeholder',
                ),
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
      bottomNavigationBar: const AppBottomNav(),
    );
  }

  String _backendModeLabel(AppBackendMode mode) {
    return switch (mode) {
      AppBackendMode.mock => 'mock',
      AppBackendMode.supabase => 'supabase',
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
      builder: (_) => _EditNameDialog(initialName: _editableName(auth)),
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
    return AlertDialog(
      title: const Text('Edit name'),
      content: TextField(
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
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        FilledButton(onPressed: _save, child: const Text('Save')),
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
