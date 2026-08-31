import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

import '../api/bangumi_api.dart';
import '../auth/oauth_config.dart';
import '../auth/oauth_service.dart';
import '../auth/oauth_session_events.dart';
import '../models/models.dart';

/// How the user is authenticated.
enum AuthMode { manual, oauth }

/// Operation used to produce a safe, user-readable authentication error.
enum AuthOperation { initialization, oauthStart, oauthCallback }

typedef AuthInitializationHandler = Future<void> Function();
typedef OAuthCallbackHandler = Future<OAuthSession?> Function(Uri uri);
typedef OAuthBeginHandler = Future<void> Function();
typedef OAuthSessionCompleter = Future<void> Function(OAuthSession session);

/// Converts an internal failure to a fixed message without interpolating the
/// exception. This prevents tickets, state, verifiers, and tokens from reaching
/// the UI even when a dependency includes them in its exception text.
String authErrorMessage(Object error, AuthOperation operation) {
  if (operation == AuthOperation.initialization) {
    if (error is ApiException &&
        (error.statusCode == 401 || error.statusCode == 403)) {
      return '登录状态已失效，请重新登录。';
    }
    return '无法恢复登录状态，请稍后重试。';
  }

  if (error is OAuthConfigurationException) {
    return 'OAuth 登录尚未配置，请使用访问令牌登录或联系应用维护者。';
  }
  if (error is OAuthBrowserLaunchException) {
    return '无法打开系统浏览器，请确认已安装浏览器后重试。';
  }
  if (error is OAuthCallbackException) {
    switch (error.reason) {
      case OAuthCallbackFailureReason.missingPendingFlow:
      case OAuthCallbackFailureReason.expiredPendingFlow:
        return '授权请求已失效，请重新发起登录。';
      case OAuthCallbackFailureReason.corruptPendingFlow:
        return '授权状态异常，请重新发起登录。';
      case OAuthCallbackFailureReason.stateMismatch:
        return '授权回调校验失败，请返回应用后重新登录。';
    }
  }
  if (error is TimeoutException) {
    return '连接授权服务超时，请检查网络后重试。';
  }
  if (error is SocketException || error is http.ClientException) {
    return '无法连接授权服务，请检查网络后重试。';
  }
  if (error is ApiException) {
    if (error.statusCode == 401 || error.statusCode == 403) {
      return operation == AuthOperation.oauthCallback
          ? '授权已失效，请重新发起登录。'
          : '授权服务拒绝了请求，请稍后重试。';
    }
    return '授权服务暂时不可用，请稍后重试。';
  }
  if (error is FormatException) {
    return '授权服务返回的数据无效，请稍后重试。';
  }
  return operation == AuthOperation.oauthCallback
      ? '未能完成 OAuth 登录，请重新发起登录。'
      : 'OAuth 登录失败，请稍后重试。';
}

/// Holds the current credential and user, backed by [FlutterSecureStorage].
///
/// Two credential kinds are supported:
/// - **OAuth** — an opaque BFF session token (never a Bangumi token), stored as
///   `oauth:<session>` in [token] so [BangumiApi] routes it through the BFF.
/// - **Manual** — a raw Bangumi access token, kept as a fallback.
class AuthStore {
  AuthStore._({
    AuthInitializationHandler? initializationHandler,
    OAuthBeginHandler? beginOAuthHandler,
    OAuthCallbackHandler? callbackHandler,
    OAuthSessionCompleter? sessionCompleter,
  }) : _initializationHandler = initializationHandler,
       _beginOAuthHandler = beginOAuthHandler,
       _callbackHandler = callbackHandler,
       _sessionCompleter = sessionCompleter {
    OAuthSessionEvents.onInvalidated = _invalidateOAuthSession;
  }

  /// Test seam for deterministic OAuth state tests; no real credentials or
  /// platform plugins are needed when injected handlers fail before storage.
  @visibleForTesting
  AuthStore.forTesting({
    AuthInitializationHandler? initializationHandler,
    OAuthBeginHandler? beginOAuthHandler,
    OAuthCallbackHandler? callbackHandler,
    OAuthSessionCompleter? sessionCompleter,
  }) : this._(
         initializationHandler: initializationHandler,
         beginOAuthHandler: beginOAuthHandler,
         callbackHandler: callbackHandler,
         sessionCompleter: sessionCompleter,
       );

  static final AuthStore instance = AuthStore._();

  static const _storage = FlutterSecureStorage();

  static const _kModeKey = 'auth_mode';
  static const _kOAuthSessionKey = 'oauth_session_token';
  static const _kOAuthExpiresKey = 'oauth_expires_at';
  static const _kManualTokenKey = 'manual_access_token';

  /// Legacy shared_preferences key (pre-secure-storage) — migrated then removed.
  static const _kLegacyTokenKey = 'bgm_token';

