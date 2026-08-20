// Bangumi API 数据模型

String _https(String url) =>
    url.startsWith('http://') ? 'https://${url.substring(7)}' : url;

String _numStr(dynamic v) {
  if (v == null) return '';
  if (v is num) return v.toInt().toString();
  return v.toString();
}

String subjectTypeLabel(int type) {
  switch (type) {
    case 1:
      return '书籍';
    case 2:
      return '动画';
    case 3:
      return '音乐';
    case 4:
      return '游戏';
    case 6:
      return '三次元';
    default:
      return '条目';
  }
}

String collectionTypeLabel(int type) {
  switch (type) {
    case 1:
      return '想看';
    case 2:
      return '看过';
    case 3:
      return '在看';
    case 4:
      return '搁置';
    case 5:
      return '抛弃';
    default:
      return '未收藏';
  }
}

/// 条目类型（用于切换）
const List<MapEntry<int, String>> kSubjectTypes = [
  MapEntry(2, '动画'),
  MapEntry(1, '书籍'),
  MapEntry(4, '游戏'),
  MapEntry(3, '音乐'),
  MapEntry(6, '三次元'),
];

/// 收藏类型
const List<MapEntry<int, String>> kCollectionTypes = [
  MapEntry(1, '想看'),
  MapEntry(2, '看过'),
  MapEntry(3, '在看'),
  MapEntry(4, '搁置'),
  MapEntry(5, '抛弃'),
];

class Subject {
  final int id;
  final int type;
  final String name;
  final String nameCn;
  final String summary;
  final String date;
  final String platform;
  final String imagesLarge;
  final String imagesCommon;
  final double score;
  final int rank;
  final int ratingTotal;
  final List<String> tags;
  final List<InfoItem> infobox;
  final int totalEpisodes;
  final int collectionDoing;
  final String relation;

  Subject({
    required this.id,
    required this.type,
    required this.name,
    required this.nameCn,
    required this.summary,
    required this.date,
    required this.platform,
    required this.imagesLarge,
    required this.imagesCommon,
    required this.score,
    required this.rank,
    required this.ratingTotal,
    required this.tags,
    required this.infobox,
    required this.totalEpisodes,
    required this.collectionDoing,
    this.relation = '',
  });

  factory Subject.fromJson(Map<String, dynamic> j) {
    final images = (j['images'] as Map?)?.cast<String, dynamic>() ?? const {};
    final rating = (j['rating'] as Map?)?.cast<String, dynamic>() ?? const {};
    return Subject(
      id: (j['id'] as num?)?.toInt() ?? 0,
      type: (j['type'] as num?)?.toInt() ?? 0,
      name: j['name']?.toString() ?? '',
      nameCn: j['name_cn']?.toString() ?? '',
      summary: j['summary']?.toString() ?? j['short_summary']?.toString() ?? '',
      date: j['date']?.toString() ?? '',
      platform: j['platform']?.toString() ?? '',
      imagesLarge: _https(images['large']?.toString() ?? ''),
      imagesCommon: _https(images['common']?.toString() ?? ''),
      score: (rating['score'] as num?)?.toDouble() ?? 0,
      rank: (rating['rank'] as num?)?.toInt() ??
          (j['rank'] as num?)?.toInt() ??
          0,
      ratingTotal: (rating['total'] as num?)?.toInt() ?? 0,
      tags: (j['tags'] as List?)
              ?.map((e) => (e as Map)['name']?.toString() ?? '')
              .where((s) => s.isNotEmpty)
              .toList() ??
          const [],
      infobox: (j['infobox'] as List?)
              ?.map((e) => InfoItem.fromJson(e as Map<String, dynamic>))
              .toList() ??
          const [],
      totalEpisodes: (j['total_episodes'] as num?)?.toInt() ?? 0,
      collectionDoing:
          ((j['collection'] as Map?)?['doing'] as num?)?.toInt() ?? 0,
      relation: j['relation']?.toString() ?? '',
    );
  }

  String get cover => imagesLarge.isNotEmpty ? imagesLarge : imagesCommon;
  String get title =>
      nameCn.isNotEmpty ? nameCn : (name.isNotEmpty ? name : '未知条目');
  String get originalTitle => name;
  String get typeLabel => subjectTypeLabel(type);
}

class InfoItem {
  final String key;
  final String value;

  InfoItem({required this.key, required this.value});

  factory InfoItem.fromJson(Map<String, dynamic> j) {
    final v = j['value'];
    String s;
    if (v is List) {
      s = v.map((e) {
        if (e is Map) return (e['v'] ?? e['k'] ?? '').toString();
        return e.toString();
      }).join(' / ');
    } else {
      s = v?.toString() ?? '';
    }
    return InfoItem(key: j['key']?.toString() ?? '', value: s);
  }
}

class Episode {
  final int id;
  final int sort;
  final double ep;
  final int comment;
  final String name;
  final String nameCn;
  final String airdate;

  Episode({
    required this.id,
    required this.sort,
    required this.ep,
    required this.comment,
    required this.name,
    required this.nameCn,
    required this.airdate,
  });

