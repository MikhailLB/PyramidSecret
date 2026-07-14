import 'package:clarity_flutter/clarity_flutter.dart';
import 'package:firebase_app_check/firebase_app_check.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'gray/core/attribution_relay.dart';
import 'gray/core/desert_transport.dart';
import 'gray/core/portal_dispatcher.dart';
import 'gray/core/signal_scanner.dart';
import 'gray/core/telegram_courier.dart';
import 'gray/core/vault_locker.dart';
import 'gray/insight/oracle_trace.dart';
import 'root.dart';

// ────────────────────────────────────────────────────────────
// main.dart — Pyramid Secret entry point.
//
// Boot order:
//   1. Widgets binding.
//   2. Firebase + AppCheck (best-effort — game continues if absent).
//   3. Preferred orientations (both portrait AND landscape for the
//      loading and WebView; the game screens lock to portrait later).
//   4. Real-device HTTP client.
//   5. Vault (SharedPreferences + Keystore).
//   6. Gray-flow services.
//   7. runApp(...) — AwakenGate takes over from here.
// ────────────────────────────────────────────────────────────

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  try {
    await Firebase.initializeApp();
    await FirebaseAppCheck.instance.activate(
      androidProvider: kDebugMode
          ? AndroidProvider.debug
          : AndroidProvider.playIntegrity,
    );
  } catch (_) {
    // Missing google-services.json is expected until Firebase config
    // is handed over. Push + config API auth degrade gracefully.
  }

  await SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
    DeviceOrientation.portraitDown,
    DeviceOrientation.landscapeLeft,
    DeviceOrientation.landscapeRight,
  ]);

  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.light,
    ),
  );

  await desertTransport.awaken();

  final vault = VaultLocker();
  await vault.awaken();

  final scanner = SignalScanner();
  final relay = AttributionRelay();
  final dispatcher = PortalDispatcher(vault);
  final courier = TelegramCourier(vault);

  // Wrap the root in ClarityWidget so Microsoft Clarity can capture
  // the NATIVE Flutter surface (loading gate, push invite, native
  // game, WebView container). Session replay + custom events wired
  // through `OracleTrace` answer the "which screen did the paid user
  // drop off on?" question — see the analytics guide for the full
  // funnel breakdown.
  runApp(ClarityWidget(
    clarityConfig: OracleTrace.config,
    app: PyramidSecretRoot(
      vault: vault,
      scanner: scanner,
      relay: relay,
      dispatcher: dispatcher,
      courier: courier,
    ),
  ));
}
