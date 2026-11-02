import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'tour_steps.dart';

/// Marks [child] as the widget the tour means by [target].
///
/// Inert on its own: it only records where it is. Screens carry anchors
/// whether or not a tour is running, and nothing about them changes.
class TourAnchor extends ConsumerStatefulWidget {
  const TourAnchor({super.key, required this.target, required this.child});

  final TourTarget target;
  final Widget child;

  @override
  ConsumerState<TourAnchor> createState() => _TourAnchorState();
}

class _TourAnchorState extends ConsumerState<TourAnchor> {
  late final TourTargetRegistry _registry;

  /// Read in build, where depending on them is allowed, so readiness can be
  /// checked later from a frame callback without new dependencies.
  bool _visible = true;
  ModalRoute<Object?>? _route;

  @override
  void initState() {
    super.initState();
    _registry = ref.read(tourTargetsProvider).._add(widget.target, this);
  }

  @override
  void didUpdateWidget(TourAnchor oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.target != widget.target) {
      _registry
        .._remove(oldWidget.target, this)
        .._add(widget.target, this);
    }
  }

  @override
  void dispose() {
    _registry._remove(widget.target, this);
    super.dispose();
  }

  /// On screen and settled: not on a hidden tab, not under another route or
  /// a dialog, not mid-transition, and laid out.
  bool get isReady {
    if (!mounted || !_visible) return false;
    final route = _route;
    if (route != null) {
      if (!route.isCurrent) return false;
      if (route.animation case final a? when !a.isCompleted) return false;
      if (route.secondaryAnimation case final a? when !a.isDismissed) {
        return false;
      }
    }
    final box = context.findRenderObject();
    return box is RenderBox && box.attached && box.hasSize;
  }

  /// Bounds in global (screen) coordinates. Only meaningful when [isReady].
  Rect get globalRect {
    final box = context.findRenderObject()! as RenderBox;
    return box.localToGlobal(Offset.zero) & box.size;
  }

  @override
  Widget build(BuildContext context) {
    // IndexedStack wraps every tab in a Visibility, so this is false for a
    // tab that is mounted but not the one showing.
    _visible = Visibility.of(context);
    _route = ModalRoute.of(context);
    return widget.child;
  }
}

/// Where each [TourAnchor] currently is. Plain bookkeeping; the overlay reads
/// it after each frame.
class TourTargetRegistry {
  final Map<TourTarget, List<_TourAnchorState>> _anchors = {};

  void _add(TourTarget target, _TourAnchorState anchor) =>
      (_anchors[target] ??= []).add(anchor);

  void _remove(TourTarget target, _TourAnchorState anchor) {
    final list = _anchors[target];
    list?.remove(anchor);
    if (list != null && list.isEmpty) _anchors.remove(target);
  }

  bool isMounted(TourTarget target) => _anchors.containsKey(target);

  bool isReady(TourTarget target) =>
      _anchors[target]?.any((a) => a.isReady) ?? false;

  Set<TourTarget> get mounted => _anchors.keys.toSet();

  Set<TourTarget> get ready => {
    for (final MapEntry(:key, :value) in _anchors.entries)
      if (value.any((a) => a.isReady)) key,
  };

  /// The ready anchor for [target], if there is one. With the same target
  /// mounted twice (a screen under another copy of itself), only the one on
  /// screen counts.
  BuildContext? readyContext(TourTarget target) =>
      _anchors[target]?.where((a) => a.isReady).firstOrNull?.context;

  /// Screen bounds of the ready anchor for [target], or null.
  Rect? readyRect(TourTarget target) =>
      _anchors[target]?.where((a) => a.isReady).firstOrNull?.globalRect;
}

final tourTargetsProvider = Provider<TourTargetRegistry>(
  (ref) => TourTargetRegistry(),
);
