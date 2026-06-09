import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:share_plus/share_plus.dart';

import '../../services/analytics_service.dart';
import '../share_text.dart';
import '../state/providers.dart';
import '../state/settings_controller.dart';
import '../theme/app_text.dart';
import '../widgets/paper_background.dart';
import '../widgets/result_card.dart';
import '../widgets/soft_button.dart';

/// Shows the Daily result as a beautiful, screenshot-worthy [ResultCard] that
/// the player can either screenshot directly or share as a PNG image (not a
/// plain text file). The image carries the CTA, so every share is a tiny ad.
class ShareResultScreen extends ConsumerStatefulWidget {
  final String dateKey;
  final int stars;
  final int groups;
  final int hintsUsed;
  final int streak;

  const ShareResultScreen({
    super.key,
    required this.dateKey,
    required this.stars,
    required this.groups,
    required this.hintsUsed,
    required this.streak,
  });

  @override
  ConsumerState<ShareResultScreen> createState() => _ShareResultScreenState();
}

class _ShareResultScreenState extends ConsumerState<ShareResultScreen> {
  final GlobalKey _cardKey = GlobalKey();
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    ref.read(analyticsServiceProvider).log(AnalyticsEvents.shareOpened);
  }

  Future<void> _share() async {
    if (_busy) return;
    setState(() => _busy = true);
    if (ref.read(settingsControllerProvider).hapticsOn) {
      HapticFeedback.selectionClick();
    }
    try {
      final boundary =
          _cardKey.currentContext?.findRenderObject() as RenderRepaintBoundary?;
      if (boundary == null) return;
      final image = await boundary.toImage(pixelRatio: 3.0);
      final data = await image.toByteData(format: ui.ImageByteFormat.png);
      if (data == null) return;

      final file = await File('${Directory.systemTemp.path}/reach_daily.png')
          .writeAsBytes(data.buffer.asUint8List());

      // Image is the hero; the text caption carries the URL + emoji fallback
      // for apps that don't preview images.
      final caption = buildDailyShareText(
        dateKey: widget.dateKey,
        groups: widget.groups,
        stars: widget.stars,
        hintsUsed: widget.hintsUsed,
        currentStreak: widget.streak,
      );
      await SharePlus.instance.share(
        ShareParams(files: [XFile(file.path)], text: caption),
      );
      ref.read(analyticsServiceProvider).log(AnalyticsEvents.shareCompleted);
    } catch (_) {
      if (mounted) {
        final palette = ref.read(paletteProvider);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              "Couldn't prepare the image — try a screenshot.",
              style: AppText.mono(size: 12.5, color: Colors.white),
            ),
            backgroundColor: palette.ink,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final palette = ref.watch(paletteProvider);

    return Scaffold(
      backgroundColor: palette.paper,
      body: PaperBackground(
        palette: palette,
        child: SafeArea(
          child: Column(
            children: [
              Align(
                alignment: Alignment.centerRight,
                child: Padding(
                  padding: const EdgeInsets.only(top: 8, right: 16),
                  child: SoftButton(
                    icon: Icons.close_rounded,
                    palette: palette,
                    onTap: () => Navigator.of(context).maybePop(),
                  ),
                ),
              ),
              const Spacer(),
              RepaintBoundary(
                key: _cardKey,
                child: ResultCard(
                  palette: palette,
                  dayNumber: dailyNumber(widget.dateKey),
                  dateKey: widget.dateKey,
                  stars: widget.stars,
                  groups: widget.groups,
                  hintsUsed: widget.hintsUsed,
                  streak: widget.streak,
                ),
              ),
              const Spacer(),
              SoftButton(
                icon: Icons.ios_share_rounded,
                palette: palette,
                primary: true,
                onTap: _busy ? null : _share,
              ),
              const SizedBox(height: 28),
            ],
          ),
        ),
      ),
    );
  }
}
