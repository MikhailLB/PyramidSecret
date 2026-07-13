import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

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

  @override
  void initState() {
    super.initState();
    // Portrait & landscape background assets ship in the bundle, so
    // let the device rotate freely on this promo. Without an explicit
    // unlock the portrait lock set by the native game earlier in the
    // session would follow us here and hide the landscape artwork.
    SystemChrome.setPreferredOrientations(const [
      DeviceOrientation.portraitUp,
      DeviceOrientation.portraitDown,
      DeviceOrientation.landscapeLeft,
      DeviceOrientation.landscapeRight,
    ]);
  }

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
                  _ShrineTablet(
                    width: size.width * (isLandscape ? 0.36 : 0.72),
                    label: 'ACCEPT',
                    withShine: true,
                    onTap: _accept,
                  ),
                  const SizedBox(height: 14),
                  _ShrineTablet(
                    width: size.width * (isLandscape ? 0.36 : 0.72),
                    label: 'SKIP',
                    withShine: false,
                    onTap: _skip,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Shrine-styled action tablet used for both Accept and Skip so the
/// pair share the exact same gradient, border, radius, height and
/// text metrics. Only the pulsing outer glow is optional — Accept
/// gets it, Skip does not, so the visual hierarchy still reads
/// "primary / secondary" without changing the button's physique.
class _ShrineTablet extends StatefulWidget {
  final double width;
  final String label;
  final bool withShine;
  final VoidCallback onTap;

  const _ShrineTablet({
    required this.width,
    required this.label,
    required this.onTap,
    this.withShine = false,
  });

  @override
  State<_ShrineTablet> createState() => _ShrineTabletState();
}

class _ShrineTabletState extends State<_ShrineTablet>
    with SingleTickerProviderStateMixin {
  bool _pressed = false;
  AnimationController? _shineCtrl;
  Animation<double>? _shine;

  @override
  void initState() {
    super.initState();
    if (widget.withShine) {
      _shineCtrl = AnimationController(
        vsync: this,
        duration: const Duration(milliseconds: 1400),
      )..repeat(reverse: true);
      _shine = Tween<double>(begin: 0.25, end: 0.6).animate(
        CurvedAnimation(parent: _shineCtrl!, curve: Curves.easeInOut),
      );
    }
  }

  @override
  void dispose() {
    _shineCtrl?.dispose();
    super.dispose();
  }

  BoxDecoration _decoration(double shineAlpha) {
    return BoxDecoration(
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
        if (shineAlpha > 0)
          BoxShadow(
            color: const Color(0xFFF4C752).withValues(alpha: shineAlpha),
            blurRadius: 22,
            spreadRadius: shineAlpha * 3,
            offset: const Offset(0, 4),
          ),
        const BoxShadow(
          color: Colors.black45,
          blurRadius: 10,
          offset: Offset(0, 5),
        ),
      ],
    );
  }

  Widget _tablet(double shineAlpha) {
    return AnimatedScale(
      scale: _pressed ? 0.96 : 1.0,
      duration: const Duration(milliseconds: 90),
      child: Container(
        width: widget.width,
        height: 60,
        decoration: _decoration(shineAlpha),
        alignment: Alignment.center,
        child: Text(
          widget.label,
          style: const TextStyle(
            color: Color(0xFF2A1200),
            fontSize: 20,
            fontWeight: FontWeight.w900,
            letterSpacing: 3.2,
          ),
        ),
      ),
    );
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
      child: _shine == null
          ? _tablet(0)
          : AnimatedBuilder(
              animation: _shine!,
              builder: (_, _) => _tablet(_shine!.value),
            ),
    );
  }
}

