import 'package:flutter/material.dart';

import '../../core/models/subject.dart';
import '../../mock/mock_ai_service.dart';

class AiTeacherScreen extends StatelessWidget {
  const AiTeacherScreen({required this.subject, super.key});

  final Subject subject;
  static const ai = MockAiService();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('AI Teacher')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Text(subject.name, style: Theme.of(context).textTheme.headlineSmall),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: const [
              ActionChip(label: Text('Explain simpler'), onPressed: null),
              ActionChip(label: Text('Give another example'), onPressed: null),
              ActionChip(label: Text('Ask a question'), onPressed: null),
            ],
          ),
          const SizedBox(height: 16),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(
                        Icons.psychology_alt_outlined,
                        color: Theme.of(context).colorScheme.primary,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        'Mock answer',
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Text(ai.aiTeacherAnswerFor(subject)),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
