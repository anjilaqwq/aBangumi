import 'package:flutter/material.dart' show Color;

/// 日式极简配色：米白纸面 + 近黑墨色 + 一点朱红。
///
/// 全部为无透明度的扁平色，静谧克制，无渐变、无阴影。
abstract final class AppColors {
  /// 米白纸面（背景）。
  static const Color paper = Color(0xFFFAFAF7);

  /// 近黑墨色（主文字）。
  static const Color ink = Color(0xFF1A1A18);

  /// 次级文字（暖灰）。
  static const Color muted = Color(0xFF6B675E);

  /// 弱化文字。
  static const Color subtle = Color(0xFFA09A8D);

  /// 细分隔线（暖灰，1px hairline）。
  static const Color line = Color(0xFFD8D5CD);

  /// 朱红：唯一点缀色，谨慎使用（1–2 处）。
  static const Color vermilion = Color(0xFFC3272B);
}
