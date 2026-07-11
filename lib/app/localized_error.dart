import 'package:flutter/widgets.dart';

import '../l10n/l10n_extensions.dart';

class LocalizedErrorFallback {
  const LocalizedErrorFallback._();

  static String generic(BuildContext context) {
    return context.l10n.genericLocalizedError;
  }
}