  factory Episode.fromJson(Map<String, dynamic> j) => Episode(
        id: (j['id'] as num?)?.toInt() ?? 0,
        sort: (j['sort'] as num?)?.toInt() ?? 0,
        ep: (j['ep'] as num?)?.toDouble() ?? 0,
        comment: (j['comment'] as num?)?.toInt() ?? 0,
        name: j['name']?.toString() ?? '',
        nameCn: j['name_cn']?.toString() ?? '',
        airdate: j['airdate']?.toString() ?? '',
      );

  String get title => nameCn.isNotEmpty ? nameCn : name;

  /// 集号（单季内），缺失时退回全局序号
  String get epLabel {
    if (ep > 0) {
      return ep == ep.roundToDouble() ? '${ep.toInt()}' : '$ep';
    }
    return '$sort';
  }
}

class CalendarDay {
  final int weekdayId;
  final String cn;
  final String en;
  final List<Subject> items;

  CalendarDay({
    required this.weekdayId,
    required this.cn,
    required this.en,
    required this.items,
  });

  factory CalendarDay.fromJson(Map<String, dynamic> j) {
    final w = (j['weekday'] as Map?)?.cast<String, dynamic>() ?? const {};
    return CalendarDay(
      weekdayId: (w['id'] as num?)?.toInt() ?? 0,
      cn: w['cn']?.toString() ?? '',
      en: w['en']?.toString() ?? '',
      items: (j['items'] as List?)
              ?.map((e) => Subject.fromJson(e as Map<String, dynamic>))
              .toList() ??
          const [],
    );
  }
}

class User {
  final int id;
  final String username;
  final String nickname;
  final String sign;
  final String avatarLarge;
  final String avatarMedium;
  final String url;

  User({
    required this.id,
    required this.username,
    required this.nickname,
    required this.sign,
    required this.avatarLarge,
    required this.avatarMedium,
    required this.url,
  });

  factory User.fromJson(Map<String, dynamic> j) {
    final av = (j['avatar'] as Map?)?.cast<String, dynamic>() ?? const {};
    return User(
      id: (j['id'] as num?)?.toInt() ?? 0,
      username: j['username']?.toString() ?? '',
      nickname: j['nickname']?.toString() ?? '',
      sign: j['sign']?.toString() ?? '',
      avatarLarge: _https(av['large']?.toString() ?? ''),
      avatarMedium: _https(av['medium']?.toString() ?? ''),
      url: j['url']?.toString() ?? '',
    );
  }

  String get displayName => nickname.isNotEmpty ? nickname : username;
}

class Collection {
  final Subject subject;
  final int type;
  final int rate;
  final String comment;
  final String updatedAt;
  final bool isPrivate;

  Collection({
    required this.subject,
    required this.type,
    required this.rate,
    required this.comment,
    required this.updatedAt,
    required this.isPrivate,
  });

  factory Collection.fromJson(Map<String, dynamic> j) => Collection(
        subject: Subject.fromJson(
            (j['subject'] as Map?)?.cast<String, dynamic>() ?? const {}),
        type: (j['type'] as num?)?.toInt() ?? 0,
        rate: (j['rate'] as num?)?.toInt() ?? 0,
        comment: j['comment']?.toString() ?? '',
        updatedAt: j['updated_at']?.toString() ?? '',
        isPrivate: j['private'] as bool? ?? false,
      );

  String get typeLabel => collectionTypeLabel(type);
}

String careerLabel(String c) {
  switch (c) {
    case 'seiyu':
      return '声优';
    case 'actor':
      return '演员';
    case 'writer':
      return '作家';
    case 'illustrator':
      return '插画家';
    case 'producer':
      return '制作人';
    case 'director':
      return '导演';
    default:
      return c;
  }
}

class Character {
  final int id;
  final String name;
  final String nameCn;
  final String relation;
  final String imagesLarge;
  final String summary;
  final List<InfoItem> infobox;
  final int statComments;
  final int statCollects;
  final String gender;
  final String birthYear;
  final String bloodType;
  final List<PersonLite> actors;

  Character({
    required this.id,
    required this.name,
    required this.nameCn,
    required this.relation,
    required this.imagesLarge,
    required this.summary,
    required this.infobox,
    required this.statComments,
    required this.statCollects,
    required this.gender,
    required this.birthYear,
    required this.bloodType,
    required this.actors,
  });

  factory Character.fromJson(Map<String, dynamic> j) {
    final images = (j['images'] as Map?)?.cast<String, dynamic>() ?? const {};
    final stat = (j['stat'] as Map?)?.cast<String, dynamic>() ?? const {};
    return Character(
      id: (j['id'] as num?)?.toInt() ?? 0,
      name: j['name']?.toString() ?? '',
      nameCn: j['name_cn']?.toString() ?? '',
      relation: j['relation']?.toString() ?? '',
      imagesLarge: _https(
          images['large']?.toString() ?? images['grid']?.toString() ?? ''),
      summary: j['summary']?.toString() ?? '',
      infobox: (j['infobox'] as List?)
              ?.map((e) => InfoItem.fromJson(e as Map<String, dynamic>))
              .toList() ??
          const [],
      statComments: (stat['comments'] as num?)?.toInt() ?? 0,
      statCollects: (stat['collects'] as num?)?.toInt() ?? 0,
      gender: j['gender']?.toString() ?? '',
      birthYear: _numStr(j['birth_year']),
      bloodType: j['blood_type']?.toString() ?? '',
      actors: (j['actors'] as List?)
              ?.map((e) => PersonLite.fromJson(e as Map<String, dynamic>))
              .toList() ??
          const [],
    );
  }

