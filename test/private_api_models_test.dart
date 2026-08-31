import 'package:bgm_app/models/private_api_models.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('解析 p1 热门条目', () {
    final item = P1TrendingSubject.fromJson({
      'subject': {
        'id': 8,
        'name': 'コードギアス',
        'nameCN': '反叛的鲁路修',
        'type': 2,
        'metaTags': ['TV', '原创'],
        'rating': {'rank': 12, 'score': 8.5, 'total': 1200},
        'images': {'large': 'http://lain.bgm.tv/cover.jpg'},
      },
      'count': 4034,
    });

    expect(item.subject.id, 8);
    expect(item.subject.title, '反叛的鲁路修');
    expect(item.subject.cover, 'https://lain.bgm.tv/cover.jpg');
    expect(item.subject.tags, ['TV', '原创']);
    expect(item.subject.score, 8.5);
    expect(item.activityCount, 4034);
  });

  test('解析 p1 热门讨论', () {
    final topic = P1SubjectTopic.fromJson({
      'id': 40823,
      'title': '讨论标题',
      'replyCount': 44,
      'createdAt': 1787000000,
      'updatedAt': 1787818216,
      'creator': {
        'id': 1,
        'username': 'sai',
        'nickname': 'Sai',
        'avatar': {'small': 'https://lain.bgm.tv/avatar.jpg'},
      },
      'subject': {
        'id': 552533,
        'name': 'subject',
        'nameCN': '测试条目',
        'type': 2,
        'metaTags': [],
        'rating': {},
        'images': {},
      },
      'replies': [
        {
          'id': 9,
          'createdAt': 1787000000,
          'content': '主楼内容',
          'creator': {
            'id': 1,
            'username': 'sai',
            'nickname': 'Sai',
            'avatar': <String, dynamic>{},
          },
          'replies': [
            {
              'id': 10,
              'createdAt': 1787000010,
              'content': '嵌套回复',
              'replies': <dynamic>[],
            },
          ],
        },
      ],
    });

    expect(topic.id, 40823);
    expect(topic.replyCount, 44);
    expect(topic.creator?.displayName, 'Sai');
    expect(topic.creator?.username, 'sai');
    expect(topic.creator?.avatar, 'https://lain.bgm.tv/avatar.jpg');
    expect(topic.subject?.title, '测试条目');
    expect(topic.replies.single.content, '主楼内容');
    expect(topic.replies.single.replies.single.content, '嵌套回复');
  });

  test('解析 p1 长评和吐槽', () {
    final user = {
      'id': 2,
      'username': 'user',
      'nickname': '用户',
      'avatar': <String, dynamic>{},
    };
    final review = P1SubjectReview.fromJson({
      'id': 3,
      'user': user,
      'entry': {
        'id': 4,
        'title': '长评标题',
        'summary': '摘要',
        'replies': 5,
        'updatedAt': 100,
      },
    });
    final comment = P1SubjectComment.fromJson({
      'id': 6,
      'user': user,
      'type': 2,
      'rate': 8,
      'comment': '很好看',
      'updatedAt': 200,
    });

    expect(review.blogId, 4);
    expect(review.replyCount, 5);
    expect(comment.user.displayName, '用户');
    expect(comment.collectionType, 2);
    expect(comment.rate, 8);
  });
}
