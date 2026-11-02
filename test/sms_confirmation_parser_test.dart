import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:ussd_pay/models/wallet.dart';
import 'package:ussd_pay/services/sms_confirmation_parser.dart';
import 'package:ussd_pay/services/wallet_repository.dart';

/// Runs the real SMS texts the carriers send against the patterns shipped in
/// assets/wallets.json. A receive SMS that matched would let incoming money
/// confirm an outgoing payment, so those cases matter as much as the sends.
void main() {
  late SmsConfirmationConfig jawwal;
  late SmsConfirmationConfig palpay;

  setUpAll(() {
    final config = WalletRepository.parse(
      File(WalletRepository.assetPath).readAsStringSync(),
    );
    jawwal = config.byId('jawwalpay')!.smsConfirmation!;
    palpay = config.byId('palpay')!.smsConfirmation!;
  });

  const jawwalSent = 'تم تحويل ILS 5.00 الى 00970597501462 رصيدك الحالي ILS 21.00';
  const jawwalReceived =
      'استلمت مبلغ ILS 100.00 من 00970599806812 رصيدك الحالي ILS 108.00';
  const palpaySent =
      'حركة دفع لصديق ل 0567061597 بمبلغ 5.00 شيكل رصيدك الحالي: 15.50 شيكل';
  const palpayReceived =
      'حركة دفع لصديق من 0568313999 بمبلغ 10.00 شيكل رصيدك الحالي: 57.50 شيكل';

  group('parse', () {
    test('JawwalPay sent: amount, and the 00970 number normalized', () {
      final result = SmsConfirmationParser.parse(jawwal, jawwalSent)!;
      expect(result.amountCents, 500);
      expect(result.recipientNumber, '0597501462');
    });

    test('PalPay sent: amount and number', () {
      final result = SmsConfirmationParser.parse(palpay, palpaySent)!;
      expect(result.amountCents, 500);
      expect(result.recipientNumber, '0567061597');
    });

    test('receive messages never parse', () {
      expect(SmsConfirmationParser.parse(jawwal, jawwalReceived), isNull);
      expect(SmsConfirmationParser.parse(palpay, palpayReceived), isNull);
    });

    test("one wallet's SMS does not parse as the other's", () {
      expect(SmsConfirmationParser.parse(jawwal, palpaySent), isNull);
      expect(SmsConfirmationParser.parse(palpay, jawwalSent), isNull);
    });

    test('a recipient shown by name carries no number', () {
      final result = SmsConfirmationParser.parse(
        jawwal,
        'تم تحويل ILS 12.50 الى أحمد محمد رصيدك الحالي ILS 8.50',
      )!;
      expect(result.amountCents, 1250);
      expect(result.recipientNumber, isNull);
    });

    test('Arabic-Indic digits, bidi marks and extra spaces are tolerated', () {
      final result = SmsConfirmationParser.parse(
        palpay,
        'حركة دفع  لصديق ل ‏٠٥٦٧٠٦١٥٩٧‏ بمبلغ ٥.٠٠ شيكل\nرصيدك',
      )!;
      expect(result.amountCents, 500);
      expect(result.recipientNumber, '0567061597');
    });

    test('"إلى" with hamza is accepted as well as "الى"', () {
      final result = SmsConfirmationParser.parse(
        jawwal,
        'تم تحويل ILS 5.00 إلى 0597501462 رصيدك الحالي ILS 21.00',
      );
      expect(result?.amountCents, 500);
    });

    test('unrelated text does not parse', () {
      expect(SmsConfirmationParser.parse(jawwal, 'رمز التحقق 1234'), isNull);
    });
  });

  group('toCents', () {
    test('handles whole, one- and two-decimal and grouped amounts', () {
      expect(SmsConfirmationParser.toCents('5'), 500);
      expect(SmsConfirmationParser.toCents('5.5'), 550);
      expect(SmsConfirmationParser.toCents('5.05'), 505);
      expect(SmsConfirmationParser.toCents('1,000.00'), 100000);
      expect(SmsConfirmationParser.toCents('5.000'), 500);
    });

    test('refuses what it cannot compare exactly', () {
      expect(SmsConfirmationParser.toCents('5.005'), isNull);
      expect(SmsConfirmationParser.toCents('5.'), isNull);
      expect(SmsConfirmationParser.toCents('.5'), isNull);
      expect(SmsConfirmationParser.toCents(''), isNull);
    });

    test('dialed amounts convert to the same cents', () {
      expect(SmsConfirmationParser.amountToCents(5), 500);
      expect(SmsConfirmationParser.amountToCents(12.5), 1250);
      expect(SmsConfirmationParser.amountToCents(0.1), 10);
    });
  });

  group('matches', () {
    final dialedAt = DateTime.utc(2026, 10, 20, 12);
    final pending = PendingConfirmation(
      historyEntryId: 'h1',
      walletId: 'jawwalpay',
      amountCents: 500,
      recipientNumber: '0597501462',
      startedAtUtc: dialedAt,
    );
    final later = dialedAt.add(const Duration(seconds: 40));

    test('same amount and number inside the window', () {
      final sms = SmsConfirmationParser.parse(jawwal, jawwalSent)!;
      expect(SmsConfirmationParser.matches(pending, sms, later), isTrue);
    });

    test('name instead of number: wallet and amount are enough', () {
      const sms = SmsParseResult(amountCents: 500);
      expect(SmsConfirmationParser.matches(pending, sms, later), isTrue);
    });

    test('a different number is a different transfer', () {
      const sms = SmsParseResult(
        amountCents: 500,
        recipientNumber: '0599000000',
      );
      expect(SmsConfirmationParser.matches(pending, sms, later), isFalse);
    });

    test('a different amount does not match', () {
      const sms = SmsParseResult(
        amountCents: 550,
        recipientNumber: '0597501462',
      );
      expect(SmsConfirmationParser.matches(pending, sms, later), isFalse);
    });

    test('only inside the 5-minute window after dialing', () {
      const sms = SmsParseResult(amountCents: 500);
      expect(
        SmsConfirmationParser.matches(
          pending,
          sms,
          dialedAt.add(const Duration(minutes: 5)),
        ),
        isTrue,
      );
      expect(
        SmsConfirmationParser.matches(
          pending,
          sms,
          dialedAt.add(const Duration(minutes: 5, seconds: 1)),
        ),
        isFalse,
      );
      // An SMS from before the payment was dialed cannot be about it.
      expect(
        SmsConfirmationParser.matches(
          pending,
          sms,
          dialedAt.subtract(const Duration(seconds: 1)),
        ),
        isFalse,
      );
    });
  });

  test('sender names compare without case or spacing', () {
    expect(jawwal.isSender('Jawwal Pay'), isTrue);
    expect(jawwal.isSender('JAWWALPAY'), isTrue);
    expect(palpay.isSender('PALPAY'), isTrue);
    expect(palpay.isSender('Pal Pay'), isTrue);
    expect(jawwal.isSender('PALPAY'), isFalse);
    expect(jawwal.isSender('Mum'), isFalse);
  });
}
