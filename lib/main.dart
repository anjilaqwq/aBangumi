import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import 'auth/oauth_service.dart';
import 'pages/root_page.dart';
import 'store/auth_store.dart';
import 'theme/app_theme.dart';

/// 开发环境代理配置。
///
/// 作者的开发环境里 Android 模拟器无法直连 bgm.tv（DNS 污染 + 直连被墙），
/// 需要走宿主机本地代理（模拟器内 `10.0.2.2` 指向宿主机回环）。
/// 仅在 debug 构建生效；release 构建直连 bgm.tv。
const String kProxyHost = '10.0.2.2';
const int kProxyPort = 2080;

class _ProxyHttpOverrides extends HttpOverrides {
  @override
  HttpClient createHttpClient(SecurityContext? context) {
    final client = super.createHttpClient(context);
    client.findProxy = (Uri uri) {
      if (!kDebugMode) return 'DIRECT';
      final host = uri.host.toLowerCase();
      if (host == 'bgm.tv' || host.endsWith('.bgm.tv')) {
        return 'PROXY $kProxyHost:$kProxyPort';
      }
      return 'DIRECT';
    };
    client.connectionTimeout = const Duration(seconds: 15);
    return client;
  }
}

Future<void> main() async {
  HttpOverrides.global = _ProxyHttpOverrides();
  WidgetsFlutterBinding.ensureInitialized();
  await AuthStore.instance.init();
  // Listen for abangumi://oauth/callback deep links (initial + future).
  OAuthService.instance.bind(
    AuthStore.instance.handleOAuthCallback,
    onError: AuthStore.instance.observeOAuthLinkError,
  );
  runApp(const BgmApp());
}

class BgmApp extends StatelessWidget {
  const BgmApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'aBangumi',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light(),
      home: const RootPage(),
    );
  }
}
