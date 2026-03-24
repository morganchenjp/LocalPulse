import 'package:flex_color_scheme/flex_color_scheme.dart';
import 'package:flutter/material.dart';

class AppTheme {
  AppTheme._();

  static ThemeData light() {
    return FlexThemeData.light(
      scheme: FlexScheme.blueM3,
      useMaterial3: true,
      surfaceMode: FlexSurfaceMode.highScaffoldLowSurface,
      blendLevel: 4,
      appBarStyle: FlexAppBarStyle.surface,
      subThemesData: const FlexSubThemesData(
        blendOnLevel: 10,
        blendOnColors: false,
        useM2StyleDividerInM3: true,
        inputDecoratorBorderType: FlexInputBorderType.outline,
        inputDecoratorRadius: 12.0,
        chipRadius: 8.0,
        cardRadius: 12.0,
        dialogRadius: 16.0,
        navigationBarLabelBehavior:
            NavigationDestinationLabelBehavior.alwaysShow,
      ),
      visualDensity: FlexColorScheme.comfortablePlatformDensity,
    );
  }

  static ThemeData dark() {
    return FlexThemeData.dark(
      scheme: FlexScheme.blueM3,
      useMaterial3: true,
      surfaceMode: FlexSurfaceMode.highScaffoldLowSurface,
      blendLevel: 8,
      appBarStyle: FlexAppBarStyle.surface,
      subThemesData: const FlexSubThemesData(
        blendOnLevel: 20,
        useM2StyleDividerInM3: true,
        inputDecoratorBorderType: FlexInputBorderType.outline,
        inputDecoratorRadius: 12.0,
        chipRadius: 8.0,
        cardRadius: 12.0,
        dialogRadius: 16.0,
        navigationBarLabelBehavior:
            NavigationDestinationLabelBehavior.alwaysShow,
      ),
      visualDensity: FlexColorScheme.comfortablePlatformDensity,
    );
  }
}
