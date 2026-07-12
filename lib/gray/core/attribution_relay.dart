import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:appsflyer_sdk/appsflyer_sdk.dart';
import 'package:flutter/foundation.dart';

import '../env/oracle_creds.dart';
import '../env/sanctum_config.dart';
import 'desert_transport.dart';

// ────────────────────────────────────────────────────────────
// AttributionRelay — AppsFlyer wrapper (init + attribution race).
// ────────────────────────────────────────────────────────────
// Behaviour matches the state machine in `android_gray_guide.md` and
// the compound fix for §11 of `gray_part_pitfalls.md` (slow SDK
// callback → parallel GCD polling).
//
// The relay never mutates AppsFlyer payload fields — the backend
// depends on them arriving as delivered.

class AttributionRelay {
  AppsflyerSdk? _sdk;

  Map<String, dynamic>? _installBody;
  Map<String, dynamic>? _deepLinkBody;
  Map<String, dynamic>? _openBody;

  final Completer<Map<String, dynamic>> _installGate = Completer();
  final Completer<void> _deepLinkGate = Completer();

  bool _booted = false;

  bool get hasInstallPayload =>
      _installBody != null && _installBody!.isNotEmpty;

  bool get deepLinkSuggestsNonOrganic {
    final data = _deepLinkBody;
    if (data == null || data.isEmpty) return false;
    bool nonEmpty(String key) {
      final value = data[key];
      return value != null && value.toString().isNotEmpty;
    }

    return nonEmpty('deep_link_value') ||
        nonEmpty('deep_link_sub1') ||
        nonEmpty('shortlink');
  }

  Future<void> awaken() async {
    if (_booted) return;
    _booted = true;

    final devKey = SanctumConfig.analyticsKey;
    if (devKey.isEmpty) {
      // No live keys yet — resolve gates immediately so the splash
      // does not stall waiting for a callback that will never arrive.
      _closeInstallGate(<String, dynamic>{});
      _closeDeepLinkGate();
      return;
    }

    final options = AppsFlyerOptions(
      afDevKey: devKey,
      appId: SanctumConfig.iosStoreId,
      showDebug: kDebugMode,
      timeToWaitForATTUserAuthorization: 10,
    );
    _sdk = AppsflyerSdk(options);

    _sdk!.onInstallConversionData((raw) async {
      final payload = _asMap(raw);
      if (payload['af_status']?.toString() == 'Organic') {
        await Future<void>.delayed(
          Duration(seconds: SanctumConfig.organicRetryDelaySeconds),
        );
        final fresh = await _fetchGcdSnapshot();
        _installBody = fresh ?? payload;
      } else {
        _installBody = payload;
      }
      _closeInstallGate(_installBody!);
    });

    _sdk!.onAppOpenAttribution((raw) {
      _openBody = _asMap(raw);
    });

    _sdk!.onDeepLinking((result) {
      final click = result.deepLink?.clickEvent;
      if (click != null) {
        _deepLinkBody = Map<String, dynamic>.from(click);
      }
      _closeDeepLinkGate();
    });

    try {
      await _sdk!.initSdk(
        registerConversionDataCallback: true,
        registerOnAppOpenAttributionCallback: true,
        registerOnDeepLinkingCallback: true,
      );
    } catch (_) {
      _closeInstallGate(<String, dynamic>{});
      _closeDeepLinkGate();
    }
  }

  Map<String, dynamic> _asMap(dynamic raw) {
    if (raw is Map) {
      final inner = raw['payload'];
      final root = inner is Map ? inner : raw;
      final result = <String, dynamic>{};
      root.forEach((k, v) => result[k.toString()] = v);
      return result;
    }
    return <String, dynamic>{};
  }

  void _closeInstallGate(Map<String, dynamic> payload) {
    if (!_installGate.isCompleted) _installGate.complete(payload);
  }

  void _closeDeepLinkGate() {
    if (!_deepLinkGate.isCompleted) _deepLinkGate.complete();
  }

  Future<Map<String, dynamic>> waitForInstallPayload({
    Duration? cap,
  }) {
    return _installGate.future.timeout(
      cap ??
          Duration(
            seconds: SanctumConfig.firstLaunchAttributionCapSeconds,
          ),
      onTimeout: () => <String, dynamic>{},
    );
  }

  Future<void> waitForDeepLink({Duration? cap}) async {
    await _deepLinkGate.future.timeout(
      cap ??
          Duration(seconds: SanctumConfig.firstLaunchDeepLinkCapSeconds),
      onTimeout: () {},
    );
  }

  Future<String?> uid() async {
    if (_sdk == null) return null;
    try {
      return await _sdk!.getAppsFlyerUID();
    } catch (_) {
      return null;
    }
  }

  Future<Map<String, dynamic>?> _fetchGcdSnapshot() async {
    final devKey = SanctumConfig.analyticsKey;
    if (devKey.isEmpty) return null;
    final device = await uid();
    if (device == null || device.isEmpty) return null;
    final appId =
        Platform.isIOS ? SanctumConfig.iosStoreId : SanctumConfig.bundleTag;
    final url = assembleOracleGcd(
      appId: appId,
      deviceId: device,
      devKey: devKey,
    );
    if (url.isEmpty) return null;
    try {
      final response = await desertTransport
          .get(Uri.parse(url))
          .timeout(const Duration(seconds: 10));
      if (response.statusCode != 200) return null;
      final decoded = jsonDecode(response.body);
      if (decoded is Map) {
        return Map<String, dynamic>.from(decoded);
      }
    } catch (_) {}
    return null;
  }

  /// Polls the GCD endpoint until an `af_status` verdict shows up or
  /// [SanctumConfig.gcdPollWindowSeconds] elapses. Used only when the
  /// SDK callback runs late but a real click was received.
  Future<void> chaseGcdSnapshot() async {
    if (_installGate.isCompleted) return;
    if (SanctumConfig.analyticsKey.isEmpty) return;

    final deadline = DateTime.now().add(
      Duration(seconds: SanctumConfig.gcdPollWindowSeconds),
    );
    while (!_installGate.isCompleted && DateTime.now().isBefore(deadline)) {
      final snapshot = await _fetchGcdSnapshot();
      if (_installGate.isCompleted) return;
      if (snapshot != null) {
        final status = snapshot['af_status']?.toString();
        if (status != null && status.isNotEmpty && status != 'error') {
          _installBody = snapshot;
          _closeInstallGate(snapshot);
          return;
        }
      }
      await Future<void>.delayed(
        Duration(seconds: SanctumConfig.gcdPollIntervalSeconds),
      );
    }
  }

  Future<Map<String, dynamic>> composeBody({
    required String locale,
    String? pushToken,
  }) async {
    final body = <String, dynamic>{};
    if (_installBody != null) body.addAll(_installBody!);
    _deepLinkBody?.forEach((k, v) => body.putIfAbsent(k, () => v));
    _openBody?.forEach((k, v) => body.putIfAbsent(k, () => v));

    final device = await uid();
    body['af_id'] = device ?? '';
    body['bundle_id'] = SanctumConfig.bundleTag;
    body['os'] = Platform.isAndroid ? 'Android' : 'iOS';
    body['store_id'] = SanctumConfig.storeTag;
    body['locale'] = locale;

    if (pushToken != null && pushToken.isNotEmpty) {
      body['push_token'] = pushToken;
    }
    final proj = SanctumConfig.messagingProjectId;
    if (proj.isNotEmpty) body['firebase_project_id'] = proj;

    if (kDebugMode) {
      debugPrint('[AttributionRelay] body → ${jsonEncode(body)}');
    }
    return body;
  }
}
