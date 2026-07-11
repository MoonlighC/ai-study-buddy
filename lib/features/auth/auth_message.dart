import 'package:flutter/material.dart';

import '../../app/design_system/tokens.dart';
import '../../l10n/l10n_extensions.dart';

class AuthMessage extends StatelessWidget {
  const AuthMessage({required this.message, this.isError = false, super.key});

  final String message;
  final bool isError;

  @override
  Widget build(BuildContext context) {
    final localizedMessage = context.localizedSafeMessage(message);
    final semanticsLabel = isError
        ? context.l10n.commonErrorSemantics
        : context.l10n.commonStatusSemantics;
    final colorScheme = Theme.of(context).colorScheme;
    final background = isError
        ? colorScheme.errorContainer
        : colorScheme.secondaryContainer;
    final foreground = isError
        ? colorScheme.onErrorContainer
        : colorScheme.onSecondaryContainer;

    return Semantics(
      liveRegion: true,
      label: '$semanticsLabel: $localizedMessage',
      child: Container(
        padding: const EdgeInsets.all(AppSpacing.sm),
        decoration: BoxDecoration(
          color: background.withValues(alpha: 0.96),
          borderRadius: BorderRadius.circular(AppRadii.control),
          border: Border.all(color: foreground.withValues(alpha: 0.28)),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(
              isError ? Icons.error_outline : Icons.info_outline,
              color: foreground,
              semanticLabel: semanticsLabel,
            ),
            const SizedBox(width: AppSpacing.sm),
            Expanded(
              child: Text(
                localizedMessage,
                style: TextStyle(color: foreground),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
