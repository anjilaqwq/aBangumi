import 'package:flutter/material.dart';

import 'app_colors.dart';

/// System sans keeps dense Chinese metadata crisp on small screens.
const String kSerifFamily = 'sans-serif';

/// 衬线回退列表：当 'serif' 无法解析时按序回退到常见中文/西文衬线。
const List<String> kSerifFamilyFallback = <String>[
  'Noto Sans CJK SC',
  'Noto Sans SC',
  'Microsoft YaHei',
  'PingFang SC',
  'Arial',
];

/// 克制的圆角（日式极简：细线、小圆角）。
const BorderRadius kRestrainedRadius = BorderRadius.all(Radius.circular(14));

/// 日式极简主题：仅浅色、Material 3，无阴影无渐变、hairline 细线、小圆角。
abstract final class AppTheme {
  static ThemeData light() {
    const ColorScheme scheme = ColorScheme.light(
      primary: AppColors.vermilion,
      onPrimary: Color(0xFFFFFFFF),
      primaryContainer: Color(0xFFFFE7E9),
      onPrimaryContainer: AppColors.ink,
      secondary: AppColors.blue,
      onSecondary: Color(0xFFFFFFFF),
      secondaryContainer: Color(0xFFE8EEFF),
      onSecondaryContainer: AppColors.ink,
      surface: AppColors.paper,
      onSurface: AppColors.ink,
      surfaceContainerHighest: Color(0xFFEBE9E3),
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
      pageTransitionsTheme: const PageTransitionsTheme(
        builders: <TargetPlatform, PageTransitionsBuilder>{
          TargetPlatform.android: _AppPageTransitionsBuilder(),
          TargetPlatform.iOS: _AppPageTransitionsBuilder(),
          TargetPlatform.macOS: _AppPageTransitionsBuilder(),
          TargetPlatform.windows: _AppPageTransitionsBuilder(),
          TargetPlatform.linux: _AppPageTransitionsBuilder(),
        },
      ),
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
          fontWeight: FontWeight.w800,
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
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(999)),
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
          backgroundColor: AppColors.vermilion,
          foregroundColor: Colors.white,
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
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
        color: AppColors.vermilion,
        linearTrackColor: AppColors.line,
        circularTrackColor: AppColors.line,
      ),
    );
  }

  static ThemeData dark() {
    const paper = Color(0xFF171A22);
    const raised = Color(0xFF242936);
    const ink = Color(0xFFF4F5F7);
    const muted = Color(0xFFB7BECA);
    const line = Color(0xFF3B4252);
    const scheme = ColorScheme.dark(
      primary: AppColors.vermilion,
      onPrimary: Colors.white,
      primaryContainer: Color(0xFF51262D),
      onPrimaryContainer: ink,
      secondary: Color(0xFF8EABFF),
      onSecondary: paper,
      secondaryContainer: raised,
      onSecondaryContainer: ink,
      surface: paper,
      onSurface: ink,
      surfaceContainerHighest: raised,
      onSurfaceVariant: muted,
      outline: line,
      outlineVariant: line,
      shadow: Colors.transparent,
      scrim: Colors.black,
    );
    final base = light();
    return base.copyWith(
      brightness: Brightness.dark,
      colorScheme: scheme,
      scaffoldBackgroundColor: paper,
      canvasColor: paper,
      textTheme: base.textTheme.apply(bodyColor: ink, displayColor: ink),
      iconTheme: const IconThemeData(color: ink),
      primaryIconTheme: const IconThemeData(color: ink),
      appBarTheme: base.appBarTheme.copyWith(
        backgroundColor: paper,
        foregroundColor: ink,
        titleTextStyle: base.appBarTheme.titleTextStyle?.copyWith(color: ink),
      ),
      cardTheme: base.cardTheme.copyWith(
        color: paper,
        shape: const RoundedRectangleBorder(
          borderRadius: kRestrainedRadius,
          side: BorderSide(color: line),
        ),
      ),
      dividerTheme: const DividerThemeData(color: line, thickness: 1, space: 1),
      chipTheme: base.chipTheme.copyWith(
        backgroundColor: paper,
        selectedColor: raised,
        side: const BorderSide(color: line),
        labelStyle: base.chipTheme.labelStyle?.copyWith(color: ink),
        secondaryLabelStyle: base.chipTheme.secondaryLabelStyle?.copyWith(
          color: ink,
        ),
      ),
      bottomNavigationBarTheme: base.bottomNavigationBarTheme.copyWith(
        backgroundColor: paper,
        selectedItemColor: AppColors.vermilion,
        unselectedItemColor: muted,
      ),
      progressIndicatorTheme: const ProgressIndicatorThemeData(
        color: AppColors.vermilion,
        linearTrackColor: line,
        circularTrackColor: line,
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

class _AppPageTransitionsBuilder extends PageTransitionsBuilder {
  const _AppPageTransitionsBuilder();

  @override
  Widget buildTransitions<T>(
    PageRoute<T> route,
    BuildContext context,
    Animation<double> animation,
    Animation<double> secondaryAnimation,
    Widget child,
  ) {
    final curved = CurvedAnimation(
      parent: animation,
      curve: Curves.easeOutCubic,
      reverseCurve: Curves.easeInCubic,
    );
    final slide = Tween<Offset>(
      begin: const Offset(0.055, 0),
      end: Offset.zero,
    ).animate(curved);
    return FadeTransition(
      opacity: curved,
      child: SlideTransition(position: slide, child: child),
    );
  }
}
