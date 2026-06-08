/// An immutable number tile occupying a single grid cell.
///
/// [id] is a stable identity used by the UI to track a tile across board
/// changes (for keyed animations). [value] is the positive integer shown on it.
///
/// Pure Dart — no Flutter imports.
class Tile {
  final int id;
  final int value;

  const Tile({required this.id, required this.value});

  @override
  bool operator ==(Object other) =>
      other is Tile && other.id == id && other.value == value;

  @override
  int get hashCode => Object.hash(id, value);

  @override
  String toString() => 'Tile(id: $id, value: $value)';
}
