import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../gray/insight/oracle_trace.dart';
import '../app_theme.dart';
import '../models/level.dart';
import 'game_screen.dart';

class LevelsScreen extends StatefulWidget {
  const LevelsScreen({super.key});

  @override
  State<LevelsScreen> createState() => _LevelsScreenState();
}

class _LevelsScreenState extends State<LevelsScreen> {
  int _highestUnlocked = 1;

  @override
  void initState() {
    super.initState();
    OracleTrace.screen('levels');
    _loadProgress();
  }

  Future<void> _loadProgress() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _highestUnlocked = prefs.getInt('highest_unlocked') ?? 1;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        fit: StackFit.expand,
        children: [
          Image.asset(AppAssets.menuBg, fit: BoxFit.cover),
          Container(color: Colors.black.withOpacity(0.35)),
          SafeArea(
            child: Column(
              children: [
                _buildHeader(context),
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 20, vertical: 12),
                    child: GridView.builder(
                      itemCount: LevelConfig.levels.length,
                      gridDelegate:
                          const SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: 3,
                        mainAxisSpacing: 14,
                        crossAxisSpacing: 14,
                        childAspectRatio: 0.85,
                      ),
                      itemBuilder: (context, i) {
                        final levelNum = i + 1;
                        final locked = levelNum > _highestUnlocked;
                        return _LevelTile(
                          number: levelNum,
                          locked: locked,
                          config: LevelConfig.levels[i],
                          onTap: locked
                              ? null
                              : () async {
                                  await Navigator.of(context).push(
                                    MaterialPageRoute(
                                      builder: (_) => GameScreen(
                                          level: LevelConfig.levels[i]),
                                    ),
                                  );
                                  _loadProgress();
                                },
                        );
                      },
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHeader(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
      child: Row(
        children: [
          _CircleIconButton(
            icon: Icons.arrow_back_ios_new_rounded,
            onTap: () => Navigator.of(context).pop(),
          ),
          const Spacer(),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 8),
            decoration: BoxDecoration(
              color: Colors.black.withOpacity(0.55),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: AppColors.goldBright, width: 2),
            ),
            child: const Text(
              'SELECT LEVEL',
              style: TextStyle(
                color: AppColors.goldBright,
                fontSize: 22,
                fontWeight: FontWeight.w900,
                letterSpacing: 3,
                shadows: [
                  Shadow(color: Colors.black87, offset: Offset(0, 2), blurRadius: 3),
                ],
              ),
            ),
          ),
          const Spacer(),
          const SizedBox(width: 44),
        ],
      ),
    );
  }
}

class _CircleIconButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;
  const _CircleIconButton({required this.icon, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 44,
        height: 44,
        decoration: BoxDecoration(
          color: Colors.black.withOpacity(0.55),
          shape: BoxShape.circle,
          border: Border.all(color: AppColors.goldBright, width: 2),
        ),
        alignment: Alignment.center,
        child: Icon(icon, color: AppColors.goldBright, size: 20),
      ),
    );
  }
}

class _LevelTile extends StatelessWidget {
  final int number;
  final bool locked;
  final LevelConfig config;
  final VoidCallback? onTap;
  const _LevelTile({
    required this.number,
    required this.locked,
    required this.config,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: locked
                ? const [Color(0xFF3A3A3A), Color(0xFF1E1E1E)]
                : const [Color(0xFFC08B34), Color(0xFF6B4111)],
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
          ),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: locked ? Colors.grey.shade700 : AppColors.goldBright,
            width: 2.5,
          ),
          boxShadow: const [
            BoxShadow(color: Colors.black54, blurRadius: 6, offset: Offset(0, 3)),
          ],
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            if (locked)
              const Icon(Icons.lock_rounded, color: Colors.white70, size: 32)
            else
              Text(
                '$number',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 30,
                  fontWeight: FontWeight.w900,
                  shadows: [
                    Shadow(color: Colors.black, offset: Offset(0, 2), blurRadius: 3),
                  ],
                ),
              ),
            const SizedBox(height: 6),
            Text(
              '${config.rows}×${config.cols}',
              style: TextStyle(
                color: Colors.white.withOpacity(locked ? 0.5 : 0.9),
                fontSize: 12,
                fontWeight: FontWeight.w600,
                letterSpacing: 1.2,
              ),
            ),
            Text(
              '${config.mines} traps',
              style: TextStyle(
                color: Colors.white.withOpacity(locked ? 0.5 : 0.9),
                fontSize: 11,
                letterSpacing: 0.8,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
