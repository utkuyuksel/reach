import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../engine/generator.dart';
import '../../util/date_key.dart';
import '../state/mosaic_controller.dart';
import '../state/providers.dart';
import '../theme/app_text.dart';
import '../widgets/mosaic_view.dart';
import '../widgets/paper_background.dart';
import '../widgets/soft_button.dart';

/// This week's mosaic, large, plus the permanent gallery of past weeks —
/// the collection layer Block Blast's Adventure forgot to keep.
class MosaicGalleryScreen extends ConsumerWidget {
  const MosaicGalleryScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final palette = ref.watch(paletteProvider);
    final record = ref.watch(mosaicControllerProvider);
    final ctrl = ref.read(mosaicControllerProvider.notifier);
    final config = ref.read(gameConfigProvider);

    final weekKey = ctrl.currentWeekKey;
    final revealed = ctrl.revealed;
    final pastWeeks = record.gallery.keys.toList()
      ..sort((a, b) => b.compareTo(a));

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
                    Icon(Icons.auto_awesome_mosaic_rounded,
                        size: 24, color: palette.ink),
                  ],
                ),
              ),
              Expanded(
                child: ListView(
                  padding: const EdgeInsets.fromLTRB(24, 16, 24, 28),
                  children: [
                    // This week, large.
                    Center(
                      child: Column(
                        children: [
                          MosaicView(
                            seed: Generator.dailySeed(dateFromKey(weekKey)),
                            revealed: revealed,
                            size: 280,
                            palette: palette,
                          ),
                          const SizedBox(height: 12),
                          Text(
                            '$revealed / ${config.mosaicSize}',
                            style: AppText.mono(
                              size: 13,
                              weight: FontWeight.w500,
                              color: palette.inkSoft,
                              letterSpacing: 2,
                            ),
                          ),
                        ],
                      ),
                    ),
                    if (pastWeeks.isNotEmpty) ...[
                      const SizedBox(height: 34),
                      Text(
                        'GALLERY',
                        style: AppText.mono(
                          size: 10.5,
                          weight: FontWeight.w500,
                          color: palette.inkSoft,
                          letterSpacing: 3,
                        ),
                      ),
                      const SizedBox(height: 14),
                      Wrap(
                        spacing: 14,
                        runSpacing: 14,
                        children: [
                          for (final week in pastWeeks)
                            Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                MosaicView(
                                  seed: Generator.dailySeed(
                                      dateFromKey(week)),
                                  revealed: record.gallery[week]!,
                                  size: 92,
                                  palette: palette,
                                ),
                                const SizedBox(height: 5),
                                Icon(
                                  record.gallery[week]! >= config.mosaicSize
                                      ? Icons.check_circle_rounded
                                      : Icons.circle_outlined,
                                  size: 13,
                                  color: record.gallery[week]! >=
                                          config.mosaicSize
                                      ? palette.good
                                      : palette.line,
                                ),
                              ],
                            ),
                        ],
                      ),
                    ],
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
