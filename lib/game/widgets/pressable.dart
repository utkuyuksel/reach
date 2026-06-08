import 'package:flutter/widgets.dart';

/// Wraps a widget with a tactile press response: it sinks down slightly while
/// held, mirroring the prototype's `:active { translateY }` feel. Disabled
/// children don't respond.
class Pressable extends StatefulWidget {
  final Widget child;
  final VoidCallback? onTap;

  /// How far (logical px) the child sinks while pressed.
  final double depth;

  const Pressable({
    super.key,
    required this.child,
    required this.onTap,
    this.depth = 2.0,
  });

  @override
  State<Pressable> createState() => _PressableState();
}

class _PressableState extends State<Pressable> {
  bool _down = false;

  void _setDown(bool v) {
    if (widget.onTap == null) return;
    if (_down != v) setState(() => _down = v);
  }

  @override
  Widget build(BuildContext context) {
    final enabled = widget.onTap != null;
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTapDown: (_) => _setDown(true),
      onTapUp: (_) => _setDown(false),
      onTapCancel: () => _setDown(false),
      onTap: widget.onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 90),
        curve: Curves.easeOut,
        transform: Matrix4.translationValues(0, _down ? widget.depth : 0, 0),
        child: Opacity(opacity: enabled ? 1 : 0.4, child: widget.child),
      ),
    );
  }
}
