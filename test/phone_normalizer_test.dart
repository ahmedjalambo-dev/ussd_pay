import 'package:flutter_test/flutter_test.dart';
import 'package:ussd_pay/services/phone_normalizer.dart';

/// Invisible characters are built from code points rather than written as
/// literals: as literals they cannot be reviewed in a diff, and the analyzer
/// rejects them for exactly that reason.
String _ch(int codePoint) => String.fromCharCode(codePoint);

const int _nbsp = 0x00A0;
const int _lrm = 0x200E;
const int _rlm = 0x200F;

void main() {
  group('normalize -> canonical local form', () {
    // Every form a user might type, paste, or pull from a contact must collapse
    // to exactly one string. A bug here sends money to the wrong number.
    const expectedLocal = '0599123456';
    const expectedNational = '599123456';

    final inputs = <String, String>{
      'already local': '0599123456',
      'bare national': '599123456',
      'plus 970': '+970599123456',
      '00970': '00970599123456',
      'bare 970': '970599123456',
      'plus 972': '+972599123456',
      '00972': '00972599123456',
      'bare 972': '972599123456',
      'plus 970 with redundant trunk zero': '+9700599123456',
      '00970 with redundant trunk zero': '009700599123456',
      'spaces': '059 912 3456',
      'dashes': '059-912-3456',
      'brackets and dash': '(059) 912-3456',
      'dots': '059.912.3456',
      'mixed separators with country code': '+970 59-912 3456',
      'leading and trailing whitespace': '  0599123456  ',
      'non-breaking spaces': '059${_ch(_nbsp)}912${_ch(_nbsp)}3456',
    };

    inputs.forEach((description, raw) {
      test(description, () {
        final result = PhoneNormalizer.normalize(raw);
        expect(result.local, expectedLocal, reason: 'input was "$raw"');
        expect(result.national, expectedNational);
        expect(result.carrier, Carrier.jawwal);
        expect(result.issue, isNull);
        expect(result.isValid, isTrue);
      });
    });
  });

  group('digit folding', () {
    test('Arabic-Indic digits', () {
      expect(PhoneNormalizer.normalize('٠٥٩٩١٢٣٤٥٦').local, '0599123456');
    });

    test('Extended Arabic-Indic digits', () {
      expect(PhoneNormalizer.normalize('۰۵۹۹۱۲۳۴۵۶').local, '0599123456');
    });

    test('Arabic-Indic digits behind a country code', () {
      expect(PhoneNormalizer.normalize('+٩٧٠٥٩٩١٢٣٤٥٦').local, '0599123456');
    });

    test('mixed ASCII and Arabic-Indic digits', () {
      expect(PhoneNormalizer.normalize('059٩١٢٣٤٥٦').local, '0599123456');
    });

    test('foldDigits covers both Unicode blocks by code point', () {
      final arabicIndic = String.fromCharCodes(
        List<int>.generate(10, (i) => 0x0660 + i),
      );
      final extended = String.fromCharCodes(
        List<int>.generate(10, (i) => 0x06F0 + i),
      );
      expect(PhoneNormalizer.foldDigits(arabicIndic), '0123456789');
      expect(PhoneNormalizer.foldDigits(extended), '0123456789');
    });

    test('foldDigits leaves non-digits untouched', () {
      expect(PhoneNormalizer.foldDigits('+abc-٥'), '+abc-5');
    });
  });

  group('bidirectional control marks are stripped', () {
    // Numbers copied out of Arabic text routinely arrive wrapped in these.
    const marks = <String, int>{
      'LRM': _lrm,
      'RLM': _rlm,
      'ALM': 0x061C,
      'LRE': 0x202A,
      'RLE': 0x202B,
      'PDF': 0x202C,
      'LRO': 0x202D,
      'RLO': 0x202E,
      'LRI': 0x2066,
      'RLI': 0x2067,
      'FSI': 0x2068,
      'PDI': 0x2069,
      'ZWSP': 0x200B,
      'ZWNJ': 0x200C,
      'ZWJ': 0x200D,
    };

    marks.forEach((name, codePoint) {
      test('$name (U+${codePoint.toRadixString(16).toUpperCase()})', () {
        final mark = _ch(codePoint);
        expect(PhoneNormalizer.normalize('$mark 0599123456$mark').local, '0599123456');
      });
    });

    test('marks embedded mid-number', () {
      final raw = '059${_ch(_rlm)}912${_ch(_lrm)}3456';
      expect(PhoneNormalizer.normalize(raw).local, '0599123456');
    });

    test('an RTL-isolated number pasted from a chat app', () {
      final raw = '${_ch(0x2067)}+970 59-912 3456${_ch(0x2069)}';
      expect(PhoneNormalizer.normalize(raw).local, '0599123456');
    });
  });

  group('carrier classification', () {
    test('059 is Jawwal', () {
      expect(PhoneNormalizer.normalize('0599123456').carrier, Carrier.jawwal);
    });

    test('056 is Ooredoo', () {
      final result = PhoneNormalizer.normalize('0569123456');
      expect(result.carrier, Carrier.ooredoo);
      expect(result.local, '0569123456');
      expect(result.isValid, isTrue);
    });

    test('+970 56 normalizes and classifies as Ooredoo', () {
      final result = PhoneNormalizer.normalize('+970569123456');
      expect(result.local, '0569123456');
      expect(result.carrier, Carrier.ooredoo);
    });
  });

  group('warn but do not block', () {
    test('unknown prefix stays dialable', () {
      // A carrier could add 057 tomorrow. We warn; we never refuse.
      final result = PhoneNormalizer.normalize('0571234567');
      expect(result.issue, PhoneIssue.unknownPrefix);
      expect(result.isValid, isFalse);
      expect(result.carrier, Carrier.unknown);
      expect(result.local, '0571234567', reason: 'must still be dialable');
      expect(result.national, '571234567');
    });
  });

  group('invalid input is reported, never thrown', () {
    test('empty string', () {
      final result = PhoneNormalizer.normalize('');
      expect(result.issue, PhoneIssue.empty);
      expect(result.local, isEmpty);
      expect(result.isValid, isFalse);
    });

    test('whitespace only', () {
      expect(PhoneNormalizer.normalize('   ').issue, PhoneIssue.empty);
    });

    test('letters only', () {
      expect(PhoneNormalizer.normalize('hello').issue, PhoneIssue.nonNumeric);
    });

    test('Arabic letters only', () {
      expect(PhoneNormalizer.normalize('مرحبا').issue, PhoneIssue.nonNumeric);
    });

    test('too short', () {
      final result = PhoneNormalizer.normalize('05991234');
      expect(result.issue, PhoneIssue.tooShort);
      expect(result.isValid, isFalse);
    });

    test('too long', () {
      final result = PhoneNormalizer.normalize('05991234567');
      expect(result.issue, PhoneIssue.tooLong);
      expect(result.isValid, isFalse);
    });

    test('a single digit', () {
      expect(PhoneNormalizer.normalize('5').issue, PhoneIssue.tooShort);
    });
  });

  group('country-code stripping is not over-eager', () {
    test('a bare 9-digit number starting with 970 is left intact', () {
      // Stripping "970" here would turn a 9-digit national number into a
      // 6-digit fragment and dial money into the void.
      final result = PhoneNormalizer.normalize('970123456');
      expect(result.national, '970123456');
      expect(result.local, '0970123456');
      expect(result.issue, PhoneIssue.unknownPrefix);
    });

    test('a bare 9-digit number starting with 972 is left intact', () {
      expect(PhoneNormalizer.normalize('972123456').national, '972123456');
    });

    test('a local number is not mistaken for a country code', () {
      expect(PhoneNormalizer.normalize('0972123456').national, '972123456');
    });
  });

  test('normalization is idempotent', () {
    final once = PhoneNormalizer.normalize('+970 599-123456');
    final twice = PhoneNormalizer.normalize(once.local);
    expect(twice, once);
  });
}
