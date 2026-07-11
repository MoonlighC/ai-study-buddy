import 'package:flutter/widgets.dart';

import 'tokens.dart';

enum AppWindowClass { phone, tablet, desktop }

abstract final class AppResponsive {
  static AppWindowClass windowClassFor(double width) {
    if (width < AppBreakpoints.phone) return AppWindowClass.phone;
    if (width < AppBreakpoints.desktop) return AppWindowClass.tablet;
    return AppWindowClass.desktop;
  }

  static AppWindowClass of(BuildContext context) =>
      windowClassFor(MediaQuery.sizeOf(context).width);

  static bool isPhone(BuildContext context) =>
      of(context) == AppWindowClass.phone;

  static double horizontalPaddingFor(double width) =>
      switch (windowClassFor(width)) {
        AppWindowClass.phone => 16,
        AppWindowClass.tablet => 24,
        AppWindowClass.desktop => 24,
      };

  static double prominentSurfacePaddingFor(double width) =>
      windowClassFor(width) == AppWindowClass.phone ? 24 : 32;
}