  String get title => nameCn.isNotEmpty ? nameCn : name;
  String get cvName => actors.isEmpty ? '' : actors.first.name;
}

/// 角色列表里的声优简略信息
class PersonLite {
  final int id;
  final String name;
  final String imagesLarge;

  PersonLite({required this.id, required this.name, required this.imagesLarge});

  factory PersonLite.fromJson(Map<String, dynamic> j) {
    final images = (j['images'] as Map?)?.cast<String, dynamic>() ?? const {};
    return PersonLite(
      id: (j['id'] as num?)?.toInt() ?? 0,
      name: j['name']?.toString() ?? '',
      imagesLarge: _https(
          images['large']?.toString() ?? images['grid']?.toString() ?? ''),
    );
  }
}

/// 人物（声优/演员/制作人员）
class Person {
  final int id;
  final String name;
  final List<String> career;
  final String imagesLarge;
  final String summary;
  final List<InfoItem> infobox;
  final int statComments;
  final int statCollects;
  final String gender;
  final String birthYear;

  Person({
    required this.id,
    required this.name,
    required this.career,
    required this.imagesLarge,
    required this.summary,
    required this.infobox,
    required this.statComments,
    required this.statCollects,
    required this.gender,
    required this.birthYear,
  });

  factory Person.fromJson(Map<String, dynamic> j) {
    final images = (j['images'] as Map?)?.cast<String, dynamic>() ?? const {};
    final stat = (j['stat'] as Map?)?.cast<String, dynamic>() ?? const {};
    return Person(
      id: (j['id'] as num?)?.toInt() ?? 0,
      name: j['name']?.toString() ?? '',
      career: (j['career'] as List?)
              ?.map((e) => e.toString())
              .toList() ??
          const [],
      imagesLarge: _https(
          images['large']?.toString() ?? images['grid']?.toString() ?? ''),
      summary: j['summary']?.toString() ?? '',
      infobox: (j['infobox'] as List?)
              ?.map((e) => InfoItem.fromJson(e as Map<String, dynamic>))
              .toList() ??
          const [],
      statComments: (stat['comments'] as num?)?.toInt() ?? 0,
      statCollects: (stat['collects'] as num?)?.toInt() ?? 0,
      gender: j['gender']?.toString() ?? '',
      birthYear: _numStr(j['birth_year']),
    );
  }

  String get careerText =>
      career.isEmpty ? '' : career.map(careerLabel).join(' / ');
}

/// 出演作品引用（角色/人物的作品列表）
class WorkRef {
  final int subjectId;
  final String staff;
  final String name;
  final String nameCn;
  final String image;
  final int type;

  WorkRef({
    required this.subjectId,
    required this.staff,
    required this.name,
    required this.nameCn,
    required this.image,
    required this.type,
  });

  factory WorkRef.fromJson(Map<String, dynamic> j) => WorkRef(
        subjectId: (j['id'] as num?)?.toInt() ?? 0,
        staff: j['staff']?.toString() ?? '',
        name: j['name']?.toString() ?? '',
        nameCn: j['name_cn']?.toString() ?? '',
        image: _https(j['image']?.toString() ?? ''),
        type: (j['type'] as num?)?.toInt() ?? 0,
      );

  String get title => nameCn.isNotEmpty ? nameCn : name;
}

/// 配音/出演关联（角色→声优 或 声优→角色）
class CastRef {
  final int id;
  final String name;
  final String imagesLarge;
  final String subjectName;
  final String subjectNameCn;
  final int subjectId;
  final String staff;

  CastRef({
    required this.id,
    required this.name,
    required this.imagesLarge,
    required this.subjectName,
    required this.subjectNameCn,
    required this.subjectId,
    required this.staff,
  });

  factory CastRef.fromJson(Map<String, dynamic> j) {
    final images = (j['images'] as Map?)?.cast<String, dynamic>() ?? const {};
    return CastRef(
      id: (j['id'] as num?)?.toInt() ?? 0,
      name: j['name']?.toString() ?? '',
      imagesLarge: _https(
          images['large']?.toString() ?? images['grid']?.toString() ?? ''),
      subjectName: j['subject_name']?.toString() ?? '',
      subjectNameCn: j['subject_name_cn']?.toString() ?? '',
      subjectId: (j['subject_id'] as num?)?.toInt() ?? 0,
      staff: j['staff']?.toString() ?? '',
    );
  }

  String get subjectTitle =>
      subjectNameCn.isNotEmpty ? subjectNameCn : subjectName;
}

/// 分页结果
class PageData<T> {
  final List<T> items;
  final int total;
  const PageData({required this.items, required this.total});

  bool get hasMore => items.length < total;
}
