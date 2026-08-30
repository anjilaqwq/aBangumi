import 'models.dart';

String _httpsUrl(String value) =>
    value.startsWith('http://') ? 'https://${value.substring(7)}' : value;

int _asInt(dynamic value) {
  if (value is num) return value.toInt();
  return int.tryParse(value?.toString() ?? '') ?? 0;
}

Subject subjectFromPrivateJson(Map<String, dynamic> json) {
  final images = (json['images'] as Map?)?.cast<String, dynamic>() ?? const {};
  final rating = (json['rating'] as Map?)?.cast<String, dynamic>() ?? const {};
  return Subject(
    id: _asInt(json['id']),
    type: _asInt(json['type']),
    name: json['name']?.toString() ?? '',
    nameCn: json['nameCN']?.toString() ?? '',
    summary: '',
    date: '',
    platform: '',
    imagesLarge: _httpsUrl(images['large']?.toString() ?? ''),
    imagesCommon: _httpsUrl(images['common']?.toString() ?? ''),
    score: (rating['score'] as num?)?.toDouble() ?? 0,
    rank: _asInt(rating['rank']),
    ratingTotal: _asInt(rating['total']),
    tags:
        (json['metaTags'] as List?)
            ?.map((item) => item.toString())
            .where((item) => item.isNotEmpty)
            .toList() ??
        const [],
    infobox: const [],
    totalEpisodes: 0,
    collectionDoing: 0,
  );
}

class P1User {
  final int id;
  final String username;
  final String nickname;
  final String avatar;

  const P1User({
    required this.id,
    required this.username,
    required this.nickname,
    required this.avatar,
  });

  factory P1User.fromJson(Map<String, dynamic> json) {
    final avatar =
        (json['avatar'] as Map?)?.cast<String, dynamic>() ?? const {};
    return P1User(
      id: _asInt(json['id']),
      username: json['username']?.toString() ?? '',
      nickname: json['nickname']?.toString() ?? '',
      avatar: _httpsUrl(
        avatar['small']?.toString() ?? avatar['medium']?.toString() ?? '',
      ),
    );
  }

  String get displayName => nickname.isNotEmpty ? nickname : username;
}

class P1TrendingSubject {
  final Subject subject;
  final int activityCount;

  const P1TrendingSubject({required this.subject, required this.activityCount});

  factory P1TrendingSubject.fromJson(Map<String, dynamic> json) =>
      P1TrendingSubject(
        subject: subjectFromPrivateJson(
          (json['subject'] as Map).cast<String, dynamic>(),
        ),
        activityCount: _asInt(json['count']),
      );
}

class P1SubjectTopic {
  final int id;
  final String title;
  final int replyCount;
  final int createdAt;
  final int updatedAt;
  final P1User? creator;
  final Subject? subject;
  final List<P1Reply> replies;

  const P1SubjectTopic({
    required this.id,
    required this.title,
    required this.replyCount,
    required this.createdAt,
    required this.updatedAt,
    this.creator,
    this.subject,
    this.replies = const [],
  });

  factory P1SubjectTopic.fromJson(Map<String, dynamic> json) {
    final creator = json['creator'];
    final subject = json['subject'];
    return P1SubjectTopic(
      id: _asInt(json['id']),
      title: json['title']?.toString() ?? '',
      replyCount: _asInt(json['replyCount']),
      createdAt: _asInt(json['createdAt']),
      updatedAt: _asInt(json['updatedAt']),
      creator: creator is Map
          ? P1User.fromJson(creator.cast<String, dynamic>())
          : null,
      subject: subject is Map
          ? subjectFromPrivateJson(subject.cast<String, dynamic>())
          : null,
      replies:
          (json['replies'] as List?)
              ?.map(
                (item) =>
                    P1Reply.fromJson((item as Map).cast<String, dynamic>()),
              )
              .toList() ??
          const [],
    );
  }
}

class P1Reply {
  final int id;
  final P1User? creator;
  final int createdAt;
  final String content;
  final List<P1Reply> replies;

  const P1Reply({
    required this.id,
    required this.createdAt,
    required this.content,
    this.creator,
    this.replies = const [],
  });

  factory P1Reply.fromJson(Map<String, dynamic> json) {
    final creator = json['creator'];
    return P1Reply(
      id: _asInt(json['id']),
      creator: creator is Map
          ? P1User.fromJson(creator.cast<String, dynamic>())
          : null,
      createdAt: _asInt(json['createdAt']),
      content: json['content']?.toString() ?? '',
      replies:
          (json['replies'] as List?)
              ?.map(
                (item) =>
                    P1Reply.fromJson((item as Map).cast<String, dynamic>()),
              )
              .toList() ??
          const [],
    );
  }
}

class P1SubjectReview {
  final int id;
  final int blogId;
  final String title;
  final String summary;
  final int replyCount;
  final int updatedAt;
  final P1User user;

  const P1SubjectReview({
    required this.id,
    required this.blogId,
    required this.title,
    required this.summary,
    required this.replyCount,
    required this.updatedAt,
    required this.user,
  });

  factory P1SubjectReview.fromJson(Map<String, dynamic> json) {
    final entry = (json['entry'] as Map).cast<String, dynamic>();
    return P1SubjectReview(
      id: _asInt(json['id']),
      blogId: _asInt(entry['id']),
      title: entry['title']?.toString() ?? '',
      summary: entry['summary']?.toString() ?? '',
      replyCount: _asInt(entry['replies']),
      updatedAt: _asInt(entry['updatedAt']),
      user: P1User.fromJson((json['user'] as Map).cast<String, dynamic>()),
    );
  }
}

class P1SubjectComment {
  final int id;
  final P1User user;
  final int collectionType;
  final int rate;
  final String comment;
  final int updatedAt;

  const P1SubjectComment({
    required this.id,
    required this.user,
    required this.collectionType,
    required this.rate,
    required this.comment,
    required this.updatedAt,
  });

  factory P1SubjectComment.fromJson(Map<String, dynamic> json) =>
      P1SubjectComment(
        id: _asInt(json['id']),
        user: P1User.fromJson((json['user'] as Map).cast<String, dynamic>()),
        collectionType: _asInt(json['type']),
        rate: _asInt(json['rate']),
        comment: json['comment']?.toString() ?? '',
        updatedAt: _asInt(json['updatedAt']),
      );
}

class P1SubjectCommunity {
  final PageData<P1SubjectTopic> topics;
  final PageData<P1SubjectReview> reviews;
  final PageData<P1SubjectComment> comments;

  const P1SubjectCommunity({
    required this.topics,
    required this.reviews,
    required this.comments,
  });
}
