import 'dart:async';
import 'dart:convert';
import 'dart:math';

import 'package:app_links/app_links.dart';
import 'package:crypto/crypto.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:http/http.dart' as http;
import 'package:url_launcher/url_launcher.dart';

import '../api/bangumi_api.dart';
import 'oauth_config.dart';

/// Result of parsing an `abangumi://oauth/callback` deep link.
class OAuthCallback {
  final String ticket;
  final String state;
  const OAuthCallback({required this.ticket, required this.state});
}

/// Credentials returned after claiming the one-time ticket from the BFF.
class OAuthSession {
  final String sessionToken;
  final DateTime expiresAt;
  const OAuthSession({required this.sessionToken, required this.expiresAt});
}

/// Safe, non-sensitive reasons why an otherwise valid callback cannot finish.
enum OAuthCallbackFailureReason {
  missingPendingFlow,
  expiredPendingFlow,
  corruptPendingFlow,
  stateMismatch,
}

/// Never includes the callback ticket, state, verifier, or a session token.
class OAuthCallbackException implements Exception {
  final OAuthCallbackFailureReason reason;
  const OAuthCallbackException(this.reason);

  @override
  String toString() => 'OAuthCallbackException(${reason.name})';
}

/// Browser launch failure without embedding a URL or credential in the error.
class OAuthBrowserLaunchException implements Exception {
  const OAuthBrowserLaunchException();

  @override
  String toString() => 'OAuthBrowserLaunchException';
}

/// Drives the secure Bangumi OAuth flow: start in the system browser, parse the
/// `abangumi://oauth/callback` deep link, verify `state`, and claim the ticket.
///
/// **Ticket-theft defense (PKCE-style claim verifier):**
/// before `/start` the app generates a ≥256-bit random `verifier` and sends the
/// BFF only its SHA-256 `challenge`. The BFF binds the challenge to the `state`.
/// The callback deep link carries only `ticket`+`state` (both are browser/public
/// values), so a malicious app that registers `abangumi://` cannot claim the
/// ticket — `/claim` requires the app-held `verifier` whose SHA-256 must match
/// the bound challenge. The verifier never appears in any URL or log.
///
/// The pending `state`/`verifier` are kept in [FlutterSecureStorage] so the flow
/// survives app process death during the browser round-trip, and are cleared on
/// success, definitive failure, timeout, or a new start.
///
/// Contains no client secret — the BFF (`server/`) owns all secrets and tokens.
class OAuthService {
  OAuthService._();

  static final OAuthService instance = OAuthService._();

  static const FlutterSecureStorage _secure = FlutterSecureStorage();

  /// Secure-storage key holding the pending `{state, verifier, ts}` JSON.
  static const String _pendingKey = 'oauth_pending';

  final AppLinks _appLinks = AppLinks();

  StreamSubscription<Uri>? _sub;

  static const _timeout = Duration(seconds: 20);
  static const _pendingTtlMs = 5 * 60 * 1000; // 5 minutes

  /// Start the flow: generate a verifier, ask the BFF for an
  /// `authorization_url` + `state` (bound to our challenge), persist the pending
  /// verifier, then open the Bangumi authorize page in the system browser.
  Future<void> beginOAuth() async {
    final base = _requireBaseUrl();

    final verifier = generateVerifier();
    final challenge = computeChallenge(verifier);

    final resp = await http
        .post(
          Uri.parse('$base${OAuthConfig.startPath}'),
          headers: const {'Content-Type': 'application/json'},
          body: jsonEncode({'verifier_challenge': challenge}),
        )
        .timeout(_timeout);
    if (resp.statusCode != 200) {
      throw ApiException(resp.statusCode);
    }
    final map = jsonDecode(utf8.decode(resp.bodyBytes)) as Map<String, dynamic>;
    final authUrl = map['authorization_url'] as String? ?? '';
    final state = map['state'] as String? ?? '';
    if (authUrl.isEmpty || state.isEmpty) {
      throw const FormatException('BFF /auth/bangumi/start 返回数据不完整');
    }

    // Persist BEFORE launching the browser so an app kill/restart during the
    // round-trip still lets us claim the ticket afterwards.
    await _savePending(state, verifier);

    final ok = await launchUrl(
      Uri.parse(authUrl),
      mode: LaunchMode.externalApplication,
    );
    if (!ok) {
      await _clearPending();
      throw const OAuthBrowserLaunchException();
    }
  }

  /// Handle an incoming `abangumi://` deep link: parse, verify state (including
  /// timeout), claim with the app-held verifier. Returns null only when the URI
  /// is not an OAuth callback. A valid callback that cannot be completed throws
  /// a non-sensitive [OAuthCallbackException]; state mismatch leaves the
  /// legitimate pending flow untouched.
  Future<OAuthSession?> handleCallback(Uri uri) async {
    final cb = parseCallback(uri);
    if (cb == null) return null;

    final pending = await _loadPending();
    if (pending == null) {
      throw const OAuthCallbackException(
        OAuthCallbackFailureReason.missingPendingFlow,
      );
    }

    final ts = int.tryParse(pending['ts'] ?? '') ?? 0;
    final now = DateTime.now().millisecondsSinceEpoch;
    if (ts == 0 || now - ts > _pendingTtlMs || now < ts) {
      await _clearPending(); // expired or corrupt
      throw const OAuthCallbackException(
        OAuthCallbackFailureReason.expiredPendingFlow,
      );
    }

    final expectedState = pending['state'] ?? '';
    final verifier = pending['verifier'] ?? '';
    if (expectedState.isEmpty || verifier.isEmpty) {
      await _clearPending();
      throw const OAuthCallbackException(
        OAuthCallbackFailureReason.corruptPendingFlow,
      );
    }

    if (cb.state != expectedState) {
      // Foreign/stale callback — do NOT destructively clear a legitimate
      // pending flow.
      throw const OAuthCallbackException(
        OAuthCallbackFailureReason.stateMismatch,
      );
    }

    try {
      final session = await claim(cb.ticket, cb.state, verifier);
      await _clearPending();
      return session;
    } catch (_) {
      await _clearPending(); // definitive failure: flow is over
      rethrow;
    }
  }

