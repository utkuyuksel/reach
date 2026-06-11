import 'package:flutter/material.dart';

import '../../engine/rng.dart';
import '../theme/palette.dart';

/// A deterministic generative "calm quilt": a 7×7 mosaic with 4-fold mirror
/// symmetry, three weekly hues, and four soft motifs. The same [seed] always
/// paints the same artwork — the weekly event's picture is pure math, no
/// assets, no authoring (the Two Dots hand-made-content lesson).
///
/// [revealed] cells (in a seed-shuffled order) are painted; the rest stay as
/// faint paper stubs, so progress reads at a glance and wordlessly.
class MosaicView extends StatelessWidget {
  static const int cellsPerSide = 7;
  static const int totalCells = cellsPerSide * cellsPerSide;

  final int seed;
  final int revealed;
  final double size;
  final GamePalette palette;

  const MosaicView({
    super.key,
    required this.seed,
    required this.revealed,
    required this.size,
    required this.palette,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: size,
      height: size,
      child: CustomPaint(
        painter: _MosaicPainter(
          seed: seed,
          revealed: revealed,
          line: palette.line,
          paper: palette.tile,
        ),
      ),
    );
  }
}

class _CellSpec {
  final int colorIndex; // 0..2 weekly hues
  final int motif; // 0 circle · 1 diamond · 2 leaf arc · 3 square
  const _CellSpec(this.colorIndex, this.motif);
}

class _MosaicPainter extends CustomPainter {
  final int seed;
  final int revealed;
  final Color line;
  final Color paper;

  _MosaicPainter({
    required this.seed,
    required this.revealed,
    required this.line,
    required this.paper,
  });

  static const _n = MosaicView.cellsPerSide;

  @override
  void paint(Canvas canvas, Size size) {
    final rng = DeterministicRng(seed);

    // Three calm weekly hues: a base hue, a neighbour, and a counterpoint —
    // muted saturation/lightness so every week sits on the paper aesthetic.
    final baseHue = rng.nextInt(360).toDouble();
    final hues = [baseHue, (baseHue + 32) % 360, (baseHue + 168) % 360];
    final colors = [
      for (final h in hues)
        HSLColor.fromAHSL(1, h, 0.38, 0.52).toColor(),
    ];

    // Quadrant specs mirrored 4 ways (quilt symmetry).
    final half = (_n + 1) ~/ 2; // 4 for n=7 (includes the centre line)
    final quad = List.generate(
      half,
      (_) => List.generate(
        half,
        (_) => _CellSpec(rng.nextInt(3), rng.nextInt(4)),
      ),
    );
    _CellSpec specFor(int r, int c) {
      final qr = r < half ? r : _n - 1 - r;
      final qc = c < half ? c : _n - 1 - c;
      return quad[qr][qc];
    }

    // Seed-shuffled reveal order.
    final order = List<int>.generate(_n * _n, (i) => i);
    for (var i = order.length - 1; i > 0; i--) {
      final j = rng.nextInt(i + 1);
      final t = order[i];
      order[i] = order[j];
      order[j] = t;
    }
    final rank = List<int>.filled(_n * _n, 0);
    for (var i = 0; i < order.length; i++) {
      rank[order[i]] = i;
    }

    final cell = size.width / _n;
    final pad = cell * 0.08;

    for (var r = 0; r < _n; r++) {
      for (var c = 0; c < _n; c++) {
        final rect = Rect.fromLTWH(
          c * cell + pad,
          r * cell + pad,
          cell - 2 * pad,
          cell - 2 * pad,
        );
        final rrect =
            RRect.fromRectAndRadius(rect, Radius.circular(cell * 0.18));

        if (rank[r * _n + c] >= revealed) {
          // Unrevealed: faint paper stub.
          canvas.drawRRect(
            rrect,
            Paint()..color = line.withValues(alpha: 0.18),
          );
          continue;
        }

        final spec = specFor(r, c);
        final color = colors[spec.colorIndex];
        // Soft tile base + motif on top.
        canvas.drawRRect(
          rrect,
          Paint()..color = color.withValues(alpha: 0.18),
        );
        final paint = Paint()..color = color;
        final center = rect.center;
        final m = rect.width;

        switch (spec.motif) {
          case 0: // circle
            canvas.drawCircle(center, m * 0.30, paint);
          case 1: // diamond
            final path = Path()
              ..moveTo(center.dx, center.dy - m * 0.34)
              ..lineTo(center.dx + m * 0.34, center.dy)
              ..lineTo(center.dx, center.dy + m * 0.34)
              ..lineTo(center.dx - m * 0.34, center.dy)
              ..close();
            canvas.drawPath(path, paint);
          case 2: // leaf arc — orientation mirrors with the quadrant
            final flipX = c >= (_n + 1) ~/ 2;
            final flipY = r >= (_n + 1) ~/ 2;
            final path = Path()
              ..moveTo(
                flipX ? rect.right : rect.left,
                flipY ? rect.bottom : rect.top,
              )
              ..arcToPoint(
                Offset(
                  flipX ? rect.left : rect.right,
                  flipY ? rect.top : rect.bottom,
                ),
                radius: Radius.circular(m),
                clockwise: flipX ^ flipY,
              )
              ..close();
            canvas.drawPath(path, paint);
          case 3: // inset square
            canvas.drawRRect(
              RRect.fromRectAndRadius(
                Rect.fromCenter(center: center, width: m * 0.5, height: m * 0.5),
                Radius.circular(m * 0.12),
              ),
              paint,
            );
        }
      }
    }
  }

  @override
  bool shouldRepaint(_MosaicPainter old) =>
      old.seed != seed ||
      old.revealed != revealed ||
      old.line != line ||
      old.paper != paper;
}
