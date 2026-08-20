import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

import '../models/models.dart';

class ApiException implements Exception {
  final int statusCode;
  ApiException(this.statusCode);

  @override
  String toString() => '请求失败 (HTTP $statusCode)';
}

class BangumiApi {
  static const String baseUrl = 'https://api.bgm.tv';
  static const String _ua = 'bgm_app/0.1.0 (https://github.com/example/bgm-app)';

  static Map<String, String> _headers({String? token}) => {
        'User-Agent': _ua,
        'Content-Type': 'application/json',
        'Accept': 'application/json',
        if (token != null && token.isNotEmpty) 'Authorization': 'Bearer $token',
      };

  static Future<dynamic> _getJson(Uri uri, {String? token}) async {
    final resp = await http
        .get(uri, headers: _headers(token: token))
        .timeout(const Duration(seconds: 20));
    if (resp.statusCode != 200) throw ApiException(resp.statusCode);
    return jsonDecode(utf8.decode(resp.bodyBytes));
  }

  /// 搜索条目（type 为 null 时不限类型；tags 用于标签页）
  static Future<PageData<Subject>> searchSubjects(String keyword,
      {int? type, int limit = 30, int offset = 0, List<String>? tags}) async {
    final filter = <String, dynamic>{
      if (type != null) 'type': [type],
      if (tags != null && tags.isNotEmpty) 'tag': tags,
    };
    final resp = await http
        .post(
          Uri.parse('$baseUrl/v0/search/subjects'),
          headers: _headers(),
          body: jsonEncode({
            'keyword': keyword,
            if (filter.isNotEmpty) 'filter': filter,
            'limit': limit,
            'offset': offset,
          }),
        )
        .timeout(const Duration(seconds: 20));
    if (resp.statusCode != 200) throw ApiException(resp.statusCode);
    final map = jsonDecode(utf8.decode(resp.bodyBytes)) as Map<String, dynamic>;
    final data = (map['data'] as List?) ?? const [];
    final list =
        data.map((e) => Subject.fromJson(e as Map<String, dynamic>)).toList();
    final total = (map['total'] as num?)?.toInt() ?? list.length;
    debugPrint(
        '[bgm] search "$keyword" (type=$type tag=$tags offset=$offset) -> ${list.length}/$total');
    return PageData(items: list, total: total);
  }

  /// 排行榜 / 浏览条目
  static Future<List<Subject>> topSubjects(
      {int type = 2, int limit = 30, String sort = 'rank'}) async {
    final uri = Uri.parse('$baseUrl/v0/subjects').replace(queryParameters: {
      'type': '$type',
      'sort': sort,
      'limit': '$limit',
    });
    final map = await _getJson(uri) as Map<String, dynamic>;
    final data = (map['data'] as List?) ?? const [];
    final list =
        data.map((e) => Subject.fromJson(e as Map<String, dynamic>)).toList();
    debugPrint('[bgm] topSubjects(type=$type) -> ${list.length} 条');
    return list;
  }

  /// 每日放送
  static Future<List<CalendarDay>> calendar() async {
    final list = await _getJson(Uri.parse('$baseUrl/calendar')) as List;
    final days = list
        .map((e) => CalendarDay.fromJson(e as Map<String, dynamic>))
        .toList();
    debugPrint('[bgm] calendar -> ${days.length} 天');
    return days;
  }

  /// 条目详情
  static Future<Subject> subject(int id) async {
    debugPrint('[bgm] subject($id)');
    final map = await _getJson(Uri.parse('$baseUrl/v0/subjects/$id'))
        as Map<String, dynamic>;
    return Subject.fromJson(map);
  }

