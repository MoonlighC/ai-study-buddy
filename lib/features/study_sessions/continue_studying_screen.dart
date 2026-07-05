import 'package:flutter/material.dart';

import '../../mock/mock_data.dart';

class ContinueStudyingScreen extends StatelessWidget {
  const ContinueStudyingScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final weakTopics = MockData.weakTopics.take(3);

    return Scaffold(
      appBar: AppBar(title: const Text('Continue Studying')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Text(
            'Today\'s recommended session',
            style: Theme.of(context).textTheme.headlineSmall,
          ),
          const SizedBox(height: 12),
          const Card(
            child: ListTile(
              leading: Icon(Icons.eco_outlined),
              title: Text('Biology review'),
              subtitle: Text(
                'Read the summary, study 8 flashcards, then retake the quick quiz.',
              ),
            ),
          ),
          const Card(
            child: ListTile(
              leading: Icon(Icons.style_outlined),
              title: Text('Due flashcards'),
              subtitle: Text('8 Biology cards are ready for review.'),
            ),
          ),
          const Card(
            child: ListTile(
              leading: Icon(Icons.quiz_outlined),
              title: Text('Last quiz score'),
              subtitle: Text('Biology quick quiz: 80%'),
            ),
          ),
          const SizedBox(height: 12),
          Text('Weak topics', style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 8),
          for (final topic in weakTopics)
            Card(
              child: ListTile(
                leading: const Icon(Icons.warning_amber_outlined),
                title: Text(topic.title),
                subtitle: Text(topic.reason),
              ),
            ),
        ],
      ),
    );
  }
}
