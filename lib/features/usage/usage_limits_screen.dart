import 'package:flutter/material.dart';

import '../../mock/mock_data.dart';

class UsageLimitsScreen extends StatelessWidget {
  const UsageLimitsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final log = MockData.usageLogs.first;

    return Scaffold(
      appBar: AppBar(title: const Text('Usage limits')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Text(
            'Backend limits planned',
            style: Theme.of(context).textTheme.headlineSmall,
          ),
          const SizedBox(height: 12),
          const _LimitTile(label: 'Flashcards per day', value: '120'),
          const _LimitTile(label: 'Quiz questions per day', value: '80'),
          const _LimitTile(label: 'Uploads per day', value: '3'),
          const _LimitTile(label: 'Estimated AI cost per day', value: r'$0.25'),
          const SizedBox(height: 16),
          Card(
            child: ListTile(
              leading: const Icon(Icons.receipt_long_outlined),
              title: Text('${log.feature} - ${log.model}'),
              subtitle: Text(
                'user_id=${log.userId}, tokens=${log.inputTokens + log.outputTokens}, cost=${log.estimatedCostUsd}',
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _LimitTile extends StatelessWidget {
  const _LimitTile({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: ListTile(
        title: Text(label),
        trailing: Text(value, style: Theme.of(context).textTheme.titleMedium),
      ),
    );
  }
}
