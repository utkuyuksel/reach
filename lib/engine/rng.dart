/// A small, fully deterministic pseudo-random generator (splitmix64).
///
/// Pure Dart, no Flutter imports. We deliberately do NOT use `dart:math`'s
/// [Random] for puzzle generation: its sequence is not guaranteed stable
/// across Dart SDK versions, and the Daily Challenge must produce the *same*
/// puzzle for every device from the same date seed. splitmix64 is a fixed,
/// well-known algorithm, so `(seed) -> sequence` is reproducible forever,
/// independent of platform or SDK version.
///
/// Relies on Dart's native 64-bit two's-complement integer arithmetic
/// (which wraps on overflow). This holds on the Dart VM and AOT (mobile);
/// it is not valid on the web target, which this game does not ship to.
class DeterministicRng {
  int _state;

  DeterministicRng(int seed) : _state = seed;

  /// Advance the generator and return the next raw 64-bit value.
  int _next() {
    // 0x9E3779B97F4A7C15 is the golden-ratio increment used by splitmix64.
    _state = _state + 0x9E3779B97F4A7C15;
    var z = _state;
    z = (z ^ (z >>> 30)) * 0xBF58476D1CE4E5B9;
    z = (z ^ (z >>> 27)) * 0x94D049BB133111EB;
    return z ^ (z >>> 31);
  }

  /// Uniform-ish integer in [0, maxExclusive). The tiny modulo bias is
  /// irrelevant for game content generation.
  int nextInt(int maxExclusive) {
    assert(maxExclusive > 0);
    // Mask off the sign bit to get a non-negative value before modulo.
    final v = _next() & 0x7FFFFFFFFFFFFFFF;
    return v % maxExclusive;
  }

  /// Inclusive integer in [minInclusive, maxInclusive].
  int range(int minInclusive, int maxInclusive) {
    assert(maxInclusive >= minInclusive);
    return minInclusive + nextInt(maxInclusive - minInclusive + 1);
  }
}
