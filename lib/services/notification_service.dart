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
          AndroidFlutterLocalNotificationsPlugin
        >();
    if (android == null) return true;
    final granted = await android.requestNotificationsPermission();
    return granted ?? true;
  }

  /// Shows the ongoing payment-decision notification for the given history
  /// entry. Replaces any previous one (same notification id).
  ///
  /// With [keepAwake], it is posted as the SMS wait's foreground-service
  /// notification instead (see [showWaitingForSms]): the Done/Cancel fallback
  /// at 3 minutes must not let the process freeze, or an SMS in minutes 3-5
  /// would again only be seen when the user comes back.
  Future<void> showPaymentDecision({
    required String historyEntryId,
    required String title,
    required String body,
    required String doneLabel,
    required String cancelLabel,
    bool keepAwake = false,
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

    if (keepAwake) {
      await _startWaitService(
        title: title,
        body: body,
        details: androidDetails,
        historyEntryId: historyEntryId,
      );
      return;
    }

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

  /// The "Waiting for confirmation SMS..." prompt, posted as the
  /// notification of a foreground service that lives for the whole wait.
  ///
  /// The service is the point, not the notification: once the user is in the
  /// dialer the app has nothing in the foreground, and Android's cached-app
  /// freezer (and MIUI's battery saver) freeze the process. A frozen process
  /// receives the "SMS notification posted" callback only when it thaws --
  /// i.e. when the user comes back -- and its timers stop too. A foreground
  /// service keeps it running until [stopSmsWait].
  ///
  /// Must be called while the app is still in the foreground (before the
  /// dialer hand-off): Android 12+ refuses to start one from the background.
  Future<void> showWaitingForSms({
    required String historyEntryId,
    required String title,
    required String body,
  }) => _startWaitService(
    title: title,
    body: body,
    historyEntryId: historyEntryId,
    details: const AndroidNotificationDetails(
      _channelId,
      _channelName,
      channelDescription: _channelDescription,
      importance: Importance.high,
      priority: Priority.high,
      ongoing: true,
      autoCancel: false,
      category: AndroidNotificationCategory.status,
      playSound: false,
      enableVibration: false,
    ),
  );

  /// Ends the SMS wait's foreground service, which also removes its
  /// notification. Post the next notification (Done/Cancel, Confirmed) only
  /// after this returns, or the stop takes it down with the service. Safe to
  /// call when no service is running.
  Future<void> stopSmsWait() async {
    await _androidPlugin?.stopForegroundService();
  }

  Future<void> _startWaitService({
    required String title,
    required String body,
    required AndroidNotificationDetails details,
    required String historyEntryId,
  }) async {
    await _androidPlugin?.startForegroundService(
      id: _notificationId,
      title: title,
      body: body,
      notificationDetails: details,
      payload: historyEntryId,
      // Not sticky: if the app is killed, the wait dies with it rather than
      // coming back as an empty service.
      startType: AndroidServiceStartType.startNotSticky,
      // specialUse, declared in AndroidManifest.xml with its reason. A
      // shortService would be cut off at ~3 minutes, before the 5-minute
      // window ends.
      foregroundServiceTypes: const {
        AndroidServiceForegroundType.foregroundServiceTypeSpecialUse,
      },
    );
  }

  AndroidFlutterLocalNotificationsPlugin? get _androidPlugin => _plugin
      .resolvePlatformSpecificImplementation<
        AndroidFlutterLocalNotificationsPlugin
      >();

  /// "Payment confirmed by SMS". Informational: it carries no payload, so
  /// tapping it is never mistaken for an answer, and it clears itself.
  Future<void> showConfirmedBySms({
    required String title,
    required String body,
  }) => _plugin.show(
    id: _notificationId,
    title: title,
    body: body,
    notificationDetails: const NotificationDetails(
      android: AndroidNotificationDetails(
        _channelId,
        _channelName,
        channelDescription: _channelDescription,
        importance: Importance.high,
        priority: Priority.high,
        category: AndroidNotificationCategory.status,
        playSound: false,
        enableVibration: false,
        timeoutAfter: 15000,
      ),
    ),
  );

  /// Dismisses the payment-decision notification if it is up, and ends any
  /// SMS wait it belonged to. Safe to call when there is no notification.
  Future<void> cancelPaymentDecision() async {
    await stopSmsWait();
    await _plugin.cancel(id: _notificationId);
  }

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
