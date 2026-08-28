import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter/material.dart';

import 'auth/oauth_service.dart';
import 'pages/root_page.dart';
import 'store/auth_store.dart';
import 'theme/app_theme.dart';

/// Android 系统代理通道；没有系统代理时，debug 模拟器回退到宿主机代理。
const _proxyChannel = MethodChannel('abgm/proxy');
const String kDebugFallbackProxy = 'PROXY 10.0.2.2:2080';
String? _systemProxy;

class _ProxyHttpOverrides extends HttpOverrides {
  @override
  HttpClient createHttpClient(SecurityContext? context) {
    final client = super.createHttpClient(context);
    client.findProxy = (Uri uri) {
      final host = uri.host.toLowerCase();
      if (host == 'bgm.tv' || host.endsWith('.bgm.tv')) {
        return _systemProxy ?? (kDebugMode ? kDebugFallbackProxy : 'DIRECT');
      }
      return 'DIRECT';
    };
    client.connectionTimeout = const Duration(seconds: 15);
    return client;
  }
}

Future<void> _loadSystemProxy() async {
  try {
    final proxy = await _proxyChannel.invokeMethod<String>('getProxy');
    if (proxy != null && proxy.isNotEmpty && proxy != 'DIRECT') {
      _systemProxy = proxy;
    }
  } on MissingPluginException {
    // 非 Android 平台没有该通道，继续使用 debug 回退或直连。
  } on PlatformException {
    // 系统代理查询失败不应阻塞应用启动。
  }
}

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await _loadSystemProxy();
  HttpOverrides.global = _ProxyHttpOverrides();
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
