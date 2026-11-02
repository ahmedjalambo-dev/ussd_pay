import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ussd_pay/models/favorite.dart';
import 'package:ussd_pay/models/history_entry.dart';
import 'package:ussd_pay/providers/app_providers.dart';
import 'package:ussd_pay/tour/tour_controller.dart';
import 'package:ussd_pay/tour/tour_steps.dart';

class _MemoryStore implements TourStatusStore {
  _MemoryStore([this.status = TourStatus.notStarted]);

  TourStatus status;
  int writes = 0;

  @override
  TourStatus read() => status;

  @override
  Future<void> write(TourStatus value) async {
    status = value;
    writes++;
  }
}

class _History extends HistoryNotifier {
  _History(this._rows);
  final List<HistoryEntry> _rows;
  @override
  List<HistoryEntry> build() => _rows;
}

class _Favorites extends FavoritesNotifier {
  @override
  List<Favorite> build() => const [];
}

/// The steps by index, so the expectations read as the tour does.
const _wallet = 0, _phone = 1, _amount = 2, _review = 3, _back = 4, _pin = 5;
const _favorites = 6, _history = 7, _settings = 8;

void main() {
  late _MemoryStore store;

  ProviderContainer container({List<HistoryEntry> history = const []}) {
    final c = ProviderContainer(
      overrides: [
        tourStatusStoreProvider.overrideWithValue(store),
        historyProvider.overrideWith(() => _History(history)),
        favoritesProvider.overrideWith(_Favorites.new),
      ],
    );
    addTearDown(c.dispose);
    return c;
  }

  setUp(() => store = _MemoryStore());

  test('the tour targets what the plan says, in order', () {
    expect(tourSteps.map((s) => s.target), [
      TourTarget.walletCard,
      TourTarget.phoneField,
      TourTarget.amountField,
      TourTarget.reviewButton,
      TourTarget.paymentBack,
      TourTarget.pinNotice,
      TourTarget.favoritesTab,
      TourTarget.historyTab,
      TourTarget.settingsButton,
    ]);
    expect(
      [
        for (final (i, s) in tourSteps.indexed)
          if (s.interactive) i,
      ],
      [_wallet, _back, _favorites, _history],
    );
  });

  group('persistence', () {
    test('starting writes nothing; finishing saves completed', () async {
      final c = container();
      final tour = c.read(tourProvider.notifier)..start();
      expect(c.read(tourProvider).step, 0);
      expect(store.writes, 0);

      await tour.finish();
      expect(c.read(tourProvider).running, isFalse);
      expect(store.status, TourStatus.completed);
    });

    test('skipping saves skipped', () async {
      final c = container();
      await (c.read(tourProvider.notifier)..start()).skip();
      expect(store.status, TourStatus.skipped);
      expect(c.read(tourProvider).status, TourStatus.skipped);
    });

    test('skipping a replay keeps completed', () async {
      store = _MemoryStore(TourStatus.completed);
      final c = container();
      await (c.read(tourProvider.notifier)..start()).skip();
      expect(store.status, TourStatus.completed);
    });

    test('an interrupted tour is still not started', () {
      final c = container();
      c.read(tourProvider.notifier)
        ..start()
        ..reconcile(mounted: {}, ready: {TourTarget.phoneField});
      expect(c.read(tourProvider).step, _phone);
      // The app is closed here, mid-tour: nothing was saved, so the next
      // launch offers the tour again.
      expect(store.writes, 0);
      expect(store.status, TourStatus.notStarted);
    });

    test('Next on the last step finishes', () {
      final c = container();
      final tour = c.read(tourProvider.notifier)..start();
      tour.reconcile(mounted: {}, ready: {TourTarget.phoneField});
      tour
        ..next()
        ..next()
        ..next();
      tour.reconcile(mounted: {}, ready: {TourTarget.homePage});
      tour.next();
      tour.reconcile(mounted: {}, ready: {TourTarget.favoritesPage});
      tour.reconcile(mounted: {}, ready: {TourTarget.historyPage});
      expect(c.read(tourProvider).step, _settings);
      expect(tour.isLastStep, isTrue);

      tour.next();
      expect(c.read(tourProvider).running, isFalse);
      expect(store.status, TourStatus.completed);
    });
  });

  group('auto-start', () {
    test('a new user gets the tour', () {
      final c = container();
      c.read(tourProvider.notifier).maybeAutoStart();
      expect(c.read(tourProvider).step, 0);
    });

    test('not after it was skipped or completed', () {
      for (final status in [TourStatus.skipped, TourStatus.completed]) {
        store = _MemoryStore(status);
        final c = container();
        c.read(tourProvider.notifier).maybeAutoStart();
        expect(c.read(tourProvider).running, isFalse, reason: '$status');
      }
    });

    test('not for someone who already has history', () {
      final c = container(
        history: [
          HistoryEntry(
            dialedAtUtc: DateTime.utc(2026),
            walletId: 'w',
            recipientType: 'friend',
            recipientNumber: '0599123456',
            amount: 5,
            ussdCode: '*1*0599123456*5#',
          ),
        ],
      );
      c.read(tourProvider.notifier).maybeAutoStart();
      expect(c.read(tourProvider).running, isFalse);
    });

    test('a replay starts whatever was saved', () {
      store = _MemoryStore(TourStatus.completed);
      final c = container();
      c.read(tourProvider.notifier).start();
      expect(c.read(tourProvider).step, 0);
    });
  });

  group('steps', () {
    late ProviderContainer c;
    late TourController tour;
    int? step() => c.read(tourProvider).step;

    setUp(() {
      c = container();
      tour = c.read(tourProvider.notifier)..start();
    });

    test('Next does nothing on an interactive step', () {
      tour.next();
      expect(step(), _wallet);
    });

    test('an interactive step passes once its outcome is on screen', () {
      // Mounted but still animating in: not yet.
      tour.reconcile(
        mounted: {TourTarget.walletCard, TourTarget.phoneField},
        ready: {},
      );
      expect(step(), _wallet);

      tour.reconcile(
        mounted: {TourTarget.walletCard, TourTarget.phoneField},
        ready: {TourTarget.phoneField},
      );
      expect(step(), _phone);
    });

    test('Back only between two Next steps', () {
      tour.reconcile(mounted: {}, ready: {TourTarget.phoneField});
      expect(tour.canGoBack, isFalse, reason: 'previous step was a tap');

      tour.next();
      expect(step(), _amount);
      expect(tour.canGoBack, isTrue);
      tour.back();
      expect(step(), _phone);

      tour
        ..next()
        ..next()
        ..next();
      expect(step(), _back);
      expect(tour.canGoBack, isFalse, reason: 'this step is a tap');
    });

    test('leaving the payment form mid-explanation rewinds to the wallet', () {
      const onForm = {
        TourTarget.walletCard,
        TourTarget.homePage,
        TourTarget.phoneField,
        TourTarget.amountField,
      };
      tour.reconcile(mounted: onForm, ready: {TourTarget.phoneField});
      tour.next();
      expect(step(), _amount);

      // The pop is still animating: the form is mounted, nothing changes.
      tour.reconcile(mounted: onForm, ready: {});
      expect(step(), _amount);

      // The form is gone.
      tour.reconcile(
        mounted: {TourTarget.walletCard, TourTarget.homePage},
        ready: {TourTarget.walletCard, TourTarget.homePage},
      );
      expect(step(), _wallet);
    });

    test('back from the form leads on to the PIN notice', () {
      tour.reconcile(mounted: {}, ready: {TourTarget.phoneField});
      tour
        ..next()
        ..next()
        ..next();
      expect(step(), _back);

      tour.reconcile(
        mounted: {TourTarget.homePage, TourTarget.pinNotice},
        ready: {TourTarget.homePage, TourTarget.pinNotice},
      );
      expect(step(), _pin);
    });

    test('a tab tap is noticed by its page showing', () {
      tour.reconcile(mounted: {}, ready: {TourTarget.phoneField});
      tour
        ..next()
        ..next()
        ..next();
      tour.reconcile(mounted: {}, ready: {TourTarget.homePage});
      tour.next();
      expect(step(), _favorites);

      const tabs = {
        TourTarget.homePage,
        TourTarget.favoritesPage,
        TourTarget.historyPage,
      };
      tour.reconcile(mounted: tabs, ready: {TourTarget.homePage});
      expect(step(), _favorites);
      tour.reconcile(mounted: tabs, ready: {TourTarget.favoritesPage});
      expect(step(), _history);
      tour.reconcile(mounted: tabs, ready: {TourTarget.historyPage});
      expect(step(), _settings);
    });

    test('proofs name the outcome of the latest interactive step', () {
      expect(tour.proofFor(_wallet), isNull);
      expect(tour.proofFor(_review), TourTarget.phoneField);
      expect(tour.proofFor(_pin), TourTarget.homePage);
      expect(tour.proofFor(_settings), TourTarget.historyPage);
    });
  });
}
