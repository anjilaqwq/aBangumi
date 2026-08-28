import 'package:flutter/material.dart';

import 'app_colors.dart';

/// 衬线字体族：无字体资源，直接使用系统衬线回退。
const String kSerifFamily = 'serif';

/// 衬线回退列表：当 'serif' 无法解析时按序回退到常见中文/西文衬线。
const List<String> kSerifFamilyFallback = <String>[
  'serif',
  'Noto Serif CJK SC',
  'Noto Serif SC',
  'Songti SC',
  'SimSun',
  'Yu Mincho',
  'Georgia',
  'Times New Roman',
];

/// 克制的圆角（日式极简：细线、小圆角）。
const BorderRadius kRestrainedRadius = BorderRadius.all(Radius.circular(4));

/// 日式极简主题：仅浅色、Material 3，无阴影无渐变、hairline 细线、小圆角。
abstract final class AppTheme {
  static ThemeData light() {
    const ColorScheme scheme = ColorScheme.light(
      primary: AppColors.vermilion,
      onPrimary: Color(0xFFFFFFFF),
      primaryContainer: Color(0xFFF2EBE2),
      onPrimaryContainer: AppColors.ink,
      secondary: AppColors.muted,
      onSecondary: Color(0xFFFFFFFF),
      secondaryContainer: Color(0xFFECE8E0),
      onSecondaryContainer: AppColors.ink,
      surface: AppColors.paper,
      onSurface: AppColors.ink,
      surfaceContainerHighest: Color(0xFFEFEDE7),
      onSurfaceVariant: AppColors.muted,
      outline: AppColors.line,
      outlineVariant: AppColors.line,
      shadow: Colors.transparent,
      scrim: Colors.black,
    );

    return ThemeData(
      useMaterial3: true,
      colorScheme: scheme,
      scaffoldBackgroundColor: AppColors.paper,
      canvasColor: AppColors.paper,
      fontFamily: kSerifFamily,
      fontFamilyFallback: kSerifFamilyFallback,
      splashFactory: NoSplash.splashFactory,
      highlightColor: Colors.transparent,
      textTheme: _textTheme(),
      appBarTheme: const AppBarTheme(
        backgroundColor: AppColors.paper,
        foregroundColor: AppColors.ink,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: false,
        titleTextStyle: TextStyle(
          fontFamily: kSerifFamily,
          fontSize: 17,
          fontWeight: FontWeight.w500,
          color: AppColors.ink,
          letterSpacing: 0.5,
        ),
      ),
      cardTheme: const CardThemeData(
        color: AppColors.paper,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(
          borderRadius: kRestrainedRadius,
          side: BorderSide(color: AppColors.line),
        ),
      ),
      dividerTheme: const DividerThemeData(
        color: AppColors.line,
        thickness: 1,
        space: 1,
      ),
      chipTheme: ChipThemeData(
        backgroundColor: AppColors.paper,
        selectedColor: scheme.secondaryContainer,
        side: const BorderSide(color: AppColors.line),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(3)),
        elevation: 0,
        pressElevation: 0,
        labelStyle: const TextStyle(
          fontFamily: kSerifFamily,
          fontSize: 12,
          fontWeight: FontWeight.w400,
          color: AppColors.ink,
        ),
        secondaryLabelStyle: const TextStyle(
          fontFamily: kSerifFamily,
          fontSize: 12,
          fontWeight: FontWeight.w500,
          color: AppColors.ink,
        ),
      ),
      bottomNavigationBarTheme: const BottomNavigationBarThemeData(
        backgroundColor: AppColors.paper,
        selectedItemColor: AppColors.vermilion,
        unselectedItemColor: AppColors.muted,
        elevation: 0,
        type: BottomNavigationBarType.fixed,
        selectedLabelStyle: TextStyle(
          fontFamily: kSerifFamily,
          fontSize: 11,
          fontWeight: FontWeight.w500,
          letterSpacing: 2,
        ),
        unselectedLabelStyle: TextStyle(
          fontFamily: kSerifFamily,
          fontSize: 11,
          fontWeight: FontWeight.w400,
          letterSpacing: 2,
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: AppColors.ink,
          foregroundColor: Colors.white,
          elevation: 0,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
          textStyle: const TextStyle(
            fontFamily: kSerifFamily,
            fontSize: 14,
            fontWeight: FontWeight.w500,
            letterSpacing: 0.5,
          ),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: AppColors.vermilion,
          textStyle: const TextStyle(
            fontFamily: kSerifFamily,
            fontSize: 13,
            fontWeight: FontWeight.w500,
            letterSpacing: 0.5,
          ),
        ),
      ),
      progressIndicatorTheme: const ProgressIndicatorThemeData(
        color: AppColors.muted,
        linearTrackColor: AppColors.line,
        circularTrackColor: AppColors.line,
      ),
    );
  }

  /// 衬线正文与标题：标题字重 ≤ 500，正文行高宽裕（「間」）。
  static TextTheme _textTheme() {
    return const TextTheme(
      headlineLarge: TextStyle(
        fontFamily: kSerifFamily,
        fontSize: 30,
        fontWeight: FontWeight.w500,
        color: AppColors.ink,
        height: 1.4,
        letterSpacing: 0.5,
      ),
      headlineMedium: TextStyle(
        fontFamily: kSerifFamily,
        fontSize: 26,
        fontWeight: FontWeight.w500,
        color: AppColors.ink,
        height: 1.4,
        letterSpacing: 0.5,
      ),
      headlineSmall: TextStyle(
        fontFamily: kSerifFamily,
        fontSize: 22,
        fontWeight: FontWeight.w500,
        color: AppColors.ink,
        height: 1.4,
        letterSpacing: 0.5,
      ),
      titleLarge: TextStyle(
        fontFamily: kSerifFamily,
        fontSize: 20,
        fontWeight: FontWeight.w500,
        color: AppColors.ink,
        height: 1.4,
        letterSpacing: 0.5,
      ),
      titleMedium: TextStyle(
        fontFamily: kSerifFamily,
        fontSize: 16,
        fontWeight: FontWeight.w500,
        color: AppColors.ink,
        height: 1.4,
        letterSpacing: 0.3,
      ),
      titleSmall: TextStyle(
        fontFamily: kSerifFamily,
        fontSize: 14,
        fontWeight: FontWeight.w500,
        color: AppColors.ink,
        height: 1.4,
        letterSpacing: 0.3,
      ),
      bodyLarge: TextStyle(
        fontFamily: kSerifFamily,
        fontSize: 16,
        fontWeight: FontWeight.w400,
        color: AppColors.ink,
        height: 1.8,
        letterSpacing: 0.2,
      ),
      bodyMedium: TextStyle(
        fontFamily: kSerifFamily,
        fontSize: 14,
        fontWeight: FontWeight.w400,
        color: AppColors.ink,
        height: 1.7,
        letterSpacing: 0.2,
      ),
      bodySmall: TextStyle(
        fontFamily: kSerifFamily,
        fontSize: 12,
        fontWeight: FontWeight.w400,
        color: AppColors.muted,
        height: 1.6,
        letterSpacing: 0.2,
      ),
      labelLarge: TextStyle(
        fontFamily: kSerifFamily,
        fontSize: 14,
        fontWeight: FontWeight.w500,
        color: AppColors.ink,
        letterSpacing: 0.5,
      ),
      labelMedium: TextStyle(
        fontFamily: kSerifFamily,
        fontSize: 12,
        fontWeight: FontWeight.w500,
        color: AppColors.muted,
        letterSpacing: 0.5,
      ),
      labelSmall: TextStyle(
        fontFamily: kSerifFamily,
        fontSize: 11,
        fontWeight: FontWeight.w400,
        color: AppColors.muted,
        letterSpacing: 2,
      ),
    );
  }
}
