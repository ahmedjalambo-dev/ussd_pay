import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

/// The "did the payment go through?" prompt shown after the user hands the
/// USSD code to the dialer (or copies it).
///
/// It is deliberately an *ongoing* notification: the user is expected to
/// answer Done or Cancel from the pulldown, without switching back to the
/// app. Actions carry `showsUserInterface: true`, so tapping either one
/// brings the app to the foreground before we handle it. That avoids the
/// background-isolate pitfalls (a separate Flutter engine, no access to
/// the running Riverpod graph, no access to the Keystore-backed Hive box).
///
/// Nothing here is I/O beyond the platform channel. No network calls; no
/// state persisted outside the notification the OS itself is drawing.
class NotificationService {
  NotificationService._(this._plugin);

  final FlutterLocalNotificationsPlugin _plugin;
  final StreamController<PaymentDecisionEvent> _events =
      StreamController<PaymentDecisionEvent>.broadcast();

  /// The single notification id used for the payment-decision prompt. There
  /// is only ever one payment in flight, so we deliberately reuse the id --
  /// starting a fresh payment while an old prompt is still up replaces it.
  static const int _notificationId = 1001;

  static const String _channelId = 'payment_decision';
  static const String _channelName = 'Payment decisions';
  static const String _channelDescription =
      'Ongoing prompt after opening the dialer, asking whether the payment '
      'went through.';

  /// Action ids match the ones we register on the Android notification.
  /// Kept as constants so [_toEvent] and the notification builder agree.
  static const String _actionDone = 'payment_done';
  static const String _actionCancel = 'payment_cancel';

  /// Opens the plugin and wires the response callback. Called once from
  /// `main()` before the app runs, mirroring [StorageService.open].
  static Future<NotificationService> init() async {
    final plugin = FlutterLocalNotificationsPlugin();

    const androidInit = AndroidInitializationSettings('@mipmap/ic_launcher');
    const initSettings = InitializationSettings(android: androidInit);

    final service = NotificationService._(plugin);

    await plugin.initialize(
      settings: initSettings,
      onDidReceiveNotificationResponse: service._onResponse,
    );

    return service;
  }

  /// Fires whenever the user taps one of the notification's action buttons.
  /// The main isolate listens and applies the action (reset draft, set the
  /// history row's status, etc.).
  Stream<PaymentDecisionEvent> get events => _events.stream;

  /// If the app was cold-started by tapping an action on the notification,
  /// this returns the event that woke it. Consumed once in `main()`.
  Future<PaymentDecisionEvent?> takeInitialEvent() async {
    final details = await _plugin.getNotificationAppLaunchDetails();
    if (details == null || !details.didNotificationLaunchApp) return null;
    return _toEvent(details.notificationResponse);
  }

  /// Requests POST_NOTIFICATIONS on Android 13+. On older versions this is
  /// a no-op that returns true. Denial is not fatal -- the confirm screen
  /// keeps its in-app Done button.
  Future<bool> ensurePermission() async {
    final android = _plugin
        .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>();
    if (android == null) return true;
    final granted = await android.requestNotificationsPermission();
    return granted ?? true;
  }

  /// Shows the ongoing payment-decision notification for the given history
  /// entry. Replaces any previous one (same notification id).
  Future<void> showPaymentDecision({
    required String historyEntryId,
    required String title,
    required String body,
    required String doneLabel,
    required String cancelLabel,
  }) async {
    final androidDetails = AndroidNotificationDetails(
      _channelId,
      _channelName,
      channelDescription: _channelDescription,
      importance: Importance.high,
      priority: Priority.high,
      // Ongoing + autoCancel:false makes the notification non-dismissible on
      // Android <=13. On 14+ users can force-dismiss it -- that counts as
      // "Cancelled", which needs no code: history rows start as cancelled
      // and only an explicit Done changes that.
      ongoing: true,
      autoCancel: false,
      category: AndroidNotificationCategory.status,
      // No sound or vibration: this fires right after the user just tapped
      // a button in-app; buzzing them would be noise.
      playSound: false,
      enableVibration: false,
      actions: <AndroidNotificationAction>[
        AndroidNotificationAction(
          _actionDone,
          doneLabel,
          // Bringing the app to the foreground here means the response is
          // delivered to onDidReceiveNotificationResponse in the main
          // isolate -- no background isolate, no separate Flutter engine.
          showsUserInterface: true,
          cancelNotification: true,
        ),
        AndroidNotificationAction(
          _actionCancel,
          cancelLabel,
          showsUserInterface: true,
          cancelNotification: true,
        ),
      ],
    );

    await _plugin.show(
      id: _notificationId,
      title: title,
      body: body,
      notificationDetails: NotificationDetails(android: androidDetails),
      // Payload carries the history row id so we know which row to mark
      // when the user answers.
      payload: historyEntryId,
    );
  }

  /// Dismisses the payment-decision notification if it is up. Safe to call
  /// when there is no notification.
  Future<void> cancelPaymentDecision() => _plugin.cancel(id: _notificationId);

  void _onResponse(NotificationResponse response) {
    final event = _toEvent(response);
    if (event != null) _events.add(event);
  }

  static PaymentDecisionEvent? _toEvent(NotificationResponse? response) {
    if (response == null) return null;
    final entryId = response.payload;
    if (entryId == null || entryId.isEmpty) return null;
    switch (response.actionId) {
      case _actionDone:
        return PaymentDecisionEvent(
          action: NotificationAction.done,
          historyEntryId: entryId,
        );
      case _actionCancel:
        return PaymentDecisionEvent(
          action: NotificationAction.cancel,
          historyEntryId: entryId,
        );
      default:
        // Tapping the notification body (not an action) is not an answer;
        // ignore it. The user still has the AppBar Done fallback.
        return null;
    }
  }

  @visibleForTesting
  void debugEmit(PaymentDecisionEvent event) => _events.add(event);
}

/// Which button the user tapped on the payment-decision notification.
enum NotificationAction { done, cancel }

/// One user answer to the payment-decision prompt.
@immutable
class PaymentDecisionEvent {
  const PaymentDecisionEvent({
    required this.action,
    required this.historyEntryId,
  });

  final NotificationAction action;
  final String historyEntryId;

  @override
  bool operator ==(Object other) =>
      other is PaymentDecisionEvent &&
      other.action == action &&
      other.historyEntryId == historyEntryId;

  @override
  int get hashCode => Object.hash(action, historyEntryId);
}
