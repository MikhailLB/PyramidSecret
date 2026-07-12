import 'package:flutter/material.dart';

// ────────────────────────────────────────────────────────────
// TempestScreen — offline / no-wifi fallback.
// ────────────────────────────────────────────────────────────
// Uses the project's Egyptian-styled full-screen artwork (portrait
// PNG + landscape WebP) and overlays a Retry button at the bottom.
// Debouncing / DNS heuristics live in SignalScanner + SanctumStage —
// this widget is purely visual + a retry hook.

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
              widthFactor: isLandscape ? 0.34 : 0.72,
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

  const _RetryTablet({
    required this.scale,
    required this.isBusy,
    required this.onTap,
    required this.onDown,
    required this.onUp,
    required this.anchorFromBottom,
    required this.widthFactor,
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
              height: 58,
              padding: const EdgeInsets.symmetric(horizontal: 24),
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
                      children: const [
                        SizedBox(
                          width: 22,
                          height: 22,
                          child: CircularProgressIndicator(
                            strokeWidth: 2.4,
                            valueColor: AlwaysStoppedAnimation<Color>(
                                Color(0xFF3A1D00)),
                          ),
                        ),
                        SizedBox(width: 14),
                        Text(
                          'CONNECTING…',
                          style: TextStyle(
                            color: Color(0xFF3A1D00),
                            fontSize: 17,
                            fontWeight: FontWeight.w900,
                            letterSpacing: 2.4,
                          ),
                        ),
                      ],
                    )
                  : const Text(
                      'RETRY',
                      style: TextStyle(
                        color: Color(0xFF3A1D00),
                        fontSize: 20,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 3.5,
                      ),
                    ),
            ),
          ),
        ),
      ),
    );
  }
}
