import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../app/app_state.dart';
import '../../app/design_system/responsive.dart';
import '../../app/design_system/theme_extensions.dart';
import '../../app/design_system/tokens.dart';
import '../../app/routes.dart';
import '../../core/models/subject.dart';
import '../../shared/widgets/glass_components.dart';
import '../../shared/widgets/responsive_app_scaffold.dart';
import '../../shared/widgets/state_views.dart';
import '../auth/auth_controller.dart';

class SubjectsScreen extends StatelessWidget {
  const SubjectsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final state = AppStateScope.watch(context);
    final subjects = state.subjects;

    return ResponsiveAppScaffold(
      title: 'Subjects',
      subtitle: 'Study workspace',
      activeRoute: AppRoutes.subjects,
      body: SingleChildScrollView(
        key: const ValueKey('subjects-scroll-view'),
        child: ResponsiveContent(
          width: ResponsiveContentWidth.wide,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _SubjectsHeader(
                creating: state.isCreatingSubject,
                onCreate: () => _createSubject(context),
              ),
              const SizedBox(height: AppSpacing.xl),
              if (state.isLoadingSubjects && subjects.isEmpty)
                const GlassSurface(
                  child: LoadingState(label: 'Loading synced subjects'),
                ),
              if (state.subjectSyncErrorMessage != null) ...[
                GlassSurface(
                  child: ErrorRetryState(
                    message: state.subjectSyncErrorMessage!,
                    supportingText: subjects.isEmpty
                        ? 'Your app is still usable.'
                        : 'Showing the subjects currently available.',
                    onRetry: state.isLoadingSubjects
                        ? null
                        : () => state.loadSubjectsFor(
                            AuthScope.read(context).user,
                          ),
                  ),
                ),
                if (subjects.isNotEmpty) const SizedBox(height: AppSpacing.md),
              ],
              if (!state.isLoadingSubjects &&
                  subjects.isEmpty &&
                  state.subjectSyncErrorMessage == null)
                GlassSurface(
                  child: EmptyState(
                    title: 'No subjects yet',
                    message: 'Create your first subject to start syncing.',
                    icon: Icons.folder_open_outlined,
                    action: FilledButton.icon(
                      onPressed: state.isCreatingSubject
                          ? null
                          : () => _createSubject(context),
                      icon: const Icon(Icons.create_new_folder_outlined),
                      label: const Text('Create subject'),
                    ),
                  ),
                ),
              if (subjects.isNotEmpty)
                _SubjectsGrid(subjects: subjects, state: state),
              const SizedBox(height: AppSpacing.xl),
              Wrap(
                spacing: AppSpacing.sm,
                runSpacing: AppSpacing.sm,
                children: [
                  FilledButton.tonalIcon(
                    onPressed: () =>
                        Navigator.pushNamed(context, AppRoutes.afterLecture),
                    icon: const Icon(Icons.auto_stories_outlined),
                    label: const Text('After Lecture'),
                  ),
                  FilledButton.tonalIcon(
                    onPressed: () =>
                        Navigator.pushNamed(context, AppRoutes.examPrep),
                    icon: const Icon(Icons.event_available_outlined),
                    label: const Text('Exam Prep'),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _createSubject(BuildContext context) async {
    final request = await showDialog<_SubjectDraft>(
      context: context,
      builder: (_) => const _CreateSubjectDialog(),
    );
    if (!context.mounted || request == null) return;
    final state = AppStateScope.read(context);
    final created = await state.createSubjectFor(
      AuthScope.read(context).user,
      name: request.name,
      description: request.description,
      colorValue: request.colorValue,
    );
    if (!context.mounted || created) return;
    final message =
        state.subjectSyncErrorMessage ?? 'Could not create subject.';
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }
}

class _SubjectsHeader extends StatelessWidget {
  const _SubjectsHeader({required this.creating, required this.onCreate});
  final bool creating;
  final VoidCallback onCreate;

  @override
  Widget build(BuildContext context) => Wrap(
    spacing: AppSpacing.xl,
    runSpacing: AppSpacing.md,
    crossAxisAlignment: WrapCrossAlignment.center,
    alignment: WrapAlignment.spaceBetween,
    children: [
      ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 650),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Your subjects',
              style: Theme.of(context).textTheme.displaySmall,
            ),
            const SizedBox(height: AppSpacing.xs),
            Text(
              'Create focused spaces for lecture notes, summaries, quizzes, and exam prep.',
              style: Theme.of(context).textTheme.bodyLarge,
            ),
          ],
        ),
      ),
      FilledButton.icon(
        key: const ValueKey('subjects-create-button'),
        onPressed: creating ? null : onCreate,
        icon: const Icon(Icons.create_new_folder_outlined),
        label: Text(creating ? 'Creating subject' : 'Create subject'),
      ),
    ],
  );
}

class _SubjectsGrid extends StatelessWidget {
  const _SubjectsGrid({required this.subjects, required this.state});
  final List<Subject> subjects;
  final AppState state;

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) {
      final scale = MediaQuery.textScalerOf(context).scale(1);
      final minimum = scale >= 1.8 ? 480.0 : 260.0;
      final gap = AppSpacing.md;
      final possible = ((constraints.maxWidth + gap) / (minimum + gap)).floor();
      final windowMax = switch (AppResponsive.windowClassFor(
        constraints.maxWidth,
      )) {
        AppWindowClass.phone => 1,
        AppWindowClass.tablet => 2,
        AppWindowClass.desktop => 3,
      };
      final columns = possible.clamp(1, windowMax);
      final width = (constraints.maxWidth - gap * (columns - 1)) / columns;

      return Wrap(
        key: ValueKey('subjects-grid-$columns'),
        spacing: gap,
        runSpacing: gap,
        children: [
          for (final subject in subjects)
            SizedBox(
              width: width,
              child: _SubjectCard(
                subject: subject,
                materialCount:
                    state.isLoadingMaterials ||
                        state.materialSyncErrorMessage != null
                    ? null
                    : state.materialsFor(subject.id).length,
              ),
            ),
        ],
      );
    },
  );
}

