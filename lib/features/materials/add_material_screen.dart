import 'package:flutter/material.dart';

import '../../core/models/subject.dart';

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
            onPressed: () {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Mock material saved locally.')),
              );
              Navigator.pop(context);
            },
            icon: const Icon(Icons.save_outlined),
            label: const Text('Save mock material'),
          ),
        ],
      ),
    );
  }
}
