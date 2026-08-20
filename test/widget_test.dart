import 'package:flutter_test/flutter_test.dart';

import 'package:bgm_app/models/models.dart';

void main() {
  test('Subject.fromJson 解析条目', () {
    final s = Subject.fromJson({
      'id': 253,
      'type': 2,
      'name': 'カウボーイビバップ',
      'name_cn': '星际牛仔',
      'platform': 'TV',
      'date': '1998-10-23',
      'rating': {'score': 9.1, 'rank': 4, 'total': 19498},
      'images': {
        'large': 'http://lain.bgm.tv/pic/cover/l/c2/4c/253.jpg',
        'common': 'http://lain.bgm.tv/r/400/pic/cover/l/c2/4c/253.jpg',
      },
      'tags': [
        {'name': '科幻', 'count': 100},
      ],
      'infobox': [
        {'key': '中文名', 'value': '星际牛仔'},
        {'key': '别名', 'value': [{'v': 'Cowboy Bebop'}]},
      ],
      'total_episodes': 26,
      'collection': {'doing': 4111},
    });

    expect(s.id, 253);
    expect(s.title, '星际牛仔');
    expect(s.score, 9.1);
    expect(s.rank, 4);
    expect(s.typeLabel, '动画');
    // http 图片地址应被规整为 https
    expect(s.cover.startsWith('https://'), isTrue);
    expect(s.tags.first, '科幻');
    expect(s.infobox.first.key, '中文名');
    expect(s.infobox.first.value, '星际牛仔');
    expect(s.infobox[1].value, 'Cowboy Bebop');
  });

  test('subjectTypeLabel 映射', () {
    expect(subjectTypeLabel(1), '书籍');
    expect(subjectTypeLabel(2), '动画');
    expect(subjectTypeLabel(3), '音乐');
    expect(subjectTypeLabel(4), '游戏');
    expect(subjectTypeLabel(6), '三次元');
    expect(subjectTypeLabel(99), '条目');
  });
}
