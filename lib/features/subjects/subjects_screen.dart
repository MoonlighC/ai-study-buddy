import 'package:flutter/material.dart';

import '../../app/app_state.dart';
import '../../app/routes.dart';
import '../auth/auth_controller.dart';
import '../../shared/widgets/app_bottom_nav.dart';
import '../../shared/widgets/app_page.dart';

class SubjectsScreen extends StatelessWidget {
  const SubjectsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final state = AppStateScope.watch(context);
    final subjects = state.subjects;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Study Workspace'),
        actions: [
          IconButton(
            tooltip: 'Search',
            onPressed: () => Navigator.pushNamed(context, AppRoutes.search),
            icon: const Icon(Icons.search),
          ),
          IconButton(
            tooltip: 'Favorites',
            onPressed: () => Navigator.pushNamed(context, AppRoutes.favorites),
            icon: const Icon(Icons.star_outline),
          ),
          IconButton(
            tooltip: 'Usage limits',
            onPressed: () => Navigator.pushNamed(context, AppRoutes.usage),
            icon: const Icon(Icons.speed_outlined),
          ),
        ],
      ),
      body: AppPage(
        children: [
          Text('Subjects', style: Theme.of(context).textTheme.headlineSmall),
          const SizedBox(height: 8),
          Text(
            'Create folders for lecture notes, summaries, quizzes, and exam prep.',
            style: Theme.of(context).textTheme.bodyMedium,
          ),
          const SizedBox(height: 16),
          if (state.isLoadingSubjects)
            const Card(
              child: ListTile(
                leading: SizedBox.square(
                  dimension: 24,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
                title: Text('Loading synced subjects'),
              ),
            ),
          if (state.subjectSyncErrorMessage != null)
            Card(
              child: ListTile(
                leading: const Icon(Icons.cloud_off_outlined),
                title: Text(state.subjectSyncErrorMessage!),
                subtitle: const Text('Your app is still usable.'),
                trailing: TextButton(
                  onPressed: state.isLoadingSubjects
                      ? null
                      : () =>
                            state.loadSubjectsFor(AuthScope.read(context).user),
                  child: const Text('Retry'),
                ),
              ),
            ),
          if (!state.isLoadingSubjects && subjects.isEmpty)
            const Card(
              child: ListTile(
                leading: Icon(Icons.folder_open_outlined),
                title: Text('No subjects yet'),
                subtitle: Text('Create your first subject to start syncing.'),
              ),
            )
          else
            for (final subject in subjects)
              Card(
                child: ListTile(
                  leading: CircleAvatar(
                    backgroundColor: Color(subject.colorValue),
                    child: Text(
                      subject.name.characters.first.toUpperCase(),
                      style: const TextStyle(color: Colors.white),
                    ),
                  ),
                  title: Text(subject.name),
                  subtitle: Text(
                    subject.description.isEmpty
                        ? 'No description yet'
                        : subject.description,
                  ),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () => Navigator.pushNamed(
                    context,
                    AppRoutes.subjectDetail,
                    arguments: subject,
                  ),
                ),
              ),
          const SizedBox(height: 12),
          OutlinedButton.icon(
            onPressed: state.isCreatingSubject
                ? null
                : () => _createSubject(context),
            icon: const Icon(Icons.create_new_folder_outlined),
            label: Text(
              state.isCreatingSubject ? 'Creating subject' : 'Create subject',
            ),
          ),
          const SizedBox(height: 24),
          Wrap(
            spacing: 12,
            runSpacing: 12,
            children: [
              _ModeButton(
                icon: Icons.auto_stories_outlined,
                label: 'After Lecture',
                route: AppRoutes.afterLecture,
              ),
              _ModeButton(
                icon: Icons.event_available_outlined,
                label: 'Exam Prep',
                route: AppRoutes.examPrep,
              ),
            ],
          ),
        ],
      ),
      bottomNavigationBar: const AppBottomNav(),
    );
  }

  Future<void> _createSubject(BuildContext context) async {
    final request = await showDialog<_SubjectDraft>(
      context: context,
      builder: (_) => const _CreateSubjectDialog(),
    );
    if (!context.mounted || request == null) {
      return;
    }
    final state = AppStateScope.read(context);
    final created = await state.createSubjectFor(
      AuthScope.read(context).user,
      name: request.name,
      description: request.description,
      colorValue: request.colorValue,
    );
    if (!context.mounted || created) {
      return;
    }
    final message =
        state.subjectSyncErrorMessage ?? 'Could not create subject.';
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }
}

class _SubjectDraft {
  const _SubjectDraft({
    required this.name,
    required this.description,
    required this.colorValue,
  });

  final String name;
  final String description;
  final int colorValue;
}

class _CreateSubjectDialog extends StatefulWidget {
  const _CreateSubjectDialog();

  @override
  State<_CreateSubjectDialog> createState() => _CreateSubjectDialogState();
}

class _CreateSubjectDialogState extends State<_CreateSubjectDialog> {
  static const _colors = [0xFF2563EB, 0xFF16A34A, 0xFFDB2777, 0xFFF59E0B];

  final _nameController = TextEditingController();
  final _descriptionController = TextEditingController();
  int _selectedColor = _colors.first;
  String? _errorText;

  @override
  void dispose() {
    _nameController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Create subject'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            TextField(
              controller: _nameController,
              autofocus: true,
              textInputAction: TextInputAction.next,
              decoration: InputDecoration(
                labelText: 'Subject name',
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
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _descriptionController,
              textInputAction: TextInputAction.done,
              decoration: const InputDecoration(labelText: 'Description'),
              onSubmitted: (_) => _save(),
            ),
            const SizedBox(height: 16),
            Text('Color', style: Theme.of(context).textTheme.labelLarge),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              children: [
                for (final color in _colors)
                  ChoiceChip(
                    label: const SizedBox.square(dimension: 18),
                    selected: _selectedColor == color,
                    avatar: CircleAvatar(backgroundColor: Color(color)),
                    onSelected: (_) => setState(() => _selectedColor = color),
                  ),
              ],
            ),
          ],
        ),
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
    final name = _nameController.text.trim();
    if (name.isEmpty) {
      setState(() {
        _errorText = 'Enter a subject name.';
      });
      return;
    }
    Navigator.pop(
      context,
      _SubjectDraft(
        name: name,
        description: _descriptionController.text.trim(),
        colorValue: _selectedColor,
      ),
    );
  }
}

class _ModeButton extends StatelessWidget {
  const _ModeButton({
    required this.icon,
    required this.label,
    required this.route,
  });

  final IconData icon;
  final String label;
  final String route;

  @override
  Widget build(BuildContext context) {
    return FilledButton.tonalIcon(
      onPressed: () => Navigator.pushNamed(context, route),
      icon: Icon(icon),
      label: Text(label),
    );
  }
}
