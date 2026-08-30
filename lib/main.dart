import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';

import 'store/proxy_store.dart';

import 'auth/oauth_service.dart';
import 'pages/root_page.dart';
import 'store/auth_store.dart';
import 'store/theme_store.dart';
import 'theme/app_theme.dart';

/// Android 无系统代理时保留 debug 模拟器宿主机回退。
const String kDebugFallbackProxy = 'PROXY 10.0.2.2:2080';

class _ProxyHttpOverrides extends HttpOverrides {
  @override
  HttpClient createHttpClient(SecurityContext? context) {
    final client = super.createHttpClient(context);
    client.findProxy = (Uri uri) {
      final configured = ProxyStore.instance.proxyFor(uri);
      if (configured != null) return configured;
      final host = uri.host.toLowerCase();
      final isBangumi = host == 'bgm.tv' || host.endsWith('.bgm.tv');
      if (isBangumi &&
          kDebugMode &&
          (ProxyStore.instance.settings.mode == ProxyMode.off ||
              ProxyStore.instance.settings.mode == ProxyMode.automatic)) {
        return kDebugFallbackProxy;
      }
      return 'DIRECT';
    };
    client.connectionTimeout = const Duration(seconds: 15);
    return client;
  }
}

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await ProxyStore.instance.init();
  HttpOverrides.global = _ProxyHttpOverrides();
  await AuthStore.instance.init();
  await ThemeStore.instance.init();
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
    return ListenableBuilder(
      listenable: ThemeStore.instance,
      builder: (context, _) => MaterialApp(
        title: 'aBangumi',
        debugShowCheckedModeBanner: false,
        theme: AppTheme.light(),
        darkTheme: AppTheme.dark(),
        themeMode: ThemeStore.instance.themeMode,
        home: const RootPage(),
      ),
    );
  }
}
