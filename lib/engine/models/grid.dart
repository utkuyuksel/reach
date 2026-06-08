import 'tile.dart';

/// An immutable R×C board. Cells hold a [Tile] or `null` (empty).
///
/// Cells are stored row-major in a flat list: index = `row * cols + col`.
/// Pure Dart — no Flutter imports. All mutating operations return a new [Grid].
class Grid {
  final int rows;
  final int cols;

  /// Row-major cells, length == rows * cols. `null` means an empty cell.
  final List<Tile?> cells;

  Grid({required this.rows, required this.cols, required List<Tile?> cells})
      : assert(cells.length == rows * cols),
        cells = List<Tile?>.unmodifiable(cells);

  int get totalCells => rows * cols;

  int indexOf(int row, int col) => row * cols + col;
  int rowOf(int index) => index ~/ cols;
  int colOf(int index) => index % cols;

  Tile? at(int index) => cells[index];
  Tile? atRC(int row, int col) => cells[indexOf(row, col)];

  bool isEmptyAt(int index) => cells[index] == null;
  bool get isFull => cells.every((c) => c != null);

  /// Indices of all occupied cells.
  List<int> occupiedIndices() {
    final result = <int>[];
    for (var i = 0; i < cells.length; i++) {
      if (cells[i] != null) result.add(i);
    }
    return result;
  }

  /// Orthogonal (up/down/left/right) in-bounds neighbour indices of [index].
  List<int> neighborsOf(int index) {
    final r = rowOf(index);
    final c = colOf(index);
    final result = <int>[];
    if (r > 0) result.add(indexOf(r - 1, c));
    if (r < rows - 1) result.add(indexOf(r + 1, c));
    if (c > 0) result.add(indexOf(r, c - 1));
    if (c < cols - 1) result.add(indexOf(r, c + 1));
    return result;
  }

  /// Whether two cell indices are orthogonally adjacent on the board.
  bool areOrthogonalNeighbors(int a, int b) {
    final dr = (rowOf(a) - rowOf(b)).abs();
    final dc = (colOf(a) - colOf(b)).abs();
    return dr + dc == 1;
  }

  /// Sum of tile values over [indices] (empty cells contribute 0).
  int sumOfRegion(Iterable<int> indices) {
    var sum = 0;
    for (final i in indices) {
      final t = cells[i];
      if (t != null) sum += t.value;
    }
    return sum;
  }

  /// Total of all tile values currently on the board.
  int get totalSum => sumOfRegion(List<int>.generate(cells.length, (i) => i));

  /// A copy with the given [cells] emptied (a cleared group).
  Grid cleared(Iterable<int> indices) {
    final next = List<Tile?>.from(cells);
    for (final i in indices) {
      next[i] = null;
    }
    return Grid(rows: rows, cols: cols, cells: next);
  }

  /// A copy with the given [indices] restored to the tiles they hold in
  /// [source] (used to undo a clear). [source] is typically the initial board.
  Grid restoredFrom(Grid source, Iterable<int> indices) {
    final next = List<Tile?>.from(cells);
    for (final i in indices) {
      next[i] = source.cells[i];
    }
    return Grid(rows: rows, cols: cols, cells: next);
  }

  @override
  bool operator ==(Object other) {
    if (other is! Grid) return false;
    if (other.rows != rows || other.cols != cols) return false;
    for (var i = 0; i < cells.length; i++) {
      if (other.cells[i] != cells[i]) return false;
    }
    return true;
  }

  @override
  int get hashCode => Object.hash(rows, cols, Object.hashAll(cells));
}
