import 'dart:math';

enum CellType { safe, mine, treasure }

class Cell {
  final int row;
  final int col;
  CellType type;
  bool revealed;
  bool flagged;
  int adjacentMines;

  Cell({
    required this.row,
    required this.col,
    this.type = CellType.safe,
    this.revealed = false,
    this.flagged = false,
    this.adjacentMines = 0,
  });
}

class Board {
  final int rows;
  final int cols;
  final int mines;
  final int treasures;
  late List<List<Cell>> grid;
  bool _minesPlaced = false;
  int _treasuresCollected = 0;
  int _cellsRevealed = 0;

  int get treasuresCollected => _treasuresCollected;
  int get cellsRevealed => _cellsRevealed;
  int get safeCellsTotal => rows * cols - mines;

  Board({
    required this.rows,
    required this.cols,
    required this.mines,
    required this.treasures,
  }) {
    grid = List.generate(
      rows,
      (r) => List.generate(cols, (c) => Cell(row: r, col: c)),
    );
  }

  bool _inBounds(int r, int c) => r >= 0 && r < rows && c >= 0 && c < cols;

  List<Cell> _neighbors(int r, int c) {
    final result = <Cell>[];
    for (var dr = -1; dr <= 1; dr++) {
      for (var dc = -1; dc <= 1; dc++) {
        if (dr == 0 && dc == 0) continue;
        final nr = r + dr;
        final nc = c + dc;
        if (_inBounds(nr, nc)) result.add(grid[nr][nc]);
      }
    }
    return result;
  }

  /// Places mines avoiding the first tapped cell and its neighbors.
  void _placeMines(int firstR, int firstC) {
    final rng = Random();
    final forbidden = <String>{'$firstR,$firstC'};
    for (final n in _neighbors(firstR, firstC)) {
      forbidden.add('${n.row},${n.col}');
    }

    var placed = 0;
    while (placed < mines) {
      final r = rng.nextInt(rows);
      final c = rng.nextInt(cols);
      if (forbidden.contains('$r,$c')) continue;
      if (grid[r][c].type == CellType.mine) continue;
      grid[r][c].type = CellType.mine;
      placed++;
    }

    // Place treasures on non-mine cells
    var t = 0;
    while (t < treasures) {
      final r = rng.nextInt(rows);
      final c = rng.nextInt(cols);
      if (grid[r][c].type != CellType.safe) continue;
      if (forbidden.contains('$r,$c')) continue;
      grid[r][c].type = CellType.treasure;
      t++;
    }

    // Compute adjacency counts for all non-mine cells
    for (var r = 0; r < rows; r++) {
      for (var c = 0; c < cols; c++) {
        if (grid[r][c].type == CellType.mine) continue;
        grid[r][c].adjacentMines =
            _neighbors(r, c).where((n) => n.type == CellType.mine).length;
      }
    }
    _minesPlaced = true;
  }

  /// Reveals a cell. Returns the reveal result.
  RevealResult reveal(int r, int c) {
    if (!_minesPlaced) _placeMines(r, c);
    final cell = grid[r][c];
    if (cell.revealed || cell.flagged) return RevealResult.noop;

    if (cell.type == CellType.mine) {
      cell.revealed = true;
      return RevealResult.mine;
    }

    _floodReveal(r, c);
    if (_cellsRevealed >= safeCellsTotal) return RevealResult.win;
    return cell.type == CellType.treasure
        ? RevealResult.treasure
        : RevealResult.safe;
  }

  void _floodReveal(int r, int c) {
    final stack = <Cell>[grid[r][c]];
    while (stack.isNotEmpty) {
      final cell = stack.removeLast();
      if (cell.revealed || cell.flagged || cell.type == CellType.mine) continue;
      cell.revealed = true;
      _cellsRevealed++;
      if (cell.type == CellType.treasure) _treasuresCollected++;
      if (cell.adjacentMines == 0 && cell.type == CellType.safe) {
        for (final n in _neighbors(cell.row, cell.col)) {
          if (!n.revealed && n.type != CellType.mine) stack.add(n);
        }
      }
    }
  }

  /// Toggles the flag on an unrevealed cell.
  void toggleFlag(int r, int c) {
    if (!_minesPlaced) return;
    final cell = grid[r][c];
    if (cell.revealed) return;
    cell.flagged = !cell.flagged;
  }

  /// Reveals all mines when the game is lost.
  void revealAllMines() {
    for (final row in grid) {
      for (final cell in row) {
        if (cell.type == CellType.mine) cell.revealed = true;
      }
    }
  }

  int get flaggedCount {
    var count = 0;
    for (final row in grid) {
      for (final cell in row) {
        if (cell.flagged) count++;
      }
    }
    return count;
  }
}

enum RevealResult { noop, safe, treasure, mine, win }
