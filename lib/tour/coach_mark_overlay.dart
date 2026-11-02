import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../l10n/generated/app_localizations.dart';
import '../theme/app_theme.dart';
import 'tour_anchor.dart';
import 'tour_controller.dart';
import 'tour_steps.dart';

/// Hosts the app tour above the Navigator, so a coach mark survives every
/// push and pop and can follow the user from screen to screen.
///
/// Mount once, from `MaterialApp.builder`. While no tour runs it is just
/// [child].
class TourOverlay extends ConsumerStatefulWidget {
  const TourOverlay({super.key, required this.child});

  final Widget child;

  @override
  ConsumerState<TourOverlay> createState() => _TourOverlayState();
}

class _TourOverlayState extends ConsumerState<TourOverlay> {
  @override
  void initState() {
    super.initState();
    // After the first frame, so the tour opens over a drawn screen.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) ref.read(tourProvider.notifier).maybeAutoStart();
    });
  }

  @override
  Widget build(BuildContext context) {
    final running = ref.watch(tourProvider.select((s) => s.running));
    return Stack(
      fit: StackFit.expand,
      children: [widget.child, if (running) const _CoachMarkLayer()],
    );
  }
}

enum _Mode {
  /// The target is loading, animating in, or covered: draw nothing and block
  /// nothing until it settles.
  hidden,

  /// Dim everything but the target.
  spotlight,

  /// A Next step whose target is not built at all (say, a lazily built list
  /// row): explain it without a spotlight rather than stall the tour.
  centered,
}

class _CoachMarkLayer extends ConsumerStatefulWidget {
  const _CoachMarkLayer();

  @override
  ConsumerState<_CoachMarkLayer> createState() => _CoachMarkLayerState();
}

