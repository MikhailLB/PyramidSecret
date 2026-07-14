import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../insight/oracle_trace.dart';

// ────────────────────────────────────────────────────────────
// TempestScreen — offline / no-wifi fallback.
// ────────────────────────────────────────────────────────────
// Uses the project's Egyptian-styled full-screen artwork (portrait
// PNG + landscape WebP) and overlays a Retry button at the bottom.
// Debouncing / DNS heuristics live in SignalScanner + SanctumStage —
// this widget is purely visual + a retry hook.
//
// Rotation: per `custom_screens.md` the no-wifi screen ships with
// both portrait & landscape assets, so we explicitly unlock all four
// orientations on entry — the game locks itself to portrait when it
// starts, and without this override that lock would leak into the
// gray fallback and the landscape asset would never surface.

class TempestScreen extends StatefulWidget {
  static const String _portraitAsset = 'assets/Nowifi/nowifi_vert.png';
  static const String _landscapeAsset = 'assets/Nowifi/nowifi_hor.webp';

  final WidgetBuilder retryBuilder;

  const TempestScreen({super.key, required this.retryBuilder});

  @override
  State<TempestScreen> createState() => _TempestScreenState();
}

class _TempestScreenState extends State<TempestScreen>
    with SingleTickerProviderStateMixin {
  bool _isRetrying = false;
  late final AnimationController _pressCtrl;
  late final Animation<double> _pressScale;

  @override
  void initState() {
    super.initState();
    OracleTrace.screen('offline');
    SystemChrome.setPreferredOrientations(const [
      DeviceOrientation.portraitUp,
      DeviceOrientation.portraitDown,
      DeviceOrientation.landscapeLeft,
      DeviceOrientation.landscapeRight,
    ]);
    _pressCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 140),
      lowerBound: 0.94,
      upperBound: 1.0,
      value: 1.0,
    );
    _pressScale =
        CurvedAnimation(parent: _pressCtrl, curve: Curves.easeOutCubic);
  }

  @override
  void dispose() {
    _pressCtrl.dispose();
    super.dispose();
  }

  Future<void> _handleRetry() async {
    if (_isRetrying) return;
    OracleTrace.event('offline_retry');
    await _pressCtrl.reverse();
    await _pressCtrl.forward();
    setState(() => _isRetrying = true);
    await Future.delayed(const Duration(milliseconds: 550));
    if (!mounted) return;
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(builder: widget.retryBuilder),
    );
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    final isLandscape =
        MediaQuery.of(context).orientation == Orientation.landscape;
    final asset = isLandscape
        ? TempestScreen._landscapeAsset
        : TempestScreen._portraitAsset;

    return Scaffold(
      backgroundColor: const Color(0xFF1B0836),
      body: SizedBox.expand(
        child: Stack(
          fit: StackFit.expand,
          children: [
            Image.asset(
              asset,
              fit: BoxFit.cover,
              width: size.width,
              height: size.height,
              errorBuilder: (_, __, ___) =>
                  const ColoredBox(color: Color(0xFF1B0836)),
            ),
            _RetryTablet(
              scale: _pressScale,
              isBusy: _isRetrying,
              onTap: _handleRetry,
              onDown: () => _pressCtrl.reverse(),
              onUp: () => _pressCtrl.forward(),
              anchorFromBottom: isLandscape ? 0.09 : 0.11,
              widthFactor: isLandscape ? 0.24 : 0.72,
              height: isLandscape ? 42.0 : 58.0,
              fontSize: isLandscape ? 14.0 : 20.0,
              busyFontSize: isLandscape ? 12.0 : 17.0,
              spinnerSize: isLandscape ? 16.0 : 22.0,
            ),
          ],
        ),
      ),
    );
  }
}

class _RetryTablet extends StatelessWidget {
  final Animation<double> scale;
  final bool isBusy;
  final VoidCallback onTap;
  final VoidCallback onDown;
  final VoidCallback onUp;
  final double anchorFromBottom;
  final double widthFactor;
  final double height;
  final double fontSize;
  final double busyFontSize;
  final double spinnerSize;

  const _RetryTablet({
    required this.scale,
    required this.isBusy,
    required this.onTap,
    required this.onDown,
    required this.onUp,
    required this.anchorFromBottom,
    required this.widthFactor,
    this.height = 58.0,
    this.fontSize = 20.0,
    this.busyFontSize = 17.0,
    this.spinnerSize = 22.0,
  });

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    return Positioned(
      left: 0,
      right: 0,
      bottom: size.height * anchorFromBottom,
      child: Center(
        child: GestureDetector(
          onTapDown: (_) => onDown(),
          onTapUp: (_) {
            onUp();
            if (!isBusy) onTap();
          },
          onTapCancel: onUp,
          child: ScaleTransition(
            scale: scale,
            child: Container(
              width: size.width * widthFactor,
              height: height,
              padding: EdgeInsets.symmetric(horizontal: height * 0.4),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFFF4C752), Color(0xFF9F5B0F)],
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                ),
                borderRadius: BorderRadius.circular(18),
                border: Border.all(
                  color: const Color(0xFFFFE9A0),
                  width: 2.4,
                ),
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFFF4C752).withValues(alpha: 0.35),
                    blurRadius: 22,
                    spreadRadius: 1,
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
              child: isBusy
                  ? Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        SizedBox(
                          width: spinnerSize,
                          height: spinnerSize,
                          child: const CircularProgressIndicator(
                            strokeWidth: 2.4,
                            valueColor: AlwaysStoppedAnimation<Color>(
                                Color(0xFF3A1D00)),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Text(
                          'CONNECTING…',
                          style: TextStyle(
                            color: const Color(0xFF3A1D00),
                            fontSize: busyFontSize,
                            fontWeight: FontWeight.w900,
                            letterSpacing: busyFontSize > 14 ? 2.4 : 1.8,
                          ),
                        ),
                      ],
                    )
                  : Text(
                      'RETRY',
                      style: TextStyle(
                        color: const Color(0xFF3A1D00),
                        fontSize: fontSize,
                        fontWeight: FontWeight.w900,
                        letterSpacing: fontSize > 17 ? 3.5 : 2.6,
                      ),
                    ),
            ),
          ),
        ),
      ),
    );
  }
}
