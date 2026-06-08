import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../engine/models/grid.dart';
import '../theme/app_text.dart';
import '../theme/palette.dart';
import 'tile_widget.dart';

/// The R×C board with drag-to-trace selection. The player drags across
/// orthogonally-adjacent tiles; a running-sum chip follows the trace head, and
/// on release the traced path is submitted. No gravity — cleared cells leave
/// faint empty slots.
class BoardWidget extends StatefulWidget {
  final Grid grid;
  final int target;
  final GamePalette palette;
  final bool colorblind;
  final bool hapticsEnabled;
  final List<int> hintCells;

  /// Submit a traced path; returns true if it cleared a group. A false return
  /// (wrong sum, or a board-stranding move) triggers a gentle bounce.
  final bool Function(List<int> path) onSubmitPath;

  const BoardWidget({
    super.key,
    required this.grid,
    required this.target,
    required this.palette,
    required this.onSubmitPath,
    this.colorblind = false,
    this.hapticsEnabled = true,
    this.hintCells = const [],
  });

  @override
  State<BoardWidget> createState() => _BoardWidgetState();
}

class _BoardWidgetState extends State<BoardWidget> {
  static const double _gap = 10;
  static const double _topPad = 32; // room for the running-sum chip

  List<int> _path = [];
  List<int> _reject = const [];
  double _cell = 0;

  Grid get _grid => widget.grid;

  int get _sum {
    var s = 0;
    for (final i in _path) {
      final t = _grid.at(i);
      if (t != null) s += t.value;
    }
    return s;
  }

  bool get _isMatch => _path.isNotEmpty && _sum == widget.target;

  int? _cellAt(Offset p) {
    final stride = _cell + _gap;
    if (stride <= 0) return null;
    final c = (p.dx / stride).floor().clamp(0, _grid.cols - 1);
    final r = ((p.dy - _topPad) / stride).floor().clamp(0, _grid.rows - 1);
    return r * _grid.cols + c;
  }

  void _start(Offset p) {
    final cell = _cellAt(p);
    if (cell == null || _grid.at(cell) == null) return;
    setState(() => _path = [cell]);
    _tick();
  }

  void _move(Offset p) {
    if (_path.isEmpty) {
      _start(p);
      return;
    }
    final cell = _cellAt(p);
    if (cell == null || cell == _path.last) return;

    // Backtrack if returning to the previous tile.
    if (_path.length >= 2 && cell == _path[_path.length - 2]) {
      setState(() => _path = _path.sublist(0, _path.length - 1));
      return;
    }
    // Otherwise extend if it's a fresh, occupied, adjacent tile.
    if (_grid.at(cell) != null &&
        !_path.contains(cell) &&
        _grid.areOrthogonalNeighbors(_path.last, cell)) {
      setState(() => _path = [..._path, cell]);
      _tick();
    }
  }

  void _end() {
    if (_path.isEmpty) return;
    final path = _path;
    setState(() => _path = []);
    final accepted = widget.onSubmitPath(path);
    if (!accepted && path.length >= 2) {
      // Gentle bounce: briefly flash the rejected trace.
      setState(() => _reject = path);
      Future.delayed(const Duration(milliseconds: 340), () {
        if (mounted) setState(() => _reject = const []);
      });
    }
  }

  void _tick() {
    if (widget.hapticsEnabled) HapticFeedback.selectionClick();
  }

  TileState _stateFor(int index) {
    if (_path.contains(index)) {
      return _isMatch ? TileState.match : TileState.path;
    }
    if (_reject.contains(index)) return TileState.reject;
    if (widget.hintCells.contains(index)) return TileState.hint;
    return TileState.normal;
  }

  @override
  Widget build(BuildContext context) {
    final cols = _grid.cols;
    final rows = _grid.rows;

    return LayoutBuilder(
      builder: (context, constraints) {
        _cell = ((constraints.maxWidth - _gap * (cols - 1)) / cols)
            .clamp(0.0, 96.0);
        final byHeight =
            (constraints.maxHeight - _topPad - _gap * (rows - 1)) / rows;
        if (byHeight < _cell) _cell = byHeight.clamp(0.0, 96.0);

        final stride = _cell + _gap;
        final boardW = _cell * cols + _gap * (cols - 1);
        final boardH = _cell * rows + _gap * (rows - 1) + _topPad;

        return Center(
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onPanStart: (d) => _start(d.localPosition),
            onPanUpdate: (d) => _move(d.localPosition),
            onPanEnd: (_) => _end(),
            onPanCancel: _end,
            child: SizedBox(
              width: boardW,
              height: boardH,
              child: Stack(
                clipBehavior: Clip.none,
                children: [
                  for (var i = 0; i < rows * cols; i++)
                    Positioned(
                      left: (i % cols) * stride,
                      top: _topPad + (i ~/ cols) * stride,
                      width: _cell,
                      height: _cell,
                      child: _cellWidget(i),
                    ),
                  if (_path.isNotEmpty) _sumChip(stride),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _cellWidget(int index) {
    final tile = _grid.at(index);
    final radius = _cell * 0.24;
    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 220),
      switchInCurve: Curves.easeOut,
      switchOutCurve: Curves.easeIn,
      transitionBuilder: (child, anim) =>
          FadeTransition(opacity: anim, child: ScaleTransition(scale: anim, child: child)),
      child: tile == null
          ? _EmptySlot(
              key: ValueKey('e$index'),
              size: _cell,
              radius: radius,
              palette: widget.palette,
            )
          : TileWidget(
              key: ValueKey('t${tile.id}'),
              value: tile.value,
              state: _stateFor(index),
              palette: widget.palette,
              size: _cell,
              colorblind: widget.colorblind,
            ),
    );
  }

  Widget _sumChip(double stride) {
    final head = _path.last;
    final col = head % _grid.cols;
    final row = head ~/ _grid.cols;
    final match = _isMatch;
    final chipW = 44.0;
    var left = col * stride + (_cell - chipW) / 2;
    left = left.clamp(0.0, _grid.cols * stride - _gap - chipW);
    final top = _topPad + row * stride - 26;
    return Positioned(
      left: left,
      top: top < 0 ? 0 : top,
      child: IgnorePointer(
        child: Container(
          width: chipW,
          alignment: Alignment.center,
          padding: const EdgeInsets.symmetric(vertical: 5),
          decoration: BoxDecoration(
            color: match ? widget.palette.good : widget.palette.accent,
            borderRadius: BorderRadius.circular(9),
            boxShadow: [
              BoxShadow(
                color: widget.palette.shadow,
                blurRadius: 8,
                offset: const Offset(0, 3),
              ),
            ],
          ),
          child: Text(
            '$_sum',
            style: AppText.mono(
              size: 13,
              weight: FontWeight.w500,
              color: Colors.white,
            ),
          ),
        ),
      ),
    );
  }
}

class _EmptySlot extends StatelessWidget {
  final double size;
  final double radius;
  final GamePalette palette;

  const _EmptySlot({
    super.key,
    required this.size,
    required this.radius,
    required this.palette,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: palette.line.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(radius),
        border: Border.all(color: palette.line.withValues(alpha: 0.4)),
      ),
    );
  }
}
