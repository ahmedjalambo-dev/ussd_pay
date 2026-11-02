import '../core/id_generator.dart';
import '../core/json_map.dart';

/// A saved recipient.
///
/// Stores only what is needed to pre-fill a payment. There is deliberately no
/// PIN field: the wallet PIN is entered in the carrier's own USSD prompt and
/// must never be persisted, dialed, or logged.
class Favorite {
  Favorite({
    String? id,
    required this.name,
    required this.number,
    required this.walletId,
    required this.defaultType,
    this.defaultAmount,
  }) : id = id ?? newId();

  final String id;

  final String name;

  /// Normalized local form, `0599123456`.
  final String number;

  final String walletId;

  /// Recipient type key, matching a key in the wallet's `templates`.
  final String defaultType;

  /// Optional pre-filled amount, for a recipient paid the same amount often.
  final num? defaultAmount;

  Favorite copyWith({
    String? name,
    String? number,
    String? walletId,
    String? defaultType,
    num? defaultAmount,
    bool clearDefaultAmount = false,
  }) =>
      Favorite(
        id: id,
        name: name ?? this.name,
        number: number ?? this.number,
        walletId: walletId ?? this.walletId,
        defaultType: defaultType ?? this.defaultType,
        defaultAmount:
            clearDefaultAmount ? null : (defaultAmount ?? this.defaultAmount),
      );

  Map<String, dynamic> toMap() => {
        'id': id,
        'name': name,
        'number': number,
        'walletId': walletId,
        'defaultType': defaultType,
        if (defaultAmount != null) 'defaultAmount': defaultAmount,
      };

  static Favorite? fromMap(Object? raw) {
    final map = asStringMap(raw);
    final id = optString(map, 'id');
    final name = optString(map, 'name');
    final number = optString(map, 'number');
    final walletId = optString(map, 'walletId');
    final defaultType = optString(map, 'defaultType');
    if (id == null ||
        name == null ||
        number == null ||
        walletId == null ||
        defaultType == null) {
      // A record we cannot read is skipped rather than crashing the list.
      return null;
    }
    return Favorite(
      id: id,
      name: name,
      number: number,
      walletId: walletId,
      defaultType: defaultType,
      defaultAmount: optNum(map, 'defaultAmount'),
    );
  }
}
