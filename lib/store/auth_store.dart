import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../api/bangumi_api.dart';
import '../models/models.dart';

class AuthStore {
  AuthStore._();

  static final AuthStore instance = AuthStore._();

  static const _kTokenKey = 'bgm_token';

  final ValueNotifier<String?> token = ValueNotifier<String?>(null);
  final ValueNotifier<User?> user = ValueNotifier<User?>(null);

  bool get isLoggedIn => token.value != null && token.value!.isNotEmpty;

  /// 启动时读取本地令牌并拉取用户信息
  Future<void> init() async {
    final sp = await SharedPreferences.getInstance();
    final t = sp.getString(_kTokenKey);
    if (t == null || t.isEmpty) return;
    try {
      final u = await BangumiApi.me(t);
      user.value = u;
      token.value = t;
    } catch (_) {
      await sp.remove(_kTokenKey); // 令牌失效则清除
    }
  }

  /// 用令牌登录（先校验再保存）
  Future<void> login(String t) async {
    final clean = t.trim();
    if (clean.isEmpty) throw ApiException(0);
    final u = await BangumiApi.me(clean); // 校验失败会抛异常
    final sp = await SharedPreferences.getInstance();
    await sp.setString(_kTokenKey, clean);
    user.value = u;
    token.value = clean;
  }

  Future<void> logout() async {
    final sp = await SharedPreferences.getInstance();
    await sp.remove(_kTokenKey);
    user.value = null;
    token.value = null;
  }
}
