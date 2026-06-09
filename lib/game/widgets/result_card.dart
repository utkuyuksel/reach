import 'package:flutter/material.dart';

import '../../config/app_constants.dart';
import '../theme/app_text.dart';
import '../theme/palette.dart';

/// A beautiful, spoiler-free, screenshot-worthy Daily result card. It shows the
/// app identity, the daily number, the player's stars + clean badge + streak,
/// and a brand-tile signature (count only) — but NEVER the target, tile values,
/// or positions, so it can't spoil the puzzle. It carries the CTA host so a
/// screenshot or shared image is itself a tiny advert (organic growth).
///
/// Pure visual: the screen wraps it in a RepaintBoundary to export a PNG.
class ResultCard extends StatelessWidget {
  final GamePalette palette;
  final int? dayNumber;
  final String dateKey;
  final int stars;
  final int groups;
  final int hintsUsed;
  final int streak;

  const ResultCard({
    super.key,
    required this.palette,
    required this.dayNumber,
    required this.dateKey,
    required this.stars,
    required this.groups,
    required this.hintsUsed,
    required this.streak,
  });

  bool get _clean => hintsUsed == 0;

  @override
  Widget build(BuildContext context) {
    final p = palette;
    final label = dayNumber != null ? 'DAILY #$dayNumber' : 'DAILY · $dateKey';
    final host = Uri.tryParse(kShareUrl)?.host ?? kShareUrl;

    return Container(
      width: 320,
      padding: const EdgeInsets.fromLTRB(30, 36, 30, 28),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [p.paperHi, p.paperLo],
        ),
        borderRadius: BorderRadius.circular(28),
        border: Border.all(color: p.tileEdge),
        boxShadow: [
          BoxShadow(
            color: p.shadow,
            blurRadius: 30,
            offset: const Offset(0, 16),
            spreadRadius: -12,
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            kAppName,
            style: AppText.fraunces(
              size: 34,
              weight: 600,
              color: p.ink,
              letterSpacing: 7,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            label,
            style: AppText.mono(
              size: 11,
              weight: FontWeight.w500,
              color: p.inkSoft,
              letterSpacing: 3,
            ),
          ),
          const SizedBox(height: 28),
          _Stars(stars: stars, palette: p),
          const SizedBox(height: 18),
          _Pill(
            icon: _clean ? Icons.auto_awesome_rounded : Icons.lightbulb_rounded,
            label: _clean
                ? 'clean'
                : '$hintsUsed hint${hintsUsed == 1 ? '' : 's'}',
            palette: p,
            highlight: _clean,
          ),
          const SizedBox(height: 26),
          _Signature(groups: groups, palette: p),
          if (streak > 1) ...[
            const SizedBox(height: 24),
            _Pill(
              icon: Icons.local_fire_department_rounded,
              label: '$streak day streak',
              palette: p,
              highlight: false,
            ),
          ],
          const SizedBox(height: 30),
          Container(
            width: 38,
            height: 2,
            color: p.line.withValues(alpha: 0.6),
          ),
          const SizedBox(height: 16),
          Text(
            host,
            style: AppText.mono(
              size: 11,
              weight: FontWeight.w500,
              color: p.accent,
              letterSpacing: 2,
            ),
          ),
        ],
      ),
    );
  }
}

/// Three stars, filled to [stars]; the efficiency brag.
class _Stars extends StatelessWidget {
  final int stars;
  final GamePalette palette;
  const _Stars({required this.stars, required this.palette});

  @override
  Widget build(BuildContext context) {
    final s = stars.clamp(0, 3);
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: List.generate(3, (i) {
        final filled = i < s;
        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 5),
          child: Icon(
            filled ? Icons.star_rounded : Icons.star_outline_rounded,
            size: 42,
            color: filled ? palette.good : palette.line,
          ),
        );
      }),
    );
  }
}

/// A soft rounded pill with an icon + short label.
class _Pill extends StatelessWidget {
  final IconData icon;
  final String label;
  final GamePalette palette;
  final bool highlight;
  const _Pill({
    required this.icon,
    required this.label,
    required this.palette,
    required this.highlight,
  });

  @override
  Widget build(BuildContext context) {
    final fg = highlight ? palette.good : palette.inkSoft;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      decoration: BoxDecoration(
        color: (highlight ? palette.good : palette.inkSoft)
            .withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: fg),
          const SizedBox(width: 7),
          Text(
            label,
            style: AppText.mono(
              size: 12.5,
              weight: FontWeight.w500,
              color: fg,
              letterSpacing: 1,
            ),
          ),
        ],
      ),
    );
  }
}

/// One small brand tile per cleared group — a count only (the same for everyone
/// that day). No numbers, no positions: spoiler-free.
class _Signature extends StatelessWidget {
  final int groups;
  final GamePalette palette;
  const _Signature({required this.groups, required this.palette});

  @override
  Widget build(BuildContext context) {
    final n = groups.clamp(0, 16);
    return Wrap(
      alignment: WrapAlignment.center,
      spacing: 7,
      runSpacing: 7,
      children: List.generate(n, (_) {
        return Container(
          width: 20,
          height: 20,
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [palette.accent, palette.accentDeep],
            ),
            borderRadius: BorderRadius.circular(6),
          ),
        );
      }),
    );
  }
}
