import 'package:flutter/material.dart';

import '../app_theme.dart';
import 'levels_screen.dart';
import 'webview_screen.dart';

class MainMenuScreen extends StatelessWidget {
  const MainMenuScreen({super.key});

  static const _privacyUrl = 'https://pyramidseccret.com';
  static const _supportUrl = 'https://pyramidseccret.com';

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        fit: StackFit.expand,
        children: [
          Image.asset(AppAssets.menuBg, fit: BoxFit.cover),
          Container(color: Colors.black.withOpacity(0.15)),
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
              child: Column(
                children: [
                  const SizedBox(height: 10),
                  _buildTitle(),
                  const Spacer(),
                  EgyptButton(
                    label: 'PLAY',
                    icon: Icons.play_arrow_rounded,
                    onTap: () => Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) => const LevelsScreen(),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  EgyptButton(
                    label: 'PRIVACY POLICY',
                    icon: Icons.privacy_tip_outlined,
                    onTap: () => _openWeb(context, _privacyUrl, 'Privacy Policy'),
                  ),
                  const SizedBox(height: 16),
                  EgyptButton(
                    label: 'SUPPORT',
                    icon: Icons.support_agent_rounded,
                    onTap: () => _openWeb(context, _supportUrl, 'Support'),
                  ),
                  const SizedBox(height: 40),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTitle() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 26, vertical: 14),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xCC0A1128), Color(0xCC1F0F00)],
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
        ),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppColors.goldBright, width: 2.5),
        boxShadow: const [
          BoxShadow(color: Colors.black54, blurRadius: 10, offset: Offset(0, 4)),
        ],
      ),
      child: Column(
        children: const [
          Text(
            'PYRAMID',
            style: TextStyle(
              color: AppColors.goldBright,
              fontSize: 34,
              fontWeight: FontWeight.w900,
              letterSpacing: 5,
              shadows: [
                Shadow(color: Colors.black, offset: Offset(0, 3), blurRadius: 4),
              ],
            ),
          ),
          Text(
            'SECRET',
            style: TextStyle(
              color: AppColors.goldBright,
              fontSize: 34,
              fontWeight: FontWeight.w900,
              letterSpacing: 8,
              shadows: [
                Shadow(color: Colors.black, offset: Offset(0, 3), blurRadius: 4),
              ],
            ),
          ),
        ],
      ),
    );
  }

  void _openWeb(BuildContext context, String url, String title) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => WebViewScreen(url: url, title: title),
      ),
    );
  }
}
