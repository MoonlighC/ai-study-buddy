import 'package:flutter/material.dart';

abstract final class AppColors {
  static const canvas = Color(0xFFF1F5FB);
  static const canvasElevated = Color(0xFFF8FAFD);
  static const primary = Color(0xFF315EA8);
  static const secondary = Color(0xFF317C78);
  static const accent = Color(0xFFC98735);
  static const success = Color(0xFF287A55);
  static const warning = Color(0xFFA86418);
  static const error = Color(0xFFB43B46);
  static const info = Color(0xFF356EA8);
  static const textStrong = Color(0xFF182133);
  static const text = Color(0xFF354158);
  static const textMuted = Color(0xFF68748A);
  static const border = Color(0xFFAAB7CB);
  static const atmosphericBlue = Color(0xFFB9D4FF);
  static const atmosphericLilac = Color(0xFFD8C9F2);
  static const atmosphericMint = Color(0xFFBDE3DC);

  static const darkCanvas = Color(0xFF0B1220);
  static const darkCanvasElevated = Color(0xFF111B2C);
  static const darkPrimary = Color(0xFF91B7FF);
  static const darkSecondary = Color(0xFF72C9C1);
  static const darkAccent = Color(0xFFE7B56F);
  static const darkSuccess = Color(0xFF72D6A5);
  static const darkWarning = Color(0xFFF0BA6A);
  static const darkError = Color(0xFFFF929C);
  static const darkInfo = Color(0xFF84B9F1);
  static const darkTextStrong = Color(0xFFF3F6FC);
  static const darkText = Color(0xFFD6DEEA);
  static const darkTextMuted = Color(0xFFAEB9CA);
  static const darkBorder = Color(0xFF718199);
  static const darkAtmosphericBlue = Color(0xFF294D8F);
  static const darkAtmosphericLilac = Color(0xFF4B3678);
  static const darkAtmosphericMint = Color(0xFF245D5B);
}

abstract final class AppSpacing {
  static const xxs = 4.0;
  static const xs = 8.0;
  static const sm = 12.0;
  static const md = 16.0;
  static const lg = 20.0;
  static const xl = 24.0;
  static const xxl = 32.0;
  static const xxxl = 40.0;
  static const huge = 48.0;
  static const giant = 64.0;
}

abstract final class AppRadii {
  static const small = 8.0;
  static const control = 12.0;
  static const card = 16.0;
  static const prominent = 22.0;
  static const navigation = 28.0;
}

abstract final class AppIconSizes {
  static const metadata = 16.0;
  static const control = 20.0;
  static const standard = 24.0;
  static const feature = 32.0;
  static const empty = 48.0;
}

abstract final class AppMotion {
  static const feedback = Duration(milliseconds: 120);
  static const stateChange = Duration(milliseconds: 200);
  static const reveal = Duration(milliseconds: 280);
  static const standardCurve = Curves.easeOutCubic;
  static const emphasizedCurve = Curves.easeInOutCubicEmphasized;
}

abstract final class AppBreakpoints {
  static const phone = 600.0;
  static const desktop = 1024.0;
}

abstract final class AppContentWidths {
  static const reading = 680.0;
  static const standard = 1120.0;
  static const wide = 1360.0;
}

abstract final class AppShellMetrics {
  static const phoneNavigationHorizontalInset = 12.0;
  static const phoneNavigationBottomInset = 10.0;
  static const phoneNavigationScrollClearance = 96.0;
  static const compactRailWorkspaceInset = 104.0;
  static const extendedRailWorkspaceInset = 214.0;
}

abstract final class AppShadows {
  static const soft = [
    BoxShadow(color: Color(0x16263A5D), blurRadius: 22, offset: Offset(0, 8)),
  ];
  static const floating = [
    BoxShadow(color: Color(0x24263A5D), blurRadius: 30, offset: Offset(0, 12)),
  ];
  static const modal = [
    BoxShadow(color: Color(0x3320304D), blurRadius: 40, offset: Offset(0, 18)),
  ];
}
