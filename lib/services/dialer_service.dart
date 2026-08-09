import 'dart:io' show Platform;

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';

/// What happened when we handed the code off.
enum DialOutcome {
  /// The system dialer opened, pre-filled with the code. The user presses call.
  openedDialer,

  /// No dialer available (iOS, tablets, emulators without telephony). The code
  /// is on the clipboard instead.
  copiedToClipboard,
}

/// Hands a built USSD code to the system dialer.
///
/// This app never places the call itself: it holds no `CALL_PHONE` permission
/// and has no direct-dial path. Handing off means the carrier's own interactive
/// USSD dialog takes over, which is what lets the user enter their PIN there --
/// and it means the last confirmation is always the user pressing call.
abstract final class DialerService {
  /// Builds the `tel:` URI for [ussdCode].
  ///
  /// `Uri`'s path encoding leaves `*` alone (it is a sub-delimiter) and encodes
  /// `#` as `%23`. That encoding is not cosmetic: a raw `#` starts a URI
  /// fragment, so `tel:*268*1*0599123456*50#` is parsed as
  /// `tel:*268*1*0599123456*50` with the fragment discarded -- the dialer would
  /// receive a truncated code that is not a valid USSD command. This is the
  /// single most common bug in USSD apps, and it is covered by a test.
  static Uri buildDialUri(String ussdCode) => Uri(scheme: 'tel', path: ussdCode);

  /// True on platforms where a `tel:` hand-off makes sense.
  static bool get supportsDialing {
    if (kIsWeb) return false;
    return Platform.isAndroid;
  }

  /// Opens the dialer pre-filled with [ussdCode], or falls back to the
  /// clipboard.
  ///
  /// The clipboard path covers iOS (where `tel:` cannot carry a USSD code) and
  /// any device with no dialer app. The caller is expected to explain the
  /// fallback to the user.
  static Future<DialOutcome> dial(String ussdCode) async {
    if (supportsDialing) {
      final uri = buildDialUri(ussdCode);
      try {
        if (await launchUrl(uri)) return DialOutcome.openedDialer;
      } on PlatformException {
        // Fall through to the clipboard rather than dead-ending the user.
      }
    }
    await Clipboard.setData(ClipboardData(text: ussdCode));
    return DialOutcome.copiedToClipboard;
  }

  /// Copies [ussdCode] without attempting to dial, for the explicit "copy
  /// code" action on the confirmation screen.
  static Future<void> copy(String ussdCode) =>
      Clipboard.setData(ClipboardData(text: ussdCode));
}
