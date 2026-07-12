import 'package:flutter/material.dart';

import '../core/signal_scanner.dart';
import '../core/telegram_courier.dart';
import '../core/vault_locker.dart';
import '../env/sanctum_config.dart';
import 'sanctum_stage.dart' deferred as sanctum;

// ────────────────────────────────────────────────────────────
// FlameTokenScreen — push-permission promo (Accept / Skip).
// ────────────────────────────────────────────────────────────
// Background art is one of the two full-screen "Notifications"
// assets (portrait/landscape). Two buttons sit at the bottom:
//   • Accept  → requests the OS permission, then continues.
//   • Skip    → defers the promo by 3 days, then continues.
// The promo is a soft opt-in; both branches route to SanctumStage.

class FlameTokenScreen extends StatefulWidget {
  static const String _portraitAsset =
      'assets/Notifications/notif_vert.webp';
  static const String _landscapeAsset =
      'assets/Notifications/notif_hor.webp';

  final VaultLocker vault;
  final TelegramCourier courier;
  final SignalScanner scanner;
  final String shrineUrl;

  const FlameTokenScreen({
    super.key,
    required this.vault,
    required this.courier,
    required this.scanner,
    required this.shrineUrl,
  });

  @override
  State<FlameTokenScreen> createState() => _FlameTokenScreenState();
}

class _FlameTokenScreenState extends State<FlameTokenScreen> {
  bool _navigating = false;

  Future<void> _accept() async {
    if (_navigating) return;
    _navigating = true;
    await widget.courier.requestFlamePermission();
    if (!mounted) return;
    _openSanctum();
  }

  Future<void> _skip() async {
    if (_navigating) return;
    _navigating = true;
    final defer = DateTime.now().millisecondsSinceEpoch ~/ 1000 +
        SanctumConfig.flameDeferSeconds;
    await widget.vault.deferFlameUntil(defer);
    if (!mounted) return;
    _openSanctum();
  }

  Future<void> _openSanctum() async {
    await sanctum.loadLibrary();
    if (!mounted) return;
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(
        builder: (_) => sanctum.SanctumStage(
          shrineUrl: widget.shrineUrl,
          vault: widget.vault,
          courier: widget.courier,
          scanner: widget.scanner,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    final isLandscape =
        MediaQuery.of(context).orientation == Orientation.landscape;
    final bg = isLandscape
        ? FlameTokenScreen._landscapeAsset
        : FlameTokenScreen._portraitAsset;

    return Scaffold(
      backgroundColor: const Color(0xFF14082A),
      body: SizedBox.expand(
        child: Stack(
          fit: StackFit.expand,
          children: [
            Image.asset(
              bg,
              fit: BoxFit.cover,
              width: size.width,
              height: size.height,
              errorBuilder: (_, __, ___) =>
                  const ColoredBox(color: Color(0xFF14082A)),
            ),
            Positioned(
              left: 0,
              right: 0,
              bottom: size.height * (isLandscape ? 0.07 : 0.09),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  _AcceptTablet(
                    width: size.width * (isLandscape ? 0.36 : 0.72),
                    onTap: _accept,
                  ),
                  const SizedBox(height: 14),
                  _SkipLink(onTap: _skip),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _AcceptTablet extends StatefulWidget {
  final double width;
  final VoidCallback onTap;
  const _AcceptTablet({required this.width, required this.onTap});
  @override
  State<_AcceptTablet> createState() => _AcceptTabletState();
}

class _AcceptTabletState extends State<_AcceptTablet>
    with SingleTickerProviderStateMixin {
  bool _pressed = false;
  late final AnimationController _shineCtrl;
  late final Animation<double> _shine;

  @override
  void initState() {
    super.initState();
    _shineCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1400),
    )..repeat(reverse: true);
    _shine = Tween<double>(begin: 0.25, end: 0.6).animate(
      CurvedAnimation(parent: _shineCtrl, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _shineCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: (_) => setState(() => _pressed = true),
      onTapUp: (_) {
        setState(() => _pressed = false);
        widget.onTap();
      },
      onTapCancel: () => setState(() => _pressed = false),
      child: AnimatedBuilder(
        animation: _shine,
        builder: (_, __) => AnimatedScale(
          scale: _pressed ? 0.96 : 1.0,
          duration: const Duration(milliseconds: 90),
          child: Container(
            width: widget.width,
            height: 60,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: _pressed
                    ? const [Color(0xFFD59A2C), Color(0xFF7A400C)]
                    : const [Color(0xFFFFE38F), Color(0xFFB0641A)],
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
              ),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: const Color(0xFFFFF3C1),
                width: 2.6,
              ),
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFFF4C752).withValues(alpha: _shine.value),
                  blurRadius: 22,
                  spreadRadius: _shine.value * 3,
                  offset: const Offset(0, 4),
                ),
                const BoxShadow(
                  color: Colors.black45,
                  blurRadius: 10,
                  offset: Offset(0, 5),
                ),
              ],
            ),
            alignment: Alignment.center,
            child: const Text(
              'ACCEPT',
              style: TextStyle(
                color: Color(0xFF2A1200),
                fontSize: 20,
                fontWeight: FontWeight.w900,
                letterSpacing: 3.2,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _SkipLink extends StatefulWidget {
  final VoidCallback onTap;
  const _SkipLink({required this.onTap});
  @override
  State<_SkipLink> createState() => _SkipLinkState();
}

class _SkipLinkState extends State<_SkipLink> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: (_) => setState(() => _pressed = true),
      onTapUp: (_) {
        setState(() => _pressed = false);
        widget.onTap();
      },
      onTapCancel: () => setState(() => _pressed = false),
      child: AnimatedOpacity(
        opacity: _pressed ? 0.5 : 0.88,
        duration: const Duration(milliseconds: 90),
        child: const Padding(
          padding: EdgeInsets.symmetric(vertical: 6, horizontal: 22),
          child: Text(
            'Skip',
            style: TextStyle(
              color: Colors.white,
              fontSize: 20,
              fontWeight: FontWeight.w700,
              letterSpacing: 1.8,
              shadows: [
                Shadow(
                  color: Colors.black87,
                  blurRadius: 8,
                  offset: Offset(0, 2),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
