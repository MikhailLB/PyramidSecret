import 'dart:async';

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../gray/insight/oracle_trace.dart';
import '../app_theme.dart';
import '../models/board.dart';
import '../models/level.dart';

class GameScreen extends StatefulWidget {
  final LevelConfig level;
  const GameScreen({super.key, required this.level});

  @override
  State<GameScreen> createState() => _GameScreenState();
}

enum _GameStatus { playing, won, lost }

class _GameScreenState extends State<GameScreen> {
  late Board _board;
  _GameStatus _status = _GameStatus.playing;
  bool _flagMode = false;
  int _seconds = 0;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    OracleTrace.screen('game');
    OracleTrace.tag('level', '${widget.level.number}');
    _newGame();
  }

  void _newGame() {
    _timer?.cancel();
    _board = Board(
      rows: widget.level.rows,
      cols: widget.level.cols,
      mines: widget.level.mines,
      treasures: widget.level.treasures,
    );
    _status = _GameStatus.playing;
    _seconds = 0;
    _flagMode = false;
    setState(() {});
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!mounted) return;
      if (_status != _GameStatus.playing) return;
      setState(() => _seconds++);
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  void _handleTap(int r, int c) {
    if (_status != _GameStatus.playing) return;
    setState(() {
      if (_flagMode) {
        _board.toggleFlag(r, c);
        return;
      }
      final result = _board.reveal(r, c);
      if (result == RevealResult.mine) {
        _board.revealAllMines();
        _status = _GameStatus.lost;
        _timer?.cancel();
        OracleTrace.event('game_lost');
        _showEndDialog(false);
      } else if (result == RevealResult.win) {
        _status = _GameStatus.won;
        _timer?.cancel();
        OracleTrace.event('game_won');
        _unlockNextLevel();
        _showEndDialog(true);
      }
    });
  }

  void _handleLongPress(int r, int c) {
    if (_status != _GameStatus.playing) return;
    setState(() => _board.toggleFlag(r, c));
  }

  Future<void> _unlockNextLevel() async {
    final prefs = await SharedPreferences.getInstance();
    final current = prefs.getInt('highest_unlocked') ?? 1;
    final next = widget.level.number + 1;
    if (next > current && next <= LevelConfig.levels.length) {
      await prefs.setInt('highest_unlocked', next);
    }
  }

  void _showEndDialog(bool win) {
    Future.delayed(const Duration(milliseconds: 260), () {
      if (!mounted) return;
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (_) => _EndDialog(
          win: win,
          levelNumber: widget.level.number,
          treasures: _board.treasuresCollected,
          seconds: _seconds,
          onRetry: () {
            Navigator.of(context).pop();
            _newGame();
          },
          onExit: () {
            Navigator.of(context).pop();
            Navigator.of(context).pop();
          },
          onNext: (widget.level.number < LevelConfig.levels.length && win)
              ? () {
                  Navigator.of(context).pop();
                  Navigator.of(context).pushReplacement(
                    MaterialPageRoute(
                      builder: (_) => GameScreen(
                        level:
                            LevelConfig.levels[widget.level.number],
                      ),
                    ),
                  );
                }
              : null,
        ),
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        fit: StackFit.expand,
        children: [
          Image.asset(AppAssets.menuBg, fit: BoxFit.cover),
          Container(color: Colors.black.withOpacity(0.55)),
          SafeArea(
            child: Column(
              children: [
                _buildHeader(context),
                Expanded(child: _buildBoard()),
                _buildFooter(),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHeader(BuildContext context) {
    final mm = (_seconds ~/ 60).toString().padLeft(2, '0');
    final ss = (_seconds % 60).toString().padLeft(2, '0');
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 6),
      child: Row(
        children: [
          _CircleBtn(
            icon: Icons.arrow_back_ios_new_rounded,
            onTap: () => Navigator.of(context).pop(),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                _statChip(Icons.warning_amber_rounded,
                    '${widget.level.mines - _board.flaggedCount}'),
                _statChip(Icons.access_time_rounded, '$mm:$ss'),
                _statChip(Icons.emoji_events_rounded,
                    '${_board.treasuresCollected}/${widget.level.treasures}'),
              ],
            ),
          ),
          const SizedBox(width: 10),
          _CircleBtn(icon: Icons.refresh_rounded, onTap: _newGame),
        ],
      ),
    );
  }

  Widget _statChip(IconData icon, String value) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.black.withOpacity(0.55),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.goldBright, width: 1.5),
      ),
      child: Row(
        children: [
          Icon(icon, color: AppColors.goldBright, size: 18),
          const SizedBox(width: 6),
          Text(
            value,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 15,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBoard() {
    return LayoutBuilder(
      builder: (context, constraints) {
        final cellW = constraints.maxWidth / widget.level.cols;
        final cellH = constraints.maxHeight / widget.level.rows;
        final cellSize = cellW < cellH ? cellW : cellH;
        final boardW = cellSize * widget.level.cols;
        final boardH = cellSize * widget.level.rows;
        return Center(
          child: SizedBox(
            width: boardW,
            height: boardH,
            child: Column(
              children: List.generate(widget.level.rows, (r) {
                return Row(
                  children: List.generate(widget.level.cols, (c) {
                    return SizedBox(
                      width: cellSize,
                      height: cellSize,
                      child: _CellView(
                        cell: _board.grid[r][c],
                        onTap: () => _handleTap(r, c),
                        onLongPress: () => _handleLongPress(r, c),
                      ),
                    );
                  }),
                );
              }),
            ),
          ),
        );
      },
    );
  }

  Widget _buildFooter() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 6, 16, 14),
      child: Row(
        children: [
          Expanded(
            child: GestureDetector(
              onTap: () => setState(() => _flagMode = !_flagMode),
              child: Container(
                height: 54,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: _flagMode
                        ? const [Color(0xFFD73B3B), Color(0xFF7A1414)]
                        : const [Color(0xFFB07B2A), Color(0xFF7A4E14)],
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                  ),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(
                    color: AppColors.goldBright,
                    width: 2.5,
                  ),
                ),
                alignment: Alignment.center,
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      _flagMode
                          ? Icons.flag_rounded
                          : Icons.flag_outlined,
                      color: Colors.white,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      _flagMode ? 'FLAG MODE: ON' : 'FLAG MODE: OFF',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 1.2,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _CircleBtn extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;
  const _CircleBtn({required this.icon, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 42,
        height: 42,
        decoration: BoxDecoration(
          color: Colors.black.withOpacity(0.55),
          shape: BoxShape.circle,
          border: Border.all(color: AppColors.goldBright, width: 2),
        ),
        alignment: Alignment.center,
        child: Icon(icon, color: AppColors.goldBright, size: 18),
      ),
    );
  }
}

class _CellView extends StatelessWidget {
  final Cell cell;
  final VoidCallback onTap;
  final VoidCallback onLongPress;
  const _CellView({
    required this.cell,
    required this.onTap,
    required this.onLongPress,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      onLongPress: onLongPress,
      child: Padding(
        padding: const EdgeInsets.all(1.5),
        child: _buildContent(),
      ),
    );
  }

  Widget _buildContent() {
    if (!cell.revealed) {
      return Stack(
        fit: StackFit.expand,
        children: [
          Image.asset(AppAssets.rock, fit: BoxFit.cover),
          if (cell.flagged)
            const Center(
              child: Icon(
                Icons.flag_rounded,
                color: Color(0xFFE53935),
                size: 26,
                shadows: [
                  Shadow(color: Colors.black87, offset: Offset(0, 1), blurRadius: 3),
                ],
              ),
            ),
        ],
      );
    }
    if (cell.type == CellType.mine) {
      return Image.asset(AppAssets.death, fit: BoxFit.cover);
    }
    if (cell.type == CellType.treasure) {
      return Image.asset(AppAssets.money, fit: BoxFit.cover);
    }
    return Stack(
      fit: StackFit.expand,
      children: [
        Image.asset(AppAssets.nothing, fit: BoxFit.cover),
        if (cell.adjacentMines > 0)
          Center(
            child: Text(
              '${cell.adjacentMines}',
              style: TextStyle(
                color: _numberColor(cell.adjacentMines),
                fontSize: 22,
                fontWeight: FontWeight.w900,
                shadows: const [
                  Shadow(color: Colors.black87, offset: Offset(0, 1), blurRadius: 2),
                ],
              ),
            ),
          ),
      ],
    );
  }

  Color _numberColor(int n) {
    switch (n) {
      case 1:
        return const Color(0xFF1E88E5);
      case 2:
        return const Color(0xFF2E7D32);
      case 3:
        return const Color(0xFFD32F2F);
      case 4:
        return const Color(0xFF6A1B9A);
      case 5:
        return const Color(0xFFAD1457);
      case 6:
        return const Color(0xFF00838F);
      case 7:
        return const Color(0xFF3E2723);
      default:
        return Colors.black87;
    }
  }
}

class _EndDialog extends StatelessWidget {
  final bool win;
  final int levelNumber;
  final int treasures;
  final int seconds;
  final VoidCallback onRetry;
  final VoidCallback onExit;
  final VoidCallback? onNext;

  const _EndDialog({
    required this.win,
    required this.levelNumber,
    required this.treasures,
    required this.seconds,
    required this.onRetry,
    required this.onExit,
    required this.onNext,
  });

  @override
  Widget build(BuildContext context) {
    final mm = (seconds ~/ 60).toString().padLeft(2, '0');
    final ss = (seconds % 60).toString().padLeft(2, '0');
    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.symmetric(horizontal: 24),
      child: Container(
        padding: const EdgeInsets.fromLTRB(20, 22, 20, 20),
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            colors: [Color(0xEE1A1F3A), Color(0xEE0A1128)],
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
          ),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: AppColors.goldBright, width: 2.5),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              win ? 'LEVEL $levelNumber CLEARED!' : 'CURSED!',
              style: TextStyle(
                color: win ? AppColors.goldBright : const Color(0xFFE05252),
                fontSize: 22,
                fontWeight: FontWeight.w900,
                letterSpacing: 2,
              ),
            ),
            const SizedBox(height: 12),
            Text(
              win
                  ? 'You escaped the pharaoh\'s tomb.\nTime: $mm:$ss  •  Treasures: $treasures'
                  : 'You triggered an ancient trap.\nTime: $mm:$ss',
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 15,
                height: 1.4,
              ),
            ),
            const SizedBox(height: 20),
            if (onNext != null) ...[
              EgyptButton(
                label: 'NEXT LEVEL',
                icon: Icons.skip_next_rounded,
                width: 240,
                onTap: onNext!,
              ),
              const SizedBox(height: 10),
            ],
            EgyptButton(
              label: 'RETRY',
              icon: Icons.refresh_rounded,
              width: 240,
              onTap: onRetry,
            ),
            const SizedBox(height: 10),
            EgyptButton(
              label: 'LEVELS',
              icon: Icons.grid_view_rounded,
              width: 240,
              onTap: onExit,
            ),
          ],
        ),
      ),
    );
  }
}
