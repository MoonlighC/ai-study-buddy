import 'package:flutter/material.dart';

import '../../core/models/flashcard.dart';
import '../../core/models/subject.dart';
import '../../mock/mock_ai_service.dart';

class FlashcardsScreen extends StatefulWidget {
  const FlashcardsScreen({required this.subject, super.key});

  final Subject subject;

  @override
  State<FlashcardsScreen> createState() => _FlashcardsScreenState();
}

class _FlashcardsScreenState extends State<FlashcardsScreen> {
  static const ai = MockAiService();
  late List<Flashcard> cards = ai.flashcardsFor(widget.subject);
  int sessionSize = 5;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Flashcards')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Text(
            widget.subject.name,
            style: Theme.of(context).textTheme.headlineSmall,
          ),
          const SizedBox(height: 12),
          const Text('Study session size'),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            children: [
              for (final size in [5, 10, 20])
                ChoiceChip(
                  label: Text('$size'),
                  selected: sessionSize == size,
                  onSelected: (_) => setState(() => sessionSize = size),
                ),
              ChoiceChip(
                label: const Text('Custom'),
                selected: false,
                onSelected: (_) {},
              ),
            ],
          ),
          const SizedBox(height: 16),
          for (final card in cards)
            Card(
              child: ListTile(
                title: Text(card.front),
                subtitle: Text('${card.back}\nTopic: ${card.topic}'),
                isThreeLine: true,
                trailing: IconButton(
                  tooltip: card.isFavorite ? 'Unfavorite' : 'Favorite',
                  icon: Icon(card.isFavorite ? Icons.star : Icons.star_border),
                  onPressed: () {
                    setState(() {
                      cards = [
                        for (final item in cards)
                          item.id == card.id
                              ? item.copyWith(isFavorite: !item.isFavorite)
                              : item,
                      ];
                    });
                  },
                ),
              ),
            ),
        ],
      ),
    );
  }
}
