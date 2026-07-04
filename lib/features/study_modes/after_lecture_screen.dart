import 'package:flutter/material.dart';

class AfterLectureScreen extends StatelessWidget {
  const AfterLectureScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('After Lecture')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Text(
            'Summary + quick comprehension quiz',
            style: Theme.of(context).textTheme.headlineSmall,
          ),
          const SizedBox(height: 12),
          const Card(
            child: ListTile(
              leading: Icon(Icons.summarize_outlined),
              title: Text('Mock summary'),
              subtitle: Text('A short recap appears here after generation.'),
            ),
          ),
          const Card(
            child: ListTile(
              leading: Icon(Icons.quiz_outlined),
              title: Text('Quick quiz'),
              subtitle: Text('A few comprehension questions appear here.'),
            ),
          ),
        ],
      ),
    );
  }
}
