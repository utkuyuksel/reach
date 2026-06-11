import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../badges.dart';
import '../state/daily_controller.dart';
import '../state/settings_controller.dart';
import '../state/stats_controller.dart';
import '../state/zen_controller.dart';
import '../state/providers.dart';
import '../theme/app_text.dart';
import '../theme/palette.dart';
import '../widgets/paper_background.dart';
import '../widgets/soft_button.dart';

/// The quiet badge shelf: ink-line engravings of cumulative effort. No
/// popups, no red dots — numbers and tiers only.
class BadgeShelfScreen extends ConsumerWidget {
  const BadgeShelfScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final palette = ref.watch(paletteProvider);
    final stats = ref.watch(statsControllerProvider);
    final daily = ref.watch(dailyControllerProvider);
    final zen = ref.watch(zenControllerProvider);
    final settings = ref.watch(settingsControllerProvider);
    final dailyCtrl = ref.read(dailyControllerProvider.notifier);

    final medals = dailyCtrl.monthsWithResults
        .where((m) => dailyCtrl.medalForMonth(m) != MonthMedal.none)
        .length;

    final inputs = BadgeInputs(
      stats: stats,
      daily: daily,
      zen: zen,
      ownedThemes: settings.ownedPaletteIds.length,
      monthMedals: medals,
    );

    return Scaffold(
      backgroundColor: palette.paper,
      body: PaperBackground(
        palette: palette,
        child: SafeArea(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
                child: Row(
                  children: [
                    SoftButton(
                      icon: Icons.arrow_back_rounded,
                      palette: palette,
                      onTap: () => Navigator.of(context).maybePop(),
                    ),
                    const SizedBox(width: 16),
                    Icon(Icons.workspace_premium_outlined,
                        size: 26, color: palette.ink),
                  ],
                ),
              ),
              Expanded(
                child: ListView(
                  padding: const EdgeInsets.fromLTRB(20, 16, 20, 28),
                  children: [
                    for (final badge in kBadges)
                      _BadgeRow(
                        palette: palette,
                        spec: badge,
                        value: badge.value(inputs),
                        tier: badge.tierFor(inputs),
                        next: badge.nextThreshold(inputs),
                      ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _BadgeRow extends StatelessWidget {
  final GamePalette palette;
  final BadgeSpec spec;
  final int value;
  final int tier; // 0..3
  final int? next;

  const _BadgeRow({
    required this.palette,
    required this.spec,
    required this.value,
    required this.tier,
    required this.next,
  });

  @override
  Widget build(BuildContext context) {
    final active = tier > 0;
    final iconColor = active ? palette.accent : palette.inkSoft;
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
      decoration: BoxDecoration(
        color: palette.tile,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: palette.tileEdge),
      ),
      child: Row(
        children: [
          Container(
            width: 46,
            height: 46,
            decoration: BoxDecoration(
              color: (active ? palette.accent : palette.inkSoft)
                  .withValues(alpha: active ? 0.14 : 0.07),
              borderRadius: BorderRadius.circular(13),
            ),
            child: Icon(spec.icon, size: 24, color: iconColor),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Tier marks: three small diamonds, filled to the tier.
                Row(
                  children: List.generate(3, (i) {
                    final filled = i < tier;
                    return Padding(
                      padding: const EdgeInsets.only(right: 5),
                      child: Icon(
                        filled
                            ? Icons.square_rounded
                            : Icons.square_outlined,
                        size: 11,
                        color: filled ? palette.accent : palette.line,
                      ),
                    );
                  }),
                ),
                const SizedBox(height: 7),
                Text(
                  next == null ? '$value' : '$value / $next',
                  style: AppText.mono(
                    size: 13,
                    weight: FontWeight.w500,
                    color: palette.ink,
                    letterSpacing: 1,
                  ),
                ),
              ],
            ),
          ),
          if (tier == 3)
            Icon(Icons.check_circle_rounded, size: 20, color: palette.good),
        ],
      ),
    );
  }
}
