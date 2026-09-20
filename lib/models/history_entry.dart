import '../core/id_generator.dart';
import '../core/json_map.dart';

/// One dialed payment, recorded at the moment the code was handed to the
/// dialer.
///
/// A history row records what *we* dialed, not whether the carrier accepted it
/// -- the app never sees the outcome of the USSD session. It exists so the user
/// can repeat a payment without retyping, and so they can check what they sent.
///
/// As with `Favorite`, no PIN is stored. [ussdCode] is the exact string handed
/// to the dialer, which by construction contains only the recipient and amount.
class HistoryEntry {
  HistoryEntry({
    String? id,
    required this.dialedAtUtc,
    required this.walletId,
    required this.recipientType,
    required this.recipientNumber,
    required this.amount,
    required this.ussdCode,
    this.recipientName,
    this.note,
  }) : id = id ?? newId();

  final String id;

  /// Stored in UTC; rendered in local time.
  final DateTime dialedAtUtc;

  final String walletId;
  final String recipientType;

  /// Normalized local form, `0599123456`.
  final String recipientNumber;

  final num amount;

  /// The exact code handed to the dialer.
  final String ussdCode;

  final String? recipientName;

  /// Optional free-text label attached at draft time. Null on old rows written
  /// before this field existed, and on rows where the user left the field
  /// blank -- both cases mean "no note".
  final String? note;

  Map<String, dynamic> toMap() => {
        'id': id,
        'dialedAtUtc': dialedAtUtc.toUtc().toIso8601String(),
        'walletId': walletId,
        'recipientType': recipientType,
        'recipientNumber': recipientNumber,
        'amount': amount,
        'ussdCode': ussdCode,
        if (recipientName != null) 'recipientName': recipientName,
        if (note != null) 'note': note,
      };

  static HistoryEntry? fromMap(Object? raw) {
    final map = asStringMap(raw);
    final id = optString(map, 'id');
    final dialedAt = DateTime.tryParse(optString(map, 'dialedAtUtc') ?? '');
    final walletId = optString(map, 'walletId');
    final recipientType = optString(map, 'recipientType');
    final recipientNumber = optString(map, 'recipientNumber');
    final amount = optNum(map, 'amount');
    final ussdCode = optString(map, 'ussdCode');
    if (id == null ||
        dialedAt == null ||
        walletId == null ||
        recipientType == null ||
        recipientNumber == null ||
        amount == null ||
        ussdCode == null) {
      return null;
    }
    return HistoryEntry(
      id: id,
      dialedAtUtc: dialedAt.toUtc(),
      walletId: walletId,
      recipientType: recipientType,
      recipientNumber: recipientNumber,
      amount: amount,
      ussdCode: ussdCode,
      recipientName: optString(map, 'recipientName'),
      note: optString(map, 'note'),
    );
  }
}
