import 'package:flutter/material.dart';

import '../services/persisted_models.dart';

/// One cumulative-effort badge: an icon, three tier thresholds, and the
/// current value extracted from the persisted records. Wordless by design —
/// the shelf renders icon + tier marks + numbers only.
class BadgeSpec {
  final String id;
  final IconData icon;
  final List<int> tiers; // bronze / silver / gold thresholds (ascending)
  final int Function(BadgeInputs) value;

  const BadgeSpec({
    required this.id,
    required this.icon,
    required this.tiers,
    required this.value,
  });

  /// 0 = none, 1..3 = bronze/silver/gold.
  int tierFor(BadgeInputs inputs) {
    final v = value(inputs);
    var tier = 0;
    for (final t in tiers) {
      if (v >= t) tier++;
    }
    return tier;
  }

  /// The next threshold to chase, or null when gold is reached.
  int? nextThreshold(BadgeInputs inputs) {
    final v = value(inputs);
    for (final t in tiers) {
      if (v < t) return t;
    }
    return null;
  }
}

/// Everything the badge formulas read. Assembled by the UI from providers.
class BadgeInputs {
  final StatsRecord stats;
  final DailyRecord daily;
  final ZenRecord zen;
  final int ownedThemes;
  final int monthMedals;

  const BadgeInputs({
    required this.stats,
    required this.daily,
    required this.zen,
    required this.ownedThemes,
    required this.monthMedals,
  });
}

/// The full shelf, in display order. Deliberately small (badge inflation
/// kills calm); tuned so 2–3 first tiers land within the first ten sessions.
const List<BadgeSpec> kBadges = [
  BadgeSpec(
    id: 'clears',
    icon: Icons.apps_rounded,
    tiers: [50, 250, 1000],
    value: _totalClears,
  ),
  BadgeSpec(
    id: 'clean',
    icon: Icons.verified_rounded,
    tiers: [10, 50, 200],
    value: _cleanClears,
  ),
  BadgeSpec(
    id: 'three_star_dailies',
    icon: Icons.star_rounded,
    tiers: [5, 25, 100],
    value: _threeStarDailies,
  ),
  BadgeSpec(
    id: 'streak',
    icon: Icons.local_fire_department_rounded,
    tiers: [7, 30, 100],
    value: _longestStreak,
  ),
  BadgeSpec(
    id: 'chain',
    icon: Icons.spa_rounded,
    tiers: [3, 7, 15],
    value: _bestChain,
  ),
  BadgeSpec(
    id: 'chapters',
    icon: Icons.bolt_rounded,
    tiers: [3, 10, 25],
    value: _chapters,
  ),
  BadgeSpec(
    id: 'themes',
    icon: Icons.palette_outlined,
    tiers: [2, 5, 9],
    value: _themes,
  ),
  BadgeSpec(
    id: 'medals',
    icon: Icons.workspace_premium_rounded,
    tiers: [1, 3, 6],
    value: _medals,
  ),
];

int _totalClears(BadgeInputs i) => i.stats.totalClears;
int _cleanClears(BadgeInputs i) => i.stats.cleanClears;
int _threeStarDailies(BadgeInputs i) => i.stats.threeStarDailies;
int _longestStreak(BadgeInputs i) => i.daily.longestStreak;
int _bestChain(BadgeInputs i) => i.zen.bestChain;
int _chapters(BadgeInputs i) => i.zen.boardsCleared ~/ 10;
int _themes(BadgeInputs i) => i.ownedThemes;
int _medals(BadgeInputs i) => i.monthMedals;