  /// Claim a one-time ticket from the BFF, proving possession of the verifier.
  Future<OAuthSession> claim(
    String ticket,
    String state,
    String verifier,
  ) async {
    final base = _requireBaseUrl();
    final resp = await http
        .post(
          Uri.parse('$base${OAuthConfig.claimPath}'),
          headers: const {'Content-Type': 'application/json'},
          body: jsonEncode({
            'ticket': ticket,
            'state': state,
            'verifier': verifier,
          }),
        )
        .timeout(_timeout);
    if (resp.statusCode != 200) throw ApiException(resp.statusCode);
    final map = jsonDecode(utf8.decode(resp.bodyBytes)) as Map<String, dynamic>;
    final session = map['session_token'] as String? ?? '';
    final expiresRaw = map['expires_at'] as String? ?? '';
    if (session.isEmpty || expiresRaw.isEmpty) {
      throw const FormatException('BFF /auth/bangumi/claim 返回数据不完整');
    }
    return OAuthSession(
      sessionToken: session,
      expiresAt: DateTime.parse(expiresRaw),
    );
  }

  /// Best-effort server-side logout (never throws).
  Future<void> logoutSession(String sessionToken) async {
    try {
      final base = _requireBaseUrl();
      await http
          .post(
            Uri.parse('$base${OAuthConfig.logoutPath}'),
            headers: {'Authorization': 'Bearer $sessionToken'},
          )
          .timeout(_timeout);
    } catch (_) {
      // Best-effort: the app still clears its local session below.
    }
  }

  /// Subscribe to deep links (both the initial link and future ones).
  ///
  /// Both synchronous and asynchronous callback failures, as well as app-links
  /// initialization/stream failures, are forwarded to [onError]. No future is
  /// intentionally left unobserved.
  void bind(
    FutureOr<void> Function(Uri) onUri, {
    void Function(Object error)? onError,
  }) {
    void reportError(Object error) {
      try {
        onError?.call(error);
      } catch (_) {
        // Error observers must not create a second unhandled async failure.
      }
    }

    Future<void> dispatch(Uri uri) async {
      try {
        await onUri(uri);
      } catch (error) {
        reportError(error);
      }
    }

    try {
      _sub ??= _appLinks.uriLinkStream.listen(
        (uri) => unawaited(dispatch(uri)),
        onError: (Object error) => reportError(error),
      );
    } catch (error) {
      reportError(error);
    }

    Future<void> dispatchInitialLink() async {
      try {
        final uri = await _appLinks.getInitialLink();
        if (uri != null) await dispatch(uri);
      } catch (error) {
        reportError(error);
      }
    }

    unawaited(dispatchInitialLink());
  }

  void dispose() {
    _sub?.cancel();
    _sub = null;
  }

  // ----- pure, testable helpers -----

  /// Generate a cryptographically random ≥256-bit (32-byte) verifier, encoded
  /// as unpadded base64url (43 chars).
  static String generateVerifier() {
    final rng = Random.secure();
    final bytes = List<int>.generate(32, (_) => rng.nextInt(256));
    return base64UrlEncode(bytes).replaceAll('=', '');
  }

  /// SHA-256 challenge (64 lowercase hex chars) for [verifier].
  static String computeChallenge(String verifier) {
    return sha256.convert(utf8.encode(verifier)).toString();
  }

  /// Pure parser for the `abangumi://oauth/callback?ticket=…&state=…` deep link.
  /// Returns null for anything that is not a well-formed OAuth callback.
  static OAuthCallback? parseCallback(Uri uri) {
    if (uri.scheme != OAuthConfig.callbackScheme) return null;
    if (uri.host != OAuthConfig.callbackHost) return null;
    if (uri.path != OAuthConfig.callbackPath) return null;
    final ticket = uri.queryParameters['ticket'];
    final state = uri.queryParameters['state'];
    if (ticket == null || ticket.isEmpty) return null;
    if (state == null || state.isEmpty) return null;
    return OAuthCallback(ticket: ticket, state: state);
  }

  // ----- pending storage -----

  Future<void> _savePending(String state, String verifier) async {
    await _secure.write(
      key: _pendingKey,
      value: jsonEncode({
        'state': state,
        'verifier': verifier,
        'ts': DateTime.now().millisecondsSinceEpoch.toString(),
      }),
    );
  }

  Future<Map<String, String>?> _loadPending() async {
    final raw = await _secure.read(key: _pendingKey);
    if (raw == null || raw.isEmpty) return null;
    try {
      final map = jsonDecode(raw) as Map<String, dynamic>;
      return {
        'state': map['state'] as String? ?? '',
        'verifier': map['verifier'] as String? ?? '',
        'ts': map['ts'] as String? ?? '',
      };
    } catch (_) {
      return null;
    }
  }

  Future<void> _clearPending() async {
    await _secure.delete(key: _pendingKey);
  }

  static String _requireBaseUrl() => OAuthConfig.requireAuthBaseUrl();
}
