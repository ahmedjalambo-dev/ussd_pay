import 'dart:io';
import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';
import 'package:ussd_pay/theme/app_theme.dart';

/// The splash and launcher icon are generated images (tool/generate_icons.py)
/// coloured with the app's `colorScheme.primary`, so the splash flows straight
/// into the app's own buttons. Those colours are computed by `fromSeed`, not
/// written anywhere in Dart -- so if the seed or contrast level changes, the
/// images silently stop matching. This test is the tripwire: when it fails,
/// update the constants in the generator and the yaml, then re-run
/// `python tool/generate_icons.py` and `dart run flutter_native_splash:create`.
void main() {
  const primaryLight = Color(0xFF314377);
  const onPrimaryLight = Color(0xFFFFFFFF);
  const primaryDark = Color(0xFFB4C5FF);
  const onPrimaryDark = Color(0xFF061D50);

  test('the theme still produces the primaries the brand assets use', () {
    final light = AppTheme.light().colorScheme;
    final dark = AppTheme.dark().colorScheme;
    expect(light.primary, primaryLight);
    expect(light.onPrimary, onPrimaryLight);
    expect(dark.primary, primaryDark);
    expect(dark.onPrimary, onPrimaryDark);
  });

  test('the generator, splash config and launcher colour carry them', () {
    final generator = File('tool/generate_icons.py').readAsStringSync();
    expect(generator, contains('PRIMARY_LIGHT = (0x31, 0x43, 0x77, 255)'));
    expect(generator, contains('ON_PRIMARY_LIGHT = (0xFF, 0xFF, 0xFF, 255)'));
    expect(generator, contains('PRIMARY_DARK = (0xB4, 0xC5, 0xFF, 255)'));
    expect(generator, contains('ON_PRIMARY_DARK = (0x06, 0x1D, 0x50, 255)'));

    final splash = File('flutter_native_splash.yaml').readAsStringSync();
    expect(splash, contains('icon_background_color: "#314377"'));
    expect(splash, contains('icon_background_color_dark: "#B4C5FF"'));

    final launcher = File(
      'android/app/src/main/res/values/ic_launcher_colors.xml',
    ).readAsStringSync();
    expect(launcher, contains('#314377'));
  });
}
