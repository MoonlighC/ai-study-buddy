import 'package:flutter/material.dart';

Future<int?> showFlashcardGenerationDialog(
  BuildContext context, {
  required int currentCardCount,
}) {
  return showDialog<int>(
    context: context,
    builder: (_) =>
        _FlashcardGenerationDialog(currentCardCount: currentCardCount),
  );
}

class _FlashcardGenerationDialog extends StatefulWidget {
  const _FlashcardGenerationDialog({required this.currentCardCount});

  final int currentCardCount;

  @override
  State<_FlashcardGenerationDialog> createState() =>
      _FlashcardGenerationDialogState();
}

class _FlashcardGenerationDialogState
    extends State<_FlashcardGenerationDialog> {
  static const _presets = [5, 10, 20];
  int _requestedNewCount = 5;
  bool _isCustom = false;
  String? _errorText;
  late final TextEditingController _customController = TextEditingController(
    text: '5',
  );

  @override
  void dispose() {
    _customController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Generate new flashcards'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Choose how many new flashcards to add.'),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final count in _presets)
                  ChoiceChip(
                    label: Text('$count'),
                    selected: !_isCustom && _requestedNewCount == count,
                    onSelected: (_) => setState(() {
                      _isCustom = false;
                      _requestedNewCount = count;
                      _errorText = null;
                    }),
                  ),
                ChoiceChip(
                  label: const Text('Custom'),
                  selected: _isCustom,
                  onSelected: (_) => setState(() {
                    _isCustom = true;
                    _errorText = null;
                  }),
                ),
              ],
            ),
            if (_isCustom) ...[
              const SizedBox(height: 12),
              TextField(
                key: const Key('custom-flashcard-count'),
                controller: _customController,
                autofocus: true,
                keyboardType: const TextInputType.numberWithOptions(
                  signed: true,
                  decimal: true,
                ),
                textInputAction: TextInputAction.done,
                decoration: InputDecoration(
                  labelText: 'New flashcards',
                  errorText: _errorText,
                ),
                onChanged: (_) => setState(() => _errorText = null),
                onSubmitted: (_) => _generate(),
              ),
            ],
            const SizedBox(height: 16),
            Text('Current: ${widget.currentCardCount}'),
            Text('Add: ${_displayedCount()}'),
            Text(
              'After generation: up to ${widget.currentCardCount + _displayedCount()}',
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        FilledButton(onPressed: _generate, child: const Text('Generate')),
      ],
    );
  }

  int _displayedCount() {
    if (!_isCustom) return _requestedNewCount;
    return int.tryParse(_customController.text.trim()) ?? 0;
  }

  void _generate() {
    if (!_isCustom) {
      Navigator.pop(context, _requestedNewCount);
      return;
    }
    final input = _customController.text.trim();
    final requestedNewCount = int.tryParse(input);
    if (requestedNewCount == null || requestedNewCount < 1) {
      setState(() {
        _errorText = 'Enter a whole number from 1 to 30.';
      });
      return;
    }
    if (requestedNewCount > 30) {
      setState(() {
        _errorText = 'Choose no more than 30 flashcards.';
      });
      return;
    }
    Navigator.pop(context, requestedNewCount);
  }
}
