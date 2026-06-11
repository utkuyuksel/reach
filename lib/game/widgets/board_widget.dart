import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../engine/models/grid.dart';
import '../../engine/models/tile.dart';
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

  /// Called when a tile joins the trace (for a soft tick sound).
  final VoidCallback? onTick;

  /// When non-empty (tutorial only), a "finger" gently glides along these
  /// cells to show the player a path to drag. Hidden while they are dragging.
  final List<int> coachPath;

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
    this.onTick,
    this.coachPath = const [],
  });

  @override
  State<BoardWidget> createState() => _BoardWidgetState();
}

class _BoardWidgetState extends State<BoardWidget>
    with SingleTickerProviderStateMixin {
  static const double _gap = 10;
  static const double _topPad = 32; // room for the running-sum chip

  List<int> _path = [];
  List<int> _reject = const [];
  double _cell = 0;

  /// Pop "echoes" of just-cleared tiles: a brief scale+fade+drift so a clear
  /// lands physically instead of tiles silently vanishing.
  final List<_Ghost> _ghosts = [];
  int _ghostSerial = 0;

  /// Looping driver for the tutorial coach finger; created only when a
  /// [BoardWidget.coachPath] is supplied (so the real game pays for no ticker).
  AnimationController? _coach;

  Grid get _grid => widget.grid;

  @override
  void initState() {
    super.initState();
    if (widget.coachPath.isNotEmpty) _ensureCoach();
  }

  @override
  void didUpdateWidget(BoardWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.coachPath.isNotEmpty) _ensureCoach();
    _spawnGhosts(oldWidget.grid, widget.grid);
  }

  /// Diff the grids: every tile that just disappeared gets a pop echo.
  /// Undo/restart only ADD tiles, and a fresh board swaps full→full, so
  /// ghosts appear exactly on clears.
  void _spawnGhosts(Grid old, Grid next) {
    if (old.rows != next.rows || old.cols != next.cols) return;
    final batch = <int>[];
    var order = 0;
    for (var i = 0; i < old.totalCells; i++) {
      final t = old.at(i);
      if (t != null && next.at(i) == null) {
        final id = _ghostSerial++;
        batch.add(id);
        _ghosts.add(_Ghost(id: id, index: i, value: t.value, order: order++));
      }
    }
    if (batch.isEmpty) return;
    setState(() {});
    Future.delayed(const Duration(milliseconds: 700), () {
      if (!mounted) return;
      setState(() => _ghosts.removeWhere((g) => batch.contains(g.id)));
    });
  }

  @override
  void dispose() {
    _coach?.dispose();
    super.dispose();
  }

  void _ensureCoach() {
    _coach ??= AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2000),
    )..repeat();
  }

  int get _sum {
    var s = 0;
    for (final i in _path) {
      final t = _grid.at(i);
      if (t != null) s += t.value;
    }
    return s;
  }

  bool get _isMatch => _path.isNotEmpty && _sum == widget.target;

  /// While a veiled tile is in the trace, the running sum stays a mystery —
  /// the match-green state is the only tell. Probing the fog is the game.
  bool get _pathHasVeiled => _path.any(
      (i) => _grid.at(i)?.modifier == TileModifier.veiled);

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
    widget.onTick?.call();
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
                  for (final g in _ghosts)
                    Positioned(
                      left: (g.index % cols) * stride,
                      top: _topPad + (g.index ~/ cols) * stride,
                      width: _cell,
                      height: _cell,
                      child: _GhostPop(
                        ghost: g,
                        palette: widget.palette,
                        size: _cell,
                      ),
                    ),
                  if (_path.isNotEmpty) _sumChip(stride),
                  if (_coach != null &&
                      _path.isEmpty &&
                      widget.coachPath.length >= 2)
                    AnimatedBuilder(
                      animation: _coach!,
                      builder: (context, _) => _coachFinger(stride),
                    ),
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
              veiled: tile.modifier == TileModifier.veiled,
              gold: tile.modifier == TileModifier.gold,
            ),
    );
  }

  /// A touch icon that glides along [BoardWidget.coachPath], showing the player
  /// "drag across these tiles". Uses the board's own cell geometry, fades in/out
  /// at the loop ends, and ignores pointers so the real drag passes through.
  Widget _coachFinger(double stride) {
    final pts = <Offset>[];
    for (final i in widget.coachPath) {
      final col = i % _grid.cols;
      final row = i ~/ _grid.cols;
      pts.add(Offset(
        col * stride + _cell / 2,
        _topPad + row * stride + _cell / 2,
      ));
    }
    if (pts.length < 2) return const SizedBox.shrink();

    final v = _coach!.value;
    final glide = (v / 0.82).clamp(0.0, 1.0); // travel, then briefly rest
    final fpos = glide * (pts.length - 1);
    final seg = fpos.floor().clamp(0, pts.length - 2);
    final pos = Offset.lerp(pts[seg], pts[seg + 1], fpos - seg)!;
    final opacity = v < 0.12
        ? v / 0.12
        : (v > 0.86 ? (1 - (v - 0.86) / 0.14) : 1.0);

    return Positioned(
      left: pos.dx - 13,
      top: pos.dy + 2,
      child: IgnorePointer(
        child: Opacity(
          opacity: opacity.clamp(0.0, 1.0),
          child: Icon(
            Icons.touch_app_rounded,
            size: 26,
            color: widget.palette.accentDeep,
          ),
        ),
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
            _pathHasVeiled && !match ? '?' : '$_sum',
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

/// A just-cleared tile's data, kept briefly for its pop echo.
class _Ghost {
  final int id;
  final int index;
  final int value;

  /// Position within the cleared group (drives the stagger).
  final int order;

  const _Ghost({
    required this.id,
    required this.index,
    required this.value,
    required this.order,
  });
}

/// The pop echo itself: a match-coloured tile that swells, lifts, and fades —
/// staggered along the traced path so the clear reads as a ripple.
class _GhostPop extends StatelessWidget {
  final _Ghost ghost;
  final GamePalette palette;
  final double size;

  const _GhostPop({
    required this.ghost,
    required this.palette,
    required this.size,
  });

  @override
  Widget build(BuildContext context) {
    const total = 620.0; // ms, including the longest stagger
    final delay = (ghost.order * 45.0).clamp(0.0, 220.0);
    return IgnorePointer(
      child: TweenAnimationBuilder<double>(
        tween: Tween(begin: 0, end: 1),
        duration: const Duration(milliseconds: 620),
        curve: Curves.linear,
        builder: (context, raw, _) {
          // Re-map global time so each tile starts after its stagger delay.
          final t =
              ((raw * total - delay) / (total - 220.0)).clamp(0.0, 1.0);
          if (t == 0) return const SizedBox.shrink();
          final eased = Curves.easeOutCubic.transform(t);
          return Opacity(
            opacity: (1 - eased) * 0.85,
            child: Transform.translate(
              offset: Offset(0, -10 * eased),
              child: Transform.scale(
                scale: 1 + 0.22 * eased,
                child: Container(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [palette.good, palette.goodDeep],
                    ),
                    borderRadius: BorderRadius.circular(size * 0.24),
                  ),
                  alignment: Alignment.center,
                  child: Text(
                    '${ghost.value}',
                    style: AppText.fraunces(
                      size: size * 0.40,
                      weight: 600,
                      color: Colors.white,
                    ),
                  ),
                ),
              ),
            ),
          );
        },
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
