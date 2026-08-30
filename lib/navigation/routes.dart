import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../pages/character_page.dart';
import '../pages/person_page.dart';
import '../pages/proxy_settings_page.dart';
import '../pages/subject_community_page.dart';
import '../pages/subject_detail_page.dart';
import '../pages/subject_topic_page.dart';
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

  static Future<T?> pushProxySettings<T>(BuildContext context) =>
      Navigator.of(context).push<T>(_route((_) => const ProxySettingsPage()));

  static Future<T?> pushSubjectTopic<T>(BuildContext context, int topicId) =>
      Navigator.of(
        context,
      ).push<T>(_route((_) => SubjectTopicPage(topicId: topicId)));

  static Future<T?> pushSubjectCommunity<T>(
    BuildContext context, {
    required int subjectId,
    required int subjectType,
    int initialTab = 0,
  }) => Navigator.of(context).push<T>(
    _route(
      (_) => SubjectCommunityPage(
        subjectId: subjectId,
        subjectType: subjectType,
        initialTab: initialTab,
      ),
    ),
  );

  static Future<void> openSubjectTopic(BuildContext context, int topicId) =>
      _openExternal(
        context,
        Uri.parse('https://bgm.tv/subject/topic/$topicId'),
      );

  static Future<void> openBlog(BuildContext context, int blogId) =>
      _openExternal(context, Uri.parse('https://bgm.tv/blog/$blogId'));

  static Future<void> _openExternal(BuildContext context, Uri uri) async {
    final opened = await launchUrl(uri, mode: LaunchMode.externalApplication);
    if (!opened && context.mounted) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('无法打开链接')));
    }
  }
}
