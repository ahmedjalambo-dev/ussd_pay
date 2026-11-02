import 'package:flutter_test/flutter_test.dart';
import 'package:ussd_pay/models/wallet.dart';
import 'package:ussd_pay/services/ussd_service.dart';

Wallet _wallet(Map<String, String> templates, {String id = 'test'}) => Wallet(
      id: id,
      names: const {'en': 'Test'},
      colorValue: 0xFF000000,
      templates: templates,
    );

void main() {
  group('build produces the exact dialed string', () {
    test('JawwalPay to a friend', () {
      expect(
        UssdService.build(
          template: '*268*1*{phone}*{amount}#',
          values: {'phone': '0599123456', 'amount': '50'},
        ),
        '*268*1*0599123456*50#',
      );
    });

    test('JawwalPay to a merchant', () {
      expect(
        UssdService.build(
          template: '*268*2*{phone}*{amount}#',
          values: {'phone': '0599123456', 'amount': '50'},
        ),
        '*268*2*0599123456*50#',
      );
    });

    test('PalPay to a friend', () {
      expect(
        UssdService.build(
          template: '*370*1*1*{phone}*{amount}#',
          values: {'phone': '0599123456', 'amount': '50'},
        ),
        '*370*1*1*0599123456*50#',
      );
    });

    test('PalPay to a merchant', () {
      expect(
        UssdService.build(
          template: '*370*2*{phone}*{amount}#',
          values: {'phone': '0599123456', 'amount': '50'},
        ),
        '*370*2*0599123456*50#',
      );
    });

    test('a placeholder repeated in one template is substituted everywhere', () {
      expect(
        UssdService.build(
          template: '*1*{phone}*{phone}#',
          values: {'phone': '0599123456'},
        ),
        '*1*0599123456*0599123456#',
      );
    });

    test('extra values that the template does not use are ignored', () {
      expect(
        UssdService.build(
          template: '*1*{phone}#',
          values: {'phone': '0599123456', 'amount': '50'},
        ),
        '*1*0599123456#',
      );
    });
  });

  group('injection guard', () {
    // This is the guard that matters most. A "*" in a user-controlled field
    // restructures the command into a different transaction entirely.
    const dangerous = <String, String>{
      'asterisk restructures the command': '50*2*0599999999',
      'hash terminates the command early': '50#',
      'leading plus': '+50',
      'embedded space': '5 0',
      'letters': '50abc',
      'Arabic-Indic digits reaching the builder unfolded': '٥٠',
      'empty string': '',
      'lone decimal point': '.',
      'two decimal points': '5.0.0',
      'negative sign': '-50',
      'newline': '50\n',
    };

    dangerous.forEach((description, value) {
      test('amount rejected: $description', () {
        expect(
          () => UssdService.build(
            template: '*268*1*{phone}*{amount}#',
            values: {'phone': '0599123456', 'amount': value},
          ),
          throwsA(isA<UssdBuildException>()),
        );
      });

      test('phone rejected: $description', () {
        expect(
          () => UssdService.build(
            template: '*268*1*{phone}*{amount}#',
            values: {'phone': value, 'amount': '50'},
          ),
          throwsA(isA<UssdBuildException>()),
        );
      });
    });

    test('the concrete attack does not produce a valid-looking code', () {
      // If this ever stops throwing, an attacker-supplied amount would send
      // money to 0599999999 instead of the confirmed recipient.
      expect(
        () => UssdService.build(
          template: '*268*1*{phone}*{amount}#',
          values: {'phone': '0599123456', 'amount': '1*0599999999*500'},
        ),
        throwsA(isA<UssdBuildException>()),
      );
    });
  });

  group('placeholder integrity', () {
    test('a missing value throws rather than dialing a literal placeholder', () {
      expect(
        () => UssdService.build(
          template: '*268*1*{phone}*{amount}#',
          values: {'phone': '0599123456'},
        ),
        throwsA(isA<UssdBuildException>()),
      );
    });

    test('an empty template throws', () {
      expect(
        () => UssdService.build(template: '', values: {}),
        throwsA(isA<UssdBuildException>()),
      );
    });

    test('placeholdersIn finds every placeholder', () {
      expect(
        UssdService.placeholdersIn('*268*1*{phone}*{amount}#'),
        {'phone', 'amount'},
      );
      expect(UssdService.placeholdersIn('*123#'), isEmpty);
    });
  });

  group('formatAmount', () {
    test('whole amounts drop their decimals', () {
      expect(UssdService.formatAmount(50), '50');
      expect(UssdService.formatAmount(50.0), '50');
      expect(UssdService.formatAmount(1000), '1000');
      expect(UssdService.formatAmount(1), '1');
    });

    test('fractional amounts keep exactly two decimals', () {
      expect(UssdService.formatAmount(50.5), '50.50');
      expect(UssdService.formatAmount(0.25), '0.25');
      expect(UssdService.formatAmount(12.345), '12.35');
    });

    test('never emits a thousands separator', () {
      expect(UssdService.formatAmount(1234567), '1234567');
      expect(UssdService.formatAmount(1234567).contains(','), isFalse);
    });

    test('rejects zero and negatives', () {
      expect(() => UssdService.formatAmount(0), throwsA(isA<UssdBuildException>()));
      expect(() => UssdService.formatAmount(-5), throwsA(isA<UssdBuildException>()));
    });

    test('rejects NaN and infinity', () {
      expect(() => UssdService.formatAmount(double.nan),
          throwsA(isA<UssdBuildException>()));
      expect(() => UssdService.formatAmount(double.infinity),
          throwsA(isA<UssdBuildException>()));
    });

    test('formatted output always survives the injection guard', () {
      for (final amount in <num>[1, 50, 50.5, 0.25, 1234567, 12.345]) {
        expect(
          UssdService.build(
            template: '*1*{amount}#',
            values: {'amount': UssdService.formatAmount(amount)},
          ),
          '*1*${UssdService.formatAmount(amount)}#',
        );
      }
    });
  });

  group('buildForWallet', () {
    final wallet = _wallet({
      'friend': '*268*1*{phone}*{amount}#',
      'merchant': '*268*2*{phone}*{amount}#',
    });

    test('resolves the template for the recipient type', () {
      expect(
        UssdService.buildForWallet(
          wallet: wallet,
          recipientType: 'friend',
          localPhone: '0599123456',
          amount: 50,
        ),
        '*268*1*0599123456*50#',
      );
      expect(
        UssdService.buildForWallet(
          wallet: wallet,
          recipientType: 'merchant',
          localPhone: '0569123456',
          amount: 20,
        ),
        '*268*2*0569123456*20#',
      );
    });

    test('an unknown recipient type throws', () {
      expect(
        () => UssdService.buildForWallet(
          wallet: wallet,
          recipientType: 'nonexistent',
          localPhone: '0599123456',
          amount: 50,
        ),
        throwsA(isA<UssdBuildException>()),
      );
    });

    test('a fractional amount reaches the code with two decimals', () {
      expect(
        UssdService.buildForWallet(
          wallet: wallet,
          recipientType: 'friend',
          localPhone: '0599123456',
          amount: 10.5,
        ),
        '*268*1*0599123456*10.50#',
      );
    });
  });
}
