import 'package:flutter/material.dart';

class AppColors {
  AppColors._();

  static const Color pageBg = Color(0xFFEDF2FF);
  static const Color surface = Color(0xFFFFFFFF);
  static const Color surfaceSoft = Color(0xFFF7F9FF);

  static const Color ink = Color(0xFF0D1B3E);
  static const Color inkMuted = Color(0xFF3A4A72);
  static const Color inkFaint = Color(0xFF7A8AAE);
  static const Color dark = Color(0xFF0D2457);

  static const Color brandBlue = Color(0xFF1E88E5);
  static const Color brandBlueDark = Color(0xFF1565C0);
  static const Color brandOrange = Color(0xFFFF9800);
  static const Color brandOrangeDark = Color(0xFFF57C00);
  static const Color brandGreen = Color(0xFF1A7A44);
  static const Color brandGreenDark = Color(0xFF135A32);

  static const Color success = Color(0xFF1A7A44);
  static const Color warning = Color(0xFFB85C00);
  static const Color danger = Color(0xFFC23D2D);

  static const Color borderSoft = Color(0xFFE1E7F5);
  static const Color border = Color(0xFFCCD5EA);

  static const Color sectionYellow = Color(0xFFFFF4D6);
  static const Color sectionPeach = Color(0xFFFFE4CC);
  static const Color sectionMint = Color(0xFFDCEFE4);
  static const Color sectionSky = Color(0xFFE3F2FD);
  static const Color sectionLavender = Color(0xFFEDE7F6);
}

class AppSpacing {
  AppSpacing._();
  static const double xs = 4;
  static const double sm = 8;
  static const double md = 12;
  static const double lg = 16;
  static const double xl = 24;
  static const double xxl = 32;
}

class AppRadius {
  AppRadius._();
  static const double sm = 8;
  static const double md = 12;
  static const double lg = 18;
  static const double xl = 24;
  static const double full = 9999;

  static const BorderRadius brSm = BorderRadius.all(Radius.circular(sm));
  static const BorderRadius brMd = BorderRadius.all(Radius.circular(md));
  static const BorderRadius brLg = BorderRadius.all(Radius.circular(lg));
  static const BorderRadius brXl = BorderRadius.all(Radius.circular(xl));
}

class AppShadow {
  AppShadow._();

  static const List<BoxShadow> card = [
    BoxShadow(
      color: Color(0x14101828),
      blurRadius: 16,
      offset: Offset(0, 4),
    ),
  ];

  static const List<BoxShadow> soft = [
    BoxShadow(
      color: Color(0x0A101828),
      blurRadius: 8,
      offset: Offset(0, 2),
    ),
  ];
}
