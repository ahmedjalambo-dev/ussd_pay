import 'package:fake_async/fake_async.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ussd_pay/services/decision_alert_scheduler.dart';

/// The banner exists to stay off the carrier's USSD screen: it must only fire
/// after the user has been away for the full delay, and only once.
void main() {
  const delay = DecisionAlertScheduler.awayDelay;
  final almost = delay - const Duration(milliseconds: 1);

  test('armed while away: alerts after the full delay, once', () {
    fakeAsync((async) {
      final scheduler = DecisionAlertScheduler();
      var alerts = 0;
      scheduler.arm(
        entryId: 'a',
        inBackground: true,
        alert: () async => alerts++,
      );

      async.elapse(almost);
      expect(alerts, 0);
      async.elapse(const Duration(milliseconds: 1));
      expect(alerts, 1);
      expect(scheduler.armedEntryId, isNull);

      // Leaving and coming back again does not re-raise it.
      scheduler
        ..appResumed()
        ..appBackgrounded();
      async.elapse(delay * 2);
      expect(alerts, 1);
    });
  });

  test('armed in the app (copy code): waits until the user leaves', () {
    fakeAsync((async) {
      final scheduler = DecisionAlertScheduler();
      var alerts = 0;
      scheduler.arm(
        entryId: 'a',
        inBackground: false,
        alert: () async => alerts++,
      );

      async.elapse(const Duration(minutes: 1));
      expect(alerts, 0);

      scheduler.appBackgrounded();
      async.elapse(delay);
      expect(alerts, 1);
    });
  });

  test('coming back early cancels; leaving again restarts the full delay', () {
    fakeAsync((async) {
      final scheduler = DecisionAlertScheduler();
      var alerts = 0;
      scheduler.arm(
        entryId: 'a',
        inBackground: true,
        alert: () async => alerts++,
      );

      async.elapse(const Duration(seconds: 3));
      scheduler.appResumed();
      async.elapse(const Duration(seconds: 10));
      expect(alerts, 0, reason: 'the user is in the app');

      scheduler.appBackgrounded();
      async.elapse(almost);
      expect(alerts, 0, reason: 'the countdown starts over');
      async.elapse(const Duration(milliseconds: 1));
      expect(alerts, 1);
    });
  });

  test('cancel disarms; cancel for another row does not', () {
    fakeAsync((async) {
      final scheduler = DecisionAlertScheduler();
      var alerts = 0;
      scheduler.arm(
        entryId: 'a',
        inBackground: true,
        alert: () async => alerts++,
      );

      scheduler.cancel('older-row');
      expect(scheduler.armedEntryId, 'a');

      scheduler.cancel('a');
      async.elapse(delay * 2);
      expect(alerts, 0);
      expect(scheduler.armedEntryId, isNull);
    });
  });

  test('a new arm replaces the old one', () {
    fakeAsync((async) {
      final scheduler = DecisionAlertScheduler();
      final alerted = <String>[];
      scheduler.arm(
        entryId: 'a',
        inBackground: true,
        alert: () async => alerted.add('a'),
      );
      async.elapse(const Duration(seconds: 5));
      scheduler.arm(
        entryId: 'b',
        inBackground: true,
        alert: () async => alerted.add('b'),
      );

      async.elapse(delay);
      expect(alerted, ['b']);
    });
  });
}
