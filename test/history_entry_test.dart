import 'package:flutter_test/flutter_test.dart';
import 'package:ussd_pay/models/history_entry.dart';

/// The status decides which History tab a payment lands in. The defaults are
/// the part that matters: an unanswered payment must never be shown as sent.
void main() {
  HistoryEntry entry({HistoryStatus? status}) {
    final base = HistoryEntry(
      id: 'abc',
      dialedAtUtc: DateTime.utc(2026, 10, 6, 12),
      walletId: 'jawwal_pay',
      recipientType: 'friend',
      recipientNumber: '0599123456',
      amount: 25,
      ussdCode: '*322*0599123456*25#',
    );
    return status == null ? base : base.copyWith(status: status);
  }

  test('a new entry starts as cancelled until the user answers', () {
    expect(entry().status, HistoryStatus.cancelled);
  });

  test('status round-trips through toMap / fromMap', () {
    for (final status in HistoryStatus.values) {
      final restored = HistoryEntry.fromMap(entry(status: status).toMap());
      expect(restored?.status, status);
      expect(restored?.id, 'abc');
    }
  });

  test('rows written before statuses existed read back as done', () {
    // Back then Cancel deleted the row, so any surviving row was not
    // cancelled.
    final map = entry().toMap()..remove('status');
    expect(HistoryEntry.fromMap(map)?.status, HistoryStatus.done);
  });

  test('an unrecognised status reads back as cancelled', () {
    final map = entry().toMap()..['status'] = 'pending';
    expect(HistoryEntry.fromMap(map)?.status, HistoryStatus.cancelled);
  });

  test('copyWith changes only the status', () {
    final done = entry().copyWith(status: HistoryStatus.done);
    expect(done.status, HistoryStatus.done);
    expect(done.toMap()..remove('status'), entry().toMap()..remove('status'));
  });

  group('confirmedBy', () {
    test('round-trips through toMap / fromMap', () {
      for (final source in ConfirmationSource.values) {
        final row = entry().copyWith(
          status: HistoryStatus.done,
          confirmedBy: source,
        );
        expect(HistoryEntry.fromMap(row.toMap())?.confirmedBy, source);
      }
    });

    test('absent on rows nobody has answered, and on old rows', () {
      expect(entry().confirmedBy, isNull);
      expect(entry().toMap().containsKey('confirmedBy'), isFalse);
      expect(HistoryEntry.fromMap(entry().toMap())?.confirmedBy, isNull);
    });

    test('an unrecognised value is not read as SMS-confirmed', () {
      final map = entry().toMap()..['confirmedBy'] = 'carrier';
      expect(HistoryEntry.fromMap(map)?.confirmedBy, isNull);
    });
  });
}
