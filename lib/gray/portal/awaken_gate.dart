import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';

import '../../white/screens/loading_screen.dart';
import '../core/attribution_relay.dart';
import '../core/portal_dispatcher.dart';
import '../core/signal_scanner.dart';
import '../core/telegram_courier.dart';
import '../core/vault_locker.dart';
import '../env/sanctum_config.dart';
import '../relics/portal_mode.dart';
import 'flame_token_screen.dart';
import 'sanctum_stage.dart' deferred as sanctum;
import 'tempest_screen.dart';

// ────────────────────────────────────────────────────────────
// AwakenGate — entry orchestrator.
// ────────────────────────────────────────────────────────────
// Draws the Egyptian loading artwork with a golden progress bar
// while the gray-flow state machine decides whether to open the
// WebView shell or hand off to the native minesweeper. The white
// LoadingScreen is used as the offline destination — it already
// carries its own progress animation into MainMenuScreen.

class AwakenGate extends StatefulWidget {
  final VaultLocker vault;
  final SignalScanner scanner;
  final AttributionRelay relay;
  final PortalDispatcher dispatcher;
  final TelegramCourier courier;

  const AwakenGate({
    super.key,
    required this.vault,
    required this.scanner,
    required this.relay,
    required this.dispatcher,
    required this.courier,
  });

  @override
  State<AwakenGate> createState() => _AwakenGateState();
}

class _AwakenGateState extends State<AwakenGate> {
  // The bar animates continuously toward 0.92 over ~9 s so the user
  // always sees motion no matter which branch of the state machine
  // is currently in flight. The remaining 8 % are filled instantly
  // right before we push the next screen — that's the "loaded"
  // signal the user asked for.
  static const Duration _ceilingApproach = Duration(milliseconds: 9000);
  static const double _naturalCeiling = 0.92;
  static const Duration _tick = Duration(milliseconds: 60);

  double _fill = 0.0;
  int _dots = 0;
  Timer? _dotTimer;
  Timer? _fillTimer;
  DateTime? _fillStart;
  bool _routed = false;

  @override
  void initState() {
    super.initState();
    _dotTimer = Timer.periodic(const Duration(milliseconds: 420), (_) {
      if (!mounted) return;
      setState(() => _dots = (_dots + 1) % 4);
    });
    _startFillTimer();
    _driveGrayFlow();
  }

  @override
  void dispose() {
    _dotTimer?.cancel();
    _fillTimer?.cancel();
    super.dispose();
  }

  void _startFillTimer() {
    _fillStart = DateTime.now();
    _fillTimer = Timer.periodic(_tick, (_) {
      if (!mounted) {
        _fillTimer?.cancel();
        return;
      }
      final elapsed = DateTime.now()
          .difference(_fillStart!)
          .inMilliseconds
          .toDouble();
      // Slight ease-out so the last 20 % crawl instead of leaping.
      final ratio =
          (elapsed / _ceilingApproach.inMilliseconds).clamp(0.0, 1.0);
      final eased = 1.0 - (1.0 - ratio) * (1.0 - ratio);
      final target = eased * _naturalCeiling;
      if (target > _fill) setState(() => _fill = target);
      if (ratio >= 1.0) _fillTimer?.cancel();
    });
  }

  /// Called just before pushReplacement — rushes the bar to 100 %
  /// and waits one frame so the user actually sees it snap full.
  Future<void> _finalizeFill() async {
    _fillTimer?.cancel();
    if (!mounted) return;
    setState(() => _fill = 1.0);
    await Future<void>.delayed(const Duration(milliseconds: 260));
  }

  // Silences the analyzer for now-unused stub while keeping call
  // sites readable if we ever need to nudge the bar mid-flow again.
  // ignore: unused_element
  void _setFill(double v) => setState(() => _fill = v.clamp(0.0, 1.0));

  Future<void> _driveGrayFlow() async {
    widget.courier.onTokenRotated = _rotateToken;
    unawaited(widget.courier.awaken());

    final mode = widget.vault.readPortalMode();
    switch (mode) {
      case PortalMode.unlocked:
        await _resumeUnlocked();
        break;
      case PortalMode.sealed:
        await _rollIntoWhite();
        break;
      case PortalMode.awaiting:
        await _firstContact();
        break;
    }
  }

  void _rotateToken(String freshToken) async {
    final body = await widget.relay.composeBody(
      locale: _resolveLocale(),
      pushToken: freshToken,
    );
    unawaited(widget.dispatcher.ask(body));
  }

  String _resolveLocale() => Platform.localeName.replaceAll('-', '_');

  Future<void> _firstContact() async {
    final online = await widget.scanner.hasReachableNet();
    if (!online) {
      _sendToTempest();
      return;
    }

    await widget.relay.awaken();

    // Phase 1 — SDK race with a hard cap.
    await Future.wait<void>([
      widget.relay.waitForInstallPayload(
        cap: Duration(
          seconds: SanctumConfig.firstLaunchAttributionCapSeconds,
        ),
      ).then((_) {}),
      widget.relay.waitForDeepLink(
        cap: Duration(
          seconds: SanctumConfig.firstLaunchDeepLinkCapSeconds,
        ),
      ),
    ]);

    // Phase 2 — deep link says non-organic, but SDK is still silent.
    if (!widget.relay.hasInstallPayload &&
        widget.relay.deepLinkSuggestsNonOrganic) {
      await Future.any<void>([
        widget.relay.chaseGcdSnapshot(),
        widget.relay
            .waitForInstallPayload(
              cap: Duration(seconds: SanctumConfig.gcdPollWindowSeconds),
            )
            .then((_) {}),
      ]);
    }

    final body = await widget.relay.composeBody(
      locale: _resolveLocale(),
      pushToken: widget.courier.token,
    );
    final reply = await widget.dispatcher.ask(body);

    if (reply.hasShrine) {
      await widget.vault.writePortalMode(PortalMode.unlocked);
      await _finalizeFill();
      _sendToShrine(reply.shrineUrl!);
      return;
    }

    // "sealed" is a permanent verdict per TZ §9 — never re-ask.
    await widget.vault.writePortalMode(PortalMode.sealed);
    await _finalizeFill();
    _rollIntoWhite();
  }

