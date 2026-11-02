import 'package:flutter_test/flutter_test.dart';
import 'package:ussd_pay/core/attempts.dart';
import 'package:ussd_pay/models/history_entry.dart';

/// The double-pay guard asks about the latest payment nobody answered. Asking
/// about the wrong one, or missing it, either nags or lets a payment be made
/// twice.
void main() {
  final now = DateTime.utc(2026, 11, 2, 12);

  HistoryEntry row(
    String id, {
    required Duration ago,
    ConfirmationSource? confirmedBy,
    HistoryStatus status = HistoryStatus.cancelled,
    num amount = 5,
    String number = '0599123456',
    String walletId = 'jawwalpay',
  }) => HistoryEntry(
    id: id,
    dialedAtUtc: now.subtract(ago),
    walletId: walletId,
    recipientType: 'friend',
    recipientNumber: number,
    amount: amount,
    ussdCode: '*268*1*$number*$amount#',
    status: status,
    confirmedBy: confirmedBy,
  );

  group('findUnansweredAttempt', () {
    test('picks the latest unanswered row', () {
      final found = findUnansweredAttempt([
        row('old', ago: const Duration(minutes: 10)),
        row('new', ago: const Duration(minutes: 2)),
      ], now);
      expect(found?.id, 'new');
    });

    test('skips rows anyone answered, however they answered', () {
      final found = findUnansweredAttempt([
        for (final source in ConfirmationSource.values)
          row(
            source.name,
            ago: const Duration(minutes: 1),
            confirmedBy: source,
            status: HistoryStatus.done,
          ),
        row('cancelled-by-user',
            ago: const Duration(seconds: 30),
            confirmedBy: ConfirmationSource.user),
      ], now);
      expect(found, isNull);
    });

    test('ignores rows older than the window', () {
      expect(
        findUnansweredAttempt([
          row('stale', ago: unansweredAttemptWindow + const Duration(seconds: 1)),
        ], now),
        isNull,
      );
      expect(
        findUnansweredAttempt([
          row('edge', ago: unansweredAttemptWindow),
        ], now)?.id,
        'edge',
      );
    });

    test('empty history: nothing to ask', () {
      expect(findUnansweredAttempt(const [], now), isNull);
    });
  });

  group('isSamePayment', () {
    final entry = row('a', ago: Duration.zero);

    test('same wallet, number and amount (5 == 5.00)', () {
      expect(
        isSamePayment(entry,
            walletId: 'jawwalpay', recipientNumber: '0599123456', amount: 5.0),
        isTrue,
      );
    });

    test('any difference is a different payment', () {
      expect(
        isSamePayment(entry,
            walletId: 'palpay', recipientNumber: '0599123456', amount: 5),
        isFalse,
      );
      expect(
        isSamePayment(entry,
            walletId: 'jawwalpay', recipientNumber: '0599000000', amount: 5),
        isFalse,
      );
      expect(
        isSamePayment(entry,
            walletId: 'jawwalpay', recipientNumber: '0599123456', amount: 5.5),
        isFalse,
      );
    });
  });
}
