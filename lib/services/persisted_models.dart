/// Plain data models for everything we persist locally. Pure data with
/// map (de)serialization — no Flutter, no storage-backend knowledge — so the
/// storage layer can swap backends (and a future cloud sync can adopt the
/// same shapes) without touching game logic.
library;

/// User settings.
class Settings {
  /// Subtle haptic feedback on clear/win.
  final bool hapticsOn;

  /// Sound effects (clear/win/tap/invalid).
  final bool sfxOn;

  /// Ambient background pad.
  final bool musicOn;

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
    this.sfxOn = true,
    this.musicOn = true,
    this.colorblind = false,
    this.paletteId = 'clay',
    this.onboardingDone = false,
    this.ownedPaletteIds = const [],
  });

  Settings copyWith({
    bool? hapticsOn,
    bool? sfxOn,
    bool? musicOn,
    bool? colorblind,
    String? paletteId,
    bool? onboardingDone,
    List<String>? ownedPaletteIds,
  }) =>
      Settings(
        hapticsOn: hapticsOn ?? this.hapticsOn,
        sfxOn: sfxOn ?? this.sfxOn,
        musicOn: musicOn ?? this.musicOn,
        colorblind: colorblind ?? this.colorblind,
        paletteId: paletteId ?? this.paletteId,
        onboardingDone: onboardingDone ?? this.onboardingDone,
        ownedPaletteIds: ownedPaletteIds ?? this.ownedPaletteIds,
      );

  Map<String, dynamic> toMap() => {
        'hapticsOn': hapticsOn,
        'sfxOn': sfxOn,
        'musicOn': musicOn,
        'colorblind': colorblind,
        'paletteId': paletteId,
        'onboardingDone': onboardingDone,
        'ownedPaletteIds': ownedPaletteIds,
      };

  factory Settings.fromMap(Map<String, dynamic> m) => Settings(
        hapticsOn: m['hapticsOn'] as bool? ?? true,
        sfxOn: m['sfxOn'] as bool? ?? true,
        musicOn: m['musicOn'] as bool? ?? true,
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

  /// Completed later via the archive (counts toward the monthly medal, shown
  /// distinctly on the calendar, never granted streak credit).
  final bool backfilled;

  const DailyResult({
    required this.dateKey,
    this.hintsUsed = 0,
    this.stars = 3,
    this.backfilled = false,
  });

  /// Cleared without any hints.
  bool get clean => hintsUsed == 0;

  Map<String, dynamic> toMap() => {
        'dateKey': dateKey,
        'hintsUsed': hintsUsed,
        'stars': stars,
        'backfilled': backfilled,
      };

  factory DailyResult.fromMap(Map<String, dynamic> m) => DailyResult(
        // Null-coalesce so one corrupt field can't take down the whole record.
        dateKey: m['dateKey'] as String? ?? '',
        hintsUsed: m['hintsUsed'] as int? ?? 0,
        stars: m['stars'] as int? ?? 3,
        backfilled: m['backfilled'] as bool? ?? false,
      );
}

/// Daily Challenge progress: streak state (with freeze/repair support) and the
/// per-day results map that backs the calendar, medals, and stats.
class DailyRecord {
  final int currentStreak;
  final int longestStreak;
  final String? lastCompletedDate; // 'YYYY-MM-DD'
  final Map<String, DailyResult> results; // dateKey -> result

  /// Banked Streak Freeze tokens (auto-consumed, one per missed day, when the
  /// next completion detects a gap).
  final int freezeTokens;

  /// When a streak breaks, its value is parked here so a Streak Repair (within
  /// the repair window, once per month) can restore it. 0 = nothing to repair.
  final int brokenStreak;

  /// Epoch millis of the moment the break was DETECTED (i.e. the completion
  /// that reset the streak), bounding the repair window.
  final int brokenAtMillis;

  /// 'YYYY-MM' of the last used Streak Repair (max one per calendar month).
  final String? lastRepairMonth;

  /// Epoch millis of the last streak-credited completion: clock-rollback
  /// guard (a new streak increment requires a minimum gap since the previous
  /// credited one).
  final int lastCompletedAtMillis;

  /// Backfill "tickets": dateKeys whose archive entry fee was paid but whose
  /// board hasn't been completed yet — re-entry is free until it is.
  final List<String> paidBackfills;

  const DailyRecord({
    this.currentStreak = 0,
    this.longestStreak = 0,
    this.lastCompletedDate,
    this.results = const {},
    this.freezeTokens = 0,
    this.brokenStreak = 0,
    this.brokenAtMillis = 0,
    this.lastRepairMonth,
    this.lastCompletedAtMillis = 0,
    this.paidBackfills = const [],
  });

  bool isCompleted(String dateKey) => results.containsKey(dateKey);
  DailyResult? resultFor(String dateKey) => results[dateKey];

  DailyRecord copyWith({
    int? currentStreak,
    int? longestStreak,
    String? lastCompletedDate,
    Map<String, DailyResult>? results,
    int? freezeTokens,
    int? brokenStreak,
    int? brokenAtMillis,
    String? lastRepairMonth,
    int? lastCompletedAtMillis,
    List<String>? paidBackfills,
  }) =>
      DailyRecord(
        currentStreak: currentStreak ?? this.currentStreak,
        longestStreak: longestStreak ?? this.longestStreak,
        lastCompletedDate: lastCompletedDate ?? this.lastCompletedDate,
        results: results ?? this.results,
        freezeTokens: freezeTokens ?? this.freezeTokens,
        brokenStreak: brokenStreak ?? this.brokenStreak,
        brokenAtMillis: brokenAtMillis ?? this.brokenAtMillis,
        lastRepairMonth: lastRepairMonth ?? this.lastRepairMonth,
        lastCompletedAtMillis:
            lastCompletedAtMillis ?? this.lastCompletedAtMillis,
        paidBackfills: paidBackfills ?? this.paidBackfills,
      );

