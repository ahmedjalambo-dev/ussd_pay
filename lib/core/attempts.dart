import '../models/history_entry.dart';

/// How far back an unanswered attempt is still worth asking about. Older than
/// this, the user has long moved on, and asking would only nag.
const Duration unansweredAttemptWindow = Duration(minutes: 30);

/// The most recent payment that was handed off but never answered, if it is
/// recent enough to matter.
///
/// "Answered" is read from [HistoryEntry.confirmedBy]: every way of answering
/// -- the notification, the in-app Done button, the double-pay dialog, the
/// wallet's SMS -- sets it. A row without it is one nobody vouched for.
///
/// Read from history rather than kept in memory, so the question still comes
/// up after the app has been killed and restarted.
HistoryEntry? findUnansweredAttempt(
  List<HistoryEntry> history,
  DateTime nowUtc,
) {
  HistoryEntry? latest;
  for (final entry in history) {
    if (entry.confirmedBy != null) continue;
    final age = nowUtc.difference(entry.dialedAtUtc);
    if (age.isNegative || age > unansweredAttemptWindow) continue;
    if (latest == null || entry.dialedAtUtc.isAfter(latest.dialedAtUtc)) {
      latest = entry;
    }
  }
  return latest;
}

/// Whether [entry] is the same payment as the one about to be dialed: same
/// wallet, same recipient, same amount. Dialing it again after it went
/// through would pay twice.
///
/// Amounts compare as cents, so `5` and `5.00` are the same payment.
bool isSamePayment(
  HistoryEntry entry, {
  required String walletId,
  required String recipientNumber,
  required num amount,
}) =>
    entry.walletId == walletId &&
    entry.recipientNumber == recipientNumber &&
    (entry.amount * 100).round() == (amount * 100).round();
