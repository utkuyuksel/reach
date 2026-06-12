import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../state/providers.dart';
import '../theme/app_text.dart';
import '../widgets/paper_background.dart';
import '../widgets/soft_button.dart';

/// The quiet reference shelf: one icon-card per system, minimal words (the
/// settings surface is already worded, unlike core gameplay). A safety net —
/// the real teaching happens contextually, the first time each system appears.
class HelpScreen extends ConsumerWidget {
  const HelpScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final palette = ref.watch(paletteProvider);

    final entries = <(List<IconData>, String)>[
      (
        [Icons.swipe_rounded, Icons.tag_rounded, Icons.check_circle_outline],
        'Trace neighbours that add up to the target',
      ),
      (
        [Icons.grid_view_rounded, Icons.check_rounded],
        'Clear every tile to finish the board',
      ),
      (
        [Icons.local_fire_department_rounded, Icons.calendar_month_rounded],
        'One shared board a day — keep the streak',
      ),
      (
        [Icons.ac_unit_rounded, Icons.healing_rounded],
        'Freeze protects a missed day; repair restores a break',
      ),
      (
        [Icons.stairs_rounded, Icons.add_circle_outline_rounded],
        'Daily ladder: easy & hard bonus boards',
      ),
      (
        [Icons.bolt_rounded, Icons.diamond_rounded],
        'Zen chapters: 10 boards, the finale pays double',
      ),
      (
        [Icons.monetization_on_rounded, Icons.help_outline_rounded,
            Icons.lock_rounded],
        'Gold pays extra · "?" reveals near clears · locks open near clears',
      ),
      (
        [Icons.auto_awesome_mosaic_rounded, Icons.collections_rounded],
        'Every clear paints the weekly mosaic — finish it for a chest',
      ),
      (
        [Icons.settings_backup_restore_rounded, Icons.play_arrow_rounded],
        'Stuck? Safe rewind jumps back to a solvable point',
      ),
    ];

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
                    Icon(Icons.help_outline_rounded,
                        size: 24, color: palette.ink),
                  ],
                ),
              ),
              Expanded(
                child: ListView(
                  padding: const EdgeInsets.fromLTRB(20, 14, 20, 28),
                  children: [
                    for (final (icons, label) in entries)
                      Container(
                        margin: const EdgeInsets.only(bottom: 10),
                        padding: const EdgeInsets.symmetric(
                            horizontal: 16, vertical: 14),
                        decoration: BoxDecoration(
                          color: palette.tile,
                          borderRadius: BorderRadius.circular(15),
                          border: Border.all(color: palette.tileEdge),
                        ),
                        child: Row(
                          children: [
                            for (final icon in icons) ...[
                              Icon(icon, size: 18, color: palette.accent),
                              const SizedBox(width: 6),
                            ],
                            const SizedBox(width: 6),
                            Expanded(
                              child: Text(
                                label,
                                style: AppText.mono(
                                    size: 11.5, color: palette.inkSoft),
                              ),
                            ),
                          ],
                        ),
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
