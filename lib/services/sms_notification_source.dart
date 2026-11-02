import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

/// One wallet SMS notification, as forwarded by the native listener.
///
/// The native side has already filtered on the sender, so anything that
/// arrives here is at least claimed to be from a watched wallet.
@immutable
class SmsNotification {
  const SmsNotification({
    required this.sender,
    required this.text,
    required this.postedAtUtc,
  });

  final String sender;
  final String text;
  final DateTime postedAtUtc;
}

/// The notification-access bridge, behind an interface so tests can drive it.
abstract interface class SmsNotificationSource {
  /// False off Android: the settings for SMS confirmation are hidden.
  bool get isSupported;

  /// Whether the user has granted notification access in system settings.
  Future<bool> isAccessGranted();

  /// Opens the system "Notification access" screen.
  Future<void> openAccessSettings();

  /// Whether Android exempts the app from battery optimization. When it does
  /// not, aggressive OEM battery savers (MIUI especially) may still hold back
  /// the SMS notification while the user is in the dialer.
  Future<bool> isIgnoringBatteryOptimizations();

  /// Opens the app's system details page, where the battery setting lives.
  Future<void> openBatterySettings();

  /// Starts forwarding notifications from [senders]. Replaces any earlier
  /// watch: only one payment is ever in flight.
  Future<void> watch(List<String> senders);

  /// Stops forwarding anything.
  Future<void> unwatch();

  Stream<SmsNotification> get notifications;
}

class PlatformSmsNotificationSource implements SmsNotificationSource {
  static const MethodChannel _methods = MethodChannel('ussd_pay/sms_confirm');
  static const EventChannel _events = EventChannel(
    'ussd_pay/sms_confirm/events',
  );

  Stream<SmsNotification>? _stream;

  @override
  bool get isSupported =>
      !kIsWeb && defaultTargetPlatform == TargetPlatform.android;

  @override
  Future<bool> isAccessGranted() async {
    if (!isSupported) return false;
    try {
      return await _methods.invokeMethod<bool>('isAccessGranted') ?? false;
    } on PlatformException {
      return false;
    } on MissingPluginException {
      // Widget tests, and any host without the native side.
      return false;
    }
  }

  @override
  Future<void> openAccessSettings() => _invoke('openAccessSettings');

  @override
  Future<bool> isIgnoringBatteryOptimizations() async {
    // Off Android there is nothing to warn about.
    if (!isSupported) return true;
    try {
      return await _methods.invokeMethod<bool>(
            'isIgnoringBatteryOptimizations',
          ) ??
          true;
    } on PlatformException {
      return true;
    } on MissingPluginException {
      return true;
    }
  }

  @override
  Future<void> openBatterySettings() => _invoke('openBatterySettings');

  @override
  Future<void> watch(List<String> senders) =>
      _invoke('watch', {'senders': senders});

  @override
  Future<void> unwatch() => _invoke('unwatch');

  @override
  Stream<SmsNotification> get notifications => _stream ??= _events
      .receiveBroadcastStream()
      .map(_parse)
      .where((n) => n != null)
      .cast<SmsNotification>()
      .asBroadcastStream();

  Future<void> _invoke(String method, [Object? arguments]) async {
    if (!isSupported) return;
    try {
      await _methods.invokeMethod<void>(method, arguments);
    } on PlatformException catch (e) {
      debugPrint('sms_confirm.$method failed: ${e.message}');
    } on MissingPluginException {
      // No native side: SMS confirmation silently stays inactive, and the
      // payment falls back to the Done/Cancel prompt on its timer.
    }
  }

  static SmsNotification? _parse(Object? raw) {
    if (raw is! Map) return null;
    final sender = raw['sender'];
    final text = raw['text'];
    final postedAtMs = raw['postedAtMs'];
    if (sender is! String || text is! String || postedAtMs is! int) {
      return null;
    }
    return SmsNotification(
      sender: sender,
      text: text,
      postedAtUtc: DateTime.fromMillisecondsSinceEpoch(
        postedAtMs,
        isUtc: true,
      ),
    );
  }
}
