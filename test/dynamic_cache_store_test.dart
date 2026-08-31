import 'package:bgm_app/store/dynamic_cache_store.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('动态缓存复用数据并允许强制刷新', () async {
    SharedPreferences.setMockInitialValues({});
    var calls = 0;
    Future<dynamic> loader() async => {'version': ++calls};

    final first = await DynamicCacheStore.instance.loadJson(
      key: 'test://ranking/anime',
      loader: loader,
    );
    final cached = await DynamicCacheStore.instance.loadJson(
      key: 'test://ranking/anime',
      loader: loader,
    );
    final refreshed = await DynamicCacheStore.instance.loadJson(
      key: 'test://ranking/anime',
      loader: loader,
      forceRefresh: true,
    );

    expect(first['version'], 1);
    expect(cached['version'], 1);
    expect(refreshed['version'], 2);
    expect(calls, 2);
  });

  test('网络失败时回退到旧页面缓存', () async {
    SharedPreferences.setMockInitialValues({});
    const key = 'test://topic/with-user';
    await DynamicCacheStore.instance.loadJson(
      key: key,
      loader: () async => {
        'creator': {'username': 'sai', 'nickname': 'Sai'},
        'content': '**缓存帖子** (bgm38)',
      },
    );

    final stale = await DynamicCacheStore.instance.loadJson(
      key: key,
      forceRefresh: true,
      loader: () async => throw Exception('offline'),
    );

    expect(stale['creator']['username'], 'sai');
    expect(stale['content'], contains('缓存帖子'));
  });
}
