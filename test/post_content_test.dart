import 'package:bgm_app/widgets/post_content.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('兼容 Markdown、Bangumi 图片、链接和表情标记', () {
    const source = '''
## 用户体验报告

**重点内容**与[网页](https://bgm.tv)。

[img]https://lain.bgm.tv/test.png[/img]

[url=https://bgm.tv/user/sai]@Sai[/url] (bgm38)
''';

    final markdown = normalizePostMarkup(source);
    expect(markdown, contains('## 用户体验报告'));
    expect(markdown, contains('**重点内容**'));
    expect(markdown, contains('![](https://lain.bgm.tv/test.png)'));
    expect(markdown, contains('[@Sai](https://bgm.tv/user/sai)'));
    expect(markdown, contains('https://bgm.tv/img/smiles/tv/15.gif'));
  });

  test('未知 Bangumi 表情保留原文，已知娘表情转换为图片', () {
    final markdown = normalizePostMarkup('(bgm999) (musume_03)');
    expect(markdown, contains('(bgm999)'));
    expect(
      markdown,
      contains('https://lain.bgm.tv/img/smiles/musume/musume_03.gif'),
    );
  });
}
