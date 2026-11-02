import 'package:flutter_test/flutter_test.dart';
import 'package:ussd_pay/models/confirmation_modes.dart';

/// With neither mode on, a payment could never leave the Cancelled tab, so
/// every path into ConfirmationModes must keep at least one on.
void main() {
  test('defaults to asking, as before SMS confirmation existed', () {
    expect(ConfirmationModes.defaults.manual, isTrue);
    expect(ConfirmationModes.defaults.sms, isFalse);
  });

  test('copyWith refuses to turn the last mode off', () {
    const smsOnly = ConfirmationModes(sms: true, manual: false);
    expect(smsOnly.copyWith(sms: false), smsOnly);
    expect(ConfirmationModes.defaults.copyWith(manual: false),
        ConfirmationModes.defaults);
  });

  test('copyWith allows any combination with one mode on', () {
    const both = ConfirmationModes(sms: true, manual: true);
    expect(ConfirmationModes.defaults.copyWith(sms: true), both);
    expect(both.copyWith(manual: false),
        const ConfirmationModes(sms: true, manual: false));
  });

  test('round-trips through toMap / fromMap', () {
    for (final modes in const [
      ConfirmationModes(),
      ConfirmationModes(sms: true, manual: true),
      ConfirmationModes(sms: true, manual: false),
    ]) {
      expect(ConfirmationModes.fromMap(modes.toMap()), modes);
    }
  });

  test('unreadable or impossible rows fall back to the defaults', () {
    expect(ConfirmationModes.fromMap(null), ConfirmationModes.defaults);
    expect(ConfirmationModes.fromMap('sms'), ConfirmationModes.defaults);
    expect(ConfirmationModes.fromMap({'sms': false, 'manual': false}),
        ConfirmationModes.defaults);
  });
}