class _SubjectCard extends StatelessWidget {
  const _SubjectCard({required this.subject, required this.materialCount});
  final Subject subject;
  final int? materialCount;

  @override
  Widget build(BuildContext context) {
    final color = safeSubjectColor(subject.colorValue);
    final initial = subject.name.trim().isEmpty
        ? '?'
        : subject.name.trim().characters.first.toUpperCase();
    return Semantics(
      button: true,
      label: 'Open ${subject.name}',
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          key: ValueKey('subject-card-${subject.id}'),
          borderRadius: BorderRadius.circular(AppRadii.card),
          onTap: () => Navigator.pushNamed(
            context,
            AppRoutes.subjectDetail,
            arguments: subject,
          ),
          child: GlassCard(
            tint: color.withValues(alpha: 0.12),
            child: ConstrainedBox(
              constraints: const BoxConstraints(minHeight: 132),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: 48,
                    height: 48,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: color,
                      borderRadius: BorderRadius.circular(AppRadii.control),
                      boxShadow: AppShadows.soft,
                    ),
                    child: Text(
                      initial,
                      style: const TextStyle(color: Colors.white),
                    ),
                  ),
                  const SizedBox(width: AppSpacing.md),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          subject.name,
                          style: Theme.of(context).textTheme.titleLarge,
                        ),
                        const SizedBox(height: AppSpacing.xxs),
                        Text(
                          subject.description.isEmpty
                              ? 'No description yet'
                              : subject.description,
                        ),
                        if (materialCount != null) ...[
                          const SizedBox(height: AppSpacing.sm),
                          Text(
                            '$materialCount currently loaded ${materialCount == 1 ? 'material' : 'materials'}',
                            style: Theme.of(context).textTheme.labelLarge,
                          ),
                        ],
                      ],
                    ),
                  ),
                  const Icon(Icons.chevron_right),
                ],
              ),
            ),
          ),
        ),
      ),
    );
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
  static const _colors = [
    (value: 0xFF2563EB, name: 'Blue'),
    (value: 0xFF16A34A, name: 'Green'),
    (value: 0xFFDB2777, name: 'Pink'),
    (value: 0xFFF59E0B, name: 'Amber'),
  ];
  final _nameController = TextEditingController();
  final _descriptionController = TextEditingController();
  int _selectedColor = _colors.first.value;
  String? _errorText;
  bool _submitted = false;

  @override
  void dispose() {
    _nameController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => GlassDialog(
    child: ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 480),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'Create subject',
              style: Theme.of(context).textTheme.headlineSmall,
            ),
            const SizedBox(height: AppSpacing.lg),
            TextField(
              controller: _nameController,
              enabled: !_submitted,
              autofocus: true,
              textInputAction: TextInputAction.next,
              decoration: InputDecoration(
                labelText: 'Subject name',
                errorText: _errorText,
              ),
              onChanged: (_) {
                if (_errorText != null) setState(() => _errorText = null);
              },
            ),
            const SizedBox(height: AppSpacing.sm),
            TextField(
              controller: _descriptionController,
              enabled: !_submitted,
              textInputAction: TextInputAction.done,
              decoration: const InputDecoration(labelText: 'Description'),
              onSubmitted: (_) => _save(),
            ),
            const SizedBox(height: AppSpacing.md),
            Text('Color', style: Theme.of(context).textTheme.labelLarge),
            const SizedBox(height: AppSpacing.xs),
            Wrap(
              spacing: AppSpacing.xs,
              runSpacing: AppSpacing.xs,
              children: [
                for (final option in _colors)
                  Semantics(
                    button: true,
                    selected: _selectedColor == option.value,
                    label: '${option.name} subject color',
                    child: Tooltip(
                      message: option.name,
                      child: Focus(
                        onKeyEvent: (_, event) {
                          if (!_submitted &&
                              event is KeyDownEvent &&
                              (event.logicalKey == LogicalKeyboardKey.enter ||
                                  event.logicalKey ==
                                      LogicalKeyboardKey.space)) {
                            setState(() => _selectedColor = option.value);
                            return KeyEventResult.handled;
                          }
                          return KeyEventResult.ignored;
                        },
                        child: InkWell(
                          key: ValueKey(
                            'subject-color-${option.name.toLowerCase()}',
                          ),
                          onTap: _submitted
                              ? null
                              : () => setState(
                                  () => _selectedColor = option.value,
                                ),
                          borderRadius: BorderRadius.circular(24),
                          child: Container(
                            width: 48,
                            height: 48,
                            decoration: BoxDecoration(
                              color: Color(option.value),
                              shape: BoxShape.circle,
                              border: Border.all(
                                color: _selectedColor == option.value
                                    ? Theme.of(context).colorScheme.onSurface
                                    : Colors.transparent,
                                width: 3,
                              ),
                            ),
                            child: _selectedColor == option.value
                                ? const Icon(Icons.check, color: Colors.white)
                                : null,
                          ),
                        ),
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: AppSpacing.xl),
            Wrap(
              alignment: WrapAlignment.end,
              spacing: AppSpacing.xs,
              children: [
                TextButton(
                  key: const ValueKey('create-subject-cancel'),
                  onPressed: _submitted ? null : () => Navigator.pop(context),
                  child: const Text('Cancel'),
                ),
                FilledButton(
                  key: const ValueKey('create-subject-save'),
                  onPressed: _submitted ? null : _save,
                  child: const Text('Save'),
                ),
              ],
            ),
          ],
        ),
      ),
    ),
  );

  void _save() {
    if (_submitted) return;
    final name = _nameController.text.trim();
    if (name.isEmpty) {
      setState(() => _errorText = 'Enter a subject name.');
      return;
    }
    setState(() => _submitted = true);
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
