import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

import 'desert_transport.dart';
import 'vault_locker.dart';

// ────────────────────────────────────────────────────────────
// TelegramCourier — Firebase Messaging + local notification display.
// ────────────────────────────────────────────────────────────
// Notification icon: @drawable/ic_flame (fire glyph — per user brief).
// Notification channel: `desert_flame_hi` (kept in sync with the
// AndroidManifest meta-data below).
//
// Push-tap URL rules (per gray_part_pitfalls §12):
//   * The URL may live under one of several keys — walk aliases.
//   * Reject anything that is not a plain http/https absolute URL.
//   * Cold-tap URLs are cached to the vault; warm-tap URLs are pushed
//     straight to the live handler and never persisted.

const String flameChannelId = 'desert_flame_hi';
const String flameChannelLabel = 'Pyramid Secret alerts';
const String flameIconResource = '@drawable/ic_flame';

@pragma('vm:entry-point')
Future<void> _backgroundMessageDrop(RemoteMessage message) async {
  // Nothing to do in the background isolate; Android will surface the
  // notification via the system channel. Cold-tap consumption happens
  // in the main isolate via getInitialMessage().
}

Uri? _sanitiseShrineUrl(dynamic candidate) {
  if (candidate is! String) return null;
  final trimmed = candidate.trim();
  if (trimmed.isEmpty) return null;
  final uri = Uri.tryParse(trimmed);
  if (uri == null) return null;
  if (uri.scheme != 'http' && uri.scheme != 'https') return null;
  if (!uri.hasAuthority) return null;
  return uri;
}

String? _pickShrineLink(Map<String, dynamic> data) {
  const aliases = <String>['url', 'link', 'landing_page', 'deep_link_value'];
  for (final key in aliases) {
    final uri = _sanitiseShrineUrl(data[key]);
    if (uri != null) return uri.toString();
  }
  return null;
}

class TelegramCourier {
  final VaultLocker _vault;
  final FlutterLocalNotificationsPlugin _local =
      FlutterLocalNotificationsPlugin();
  FirebaseMessaging? _fcm;

  String? _token;
  bool _booted = false;

  TelegramCourier(this._vault);

  String? get token => _token;

  /// Fired by SanctumStage while the user is inside the WebView —
  /// live handler for warm push URLs.
  void Function(String url)? onWarmShrine;

  /// Fired when FCM rotates the token — SplashScreen re-POSTs.
  void Function(String token)? onTokenRotated;

  Future<void> awaken() async {
    if (_booted) return;

    try {
      await Firebase.initializeApp();
      _fcm = FirebaseMessaging.instance;

      FirebaseMessaging.onBackgroundMessage(_backgroundMessageDrop);

      await _prepareLocal();

      _token = await _fcm!.getToken();

      _fcm!.onTokenRefresh.listen((fresh) {
        _token = fresh;
        onTokenRotated?.call(fresh);
      });

      FirebaseMessaging.onMessage.listen(_showForegroundBanner);
      FirebaseMessaging.onMessageOpenedApp.listen(_warmTap);

      final cold = await _fcm!.getInitialMessage();
      if (cold != null) await _coldTap(cold);
    } catch (_) {
      // Firebase missing / misconfigured — push is silently disabled.
    } finally {
      _booted = true;
    }
  }

  Future<void> _prepareLocal() async {
    const androidSettings =
        AndroidInitializationSettings(flameIconResource);
    const iosSettings = DarwinInitializationSettings(
      requestAlertPermission: false,
      requestBadgePermission: false,
      requestSoundPermission: false,
    );
    await _local.initialize(
      const InitializationSettings(
        android: androidSettings,
        iOS: iosSettings,
      ),
      onDidReceiveNotificationResponse: (response) {
        if (response.payload == null) return;
        try {
          final data =
              jsonDecode(response.payload!) as Map<String, dynamic>;
          final link = _pickShrineLink(data);
          if (link != null) onWarmShrine?.call(link);
        } catch (_) {}
      },
    );

    if (Platform.isAndroid) {
      final android = _local.resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin>();
      await android?.createNotificationChannel(
        const AndroidNotificationChannel(
          flameChannelId,
          flameChannelLabel,
          importance: Importance.high,
          description: 'Pyramid Secret content updates',
        ),
      );
    }
  }

  Future<bool> requestFlamePermission() async {
    if (_fcm == null) return false;
    final settings = await _fcm!.requestPermission(
      alert: true,
      badge: true,
      sound: true,
      provisional: false,
    );
    final status = settings.authorizationStatus;
    final granted = status == AuthorizationStatus.authorized ||
        status == AuthorizationStatus.provisional;
    await _vault.markFlameGranted(granted);
    if (status == AuthorizationStatus.denied) {
      await _vault.markFlameOsDenied();
    }
    return granted;
  }

  Future<void> _showForegroundBanner(RemoteMessage message) async {
    final notification = message.notification;
    if (notification == null) return;
    if (!Platform.isAndroid) return;

    AndroidNotificationDetails? details;
    final imageUrl = notification.android?.imageUrl;
    if (imageUrl != null && imageUrl.isNotEmpty) {
      final bytes = await _fetchBytes(imageUrl);
      if (bytes != null) {
        details = AndroidNotificationDetails(
          flameChannelId,
          flameChannelLabel,
          importance: Importance.high,
          priority: Priority.high,
          icon: flameIconResource,
          styleInformation: BigPictureStyleInformation(
            ByteArrayAndroidBitmap(bytes),
            largeIcon:
                const DrawableResourceAndroidBitmap('@mipmap/ic_launcher'),
          ),
        );
      }
    }
    details ??= const AndroidNotificationDetails(
      flameChannelId,
      flameChannelLabel,
      importance: Importance.high,
      priority: Priority.high,
      icon: flameIconResource,
    );

    final payload =
        message.data.isNotEmpty ? jsonEncode(message.data) : null;

    await _local.show(
      notification.hashCode,
      notification.title,
      notification.body,
      NotificationDetails(android: details),
      payload: payload,
    );
  }

  Future<void> _coldTap(RemoteMessage message) async {
    final link = _pickShrineLink(Map<String, dynamic>.from(message.data));
    if (link != null) await _vault.stashColdPushUrl(link);
  }

  void _warmTap(RemoteMessage message) {
    final link = _pickShrineLink(Map<String, dynamic>.from(message.data));
    if (link != null) onWarmShrine?.call(link);
  }

  Future<Uint8List?> _fetchBytes(String url) async {
    try {
      final response = await desertTransport
          .get(Uri.parse(url))
          .timeout(const Duration(seconds: 10));
      if (response.statusCode == 200) return response.bodyBytes;
    } catch (_) {}
    return null;
  }
}
