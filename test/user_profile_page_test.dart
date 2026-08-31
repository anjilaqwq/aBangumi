import 'package:bgm_app/models/models.dart';
import 'package:bgm_app/pages/user_profile_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('personal profile shows account identity and collection total', (
    tester,
  ) async {
    final user = User(
      id: 42,
      username: 'tester',
      nickname: '测试用户',
      sign: '今天也要看动画。',
      avatarLarge: '',
      avatarMedium: '',
      url: 'https://bgm.tv/user/tester',
    );

    await tester.pumpWidget(
      MaterialApp(home: UserProfilePage(user: user, collectionTotal: 128)),
    );

    expect(find.text('个人资料'), findsOneWidget);
    expect(find.text('测试用户'), findsAtLeastNWidgets(1));
    expect(find.text('@tester'), findsOneWidget);
    expect(find.text('128'), findsOneWidget);
    expect(find.text('今天也要看动画。'), findsOneWidget);
  });
}