class _CoachMarkLayerState extends ConsumerState<_CoachMarkLayer>
    with SingleTickerProviderStateMixin {
  /// Space between the target and the spotlight's edge.
  static const double _holePadding = 6;

  static const Duration _motion = Duration(milliseconds: 280);

  /// The ring around an interactive target pulses a few times to invite the
  /// tap, then rests: a ring that never stops would keep drawing frames.
  late final AnimationController _pulse = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 700),
  );

  _Mode _mode = _Mode.hidden;

  /// The target's bounds in this layer's coordinates.
  Rect? _hole;

  /// The step whose one-off setup (keyboard, scrolling) has run.
  int? _activeStep;

  @override
  void initState() {
    super.initState();
    _watchFrames();
  }

  @override
  void dispose() {
    _pulse.dispose();
    super.dispose();
  }

  /// Re-measures after every frame the app draws anyway: route transitions,
  /// scrolling, the keyboard, async data arriving. It never asks for a frame
  /// itself, so an idle screen stays idle, and no timer is involved.
  void _watchFrames() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _sync();
      _watchFrames();
    });
  }

  void _sync() {
    final controller = ref.read(tourProvider.notifier);
    final registry = ref.read(tourTargetsProvider);
    controller.reconcile(mounted: registry.mounted, ready: registry.ready);

    final index = ref.read(tourProvider).step;
    final layer = context.findRenderObject();
    if (index == null || layer is! RenderBox || !layer.hasSize) return;
    final step = controller.steps[index];

    var mode = _Mode.hidden;
    Rect? hole;
    final target = registry.readyRect(step.target);
    if (target != null) {
      mode = _Mode.spotlight;
      hole = target.shift(-layer.localToGlobal(Offset.zero));
    } else if (!step.interactive && !registry.isMounted(step.target)) {
      final proof = controller.proofFor(index);
      if (proof == null || registry.isReady(proof)) mode = _Mode.centered;
    }

    if (mode != _Mode.hidden) {
      _dismissKeyboard();
      if (_activeStep != index) {
        _activeStep = index;
        _activate(step, registry.readyContext(step.target));
      }
    }
    if (mode != _mode || (mode == _Mode.spotlight && hole != _hole)) {
      setState(() {
        _mode = mode;
        if (mode == _Mode.spotlight) _hole = hole;
      });
    }
  }

  /// No step involves typing, and a keyboard would sit over the coach mark.
  /// Checked on every frame, not once: the payment form's autofocus lands
  /// in the same frame its route settles, which can be after a step shows.
  void _dismissKeyboard() {
    final focus = FocusManager.instance.primaryFocus;
    if (focus == null || focus is FocusScopeNode) return;
    if (focus.context?.findAncestorStateOfType<EditableTextState>() != null) {
      focus.unfocus();
    }
  }

  void _activate(TourStep step, BuildContext? target) {
    if (target != null) _bringIntoView(target);

    _pulse.reset();
    if (step.interactive && !MediaQuery.disableAnimationsOf(context)) {
      _pulse.repeat(count: 3).whenCompleteOrCancel(() {
        if (mounted) _pulse.value = 0;
      });
    }
  }

  /// Scrolls a target that is cut off by its list into the middle of it. The
  /// next frames re-measure it as it moves.
  void _bringIntoView(BuildContext target) {
    final scrollable = Scrollable.maybeOf(target);
    final viewport = scrollable?.context.findRenderObject();
    final box = target.findRenderObject();
    if (viewport is! RenderBox || box is! RenderBox) return;

    final visible = viewport.localToGlobal(Offset.zero) & viewport.size;
    final rect = box.localToGlobal(Offset.zero) & box.size;
    if (visible.intersect(rect) == rect) return;

    Scrollable.ensureVisible(
      target,
      alignment: 0.5,
      duration: MediaQuery.disableAnimationsOf(context)
          ? Duration.zero
          : _motion,
      curve: Curves.easeOutCubic,
    );
  }

  @override
  Widget build(BuildContext context) {
    final index = ref.watch(tourProvider.select((s) => s.step));
    if (index == null) return const SizedBox.shrink();

    final controller = ref.read(tourProvider.notifier);
    final step = controller.steps[index];
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final media = MediaQuery.of(context);
    final reduceMotion = media.disableAnimations;

    final hidden = _mode == _Mode.hidden;
    final hole = _mode == _Mode.spotlight ? _hole?.inflate(_holePadding) : null;
    // On the scrim the ring must be light in both themes: light mode's
    // primary is a dark navy that would vanish against it.
    final ring = theme.brightness == Brightness.dark
        ? scheme.primary
        : scheme.inversePrimary;
    final scrim = scheme.scrim.withValues(alpha: 0.72);

    Widget barrier(Rect? rect) => _SpotlightBarrier(
      hole: rect,
      passThrough: step.interactive,
      child: CustomPaint(
        size: Size.infinite,
        painter: _SpotlightPainter(
          hole: rect,
          radius: AppTheme.radiusMd,
          scrim: scrim,
          ring: ring,
          pulse: _pulse,
        ),
      ),
    );

    final tooltip = AnimatedSwitcher(
      duration: reduceMotion ? Duration.zero : _motion,
      switchInCurve: Curves.easeOutCubic,
      transitionBuilder: (child, animation) => FadeTransition(
        opacity: animation,
        child: ScaleTransition(
          scale: Tween(begin: 0.96, end: 1.0).animate(animation),
          child: child,
        ),
      ),
      child: CoachMarkTooltip(
        key: ValueKey(index),
        stepNumber: index + 1,
        stepCount: controller.steps.length,
        title: step.title(l10n),
        body: step.body(l10n),
        interactive: step.interactive,
        isLast: controller.isLastStep,
        onNext: controller.next,
        onBack: controller.canGoBack ? controller.back : null,
        onSkip: controller.skip,
      ),
    );

    return IgnorePointer(
      // Waiting for a target must never trap the user in a dimmed app.
      ignoring: hidden,
      child: ExcludeSemantics(
        excluding: hidden,
        child: AnimatedOpacity(
          opacity: hidden ? 0 : 1,
          duration: reduceMotion ? Duration.zero : _motion,
          child: Stack(
            fit: StackFit.expand,
            children: [
              // Screen readers skip the dimmed app on Next steps; on an
              // interactive step its target must stay reachable.
              BlockSemantics(
                blocking: !step.interactive,
                child: ExcludeSemantics(
                  child: hole == null
                      ? barrier(null)
                      : TweenAnimationBuilder<Rect?>(
                          tween: RectTween(begin: hole, end: hole),
                          duration: reduceMotion ? Duration.zero : _motion,
                          curve: Curves.easeInOutCubic,
                          builder: (context, rect, _) => barrier(rect),
                        ),
                ),
              ),
              CustomSingleChildLayout(
                delegate: _TooltipLayout(
                  hole: hole,
                  safeArea: media.padding.copyWith(
                    bottom: math.max(
                      media.padding.bottom,
                      media.viewInsets.bottom,
                    ),
                  ),
                ),
                child: tooltip,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Absorbs every tap except, on interactive steps, those inside the hole:
/// those fall through to the real widget beneath, which handles them as it
/// always does. The tour never calls a target's callback itself.
class _SpotlightBarrier extends SingleChildRenderObjectWidget {
  const _SpotlightBarrier({
    required this.hole,
    required this.passThrough,
    super.child,
  });

  final Rect? hole;
  final bool passThrough;

  @override
  _RenderSpotlightBarrier createRenderObject(BuildContext context) =>
      _RenderSpotlightBarrier(hole: hole, passThrough: passThrough);

  @override
  void updateRenderObject(
    BuildContext context,
    _RenderSpotlightBarrier renderObject,
  ) {
    renderObject
      ..hole = hole
      ..passThrough = passThrough;
  }
}

class _RenderSpotlightBarrier extends RenderProxyBox {
  _RenderSpotlightBarrier({required this.hole, required this.passThrough});

  Rect? hole;
  bool passThrough;

  @override
  bool hitTest(BoxHitTestResult result, {required Offset position}) {
    if (!size.contains(position)) return false;
    if (passThrough && (hole?.contains(position) ?? false)) return false;
    result.add(BoxHitTestEntry(this, position));
    return true;
  }
}

class _SpotlightPainter extends CustomPainter {
  _SpotlightPainter({
    required this.hole,
    required this.radius,
    required this.scrim,
    required this.ring,
    required this.pulse,
  }) : super(repaint: pulse);

  final Rect? hole;
  final double radius;
  final Color scrim;
  final Color ring;
  final Animation<double> pulse;

  @override
  void paint(Canvas canvas, Size size) {
    final path = Path()
      ..fillType = PathFillType.evenOdd
      ..addRect(Offset.zero & size);
    final rect = hole;
    if (rect == null) {
      canvas.drawPath(path, Paint()..color = scrim);
      return;
    }

    final rrect = RRect.fromRectAndRadius(rect, Radius.circular(radius));
    canvas.drawPath(path..addRRect(rrect), Paint()..color = scrim);
    canvas.drawRRect(
      rrect,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.5
        ..color = ring,
    );

    final t = pulse.value;
    if (t > 0) {
      canvas.drawRRect(
        rrect.inflate(10 * t),
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2
          ..color = ring.withValues(alpha: 0.7 * (1 - t)),
      );
    }
  }

  @override
  bool shouldRepaint(_SpotlightPainter old) =>
      old.hole != hole ||
      old.radius != radius ||
      old.scrim != scrim ||
      old.ring != ring ||
      old.pulse != pulse;
}

/// Puts the tooltip on whichever side of the target has more room, inside
/// the safe area and above the keyboard; centred when there is no target.
/// Full width up to a readable maximum, so it needs no left/right logic and
/// is the same in Arabic and English.
class _TooltipLayout extends SingleChildLayoutDelegate {
  _TooltipLayout({required this.hole, required this.safeArea});

  static const double _margin = AppTheme.gapLg;
  static const double _gap = AppTheme.gapMd;
  static const double _maxWidth = 420;

  final Rect? hole;
  final EdgeInsets safeArea;

  @override
  BoxConstraints getConstraintsForChild(BoxConstraints constraints) {
    final width = math.min(constraints.maxWidth - 2 * _margin, _maxWidth);
    return BoxConstraints(
      minWidth: width,
      maxWidth: width,
      maxHeight: math.max(
        0,
        constraints.maxHeight - safeArea.vertical - 2 * _margin,
      ),
    );
  }

  @override
  Offset getPositionForChild(Size size, Size childSize) {
    final left = (size.width - childSize.width) / 2;
    final minTop = safeArea.top + _margin;
    final maxTop = math.max(
      minTop,
      size.height - safeArea.bottom - _margin - childSize.height,
    );

    final rect = hole;
    if (rect == null) {
      return Offset(left, ((minTop + maxTop) / 2).clamp(minTop, maxTop));
    }

    final below = rect.bottom + _gap;
    final above = rect.top - _gap - childSize.height;
    final fitsBelow = below <= maxTop;
    final fitsAbove = above >= minTop;
    final roomBelow = size.height - safeArea.bottom - rect.bottom;
    final roomAbove = rect.top - safeArea.top;

    final double top;
    if (roomBelow >= roomAbove) {
      top = fitsBelow || !fitsAbove ? below : above;
    } else {
      top = fitsAbove || !fitsBelow ? above : below;
    }
    return Offset(left, top.clamp(minTop, maxTop));
  }

  @override
  bool shouldRelayout(_TooltipLayout old) =>
      old.hole != hole || old.safeArea != safeArea;
}

/// The card beside a highlighted widget: progress, what it is, and the way
/// on. On interactive steps the way on is the highlighted widget itself, so
/// there is no Next button, only the hint to tap it.
class CoachMarkTooltip extends StatelessWidget {
  const CoachMarkTooltip({
    super.key,
    required this.stepNumber,
    required this.stepCount,
    required this.title,
    required this.body,
    required this.interactive,
    required this.isLast,
    required this.onNext,
    required this.onSkip,
    this.onBack,
  });

  final int stepNumber;
  final int stepCount;
  final String title;
  final String body;
  final bool interactive;
  final bool isLast;
  final VoidCallback onNext;
  final VoidCallback onSkip;

  /// Null hides Back.
  final VoidCallback? onBack;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    return Semantics(
      container: true,
      liveRegion: true,
      child: Material(
        type: MaterialType.transparency,
        child: Container(
          padding: const EdgeInsets.fromLTRB(
            AppTheme.gapLg,
            AppTheme.gapLg,
            AppTheme.gapLg,
            AppTheme.gapSm,
          ),
          decoration: AppTheme.surface(context, radius: AppTheme.radiusLg),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  l10n.tourStepCounter(stepNumber, stepCount),
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: scheme.primary,
                  ),
                ),
                const SizedBox(height: AppTheme.gapSm),
                ClipRRect(
                  borderRadius: BorderRadius.circular(2),
                  child: LinearProgressIndicator(
                    value: stepNumber / stepCount,
                    minHeight: 4,
                    backgroundColor: scheme.surfaceContainerHighest,
                  ),
                ),
                const SizedBox(height: AppTheme.gapMd),
                Text(title, style: theme.textTheme.titleMedium),
                const SizedBox(height: AppTheme.gapXs),
                Text(body, style: theme.textTheme.bodyMedium),
                if (interactive) ...[
                  const SizedBox(height: AppTheme.gapMd),
                  Row(
                    children: [
                      Icon(
                        Icons.touch_app_rounded,
                        size: 20,
                        color: scheme.primary,
                      ),
                      const SizedBox(width: AppTheme.gapSm),
                      Expanded(
                        child: Text(
                          l10n.tourTapToContinue,
                          style: theme.textTheme.labelMedium?.copyWith(
                            color: scheme.primary,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
                const SizedBox(height: AppTheme.gapSm),
                // Skip at the start edge, the way on at the end; on a narrow
                // screen or with long labels the pair wraps rather than
                // overflowing.
                Wrap(
                  alignment: WrapAlignment.spaceBetween,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    TextButton(
                      style: TextButton.styleFrom(
                        minimumSize: AppTheme.dialogActionSize,
                        foregroundColor: scheme.onSurfaceVariant,
                      ),
                      onPressed: onSkip,
                      child: Text(l10n.tourSkip),
                    ),
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        if (onBack case final onBack?)
                          TextButton(
                            style: TextButton.styleFrom(
                              minimumSize: AppTheme.dialogActionSize,
                            ),
                            onPressed: onBack,
                            child: Text(l10n.tourBack),
                          ),
                        if (!interactive) ...[
                          const SizedBox(width: AppTheme.gapSm),
                          FilledButton(
                            style: FilledButton.styleFrom(
                              minimumSize: AppTheme.dialogActionSize,
                            ),
                            onPressed: onNext,
                            child: Text(
                              isLast ? l10n.tourFinish : l10n.tourNext,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
