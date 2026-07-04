import 'package:flutter/material.dart';

class ExamPrepScreen extends StatelessWidget {
  const ExamPrepScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Exam Prep')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Text(
            'Plan from exam date and selected materials',
            style: Theme.of(context).textTheme.headlineSmall,
          ),
          const SizedBox(height: 12),
          TextField(
            readOnly: true,
            decoration: InputDecoration(
              labelText: 'Exam date',
              suffixIcon: IconButton(
                tooltip: 'Pick date placeholder',
                onPressed: () {},
                icon: const Icon(Icons.calendar_today_outlined),
              ),
            ),
          ),
          const SizedBox(height: 12),
          const Card(
            child: ListTile(
              leading: Icon(Icons.checklist_outlined),
              title: Text('Selected materials'),
              subtitle: Text('Later: choose exact notes, PDFs, and images.'),
            ),
          ),
          const Card(
            child: ListTile(
              leading: Icon(Icons.trending_up_outlined),
              title: Text('Weak topics'),
              subtitle: Text('Mock weak-topic tracking for smart study.'),
            ),
          ),
        ],
      ),
    );
  }
}
