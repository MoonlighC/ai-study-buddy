import 'package:flutter/material.dart';

import '../../app/app_state.dart';
import '../../core/models/subject.dart';
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

    return Scaffold(
      appBar: AppBar(title: const Text('Add pasted text')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Text(
            widget.subject.name,
            style: Theme.of(context).textTheme.titleLarge,
          ),
          const SizedBox(height: 16),
          TextField(
            controller: titleController,
            decoration: const InputDecoration(labelText: 'Material title'),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: contentController,
            minLines: 8,
            maxLines: 12,
            decoration: const InputDecoration(
              labelText: 'Paste lecture text',
              alignLabelWithHint: true,
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
