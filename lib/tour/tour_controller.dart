import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../providers/app_providers.dart';
import '../services/storage_service.dart';
import 'tour_steps.dart';

/// Where the user stands with the tour, as saved on the device.
///
/// Opening the tour saves nothing: only finishing or skipping it does. A tour
/// cut short (the app was closed, or killed in the background) is still
/// [notStarted] and is offered again on the next launch.
enum TourStatus { notStarted, skipped, completed }

/// Persistence for [TourStatus]. A seam so tests do not need Hive.
abstract interface class TourStatusStore {
  TourStatus read();
  Future<void> write(TourStatus status);
}

/// Kept in the unencrypted settings box, beside the theme: nothing sensitive.
class StorageTourStatusStore implements TourStatusStore {
  StorageTourStatusStore(this._storage);

  final StorageService _storage;

  @override
  TourStatus read() => switch (_storage.tourStatusName()) {
    'completed' => TourStatus.completed,
    'skipped' => TourStatus.skipped,
    _ => TourStatus.notStarted,
  };

  @override
  Future<void> write(TourStatus status) =>
      _storage.setTourStatusName(status.name);
}

final tourStatusStoreProvider = Provider<TourStatusStore>(
  (ref) => StorageTourStatusStore(ref.watch(storageServiceProvider)),
);

class TourState {
  const TourState({required this.status, this.step});

  final TourStatus status;

  /// Index into [tourSteps] while the tour runs; null otherwise.
  final int? step;

  bool get running => step != null;
}

/// Runs the tour: which step is showing, and what is saved when it ends.
///
/// Holds no widgets. The overlay reports what is on screen through
/// [reconcile], which is where the tour follows the user between screens.
class TourController extends Notifier<TourState> {
  /// The steps are a parameter only so tests can run a shorter tour.
  TourController({List<TourStep>? steps}) : steps = steps ?? tourSteps;

  final List<TourStep> steps;

  @override
  TourState build() =>
      TourState(status: ref.read(tourStatusStoreProvider).read());

  /// Starts from the first step, whatever was saved: this is also how the
  /// tour is replayed from Settings. Nothing is written until it ends.
  void start() => state = TourState(status: state.status, step: 0);

  /// The first-launch start. Only for someone who has never finished or
  /// skipped the tour and has nothing in the app yet: a user who already has
  /// history or favorites (an upgrade from a version without the tour) is not
  /// interrupted, and can start it from Settings.
  void maybeAutoStart() {
    if (state.running || state.status != TourStatus.notStarted) return;
    if (ref.read(historyProvider).isNotEmpty) return;
    if (ref.read(favoritesProvider).isNotEmpty) return;
    start();
  }

  /// Back is offered only between two Next steps. Going back over an
  /// interactive step would mean navigating for the user, so it is not.
  bool get canGoBack {
    final index = state.step;
    if (index == null || index == 0) return false;
    return !steps[index].interactive && !steps[index - 1].interactive;
  }

  bool get isLastStep => state.step == steps.length - 1;

  void next() {
    final index = state.step;
    if (index == null || steps[index].interactive) return;
    if (index == steps.length - 1) {
      finish();
    } else {
      state = TourState(status: state.status, step: index + 1);
    }
  }

  void back() {
    if (!canGoBack) return;
    state = TourState(status: state.status, step: state.step! - 1);
  }

  Future<void> finish() => _end(TourStatus.completed);

  /// A tour skipped on a replay does not undo having completed it once.
  Future<void> skip() => _end(
    state.status == TourStatus.completed
        ? TourStatus.completed
        : TourStatus.skipped,
  );

  Future<void> _end(TourStatus status) async {
    state = TourState(status: status);
    await ref.read(tourStatusStoreProvider).write(status);
  }

  /// The target whose presence shows that the interactive step before
  /// [index] really happened: the payment form is still open, the user is
  /// still on the tab they were sent to. Null before the first interactive
  /// step.
  TourTarget? proofFor(int index) {
    for (var i = index - 1; i >= 0; i--) {
      final reached = steps[i].advanceWhenReady;
      if (reached != null) return reached;
    }
    return null;
  }

  /// Brings the tour in line with what is on screen. Called by the overlay
  /// after each frame with the targets that are [mounted] at all and those
  /// that are [ready] (visible, on the current route, done animating).
  ///
  /// - An interactive step is passed once its outcome is ready, however the
  ///   user got there.
  /// - If what an earlier interactive step achieved has been undone -- the
  ///   payment form closed by the system back gesture mid-explanation, or
  ///   a notification answer popped to the root -- the tour steps back to
  ///   that step, rather than pointing at a widget that is gone.
  ///
  /// Only an unmounted proof counts as undone: a route still animating keeps
  /// its widgets mounted, so a transition never rewinds the tour.
  void reconcile({
    required Set<TourTarget> mounted,
    required Set<TourTarget> ready,
  }) {
    final index = state.step;
    if (index == null) return;

    final reached = steps[index].advanceWhenReady;
    if (reached != null && ready.contains(reached)) {
      if (index == steps.length - 1) {
        finish();
      } else {
        state = TourState(status: state.status, step: index + 1);
      }
      return;
    }

    final proof = proofFor(index);
    if (proof != null && !mounted.contains(proof)) {
      for (var i = index - 1; i >= 0; i--) {
        if (steps[i].advanceWhenReady == proof) {
          state = TourState(status: state.status, step: i);
          return;
        }
      }
    }
  }
}

final tourProvider = NotifierProvider<TourController, TourState>(
  TourController.new,
);
