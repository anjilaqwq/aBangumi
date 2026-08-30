import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

import '../models/models.dart';
import '../models/private_api_models.dart';
import 'bangumi_api.dart';

/// Read-only enhancements backed by Bangumi's unstable `/p1` private API.
///
/// Core browsing, collections, and authentication continue to use `/v0`.
/// A `/p1` failure must never prevent the primary app features from working.
abstract final class BangumiPrivateApi {
  static const String baseUrl = 'https://next.bgm.tv/p1';
  static const String _ua =
      'aBangumi/1.1.1 (https://github.com/anjilaqwq/aBangumi)';

  static const Map<String, String> _headers = {
    'User-Agent': _ua,
    'Accept': 'application/json',
  };

  static Future<dynamic> _get(String path, {Map<String, String>? query}) async {
    final uri = Uri.parse('$baseUrl$path').replace(queryParameters: query);
    final response = await http
        .get(uri, headers: _headers)
        .timeout(const Duration(seconds: 20));
    if (response.statusCode != 200) throw ApiException(response.statusCode);
    return jsonDecode(utf8.decode(response.bodyBytes));
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
    int type = 2,
    int limit = 12,
    int offset = 0,
  }) async {
    final value = await _get(
      '/trending/subjects',
      query: {'type': '$type', 'limit': '$limit', 'offset': '$offset'},
    );
    final page = _page(value, P1TrendingSubject.fromJson);
    debugPrint('[bgm/p1] trendingSubjects(type=$type) -> ${page.items.length}');
    return page;
  }

  static Future<PageData<P1SubjectTopic>> trendingSubjectTopics({
    int limit = 12,
    int offset = 0,
  }) async {
    final value = await _get(
      '/trending/subjects/topics',
      query: {'limit': '$limit', 'offset': '$offset'},
    );
    final page = _page(value, P1SubjectTopic.fromJson);
    debugPrint('[bgm/p1] trendingTopics -> ${page.items.length}');
    return page;
  }

  static Future<PageData<P1SubjectTopic>> subjectTopics(
    int subjectId, {
    int limit = 20,
    int offset = 0,
  }) async {
    final value = await _get(
      '/subjects/$subjectId/topics',
      query: {'limit': '$limit', 'offset': '$offset'},
    );
    return _page(value, P1SubjectTopic.fromJson);
  }

  static Future<PageData<P1SubjectReview>> subjectReviews(
    int subjectId, {
    int limit = 20,
    int offset = 0,
  }) async {
    final value = await _get(
      '/subjects/$subjectId/reviews',
      query: {'limit': '$limit', 'offset': '$offset'},
    );
    return _page(value, P1SubjectReview.fromJson);
  }

  static Future<PageData<P1SubjectComment>> subjectComments(
    int subjectId, {
    int limit = 20,
    int offset = 0,
  }) async {
    final value = await _get(
      '/subjects/$subjectId/comments',
      query: {'limit': '$limit', 'offset': '$offset'},
    );
    return _page(value, P1SubjectComment.fromJson);
  }

  static Future<P1SubjectCommunity> subjectCommunity(int subjectId) async {
    final values = await Future.wait<dynamic>([
      subjectTopics(subjectId, limit: 4),
      subjectReviews(subjectId, limit: 3),
      subjectComments(subjectId, limit: 4),
    ]);
    return P1SubjectCommunity(
      topics: values[0] as PageData<P1SubjectTopic>,
      reviews: values[1] as PageData<P1SubjectReview>,
      comments: values[2] as PageData<P1SubjectComment>,
    );
  }

  static Future<P1SubjectTopic> subjectTopic(int topicId) async {
    final value = await _get('/subjects/-/topics/$topicId');
    return P1SubjectTopic.fromJson((value as Map).cast<String, dynamic>());
  }
}
