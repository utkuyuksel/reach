/// Cosmetic-to-tactical tile modifiers, applied AFTER the solvable partition
/// is carved — they decorate values, never change them, so
/// solvability-by-construction is untouched.
///
///  * [veiled]: the value is hidden behind a "?" until any orthogonally
///    adjacent group clears (scan strategy becomes "clear edges to reveal").
///  * [gold]: pays bonus coins when the board is cleared — a visible
///    "this board pays extra" marker.
enum TileModifier { none, veiled, gold }

/// An immutable number tile occupying a single grid cell.
///
/// [id] is a stable identity used by the UI to track a tile across board
/// changes (for keyed animations). [value] is the positive integer shown on it.
///
/// Pure Dart — no Flutter imports.
class Tile {
  final int id;
  final int value;
  final TileModifier modifier;

  const Tile({
    required this.id,
    required this.value,
    this.modifier = TileModifier.none,
  });

  /// This tile with its veil lifted (no-op for other modifiers).
  Tile unveiled() => modifier == TileModifier.veiled
      ? Tile(id: id, value: value)
      : this;

  @override
  bool operator ==(Object other) =>
      other is Tile &&
      other.id == id &&
      other.value == value &&
      other.modifier == modifier;

  @override
  int get hashCode => Object.hash(id, value, modifier);

  @override
  String toString() => 'Tile(id: $id, value: $value'
      '${modifier == TileModifier.none ? '' : ', ${modifier.name}'})';
}