  final AuthInitializationHandler? _initializationHandler;
  final OAuthBeginHandler? _beginOAuthHandler;
  final OAuthCallbackHandler? _callbackHandler;
  final OAuthSessionCompleter? _sessionCompleter;
  int _busyDepth = 0;
  bool _callbackInFlight = false;
  bool _sessionInvalidationInFlight = false;
  int? _completedCallbackFingerprint;

  /// Effective credential visible to pages: a raw access token (manual) or an
  /// `oauth:<session>` opaque session token (OAuth).
  final ValueNotifier<String?> token = ValueNotifier<String?>(null);
  final ValueNotifier<User?> user = ValueNotifier<User?>(null);
  final ValueNotifier<AuthMode> authMode = ValueNotifier<AuthMode>(
    AuthMode.manual,
  );

  /// Observable state for initialization and OAuth start/callback work.
  final ValueNotifier<bool> busy = ValueNotifier<bool>(false);

  /// Fixed, user-readable message. Internal exception text is never assigned.
  final ValueNotifier<String?> error = ValueNotifier<String?>(null);

  bool get isLoggedIn => token.value != null && token.value!.isNotEmpty;

  void clearError() => error.value = null;

  Future<void> _invalidateOAuthSession() async {
    if (_sessionInvalidationInFlight ||
        !OAuthConfig.isSessionToken(token.value)) {
      return;
    }
    _sessionInvalidationInFlight = true;
    try {
      await _clearPersistedCredentialsBestEffort();
    } finally {
      authMode.value = AuthMode.manual;
      token.value = null;
      user.value = null;
      error.value = '登录状态已失效，请重新登录；公开内容已继续加载。';
      _sessionInvalidationInFlight = false;
    }
  }

  void _startWork() {
    _busyDepth += 1;
    busy.value = true;
    error.value = null;
  }

  void _finishWork() {
    _busyDepth -= 1;
    if (_busyDepth < 0) _busyDepth = 0;
    busy.value = _busyDepth > 0;
  }

  void _observeError(Object failure, AuthOperation operation) {
    error.value = authErrorMessage(failure, operation);
  }

  /// Receives app-links stream/initialization failures from [OAuthService.bind].
  void observeOAuthLinkError(Object failure) {
    _observeError(failure, AuthOperation.oauthCallback);
  }

  /// 启动时迁移旧令牌、读取本地凭据并拉取用户信息。
  ///
  /// Initialization failures are converted to observable state and never escape
  /// as an unhandled startup future.
  Future<void> init() async {
    _startWork();
    try {
      final initializationHandler = _initializationHandler;
      if (initializationHandler != null) {
        await initializationHandler();
      } else {
        await _initCredentials();
      }
    } catch (failure) {
      _observeError(failure, AuthOperation.initialization);
    } finally {
      _finishWork();
    }
  }

  Future<void> _initCredentials() async {
    await _migrateLegacyToken();

    final modeRaw = await _storage.read(key: _kModeKey);
    if (modeRaw == 'oauth') {
      final session = (await _storage.read(key: _kOAuthSessionKey)) ?? '';
      if (session.isEmpty) {
        await _clearAll(clearError: false);
        return;
      }
      final effective = '${OAuthConfig.sessionTokenPrefix}$session';
      try {
        final u = await BangumiApi.me(effective);
        token.value = effective;
        user.value = u;
        authMode.value = AuthMode.oauth;
      } catch (_) {
        await _clearAll(clearError: false);
        rethrow;
      }
      return;
    }

    // Manual access token fallback.
    final t = await _storage.read(key: _kManualTokenKey);
    if (t == null || t.isEmpty) return;
    try {
      final u = await BangumiApi.me(t);
      token.value = t;
      user.value = u;
      authMode.value = AuthMode.manual;
    } catch (_) {
      await _clearAll(clearError: false);
      rethrow;
    }
  }

  /// 用 Bangumi 访问令牌登录（先校验再保存）。保留 `login(String)` 契约。
  Future<void> login(String t) async {
    final clean = t.trim();
    if (clean.isEmpty) throw ApiException(0);
    final u = await BangumiApi.me(clean); // 校验失败会抛异常
    await _storage.write(key: _kModeKey, value: 'manual');
    await _storage.write(key: _kManualTokenKey, value: clean);
    await _storage.delete(key: _kOAuthSessionKey);
    await _storage.delete(key: _kOAuthExpiresKey);
    await _removeLegacyToken();
    authMode.value = AuthMode.manual;
    token.value = clean;
    user.value = u;
    clearError();
  }

  /// 开始 OAuth：系统浏览器打开 Bangumi 授权页。
  /// Failures are observable through [error] and do not escape.
  Future<void> beginOAuth() async {
    if (busy.value) return;
    _startWork();
    try {
      await (_beginOAuthHandler ?? OAuthService.instance.beginOAuth)();
    } catch (failure) {
      _observeError(failure, AuthOperation.oauthStart);
    } finally {
      _finishWork();
    }
  }

