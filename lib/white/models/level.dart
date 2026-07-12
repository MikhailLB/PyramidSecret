class LevelConfig {
  final int number;
  final int rows;
  final int cols;
  final int mines;
  final int treasures;

  const LevelConfig({
    required this.number,
    required this.rows,
    required this.cols,
    required this.mines,
    required this.treasures,
  });

  int get totalCells => rows * cols;
  int get safeCells => totalCells - mines;

  static const List<LevelConfig> levels = [
    LevelConfig(number: 1, rows: 5, cols: 5, mines: 3, treasures: 2),
    LevelConfig(number: 2, rows: 6, cols: 5, mines: 5, treasures: 2),
    LevelConfig(number: 3, rows: 6, cols: 6, mines: 7, treasures: 3),
    LevelConfig(number: 4, rows: 7, cols: 6, mines: 10, treasures: 3),
    LevelConfig(number: 5, rows: 7, cols: 7, mines: 12, treasures: 4),
    LevelConfig(number: 6, rows: 8, cols: 7, mines: 15, treasures: 4),
    LevelConfig(number: 7, rows: 9, cols: 7, mines: 18, treasures: 5),
    LevelConfig(number: 8, rows: 9, cols: 8, mines: 22, treasures: 5),
    LevelConfig(number: 9, rows: 10, cols: 8, mines: 26, treasures: 6),
    LevelConfig(number: 10, rows: 11, cols: 8, mines: 30, treasures: 6),
  ];
}
