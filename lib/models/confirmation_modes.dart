import 'package:flutter/foundation.dart';

/// How one wallet's payments get their Done/Cancel status after dialing.
///
/// At least one mode is always on: with neither, a payment would have no way
/// to leave the Cancelled tab.
@immutable
class ConfirmationModes {
  const ConfirmationModes({this.sms = false, this.manual = true})
    : assert(sms || manual, 'at least one confirmation mode must be on');

  /// Today's behaviour: ask the user with the Done/Cancel prompt.
  static const ConfirmationModes defaults = ConfirmationModes();

  /// Mark the payment done when the wallet's "money sent" SMS arrives.
  final bool sms;

  /// Show the Done/Cancel prompt -- at once, or as the fallback when no SMS
  /// arrives in time.
  final bool manual;

  /// Applies a toggle, refusing the one that would turn the last mode off.
  ConfirmationModes copyWith({bool? sms, bool? manual}) {
    final next = (sms: sms ?? this.sms, manual: manual ?? this.manual);
    if (!next.sms && !next.manual) return this;
    return ConfirmationModes(sms: next.sms, manual: next.manual);
  }

  Map<String, bool> toMap() => {'sms': sms, 'manual': manual};

  /// Unreadable or impossible rows fall back to [defaults]: never leave a
  /// wallet with no way to record a payment.
  static ConfirmationModes fromMap(Object? raw) {
    if (raw is! Map) return defaults;
    final sms = raw['sms'] == true;
    final manual = raw['manual'] is bool ? raw['manual'] as bool : true;
    if (!sms && !manual) return defaults;
    return ConfirmationModes(sms: sms, manual: manual);
  }

  @override
  bool operator ==(Object other) =>
      other is ConfirmationModes && other.sms == sms && other.manual == manual;

  @override
  int get hashCode => Object.hash(sms, manual);
}
