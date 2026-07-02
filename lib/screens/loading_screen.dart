import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../app_theme.dart';
import '../main.dart';
import 'main_menu_screen.dart';

class LoadingScreen extends StatefulWidget {
  const LoadingScreen({super.key});

  @override
  State<LoadingScreen> createState() => _LoadingScreenState();
}

class _LoadingScreenState extends State<LoadingScreen>
    with SingleTickerProviderStateMixin {
  static const int _totalDurationMs = 4200;
  static const int _fillDelayMs = 3400;

  double _progress = 0.0;
  Timer? _tickTimer;
  int _dotCount = 0;
  Timer? _dotTimer;

  @override
  void initState() {
    super.initState();
    allowAllOrientations();
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
    _startLoading();
    _startDots();
  }

  void _startDots() {
    _dotTimer = Timer.periodic(const Duration(milliseconds: 450), (_) {
      if (!mounted) return;
      setState(() {
        _dotCount = (_dotCount + 1) % 4;
      });
    });
  }

  void _startLoading() {
    final start = DateTime.now();
    _tickTimer = Timer.periodic(const Duration(milliseconds: 40), (t) {
      if (!mounted) return;
      final elapsed = DateTime.now().difference(start).inMilliseconds;
      double p;
      if (elapsed < _fillDelayMs) {
        // ease progress up to 92% during the "load" phase
        final ratio = elapsed / _fillDelayMs;
        p = (ratio * 0.92).clamp(0.0, 0.92);
      } else {
        // fill the rest quickly right before launching the menu
        final ratio =
            (elapsed - _fillDelayMs) / (_totalDurationMs - _fillDelayMs);
        p = 0.92 + ratio.clamp(0.0, 1.0) * 0.08;
      }
      setState(() {
        _progress = p.clamp(0.0, 1.0);
      });
      if (elapsed >= _totalDurationMs) {
        t.cancel();
        _finish();
      }
    });
  }

  Future<void> _finish() async {
    setState(() => _progress = 1.0);
    await Future.delayed(const Duration(milliseconds: 180));
    if (!mounted) return;
    await lockPortrait();
    if (!mounted) return;
    Navigator.of(context).pushReplacement(
      PageRouteBuilder(
        pageBuilder: (_, a, __) => const MainMenuScreen(),
        transitionsBuilder: (_, a, __, child) =>
            FadeTransition(opacity: a, child: child),
        transitionDuration: const Duration(milliseconds: 500),
      ),
    );
  }

  @override
  void dispose() {
    _tickTimer?.cancel();
    _dotTimer?.cancel();
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.darkNavy,
      body: LayoutBuilder(
        builder: (context, constraints) {
          final isPortrait = constraints.maxHeight >= constraints.maxWidth;
          final bgAsset =
              isPortrait ? AppAssets.verticalLoading : AppAssets.frame;
          return Stack(
            fit: StackFit.expand,
            children: [
              Image.asset(
                bgAsset,
                fit: BoxFit.cover,
                alignment: Alignment.center,
              ),
              // Dark overlay to make progress readable
              Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      Colors.transparent,
                      Colors.black.withOpacity(0.55),
                    ],
                    stops: const [0.5, 1.0],
                  ),
                ),
              ),
              _buildLoadingUi(constraints, isPortrait),
            ],
          );
        },
      ),
    );
  }

  Widget _buildLoadingUi(BoxConstraints constraints, bool isPortrait) {
    final dots = '.' * _dotCount;
    final barWidth = (constraints.maxWidth * (isPortrait ? 0.78 : 0.55))
        .clamp(240.0, 700.0);
    return Padding(
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
              'Loading$dots',
              style: const TextStyle(
                color: Colors.white,
                fontSize: 22,
                fontWeight: FontWeight.w800,
                letterSpacing: 2,
                shadows: [
                  Shadow(color: Colors.black, offset: Offset(0, 2), blurRadius: 6),
                ],
              ),
            ),
            const SizedBox(height: 14),
            _buildProgressBar(barWidth),
            const SizedBox(height: 10),
            Text(
              '${(_progress * 100).toInt()}%',
              style: const TextStyle(
                color: Colors.white,
                fontSize: 14,
                fontWeight: FontWeight.w600,
                letterSpacing: 1.2,
                shadows: [
                  Shadow(color: Colors.black, offset: Offset(0, 1), blurRadius: 3),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildProgressBar(double width) {
    return Container(
      width: width,
      height: 18,
      decoration: BoxDecoration(
        color: Colors.black.withOpacity(0.55),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.goldBright, width: 2),
      ),
      padding: const EdgeInsets.all(2.5),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(20),
        child: Align(
          alignment: Alignment.centerLeft,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 120),
            width: (width - 9) * _progress,
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFFF9E39A), AppColors.gold, Color(0xFFB0752B)],
                begin: Alignment.centerLeft,
                end: Alignment.centerRight,
              ),
              borderRadius: BorderRadius.circular(20),
              boxShadow: [
                BoxShadow(
                  color: AppColors.gold.withOpacity(0.5),
                  blurRadius: 6,
                  offset: const Offset(0, 0),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
