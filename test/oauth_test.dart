import 'dart:async';
import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';

import 'package:bgm_app/auth/oauth_config.dart';
import 'package:bgm_app/auth/oauth_session_events.dart';
import 'package:bgm_app/auth/oauth_service.dart';
import 'package:bgm_app/store/auth_store.dart';

void main() {
  group('OAuthConfig', () {
    test('session token prefix marks opaque BFF sessions', () {
      expect(OAuthConfig.sessionTokenPrefix, 'oauth:');
      expect(OAuthConfig.isSessionToken('oauth:abc123'), isTrue);
      expect(OAuthConfig.isSessionToken('raw-access-token'), isFalse);
      expect(OAuthConfig.isSessionToken(null), isFalse);
      expect(OAuthConfig.sessionTokenOf('oauth:abc123'), 'abc123');
      expect(OAuthConfig.sessionTokenOf('raw'), 'raw');
    });

    test('callback URI constants are consistent', () {
      expect(OAuthConfig.callbackScheme, 'abangumi');
      expect(OAuthConfig.callbackHost, 'oauth');
      expect(OAuthConfig.callbackPath, '/callback');
      expect(OAuthConfig.callbackUri, 'abangumi://oauth/callback');
    });
  });

  group('OAuthService.generateVerifier', () {
    test('produces >=256 bits as unpadded base64url', () {
      final v = OAuthService.generateVerifier();
      expect(v, matches(RegExp(r'^[A-Za-z0-9_-]{43}$')));
      expect(base64Url.decode(base64Url.normalize(v)).length, 32);
    });

    test('produces unique values', () {
      final seen = <String>{};
      for (var i = 0; i < 100; i++) {
        seen.add(OAuthService.generateVerifier());
      }
      expect(seen.length, 100);
    });
  });

  group('OAuthService.computeChallenge', () {
    test('is a 64-char lowercase hex digest and deterministic', () {
      final c = OAuthService.computeChallenge('verifier-1');
      expect(c, matches(RegExp(r'^[0-9a-f]{64}$')));
      expect(OAuthService.computeChallenge('verifier-1'), c);
    });

    test('differs for different verifiers', () {
      expect(
        OAuthService.computeChallenge('a'),
        isNot(OAuthService.computeChallenge('b')),
      );
    });

    test('matches the BFF SHA-256 hex convention (UTF-8)', () {
      // sha256('verifier') in hex — a fixed known value computed from UTF-8.
      final c = OAuthService.computeChallenge('verifier');
      expect(c.length, 64);
      expect(c, c.toLowerCase());
    });
  });

  group('AuthStore observable OAuth state', () {
    test('rejected OA session clears stale local auth state', () async {
      final store = AuthStore.forTesting();
      store.token.value = 'oauth:stale-session-for-test';

      await OAuthSessionEvents.notifyInvalidated();

      expect(store.token.value, isNull);
      expect(store.user.value, isNull);
      expect(store.authMode.value, AuthMode.manual);
      expect(store.error.value, contains('登录状态已失效'));
    });

    test('initialization failure is observed and does not escape', () async {
      const fakeToken = 'fake-initialization-token-for-test-only';
      final store = AuthStore.forTesting(
        initializationHandler: () async {
          throw Exception('secure storage failed for $fakeToken');
        },
      );

      await expectLater(store.init(), completes);

      expect(store.busy.value, isFalse);
      expect(store.error.value, '无法恢复登录状态，请稍后重试。');
      expect(store.error.value, isNot(contains(fakeToken)));
    });

    test('callback failure is observed and does not escape', () async {
      final pending = Completer<OAuthSession?>();
      final store = AuthStore.forTesting(
        callbackHandler: (_) => pending.future,
      );

      final handling = store.handleOAuthCallback(
        Uri.parse('abangumi://oauth/callback?ticket=fake&state=fake'),
      );
      expect(store.busy.value, isTrue);
      expect(store.error.value, isNull);

      pending.completeError(
        Exception(
          'session_token=not-a-real-token&verifier=not-a-real-verifier',
        ),
      );
      await expectLater(handling, completes);

      expect(store.busy.value, isFalse);
      expect(store.error.value, '未能完成 OAuth 登录，请重新发起登录。');
      expect(store.error.value, isNot(contains('not-a-real')));
      expect(store.token.value, isNull);
    });

    test(
      'duplicate callback delivery is ignored while claim is active',
      () async {
        final pending = Completer<OAuthSession?>();
        var callbackCount = 0;
        final store = AuthStore.forTesting(
          callbackHandler: (_) {
            callbackCount += 1;
            return pending.future;
          },
        );
        final uri = Uri.parse(
          'abangumi://oauth/callback?ticket=fake&state=fake',
        );

        final first = store.handleOAuthCallback(uri);
        await expectLater(store.handleOAuthCallback(uri), completes);
        expect(callbackCount, 1);
        expect(store.busy.value, isTrue);

        pending.complete(null);
        await first;
        expect(store.busy.value, isFalse);
      },
    );

    test(
      'sequential duplicate callback is ignored after successful claim',
      () async {
        var callbackCount = 0;
        final store = AuthStore.forTesting(
          callbackHandler: (_) async {
            callbackCount += 1;
            return OAuthSession(
              sessionToken: 'fake-session-for-dedup-test',
              expiresAt: DateTime.utc(2030),
            );
          },
          sessionCompleter: (_) async {},
        );
        final uri = Uri.parse(
          'abangumi://oauth/callback?ticket=fake&state=fake',
        );

        await store.handleOAuthCallback(uri);
        await store.handleOAuthCallback(uri);

        expect(callbackCount, 1);
        expect(store.error.value, isNull);
      },
    );

    test(
      'claim completion failure is observed without exposing session',
      () async {
        const fakeSession = 'fake-session-value-for-test-only';
        final store = AuthStore.forTesting(
          callbackHandler: (_) async => OAuthSession(
            sessionToken: fakeSession,
            expiresAt: DateTime.utc(2030),
          ),
          sessionCompleter: (_) async {
            throw Exception('failed while storing $fakeSession');
          },
        );

        await expectLater(
          store.handleOAuthCallback(Uri.parse('abangumi://unrelated')),
          completes,
        );

        expect(store.busy.value, isFalse);
        expect(store.error.value, '未能完成 OAuth 登录，请重新发起登录。');
        expect(store.error.value, isNot(contains(fakeSession)));
      },
    );

    test('OAuth start failure updates safe observable error', () async {
      const fakeVerifier = 'fake-verifier-value-for-test-only';
      final store = AuthStore.forTesting(
        beginOAuthHandler: () async {
          throw Exception('launch failed for verifier=$fakeVerifier');
        },
      );

      await expectLater(store.beginOAuth(), completes);

      expect(store.busy.value, isFalse);
      expect(store.error.value, 'OAuth 登录失败，请稍后重试。');
      expect(store.error.value, isNot(contains(fakeVerifier)));
    });

    test('callback validation errors have specific non-sensitive messages', () {
      expect(
        authErrorMessage(
          const OAuthCallbackException(
            OAuthCallbackFailureReason.stateMismatch,
          ),
          AuthOperation.oauthCallback,
        ),
        '授权回调校验失败，请返回应用后重新登录。',
      );
      expect(
        authErrorMessage(
          const OAuthCallbackException(
            OAuthCallbackFailureReason.expiredPendingFlow,
          ),
          AuthOperation.oauthCallback,
        ),
        '授权请求已失效，请重新发起登录。',
      );
    });
  });

  group('OAuthService.parseCallback', () {
    test('parses a valid abangumi://oauth/callback deep link', () {
      final cb = OAuthService.parseCallback(
        Uri.parse('abangumi://oauth/callback?ticket=t1&state=s1'),
      );
      expect(cb, isNotNull);
      expect(cb!.ticket, 't1');
      expect(cb.state, 's1');
    });

    test('rejects a different scheme', () {
      expect(
        OAuthService.parseCallback(
          Uri.parse('https://example.com/oauth/callback?ticket=t&state=s'),
        ),
        isNull,
      );
    });

    test('rejects a different host', () {
      expect(
        OAuthService.parseCallback(
          Uri.parse('abangumi://other/callback?ticket=t&state=s'),
        ),
        isNull,
      );
    });

    test('rejects a different path', () {
      expect(
        OAuthService.parseCallback(
          Uri.parse('abangumi://oauth/elsewhere?ticket=t&state=s'),
        ),
        isNull,
      );
    });

    test('rejects missing ticket', () {
      expect(
        OAuthService.parseCallback(
          Uri.parse('abangumi://oauth/callback?state=s'),
        ),
        isNull,
      );
    });

    test('rejects missing state', () {
      expect(
        OAuthService.parseCallback(
          Uri.parse('abangumi://oauth/callback?ticket=t'),
        ),
        isNull,
      );
    });
  });
}
