import 'package:flutter/material.dart';

import '../pages/character_page.dart';
import '../pages/person_page.dart';
import '../pages/subject_detail_page.dart';
import '../pages/tag_page.dart';

/// 页面导航辅助：统一跳转入口，避免各处散落的 `MaterialPageRoute`。
abstract final class AppRoutes {
  static Route<T> _route<T>(WidgetBuilder builder) =>
      MaterialPageRoute<T>(builder: builder);

  /// 跳转条目详情页。
  static Future<T?> pushSubject<T>(BuildContext context, int subjectId) =>
      Navigator.of(
        context,
      ).push<T>(_route((_) => SubjectDetailPage(subjectId: subjectId)));

  /// 跳转角色页。
  static Future<T?> pushCharacter<T>(BuildContext context, int characterId) =>
      Navigator.of(
        context,
      ).push<T>(_route((_) => CharacterPage(characterId: characterId)));

  /// 跳转人物（声优/演员/制作人员）页。
  static Future<T?> pushPerson<T>(BuildContext context, int personId) =>
      Navigator.of(
        context,
      ).push<T>(_route((_) => PersonPage(personId: personId)));

  /// 跳转标签页。
  static Future<T?> pushTag<T>(BuildContext context, String tag) =>
      Navigator.of(context).push<T>(_route((_) => TagPage(tag: tag)));
}