  /// 章节列表（本篇）
  static Future<List<Episode>> episodes(int subjectId) async {
    final uri = Uri.parse('$baseUrl/v0/episodes').replace(queryParameters: {
      'subject_id': '$subjectId',
      'type': '0', // 0 = 本篇
      'limit': '200',
      'offset': '0',
    });
    final map = await _getJson(uri) as Map<String, dynamic>;
    final data = (map['data'] as List?) ?? const [];
    return data
        .map((e) => Episode.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  /// 相关条目
  static Future<List<Subject>> relatedSubjects(int subjectId) async {
    final uri = Uri.parse('$baseUrl/v0/subjects/$subjectId/subjects')
        .replace(queryParameters: {'limit': '50'});
    final list = await _getJson(uri) as List;
    return list.map((e) => Subject.fromJson(e as Map<String, dynamic>)).toList();
  }

  /// 角色
  static Future<List<Character>> characters(int subjectId) async {
    final uri = Uri.parse('$baseUrl/v0/subjects/$subjectId/characters')
        .replace(queryParameters: {'limit': '50'});
    final list = await _getJson(uri) as List;
    return list
        .map((e) => Character.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  /// 角色详情
  static Future<Character> character(int id) async {
    debugPrint('[bgm] character($id)');
    final map = await _getJson(Uri.parse('$baseUrl/v0/characters/$id'))
        as Map<String, dynamic>;
    return Character.fromJson(map);
  }

  /// 角色出演作品
  static Future<List<WorkRef>> characterSubjects(int id) async {
    final list =
        await _getJson(Uri.parse('$baseUrl/v0/characters/$id/subjects'))
            as List;
    final refs =
        list.map((e) => WorkRef.fromJson(e as Map<String, dynamic>)).toList();
    debugPrint('[bgm] characterSubjects($id) -> ${refs.length}');
    return refs;
  }

  /// 角色配音演员
  static Future<List<CastRef>> characterPersons(int id) async {
    final list =
        await _getJson(Uri.parse('$baseUrl/v0/characters/$id/persons')) as List;
    final refs =
        list.map((e) => CastRef.fromJson(e as Map<String, dynamic>)).toList();
    debugPrint('[bgm] characterPersons($id) -> ${refs.length}');
    return refs;
  }

  /// 人物详情
  static Future<Person> person(int id) async {
    debugPrint('[bgm] person($id)');
    final map = await _getJson(Uri.parse('$baseUrl/v0/persons/$id'))
        as Map<String, dynamic>;
    return Person.fromJson(map);
  }

  /// 人物配音角色
  static Future<List<CastRef>> personCharacters(int id) async {
    final uri = Uri.parse('$baseUrl/v0/persons/$id/characters')
        .replace(queryParameters: {'limit': '100'});
    final list = await _getJson(uri) as List;
    return list.map((e) => CastRef.fromJson(e as Map<String, dynamic>)).toList();
  }

  /// 人物参与作品
  static Future<List<WorkRef>> personSubjects(int id) async {
    final uri = Uri.parse('$baseUrl/v0/persons/$id/subjects')
        .replace(queryParameters: {'limit': '100'});
    final list = await _getJson(uri) as List;
    return list.map((e) => WorkRef.fromJson(e as Map<String, dynamic>)).toList();
  }

  /// 当前用户信息（校验令牌）
  static Future<User> me(String token) async {
    final resp = await http
        .get(Uri.parse('$baseUrl/v0/me'), headers: _headers(token: token))
        .timeout(const Duration(seconds: 20));
    if (resp.statusCode != 200) throw ApiException(resp.statusCode);
    final u = User.fromJson(
        jsonDecode(utf8.decode(resp.bodyBytes)) as Map<String, dynamic>);
    debugPrint('[bgm] me -> ${u.username}');
    return u;
  }

  /// 用户收藏列表（分页）
  static Future<PageData<Collection>> userCollections(
      String token, String username,
      {int? subjectType, int? collectionType, int limit = 50, int offset = 0}) async {
    final uri = Uri.parse('$baseUrl/v0/users/$username/collections')
        .replace(queryParameters: {
      if (subjectType != null) 'subject_type': '$subjectType',
      if (collectionType != null) 'type': '$collectionType',
      'limit': '$limit',
      'offset': '$offset',
    });
    final resp = await http
        .get(uri, headers: _headers(token: token))
        .timeout(const Duration(seconds: 20));
    if (resp.statusCode != 200) throw ApiException(resp.statusCode);
    final map = jsonDecode(utf8.decode(resp.bodyBytes)) as Map<String, dynamic>;
    final data = (map['data'] as List?) ?? const [];
    final list = data
        .map((e) => Collection.fromJson(e as Map<String, dynamic>))
        .toList();
    final total = (map['total'] as num?)?.toInt() ?? list.length;
    debugPrint(
        '[bgm] collections(ct=$collectionType st=$subjectType offset=$offset) -> ${list.length}/$total');
    return PageData(items: list, total: total);
  }

  /// 单个条目收藏状态（未收藏返回 null）
  static Future<Collection?> subjectCollection(
      String token, String username, int subjectId) async {
    final resp = await http
        .get(
          Uri.parse('$baseUrl/v0/users/$username/collections/$subjectId'),
          headers: _headers(token: token),
        )
        .timeout(const Duration(seconds: 20));
    if (resp.statusCode == 404) return null;
    if (resp.statusCode != 200) throw ApiException(resp.statusCode);
    return Collection.fromJson(
        jsonDecode(utf8.decode(resp.bodyBytes)) as Map<String, dynamic>);
  }

  /// 单集观看状态：episodeId -> type（1=想看, 2=看过, 3=抛弃）
  static Future<Map<int, int>> episodeStatus(String token, int subjectId) async {
    final uri = Uri.parse('$baseUrl/v0/users/-/collections/$subjectId/episodes')
        .replace(queryParameters: {'limit': '200'});
    final resp = await http
        .get(uri, headers: _headers(token: token))
        .timeout(const Duration(seconds: 20));
    if (resp.statusCode != 200) throw ApiException(resp.statusCode);
    final map = jsonDecode(utf8.decode(resp.bodyBytes)) as Map<String, dynamic>;
    final data = (map['data'] as List?) ?? const [];
    final result = <int, int>{};
    for (final item in data) {
      final m = item as Map<String, dynamic>;
      final ep = (m['episode'] as Map?)?.cast<String, dynamic>() ?? const {};
      final id = (ep['id'] as num?)?.toInt();
      final t = (m['type'] as num?)?.toInt() ?? 0;
      if (id != null && t > 0) result[id] = t;
    }
    debugPrint('[bgm] episodeStatus(subject=$subjectId) -> ${result.length} 集');
    return result;
  }

  /// 更新单集观看状态（type: 0=未标记, 1=想看, 2=看过, 3=抛弃）
  static Future<void> updateEpisode(String token, int episodeId, int type) async {
    final resp = await http
        .put(
          Uri.parse('$baseUrl/v0/users/-/collections/-/episodes/$episodeId'),
          headers: _headers(token: token),
          body: jsonEncode({'type': type}),
        )
        .timeout(const Duration(seconds: 20));
    if (resp.statusCode < 200 || resp.statusCode >= 300) {
      throw ApiException(resp.statusCode);
    }
    debugPrint('[bgm] updateEpisode($episodeId, type=$type) ok');
  }

  /// 新增或修改收藏（type/rate/comment 均可选）
  static Future<void> updateCollection(String token, int subjectId,
      {int? type, int? rate, String? comment}) async {
    final resp = await http
        .post(
          Uri.parse('$baseUrl/v0/users/-/collections/$subjectId'),
          headers: _headers(token: token),
          body: jsonEncode({
            if (type != null) 'type': type,
            if (rate != null) 'rate': rate,
            if (comment != null) 'comment': comment,
          }),
        )
        .timeout(const Duration(seconds: 20));
    if (resp.statusCode < 200 || resp.statusCode >= 300) {
      throw ApiException(resp.statusCode);
    }
    debugPrint('[bgm] updateCollection(subject=$subjectId, type=$type, rate=$rate) ok');
  }
}
