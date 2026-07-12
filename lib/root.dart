import 'package:flutter/material.dart';

import 'gray/core/attribution_relay.dart';
import 'gray/core/portal_dispatcher.dart';
import 'gray/core/signal_scanner.dart';
import 'gray/core/telegram_courier.dart';
import 'gray/core/vault_locker.dart';
import 'gray/portal/awaken_gate.dart';

class PyramidSecretRoot extends StatelessWidget {
  final VaultLocker vault;
  final SignalScanner scanner;
  final AttributionRelay relay;
  final PortalDispatcher dispatcher;
  final TelegramCourier courier;

  const PyramidSecretRoot({
    super.key,
    required this.vault,
    required this.scanner,
    required this.relay,
    required this.dispatcher,
    required this.courier,
  });

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Pyramid Secret',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        scaffoldBackgroundColor: const Color(0xFF0A1128),
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFFD4A24C),
          brightness: Brightness.dark,
        ),
        textTheme: const TextTheme(
          bodyMedium: TextStyle(color: Colors.white),
          titleLarge: TextStyle(color: Colors.white),
        ),
      ),
      home: AwakenGate(
        vault: vault,
        scanner: scanner,
        relay: relay,
        dispatcher: dispatcher,
        courier: courier,
      ),
    );
  }
}