  Future<void> _resumeUnlocked() async {
    final live = await widget.scanner.hasReachableNet();
    if (!live) {
      _sendToTempest();
      return;
    }

    // Cold-tap URL wins over every other candidate.
    final cold = await widget.vault.pluckColdPushUrl();
    if (cold != null && cold.isNotEmpty) {
      await _finalizeFill();
      _sendToShrine(cold);
      return;
    }

    final cached = await widget.dispatcher.lastKnownShrine();

    await widget.relay.awaken();
    await Future.wait<void>([
      widget.relay
          .waitForInstallPayload(
            cap: Duration(
              seconds: SanctumConfig.warmAttributionCapSeconds,
            ),
          )
          .then((_) {}),
      widget.relay.waitForDeepLink(
        cap: Duration(seconds: SanctumConfig.firstLaunchDeepLinkCapSeconds),
      ),
    ]);

    final body = await widget.relay.composeBody(
      locale: _resolveLocale(),
      pushToken: widget.courier.token,
    );
    final reply = await widget.dispatcher.ask(body);
    await _finalizeFill();

    if (reply.hasShrine) {
      _sendToShrine(reply.shrineUrl!);
      return;
    }

    if (cached != null && cached.isNotEmpty) {
      _sendToShrine(cached);
      return;
    }

    _sendToTempest();
  }

  Future<void> _rollIntoWhite() async {
    if (_routed) return;
    _routed = true;
    await _finalizeFill();
    if (!mounted) return;
    Navigator.of(context).pushReplacement(
      PageRouteBuilder(
        transitionDuration: const Duration(milliseconds: 450),
        pageBuilder: (_, __, ___) => const LoadingScreen(),
        transitionsBuilder: (_, a, __, child) =>
            FadeTransition(opacity: a, child: child),
      ),
    );
  }

  Future<void> _sendToShrine(String url) async {
    if (_routed) return;
    _routed = true;
    await sanctum.loadLibrary();
    await sanctum.primeSanctumEngine();
    if (!mounted) return;

    if (widget.vault.shouldSummonFlame()) {
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(
          builder: (_) => FlameTokenScreen(
            vault: widget.vault,
            courier: widget.courier,
            scanner: widget.scanner,
            shrineUrl: url,
          ),
        ),
      );
    } else {
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(
          builder: (_) => sanctum.SanctumStage(
            shrineUrl: url,
            vault: widget.vault,
            courier: widget.courier,
            scanner: widget.scanner,
          ),
        ),
      );
    }
  }

  void _sendToTempest() {
    if (_routed) return;
    _routed = true;
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(
        builder: (_) => TempestScreen(
          retryBuilder: (_) => AwakenGate(
            vault: widget.vault,
            scanner: widget.scanner,
            relay: widget.relay,
            dispatcher: widget.dispatcher,
            courier: widget.courier,
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final dotsText = '.' * _dots;
    final fill = _fill;
    return Scaffold(
      backgroundColor: const Color(0xFF0A1128),
      body: LayoutBuilder(
        builder: (context, constraints) {
          final isPortrait = constraints.maxHeight >= constraints.maxWidth;
          final bg = isPortrait
              ? 'assets/vertical_loadingg.png'
              : 'assets/Frame 2.webp';
          final barWidth =
              (constraints.maxWidth * (isPortrait ? 0.78 : 0.55))
                  .clamp(240.0, 700.0);

          return Stack(
            fit: StackFit.expand,
            children: [
              Image.asset(
                bg,
                fit: BoxFit.cover,
                errorBuilder: (_, __, ___) =>
                    const ColoredBox(color: Color(0xFF0A1128)),
              ),
              DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      Colors.transparent,
                      Colors.black.withValues(alpha: 0.6),
                    ],
                    stops: const [0.5, 1.0],
                  ),
                ),
              ),
              Padding(
                padding: EdgeInsets.only(
                  bottom: isPortrait ? constraints.maxHeight * 0.10 : 40,
                  left: 24,
                  right: 24,
                ),
                child: Align(
                  alignment: Alignment.bottomCenter,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        'Loading$dotsText',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 22,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 2,
                          shadows: [
                            Shadow(
                              color: Colors.black,
                              blurRadius: 6,
                              offset: Offset(0, 2),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 14),
                      _GoldBar(width: barWidth, fill: fill),
                      const SizedBox(height: 10),
                      Text(
                        '${(fill * 100).toInt()}%',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          letterSpacing: 1.2,
                          shadows: [
                            Shadow(
                              color: Colors.black,
                              blurRadius: 3,
                              offset: Offset(0, 1),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _GoldBar extends StatelessWidget {
  final double width;
  final double fill;
  const _GoldBar({required this.width, required this.fill});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: width,
      height: 18,
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.55),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFFF7D77E), width: 2),
      ),
      padding: const EdgeInsets.all(2.5),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(20),
        child: Align(
          alignment: Alignment.centerLeft,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            width: (width - 9) * fill,
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [
                  Color(0xFFF9E39A),
                  Color(0xFFD4A24C),
                  Color(0xFFB0752B),
                ],
              ),
              borderRadius: BorderRadius.circular(20),
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFFD4A24C).withValues(alpha: 0.5),
                  blurRadius: 6,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
