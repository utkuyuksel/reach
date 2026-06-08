import 'package:flutter/widgets.dart';

import '../theme/palette.dart';

/// The calm, warm "paper" backdrop: a soft radial gradient lifting toward the
/// top of the screen, matching the prototype's tone.
class PaperBackground extends StatelessWidget {
  final GamePalette palette;
  final Widget child;

  const PaperBackground({
    super.key,
    required this.palette,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        gradient: RadialGradient(
          center: const Alignment(0, -1.15),
          radius: 1.25,
          colors: [palette.paperHi, palette.paper, palette.paperLo],
          stops: const [0.0, 0.55, 1.0],
        ),
      ),
      child: child,
    );
  }
}
