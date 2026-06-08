/// Plain data models for everything we persist locally. Pure data with
/// map (de)serialization — no Flutter, no storage-backend knowledge — so the
/// storage layer can swap backends (and a future cloud sync can adopt the
/// same shapes) without touching game logic.
library;

/// User settings.
class Settings {
  /// Subtle haptic feedback on clear/win (the tactile substitute for SFX in v1).
  final bool hapticsOn;

  /// Colourblind mode: always-visible, higher-contrast state cues.
  final bool colorblind;

  /// Selected cosmetic palette id. Non-default palettes require Premium; the
  /// controller enforces that.
  final String paletteId;

  /// Whether the player has seen the first-run tutorial.
  final bool onboardingDone;

  /// Palette ids unlocked with coins (Premium unlocks all regardless).
  final List<String> ownedPaletteIds;

  const Settings({
    this.hapticsOn = true,
    this.colorblind = false,
    this.paletteId = 'clay',
    this.onboardingDone = false,
    this.ownedPaletteIds = const [],
  });

  Settings copyWith({
    bool? hapticsOn,
    bool? colorblind,
    String? paletteId,
    bool? onboardingDone,
    List<String>? ownedPaletteIds,
  }) =>
      Settings(
        hapticsOn: hapticsOn ?? this.hapticsOn,
        colorblind: colorblind ?? this.colorblind,
        paletteId: paletteId ?? this.paletteId,
        onboardingDone: onboardingDone ?? this.onboardingDone,
        ownedPaletteIds: ownedPaletteIds ?? this.ownedPaletteIds,
      );

  Map<String, dynamic> toMap() => {
        'hapticsOn': hapticsOn,
        'colorblind': colorblind,
        'paletteId': paletteId,
        'onboardingDone': onboardingDone,
        'ownedPaletteIds': ownedPaletteIds,
      };

  factory Settings.fromMap(Map<String, dynamic> m) => Settings(
        hapticsOn: m['hapticsOn'] as bool? ?? true,
        colorblind: m['colorblind'] as bool? ?? false,
        paletteId: m['paletteId'] as String? ?? 'clay',
        onboardingDone: m['onboardingDone'] as bool? ?? false,
        ownedPaletteIds:
            (m['ownedPaletteIds'] as List?)?.cast<String>() ?? const [],
      );
}

/// One completed Daily result.
class DailyResult {
  final String dateKey; // 'YYYY-MM-DD'
  final int hintsUsed;

  /// Efficiency rating 1–3 (independent of hints).
  final int stars;

  const DailyResult({
    required this.dateKey,
    this.hintsUsed = 0,
    this.stars = 3,
  });

  /// Cleared without any hints.
  bool get clean => hintsUsed == 0;

  Map<String, dynamic> toMap() => {
        'dateKey': dateKey,
        'hintsUsed': hintsUsed,
        'stars': stars,
      };

  factory DailyResult.fromMap(Map<String, dynamic> m) => DailyResult(
        // Null-coalesce so one corrupt field can't take down the whole record.
        dateKey: m['dateKey'] as String? ?? '',
        hintsUsed: m['hintsUsed'] as int? ?? 0,
        stars: m['stars'] as int? ?? 3,
      );
}

/// Daily Challenge progress.
class DailyRecord {
  final int currentStreak;
  final int longestStreak;
  final String? lastCompletedDate; // 'YYYY-MM-DD'
  final Map<String, DailyResult> results; // dateKey -> result

  const DailyRecord({
    this.currentStreak = 0,
    this.longestStreak = 0,
    this.lastCompletedDate,
    this.results = const {},
  });

  bool isCompleted(String dateKey) => results.containsKey(dateKey);
  DailyResult? resultFor(String dateKey) => results[dateKey];

  DailyRecord copyWith({
    int? currentStreak,
    int? longestStreak,
    String? lastCompletedDate,
    Map<String, DailyResult>? results,
  }) =>
      DailyRecord(
        currentStreak: currentStreak ?? this.currentStreak,
        longestStreak: longestStreak ?? this.longestStreak,
        lastCompletedDate: lastCompletedDate ?? this.lastCompletedDate,
        results: results ?? this.results,
      );

  Map<String, dynamic> toMap() => {
        'currentStreak': currentStreak,
        'longestStreak': longestStreak,
        'lastCompletedDate': lastCompletedDate,
        'results': results.map((k, v) => MapEntry(k, v.toMap())),
      };

  factory DailyRecord.fromMap(Map<String, dynamic> m) {
    final rawResults = (m['results'] as Map?) ?? const {};
    final results = <String, DailyResult>{};
    rawResults.forEach((k, v) {
      results[k as String] =
          DailyResult.fromMap(Map<String, dynamic>.from(v as Map));
    });
    return DailyRecord(
      currentStreak: m['currentStreak'] as int? ?? 0,
      longestStreak: m['longestStreak'] as int? ?? 0,
      lastCompletedDate: m['lastCompletedDate'] as String?,
      results: results,
    );
  }
}

/// The player's coin balance (spent on hints; earned from clears/ads/IAP).
class WalletRecord {
  final int coins;

  const WalletRecord({this.coins = 0});

  WalletRecord copyWith({int? coins}) =>
      WalletRecord(coins: coins ?? this.coins);

  Map<String, dynamic> toMap() => {'coins': coins};

  factory WalletRecord.fromMap(Map<String, dynamic> m) =>
      WalletRecord(coins: m['coins'] as int? ?? 0);
}

/// Zen mode progress. The displayed level is derived from boards cleared.
class ZenRecord {
  /// Total boards cleared in Zen (drives the difficulty ramp and the level).
  final int boardsCleared;

  const ZenRecord({this.boardsCleared = 0});

  ZenRecord copyWith({int? boardsCleared}) =>
      ZenRecord(boardsCleared: boardsCleared ?? this.boardsCleared);

  Map<String, dynamic> toMap() => {'boardsCleared': boardsCleared};

  factory ZenRecord.fromMap(Map<String, dynamic> m) =>
      ZenRecord(boardsCleared: m['boardsCleared'] as int? ?? 0);
}
