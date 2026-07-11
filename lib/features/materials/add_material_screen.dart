import 'package:flutter/material.dart';

import '../../app/app_state.dart';
import '../../core/models/subject.dart';
import '../../l10n/l10n_extensions.dart';
import '../../shared/widgets/glass_components.dart';
import '../../shared/widgets/responsive_app_scaffold.dart';
import '../auth/auth_controller.dart';

class AddMaterialScreen extends StatefulWidget {
  const AddMaterialScreen({required this.subject, super.key});

  final Subject subject;

  @override
  State<AddMaterialScreen> createState() => _AddMaterialScreenState();
}

class _AddMaterialScreenState extends State<AddMaterialScreen> {
  final titleController = TextEditingController();
  final contentController = TextEditingController();

  @override
  void dispose() {
    titleController.dispose();
    contentController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final state = AppStateScope.watch(context);
    final l10n = context.l10n;

    return ResponsiveAppScaffold(
      title: l10n.materialAddTitle,
      subtitle: widget.subject.name,
      showBack: true,
      body: ResponsiveContent(
        width: ResponsiveContentWidth.reading,
        child: ListView(
          key: const ValueKey('pasted-text-scroll-view'),
          keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
          padding: EdgeInsets.only(
            bottom: MediaQuery.viewInsetsOf(context).bottom,
          ),
          children: [
            Text(
              widget.subject.name,
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 16),
            GlassCard(
              key: const ValueKey('pasted-text-editor'),
              reading: true,
              child: Column(
                children: [
                  TextField(
                    key: const ValueKey('material-title-field'),
                    controller: titleController,
                    textInputAction: TextInputAction.next,
                    decoration: InputDecoration(
                      labelText: l10n.materialTitleLabel,
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    key: const ValueKey('material-content-field'),
                    controller: contentController,
                    minLines: 8,
                    maxLines: 16,
                    decoration: InputDecoration(
                      labelText: l10n.materialPasteTextLabel,
                      helperText: l10n.materialAddIntro,
                      alignLabelWithHint: true,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            FilledButton.icon(
              onPressed: state.isCreatingMaterial
                  ? null
                  : () => _saveMaterial(context),
              icon: const Icon(Icons.save_outlined),
              label: Text(
                state.isCreatingMaterial
                    ? l10n.materialSavingMaterial
                    : l10n.materialSaveMaterial,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _saveMaterial(BuildContext context) async {
    final state = AppStateScope.read(context);
    final saved = await state.createMaterialFor(
      AuthScope.read(context).user,
      subjectId: widget.subject.id,
      title: titleController.text,
      content: contentController.text,
    );
    if (!context.mounted) {
      return;
    }
    if (!saved) {
      final message =
          state.materialSyncErrorMessage ?? 'Could not save material.';
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(context.localizedSafeMessage(message))),
      );
      return;
    }
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(context.l10n.materialSaved)));
    Navigator.pop(context);
  }
}
