import 'package:flutter/material.dart';

import '../../app/app_state.dart';
import '../../core/models/subject.dart';
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

    return ResponsiveAppScaffold(
      title: 'Add pasted text',
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
                    decoration: const InputDecoration(
                      labelText: 'Material title',
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    key: const ValueKey('material-content-field'),
                    controller: contentController,
                    minLines: 8,
                    maxLines: 16,
                    decoration: const InputDecoration(
                      labelText: 'Paste lecture text',
                      helperText:
                          'Add enough readable study text for useful learning tools.',
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
                state.isCreatingMaterial ? 'Saving material' : 'Save material',
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
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(message)));
      return;
    }
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('Material saved.')));
    Navigator.pop(context);
  }
}
