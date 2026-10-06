import '../core/id_generator.dart';
import '../core/json_map.dart';

/// What the user said happened to a payment after the hand-off.
///
/// This is the user's own answer (notification Done/Cancel, or the in-app
/// Done button), never a carrier result -- the app cannot see the USSD
/// session.
enum HistoryStatus { done, cancelled }

/// One dialed payment, recorded at the moment the code was handed to the
/// dialer.
///
/// A history row records what *we* dialed, not whether the carrier accepted it
/// -- the app never sees the outcome of the USSD session. It exists so the user
/// can repeat a payment without retyping, and so they can check what they sent.
///
/// [status] starts as [HistoryStatus.cancelled] and becomes
/// [HistoryStatus.done] only on an explicit answer: a payment nobody vouched
/// for must not be listed as sent.
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
    this.status = HistoryStatus.cancelled,
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

  final HistoryStatus status;

  HistoryEntry copyWith({HistoryStatus? status}) => HistoryEntry(
        id: id,
        dialedAtUtc: dialedAtUtc,
        walletId: walletId,
        recipientType: recipientType,
        recipientNumber: recipientNumber,
        amount: amount,
        ussdCode: ussdCode,
        recipientName: recipientName,
        note: note,
        status: status ?? this.status,
      );

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
        'status': status.name,
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
      status: _statusFrom(
        optString(map, 'status'),
        hasKey: map.containsKey('status'),
      ),
    );
  }

  /// A missing key means the row predates statuses. Back then Cancel deleted
  /// the row outright, so every surviving old row was not cancelled -> done.
  /// An unrecognised value falls to cancelled: never claim a payment went
  /// through on data we cannot read.
  static HistoryStatus _statusFrom(String? raw, {required bool hasKey}) {
    if (!hasKey) return HistoryStatus.done;
    return HistoryStatus.values.where((s) => s.name == raw).firstOrNull ??
        HistoryStatus.cancelled;
  }
}