  /// 处理 OAuth 回跳深链，成功后完成登录。
  /// Claim, profile initialization, and persistence failures are all observed.
  Future<void> handleOAuthCallback(Uri uri) async {
    // app_links may surface the same cold-start URI through both getInitialLink
    // and the stream. A one-time ticket must never be claimed twice, including
    // when the duplicate arrives just after the first claim has completed.
    final callback = OAuthService.parseCallback(uri);
    final fingerprint = callback == null
        ? null
        : Object.hash(callback.ticket, callback.state);
    if (_callbackInFlight ||
        (fingerprint != null && fingerprint == _completedCallbackFingerprint)) {
      return;
    }
    _callbackInFlight = true;
    _startWork();
    try {
      final session =
          await (_callbackHandler ?? OAuthService.instance.handleCallback)(uri);
      if (session == null) return;
      _completedCallbackFingerprint = fingerprint;
      final completer = _sessionCompleter;
      if (completer != null) {
        await completer(session);
      } else {
        await completeOAuth(session.sessionToken, session.expiresAt);
      }
    } catch (failure) {
      _observeError(failure, AuthOperation.oauthCallback);
    } finally {
      _callbackInFlight = false;
      _finishWork();
    }
  }

  /// 用 BFF 返回的不透明会话完成登录（拉取用户信息）。
  Future<void> completeOAuth(String sessionToken, DateTime expiresAt) async {
    final effective = '${OAuthConfig.sessionTokenPrefix}$sessionToken';
    final u = await BangumiApi.me(effective); // 失败会抛异常，不落盘
    await _storage.write(key: _kModeKey, value: 'oauth');
    await _storage.write(key: _kOAuthSessionKey, value: sessionToken);
    await _storage.write(
      key: _kOAuthExpiresKey,
      value: expiresAt.toIso8601String(),
    );
    await _storage.delete(key: _kManualTokenKey);
    await _removeLegacyToken();
    authMode.value = AuthMode.oauth;
    token.value = effective;
    user.value = u;
    clearError();
  }

  Future<void> logout() async {
    _startWork();
    try {
      final current = token.value;
      if (OAuthConfig.isSessionToken(current)) {
        // Best-effort server-side session delete; never blocks local logout.
        await OAuthService.instance.logoutSession(
          OAuthConfig.sessionTokenOf(current!),
        );
      }
      final fullyCleared = await _clearPersistedCredentialsBestEffort();
      if (!fullyCleared) {
        error.value = '已退出登录，但本地登录信息清理失败，请重启应用后重试。';
      }
    } catch (_) {
      // Never interpolate an internal error or credential.
      error.value = '已退出登录，但本地登录信息清理失败，请重启应用后重试。';
    } finally {
      authMode.value = AuthMode.manual;
      token.value = null;
      user.value = null;
      _finishWork();
    }
  }

  Future<bool> _clearPersistedCredentialsBestEffort() async {
    var success = true;
    for (final key in const [
      _kModeKey,
      _kOAuthSessionKey,
      _kOAuthExpiresKey,
      _kManualTokenKey,
    ]) {
      try {
        await _storage.delete(key: key);
      } catch (_) {
        success = false;
      }
    }
    try {
      await _removeLegacyToken();
    } catch (_) {
      success = false;
    }
    return success;
  }

  Future<void> _clearAll({bool clearError = true}) async {
    await _storage.delete(key: _kModeKey);
    await _storage.delete(key: _kOAuthSessionKey);
    await _storage.delete(key: _kOAuthExpiresKey);
    await _storage.delete(key: _kManualTokenKey);
    await _removeLegacyToken();
    authMode.value = AuthMode.manual;
    token.value = null;
    user.value = null;
    if (clearError) error.value = null;
  }

  /// 将旧的 shared_preferences `bgm_token` 迁移到安全存储后删除。
  Future<void> _migrateLegacyToken() async {
    final sp = await SharedPreferences.getInstance();
    final legacy = sp.getString(_kLegacyTokenKey);
    if (legacy == null || legacy.isEmpty) return;

    // 若已有安全存储凭据，仅移除旧键，避免覆盖新登录态。
    final existingMode = await _storage.read(key: _kModeKey);
    if (existingMode != null) {
      await sp.remove(_kLegacyTokenKey);
      return;
    }

    try {
      final u = await BangumiApi.me(legacy);
      await _storage.write(key: _kModeKey, value: 'manual');
      await _storage.write(key: _kManualTokenKey, value: legacy);
      authMode.value = AuthMode.manual;
      token.value = legacy;
      user.value = u;
    } catch (_) {
      // 旧令牌失效，直接丢弃。
    }
    await sp.remove(_kLegacyTokenKey);
  }

  Future<void> _removeLegacyToken() async {
    final sp = await SharedPreferences.getInstance();
    await sp.remove(_kLegacyTokenKey);
  }
}
