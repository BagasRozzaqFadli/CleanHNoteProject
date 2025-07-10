import 'package:flutter/material.dart';
import 'responsive_layout.dart';

class ResponsiveTheme {
  static TextTheme getResponsiveTextTheme(BuildContext context, TextTheme baseTheme) {
    final fontScale = ResponsiveLayout.getFontScale(context);
    
    return baseTheme.copyWith(
      displayLarge: baseTheme.displayLarge?.copyWith(
        fontSize: (baseTheme.displayLarge?.fontSize ?? 34) * fontScale,
      ),
      displayMedium: baseTheme.displayMedium?.copyWith(
        fontSize: (baseTheme.displayMedium?.fontSize ?? 24) * fontScale,
      ),
      displaySmall: baseTheme.displaySmall?.copyWith(
        fontSize: (baseTheme.displaySmall?.fontSize ?? 20) * fontScale,
      ),
      headlineLarge: baseTheme.headlineLarge?.copyWith(
        fontSize: (baseTheme.headlineLarge?.fontSize ?? 28) * fontScale,
      ),
      headlineMedium: baseTheme.headlineMedium?.copyWith(
        fontSize: (baseTheme.headlineMedium?.fontSize ?? 24) * fontScale,
      ),
      headlineSmall: baseTheme.headlineSmall?.copyWith(
        fontSize: (baseTheme.headlineSmall?.fontSize ?? 20) * fontScale,
      ),
      titleLarge: baseTheme.titleLarge?.copyWith(
        fontSize: (baseTheme.titleLarge?.fontSize ?? 18) * fontScale,
      ),
      titleMedium: baseTheme.titleMedium?.copyWith(
        fontSize: (baseTheme.titleMedium?.fontSize ?? 16) * fontScale,
      ),
      titleSmall: baseTheme.titleSmall?.copyWith(
        fontSize: (baseTheme.titleSmall?.fontSize ?? 14) * fontScale,
      ),
      bodyLarge: baseTheme.bodyLarge?.copyWith(
        fontSize: (baseTheme.bodyLarge?.fontSize ?? 16) * fontScale,
      ),
      bodyMedium: baseTheme.bodyMedium?.copyWith(
        fontSize: (baseTheme.bodyMedium?.fontSize ?? 14) * fontScale,
      ),
      bodySmall: baseTheme.bodySmall?.copyWith(
        fontSize: (baseTheme.bodySmall?.fontSize ?? 12) * fontScale,
      ),
      labelLarge: baseTheme.labelLarge?.copyWith(
        fontSize: (baseTheme.labelLarge?.fontSize ?? 14) * fontScale,
      ),
      labelMedium: baseTheme.labelMedium?.copyWith(
        fontSize: (baseTheme.labelMedium?.fontSize ?? 12) * fontScale,
      ),
      labelSmall: baseTheme.labelSmall?.copyWith(
        fontSize: (baseTheme.labelSmall?.fontSize ?? 10) * fontScale,
      ),
    );
  }

  static EdgeInsets getResponsivePadding(BuildContext context, EdgeInsets basePadding) {
    final paddingScale = ResponsiveLayout.getPaddingScale(context);
    
    return EdgeInsets.only(
      left: basePadding.left * paddingScale,
      top: basePadding.top * paddingScale,
      right: basePadding.right * paddingScale,
      bottom: basePadding.bottom * paddingScale,
    );
  }

  static ThemeData getResponsiveThemeData(BuildContext context, ThemeData baseTheme) {
    final responsiveTextTheme = getResponsiveTextTheme(context, baseTheme.textTheme);
    
    return baseTheme.copyWith(
      textTheme: responsiveTextTheme,
      primaryTextTheme: getResponsiveTextTheme(context, baseTheme.primaryTextTheme),
    );
  }
}