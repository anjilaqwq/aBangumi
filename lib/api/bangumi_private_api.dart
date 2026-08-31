import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

import '../auth/oauth_config.dart';
import '../models/models.dart';
import '../models/private_api_models.dart';
import '../store/dynamic_cache_store.dart';
import 'bangumi_api.dart';

/// Read-only enhancements backed by Bangumi's unstable `/p1` private API.
///
/// Core browsing, collections, and authentication continue to use `/v0`.
/// A `/p1` failure must never prevent the primary app features from working.
abstract final class BangumiPrivateApi {
  static const String baseUrl = 'https://next.bgm.tv/p1';
  static const String _ua =
      'aBangumi/1.1.1 (https://github.com/anjilaqwq/aBangumi)';

  static Map<String, String> _headers({String? token}) => {
    'User-Agent': _ua,
    'Accept': 'application/json',
    if (token != null && token.isNotEmpty) 'Authorization': 'Bearer $token',
  };

  static Future<dynamic> _get(
    String path, {
    String? token,
    Map<String, String>? query,
    bool forceRefresh = false,
  }) async {
    final authenticated = token != null && token.isNotEmpty;
    final isSession = OAuthConfig.isSessionToken(token);
    final useProxy = isSession || (!authenticated && OAuthConfig.isConfigured);
    final uri = Uri.parse(
      useProxy
          ? '${OAuthConfig.requireAuthBaseUrl()}${OAuthConfig.privateProxyPrefix}$path'
          : '$baseUrl$path',
    ).replace(queryParameters: query);

    Future<dynamic> request() async {
      final response = await http
          .get(
            uri,
            headers: _headers(
              token: isSession
                  ? OAuthConfig.sessionTokenOf(token!)
                  : authenticated
                  ? token
                  : null,
            ),
          )
          .timeout(const Duration(seconds: 20));
      if (response.statusCode != 200) throw ApiException(response.statusCode);
      return jsonDecode(utf8.decode(response.bodyBytes));
    }

    // Authenticated P1 responses can contain per-user and restricted data.
    if (authenticated) return request();
    return DynamicCacheStore.instance.loadJson(
      key: uri.toString(),
      maxAge: const Duration(minutes: 6),
      forceRefresh: forceRefresh,
      loader: request,
    );
  }

  static PageData<T> _page<T>(
    dynamic value,
    T Function(Map<String, dynamic>) parse,
  ) {
    final map = (value as Map).cast<String, dynamic>();
    final items = ((map['data'] as List?) ?? const [])
        .map((item) => parse((item as Map).cast<String, dynamic>()))
        .toList();
    return PageData(
      items: items,
      total: (map['total'] as num?)?.toInt() ?? items.length,
    );
  }

  static Future<PageData<P1TrendingSubject>> trendingSubjects({
    String? token,
    int type = 2,
    int limit = 12,
    int offset = 0,
    bool forceRefresh = false,
  }) async {
    final value = await _get(
      '/trending/subjects',
      token: token,
      query: {'type': '$type', 'limit': '$limit', 'offset': '$offset'},
      forceRefresh: forceRefresh,
    );
    final page = _page(value, P1TrendingSubject.fromJson);
    debugPrint('[bgm/p1] trendingSubjects(type=$type) -> ${page.items.length}');
    return page;
  }

  static Future<PageData<P1SubjectTopic>> trendingSubjectTopics({
    String? token,
    int limit = 12,
    int offset = 0,
    bool forceRefresh = false,
  }) async {
    final value = await _get(
      '/trending/subjects/topics',
      token: token,
      query: {'limit': '$limit', 'offset': '$offset'},
      forceRefresh: forceRefresh,
    );
    final page = _page(value, P1SubjectTopic.fromJson);
    debugPrint('[bgm/p1] trendingTopics -> ${page.items.length}');
    return page;
  }

  static Future<PageData<P1SubjectTopic>> subjectTopics(
    int subjectId, {
    String? token,
    int limit = 20,
    int offset = 0,
  }) async {
    final value = await _get(
      '/subjects/$subjectId/topics',
      token: token,
      query: {'limit': '$limit', 'offset': '$offset'},
    );
    return _page(value, P1SubjectTopic.fromJson);
  }

  static Future<PageData<P1SubjectReview>> subjectReviews(
    int subjectId, {
    String? token,
    int limit = 20,
    int offset = 0,
  }) async {
    final value = await _get(
      '/subjects/$subjectId/reviews',
      token: token,
      query: {'limit': '$limit', 'offset': '$offset'},
    );
    return _page(value, P1SubjectReview.fromJson);
  }

  static Future<PageData<P1SubjectComment>> subjectComments(
    int subjectId, {
    String? token,
    int limit = 20,
    int offset = 0,
  }) async {
    final value = await _get(
      '/subjects/$subjectId/comments',
      token: token,
      query: {'limit': '$limit', 'offset': '$offset'},
    );
    return _page(value, P1SubjectComment.fromJson);
  }

  static Future<P1SubjectCommunity> subjectCommunity(
    int subjectId, {
    String? token,
  }) async {
    final values = await Future.wait<dynamic>([
      subjectTopics(subjectId, token: token, limit: 4),
      subjectReviews(subjectId, token: token, limit: 3),
      subjectComments(subjectId, token: token, limit: 4),
    ]);
    return P1SubjectCommunity(
      topics: values[0] as PageData<P1SubjectTopic>,
      reviews: values[1] as PageData<P1SubjectReview>,
      comments: values[2] as PageData<P1SubjectComment>,
    );
  }

  static Future<P1SubjectTopic> subjectTopic(
    int topicId, {
    String? token,
  }) async {
    final value = await _get('/subjects/-/topics/$topicId', token: token);
    return P1SubjectTopic.fromJson((value as Map).cast<String, dynamic>());
  }
}
