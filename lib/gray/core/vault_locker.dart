import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../relics/portal_mode.dart';

// ────────────────────────────────────────────────────────────
// VaultLocker — persistence layer (SharedPreferences + Keystore).
// ────────────────────────────────────────────────────────────
// SharedPreferences holds non-secret flags: portal mode, timestamps.
// FlutterSecureStorage holds anything that would be sensitive to
// leak on a rooted device: the last confirmed shrine URL, the cold
// push URL, the URL expiry timestamp.

class VaultLocker {
  static const String _kPortalMode = 'gate_state';
  static const String _kShrineUrl = 'sanctum_link';
  static const String _kShrineExpiry = 'sanctum_expiry';
  static const String _kFlameDefer = 'flame_defer';
  static const String _kFlameGrant = 'flame_open';
  static const String _kFlameDenied = 'flame_denied';
  static const String _kColdPushUrl = 'courier_link';

  late final SharedPreferences _prefs;
  final FlutterSecureStorage _safe;

  VaultLocker({FlutterSecureStorage? safe})
      : _safe = safe ?? const FlutterSecureStorage();

  Future<void> awaken() async {
    _prefs = await SharedPreferences.getInstance();
  }

  // ─── Portal mode ─────────────────────────────────────────

  PortalMode readPortalMode() =>
      PortalMode.fromToken(_prefs.getString(_kPortalMode));

  Future<void> writePortalMode(PortalMode mode) =>
      _prefs.setString(_kPortalMode, mode.toToken());

  // ─── Shrine URL (secure) ─────────────────────────────────

  Future<String?> peekShrineUrl() => _safe.read(key: _kShrineUrl);

  Future<void> stashShrineUrl(String value) =>
      _safe.write(key: _kShrineUrl, value: value);

  Future<void> setShrineExpiry(int unixSeconds) =>
      _prefs.setInt(_kShrineExpiry, unixSeconds);

  int? peekShrineExpiry() => _prefs.getInt(_kShrineExpiry);

  bool isShrineExpired() {
    final at = peekShrineExpiry();
    if (at == null) return true;
    final now = DateTime.now().millisecondsSinceEpoch ~/ 1000;
    return now >= at;
  }

  // ─── Flame (push) permission gating ─────────────────────

  bool isFlameGranted() => _prefs.getBool(_kFlameGrant) ?? false;

  Future<void> markFlameGranted(bool value) =>
      _prefs.setBool(_kFlameGrant, value);

  bool isFlameOsDenied() => _prefs.getBool(_kFlameDenied) ?? false;

  Future<void> markFlameOsDenied() => _prefs.setBool(_kFlameDenied, true);

  int? peekFlameDeferUntil() => _prefs.getInt(_kFlameDefer);

  Future<void> deferFlameUntil(int unixSeconds) =>
      _prefs.setInt(_kFlameDefer, unixSeconds);

  /// Gray-flow rule (per TZ): show the promo only if permission is
  /// not yet granted AND the OS still allows a request AND the user
  /// has not just tapped Skip inside the last 3 days.
  bool shouldSummonFlame() {
    if (isFlameGranted()) return false;
    if (isFlameOsDenied()) return false;
    final until = peekFlameDeferUntil();
    if (until == null) return true;
    final now = DateTime.now().millisecondsSinceEpoch ~/ 1000;
    return now >= until;
  }

  // ─── Cold-tap push URL (secure, one-shot) ───────────────

  Future<void> stashColdPushUrl(String? value) async {
    if (value == null || value.isEmpty) {
      await _safe.delete(key: _kColdPushUrl);
    } else {
      await _safe.write(key: _kColdPushUrl, value: value);
    }
  }

  Future<String?> pluckColdPushUrl() async {
    final value = await _safe.read(key: _kColdPushUrl);
    if (value != null) {
      await _safe.delete(key: _kColdPushUrl);
    }
    return value;
  }
}
