import 'package:bgm_app/models/models.dart';
import 'package:bgm_app/pages/search_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('search categories include every supported item from the design', () {
    expect(kSearchTypes.map((entry) => entry.value), [
      '全部',
      '动画',
      '书籍',
      '游戏',
      '音乐',
      '三次元',
      '人物',
    ]);
  });

  testWidgets('tablet search uses a vertical category rail', (tester) async {
    tester.view.physicalSize = const Size(1280, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(const MaterialApp(home: SearchPage()));

    expect(find.byType(VerticalDivider), findsOneWidget);
    for (final category in kSearchTypes) {
      expect(find.text(category.value), findsOneWidget);
    }
    expect(find.text('搜索条目、角色与人物…'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
