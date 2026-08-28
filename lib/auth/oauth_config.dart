library;

import 'package:flutter/foundation.dart';

/// Missing or unsafe public BFF base URL; contains no environment value.
class OAuthConfigurationException implements Exception {
  const OAuthConfigurationException();

  @override
  String toString() => 'OAuthConfigurationException';
}

/// Bangumi OAuth configuration.
///
/// These values are public and safe to ship in the app. The **client secret**
/// lives only on the BFF (see `server/`) and is never present here.
class OAuthConfig {
  OAuthConfig._();

  /// Public Bangumi OAuth application ID.
  ///
  /// Overridable at build time with:
  /// `--dart-define=ABANGUMI_CLIENT_ID=your_id`
  static const String clientId = String.fromEnvironment(
    'ABANGUMI_CLIENT_ID',
    defaultValue: 'bgm69386a8765324f840',
  );

  /// Base URL of the auth BFF, e.g. `https://auth.example.com`.
  ///
  /// Required for the OAuth flow. Overridable at build time with:
  /// `--dart-define=ABANGUMI_AUTH_BASE_URL=https://auth.example.com`
  static const String authBaseUrl = String.fromEnvironment(
    'ABANGUMI_AUTH_BASE_URL',
  );

  /// Custom scheme deep link the BFF redirects back to after authorization.
  static const String callbackScheme = 'abangumi';
  static const String callbackHost = 'oauth';
  static const String callbackPath = '/callback';
  static const String callbackUri = 'abangumi://oauth/callback';

  /// Validated BFF origin. Production requires HTTPS; debug builds may use an
  /// explicit emulator/loopback host over HTTP for local development only.
  static String requireAuthBaseUrl() {
    final base = authBaseUrl.trim();
    final uri = Uri.tryParse(base);
    if (uri == null || !uri.hasScheme || !uri.hasAuthority) {
      throw const OAuthConfigurationException();
    }

    final host = uri.host.toLowerCase();
    final debugLoopback = kDebugMode &&
        uri.scheme == 'http' &&
        (host == 'localhost' ||
            host == '127.0.0.1' ||
            host == '::1' ||
            host == '10.0.2.2');
    if (uri.scheme != 'https' && !debugLoopback) {
      throw const OAuthConfigurationException();
    }
    return base.replaceAll(RegExp(r'/+$'), '');
  }

  /// Whether the OAuth flow has a valid public BFF base URL.
  static bool get isConfigured {
    try {
      requireAuthBaseUrl();
      return true;
    } on OAuthConfigurationException {
      return false;
    }
  }

  /// Prefix used to mark an opaque BFF session token, so [BangumiApi] can
  /// distinguish it from a raw (manual) Bangumi access token.
  static const String sessionTokenPrefix = 'oauth:';

  /// True if [token] is an opaque BFF session token (OAuth mode).
  static bool isSessionToken(String? token) =>
      token != null && token.startsWith(sessionTokenPrefix);

  /// Strip the prefix and return the raw opaque session token.
  static String sessionTokenOf(String token) =>
      token.startsWith(sessionTokenPrefix)
      ? token.substring(sessionTokenPrefix.length)
      : token;

  /// BFF endpoint paths.
  static const String startPath = '/auth/bangumi/start';
  static const String claimPath = '/auth/bangumi/claim';
  static const String logoutPath = '/auth/logout';
  static const String proxyPrefix = '/api/bangumi';
}
