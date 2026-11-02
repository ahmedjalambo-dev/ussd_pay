import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ussd_pay/services/notification_service.dart';

/// PaymentDecisionEvent equality is what PaymentDecisionListener switches on,
/// so pin down that the same-action same-id events compare equal (drives
/// StreamController.distinct etc. cleanly) and that different actions do not.
void main() {
  group('PaymentDecisionEvent', () {
    test('equal when action and history id match', () {
      const a = PaymentDecisionEvent(
        action: NotificationAction.done,
        historyEntryId: 'abc',
      );
      const b = PaymentDecisionEvent(
        action: NotificationAction.done,
        historyEntryId: 'abc',
      );
      expect(a, equals(b));
      expect(a.hashCode, b.hashCode);
    });

    test('unequal when action differs', () {
      const a = PaymentDecisionEvent(
        action: NotificationAction.done,
        historyEntryId: 'abc',
      );
      const b = PaymentDecisionEvent(
        action: NotificationAction.cancel,
        historyEntryId: 'abc',
      );
      expect(a, isNot(equals(b)));
    });

    test('unequal when history id differs', () {
      const a = PaymentDecisionEvent(
        action: NotificationAction.done,
        historyEntryId: 'abc',
      );
      const b = PaymentDecisionEvent(
        action: NotificationAction.done,
        historyEntryId: 'xyz',
      );
      expect(a, isNot(equals(b)));
    });
  });

  group('flutter_local_notifications binding shape', () {
    // Cheap smoke check that the constants we depend on still exist so a
    // future major-version bump surfaces here rather than at runtime.
    test('categories and action-input constants resolve', () {
      expect(AndroidNotificationCategory.status.name, 'status');
      expect(Importance.high.value, greaterThan(Importance.low.value));
    });
  });
}
