import 'dart:async';

/// Decouples API transport code from the auth store while allowing a rejected OA
/// session to clear the app's stale local authentication state immediately.
abstract final class OAuthSessionEvents {
  static FutureOr<void> Function()? onInvalidated;

  static Future<void> notifyInvalidated() async {
    await onInvalidated?.call();
  }
}
