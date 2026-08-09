import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:ussd_pay/models/recipient_type.dart';
import 'package:ussd_pay/models/wallet.dart';
import 'package:ussd_pay/services/phone_normalizer.dart';
import 'package:ussd_pay/services/ussd_service.dart';
import 'package:ussd_pay/services/wallet_repository.dart';

void main() {
  // Reads the real shipped asset, not a fixture. A typo in a carrier code is a
  // money bug, and this is the only place it can be caught before a user hits
  // it.
  late WalletConfig config;

  setUpAll(() {
    final file = File(WalletRepository.assetPath);
    expect(file.existsSync(), isTrue,
        reason: '${WalletRepository.assetPath} must ship with the app');
    config = WalletRepository.parse(file.readAsStringSync());
  });

  group('shipped assets/wallets.json', () {
    test('declares the wallets the app is built around', () {
      expect(config.wallets.map((w) => w.id), containsAll(['jawwalpay', 'palpay']));
    });

    test('wallet ids are unique', () {
      final ids = config.wallets.map((w) => w.id).toList();
      expect(ids.toSet().length, ids.length);
    });

    test('every wallet has Arabic and English names', () {
      for (final wallet in config.wallets) {
        expect(wallet.names['ar'], isNotNull, reason: wallet.id);
        expect(wallet.names['en'], isNotNull, reason: wallet.id);
        expect(wallet.nameFor('ar'), isNotEmpty);
        expect(wallet.nameFor('en'), isNotEmpty);
      }
    });

    test('nameFor falls back instead of throwing on a missing locale', () {
      expect(config.wallets.first.nameFor('fr'), isNotEmpty);
    });

    test('every wallet supports friend and merchant', () {
      for (final wallet in config.wallets) {
        expect(wallet.recipientTypes, containsAll(RecipientTypes.known),
            reason: wallet.id);
      }
    });
  });

  group('every shipped template', () {
    test('is a well-formed USSD command', () {
      for (final wallet in config.wallets) {
        wallet.templates.forEach((type, template) {
          final where = '${wallet.id}/$type';
          expect(template.startsWith('*'), isTrue, reason: '$where: "$template"');
          expect(template.endsWith('#'), isTrue, reason: '$where: "$template"');
          expect(template.contains('**'), isFalse,
              reason: '$where has an empty field: "$template"');
          expect(template.substring(0, template.length - 1).contains('#'), isFalse,
              reason: '$where has a "#" before the end: "$template"');
        });
      }
    });

    test('uses exactly the placeholders {phone} and {amount}', () {
      // Guards the PIN invariant from the other direction: if anyone ever adds
      // a {pin} placeholder to the config, this fails.
      for (final wallet in config.wallets) {
        wallet.templates.forEach((type, template) {
          expect(
            UssdService.placeholdersIn(template),
            {'phone', 'amount'},
            reason: '${wallet.id}/$type: "$template"',
          );
        });
      }
    });

    test('mentions no PIN anywhere', () {
      for (final wallet in config.wallets) {
        wallet.templates.forEach((type, template) {
          expect(template.toLowerCase(), isNot(contains('pin')),
              reason: '${wallet.id}/$type');
        });
      }
    });

    test('builds a dialable code end to end', () {
      final phone = PhoneNormalizer.normalize('+970 599-123456');
      expect(phone.isValid, isTrue);

      for (final wallet in config.wallets) {
        for (final type in wallet.recipientTypes) {
          final code = UssdService.buildForWallet(
            wallet: wallet,
            recipientType: type,
            localPhone: phone.local,
            amount: 50,
          );
          expect(code, contains('0599123456'), reason: '${wallet.id}/$type');
          expect(code, contains('50'));
          expect(code.endsWith('#'), isTrue);
          expect(UssdService.placeholdersIn(code), isEmpty);
        }
      }
    });
  });

  group('the exact codes the user approved in the spec', () {
    final phone = PhoneNormalizer.normalize('0599123456').local;

    const expected = <String, String>{
      'jawwalpay/friend': '*268*1*0599123456*50#',
      'jawwalpay/merchant': '*268*2*0599123456*50#',
      'palpay/friend': '*370*1*1*0599123456*50#',
      'palpay/merchant': '*370*2*1*0599123456*50#',
    };

    expected.forEach((key, code) {
      test(key, () {
        final parts = key.split('/');
        final wallet = config.byId(parts[0]);
        expect(wallet, isNotNull);
        expect(
          UssdService.buildForWallet(
            wallet: wallet!,
            recipientType: parts[1],
            localPhone: phone,
            amount: 50,
          ),
          code,
        );
      });
    });
  });

  group('malformed config is rejected, not silently accepted', () {
    test('not JSON', () {
      expect(() => WalletRepository.parse('nonsense'),
          throwsA(isA<WalletConfigException>()));
    });

    test('no wallets array', () {
      expect(() => WalletRepository.parse('{"schemaVersion":1}'),
          throwsA(isA<WalletConfigException>()));
    });

    test('empty wallets array', () {
      expect(() => WalletRepository.parse('{"wallets":[]}'),
          throwsA(isA<WalletConfigException>()));
    });

    test('wallet without an id', () {
      expect(
        () => WalletRepository.parse(
            '{"wallets":[{"name":{"en":"X"},"templates":{"friend":"*1#"}}]}'),
        throwsA(isA<WalletConfigException>()),
      );
    });

    test('wallet without templates', () {
      expect(
        () => WalletRepository.parse('{"wallets":[{"id":"x","name":{"en":"X"}}]}'),
        throwsA(isA<WalletConfigException>()),
      );
    });

    test('duplicate wallet ids', () {
      expect(
        () => WalletRepository.parse('{"wallets":['
            '{"id":"x","name":{"en":"X"},"templates":{"friend":"*1#"}},'
            '{"id":"x","name":{"en":"Y"},"templates":{"friend":"*2#"}}]}'),
        throwsA(isA<WalletConfigException>()),
      );
    });

    test('a bad colour is tolerated -- it is cosmetic, not a money bug', () {
      final parsed = WalletRepository.parse('{"wallets":[{"id":"x",'
          '"name":{"en":"X"},"colorHex":"not-a-colour",'
          '"templates":{"friend":"*1*{phone}*{amount}#"}}]}');
      expect(parsed.wallets.single.colorValue, isNonZero);
    });
  });

  test('a new wallet can be added by editing JSON alone', () {
    // The whole point of the config file: no Dart change to support a new
    // wallet, including one with a third recipient type.
    final parsed = WalletRepository.parse('''
      {
        "schemaVersion": 1,
        "wallets": [{
          "id": "newbank",
          "name": {"ar": "بنك جديد", "en": "New Bank"},
          "colorHex": "#123456",
          "templates": {
            "friend": "*999*1*{phone}*{amount}#",
            "merchant": "*999*2*{phone}*{amount}#",
            "bill": "*999*3*{phone}*{amount}#"
          }
        }]
      }
    ''');

    final wallet = parsed.wallets.single;
    expect(wallet.recipientTypes, ['friend', 'merchant', 'bill']);
    expect(wallet.colorValue, 0xFF123456);
    expect(
      UssdService.buildForWallet(
        wallet: wallet,
        recipientType: 'bill',
        localPhone: '0599123456',
        amount: 75,
      ),
      '*999*3*0599123456*75#',
    );
  });
}
