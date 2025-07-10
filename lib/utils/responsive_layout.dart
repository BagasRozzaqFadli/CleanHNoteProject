import 'package:flutter/material.dart';

class ResponsiveLayout {
  static bool isMobile(BuildContext context) =>
      MediaQuery.of(context).size.width < 600;

  static bool isTablet(BuildContext context) =>
      MediaQuery.of(context).size.width >= 600 &&
      MediaQuery.of(context).size.width < 900;

  static bool isDesktop(BuildContext context) =>
      MediaQuery.of(context).size.width >= 900;

  static double getScreenWidth(BuildContext context) =>
      MediaQuery.of(context).size.width;

  static double getScreenHeight(BuildContext context) =>
      MediaQuery.of(context).size.height;

  static double getPaddingScale(BuildContext context) {
    final width = getScreenWidth(context);
    if (width < 360) return 0.8; // Smaller phones
    if (width < 600) return 1.0; // Normal phones
    if (width < 900) return 1.2; // Tablets
    return 1.5; // Desktop
  }

  static double getFontScale(BuildContext context) {
    final width = getScreenWidth(context);
    if (width < 360) return 0.8; // Smaller phones
    if (width < 600) return 1.0; // Normal phones
    if (width < 900) return 1.1; // Tablets
    return 1.2; // Desktop
  }

  static Widget buildResponsive({
    required BuildContext context,
    required Widget mobile,
    Widget? tablet,
    Widget? desktop,
  }) {
    if (isDesktop(context) && desktop != null) {
      return desktop;
    }
    if (isTablet(context) && tablet != null) {
      return tablet;
    }
    return mobile;
  }
}