  Map<String, dynamic> toMap() => {
        'currentStreak': currentStreak,
        'longestStreak': longestStreak,
        'lastCompletedDate': lastCompletedDate,
        'results': results.map((k, v) => MapEntry(k, v.toMap())),
        'freezeTokens': freezeTokens,
        'brokenStreak': brokenStreak,
        'brokenAtMillis': brokenAtMillis,
        'lastRepairMonth': lastRepairMonth,
        'lastCompletedAtMillis': lastCompletedAtMillis,
        'paidBackfills': paidBackfills,
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
      freezeTokens: m['freezeTokens'] as int? ?? 0,
      brokenStreak: m['brokenStreak'] as int? ?? 0,
      brokenAtMillis: m['brokenAtMillis'] as int? ?? 0,
      lastRepairMonth: m['lastRepairMonth'] as String?,
      lastCompletedAtMillis: m['lastCompletedAtMillis'] as int? ?? 0,
      paidBackfills:
          (m['paidBackfills'] as List?)?.cast<String>() ?? const [],
    );
  }
}

/// The player's coin balance (spent on hints/cosmetics/streak protection;
/// earned from clears/ads/IAP).
class WalletRecord {
  final int coins;

  /// Local dateKey on which the once-daily home-screen gift ad was claimed.
  final String? giftDateKey;

  const WalletRecord({this.coins = 0, this.giftDateKey});

  WalletRecord copyWith({int? coins, String? giftDateKey}) => WalletRecord(
        coins: coins ?? this.coins,
        giftDateKey: giftDateKey ?? this.giftDateKey,
      );

  Map<String, dynamic> toMap() =>
      {'coins': coins, 'giftDateKey': giftDateKey};

  factory WalletRecord.fromMap(Map<String, dynamic> m) => WalletRecord(
        coins: m['coins'] as int? ?? 0,
        giftDateKey: m['giftDateKey'] as String?,
      );
}

/// Zen mode progress: total clears (drives the difficulty ramp and chapter)
/// and the flow chain (consecutive clean clears).
class ZenRecord {
  /// Total boards cleared in Zen (drives the difficulty ramp and the chapter).
  final int boardsCleared;

  /// Current flow chain: consecutive Zen clears with no wrong traces and no
  /// hints. A wrong trace gently resets it.
  final int chain;

  /// Best flow chain ever reached.
  final int bestChain;

  const ZenRecord({
    this.boardsCleared = 0,
    this.chain = 0,
    this.bestChain = 0,
  });

  ZenRecord copyWith({int? boardsCleared, int? chain, int? bestChain}) =>
      ZenRecord(
        boardsCleared: boardsCleared ?? this.boardsCleared,
        chain: chain ?? this.chain,
        bestChain: bestChain ?? this.bestChain,
      );

  Map<String, dynamic> toMap() => {
        'boardsCleared': boardsCleared,
        'chain': chain,
        'bestChain': bestChain,
      };

  factory ZenRecord.fromMap(Map<String, dynamic> m) => ZenRecord(
        boardsCleared: m['boardsCleared'] as int? ?? 0,
        chain: m['chain'] as int? ?? 0,
        bestChain: m['bestChain'] as int? ?? 0,
      );
}

/// Cumulative, cross-mode counters: the data behind the badge shelf, plus
/// small daily-keyed quotas (Premium free hints).
class StatsRecord {
  /// Boards cleared across all modes (Daily + Zen + archive).
  final int totalClears;

  /// Boards cleared without using a hint.
  final int cleanClears;

  /// Daily boards finished with 3 stars.
  final int threeStarDailies;

  /// Local dateKey the Premium free-hint quota was last used on.
  final String? hintQuotaDateKey;

  /// Premium free hints used on [hintQuotaDateKey].
  final int hintQuotaUsed;

  const StatsRecord({
    this.totalClears = 0,
    this.cleanClears = 0,
    this.threeStarDailies = 0,
    this.hintQuotaDateKey,
    this.hintQuotaUsed = 0,
  });

  StatsRecord copyWith({
    int? totalClears,
    int? cleanClears,
    int? threeStarDailies,
    String? hintQuotaDateKey,
    int? hintQuotaUsed,
  }) =>
      StatsRecord(
        totalClears: totalClears ?? this.totalClears,
        cleanClears: cleanClears ?? this.cleanClears,
        threeStarDailies: threeStarDailies ?? this.threeStarDailies,
        hintQuotaDateKey: hintQuotaDateKey ?? this.hintQuotaDateKey,
        hintQuotaUsed: hintQuotaUsed ?? this.hintQuotaUsed,
      );

  Map<String, dynamic> toMap() => {
        'totalClears': totalClears,
        'cleanClears': cleanClears,
        'threeStarDailies': threeStarDailies,
        'hintQuotaDateKey': hintQuotaDateKey,
        'hintQuotaUsed': hintQuotaUsed,
      };

  factory StatsRecord.fromMap(Map<String, dynamic> m) => StatsRecord(
        totalClears: m['totalClears'] as int? ?? 0,
        cleanClears: m['cleanClears'] as int? ?? 0,
        threeStarDailies: m['threeStarDailies'] as int? ?? 0,
        hintQuotaDateKey: m['hintQuotaDateKey'] as String?,
        hintQuotaUsed: m['hintQuotaUsed'] as int? ?? 0,
      );
}
