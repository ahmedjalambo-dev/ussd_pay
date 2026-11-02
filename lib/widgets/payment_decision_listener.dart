import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/history_entry.dart';
import '../providers/app_providers.dart';
import '../services/notification_service.dart';

/// Bridges the payment-decision notification back into the running app.
///
/// - Requests POST_NOTIFICATIONS on first mount (Android 13+); silent no-op
///   elsewhere.
/// - Drains any event that woke the app from a cold start via the
///   notification (`takeInitialEvent`).
/// - Subscribes to the event stream so taps that happen while the app is
///   already running resolve immediately.
///
/// Actions apply directly to the running Riverpod graph: both record the
/// answer as the status of the history row the notification was attached
/// to, reset the draft, and pop to the root.
///
/// Also feeds the app's lifecycle to DecisionAlertScheduler, so the delayed
/// Done/Cancel banner counts only time the user actually spends away.
///
/// Also applies SMS confirmations from SmsConfirmationController the same
/// way, as Done -- and stops that controller when the user answers by hand,
/// so a manual answer is never overwritten by a later SMS.
class PaymentDecisionListener extends ConsumerStatefulWidget {
  const PaymentDecisionListener({super.key, required this.child});

  final Widget child;

  @override
  ConsumerState<PaymentDecisionListener> createState() =>
      _PaymentDecisionListenerState();
}

class _PaymentDecisionListenerState
    extends ConsumerState<PaymentDecisionListener>
    with WidgetsBindingObserver {
  StreamSubscription<PaymentDecisionEvent>? _subscription;
  StreamSubscription<String>? _smsSubscription;

  @override
  void initState() {
    super.initState();
    final service = ref.read(notificationServiceProvider);

    WidgetsBinding.instance.addObserver(this);
    _subscription = service.events.listen(_apply);
    _smsSubscription = ref
        .read(smsConfirmationControllerProvider)
        .confirmed
        .listen(_applySmsConfirmation);

    // Deferred so ref is safe to use and Navigator is mounted.
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (!mounted) return;
      await service.ensurePermission();

      // Cold-start via a notification action: apply once, then let the
      // stream handle any later taps.
      final launched = await service.takeInitialEvent();
      if (launched != null && mounted) _apply(launched);
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _subscription?.cancel();
    _smsSubscription?.cancel();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    final scheduler = ref.read(decisionAlertSchedulerProvider);
    switch (state) {
      case AppLifecycleState.hidden:
      case AppLifecycleState.paused:
        scheduler.appBackgrounded();
      case AppLifecycleState.resumed:
        scheduler.appResumed();
      // Inactive is also what pulling the shade down inside the app looks
      // like -- that is not leaving.
      case AppLifecycleState.inactive:
      case AppLifecycleState.detached:
        break;
    }
  }

  void _apply(PaymentDecisionEvent event) {
    if (!mounted) return;

    ref.read(smsConfirmationControllerProvider).clear();
    ref.read(decisionAlertSchedulerProvider).cancel(event.historyEntryId);

    // Cancel is written explicitly even though new rows already start as
    // cancelled: the row must end up matching what the user tapped, whatever
    // state it was in.
    final status = switch (event.action) {
      NotificationAction.done => HistoryStatus.done,
      NotificationAction.cancel => HistoryStatus.cancelled,
    };
    ref
        .read(historyProvider.notifier)
        .setStatus(
          event.historyEntryId,
          status,
          confirmedBy: ConfirmationSource.user,
        );

    ref.read(paymentDraftProvider.notifier).reset();
    // The confirm screen may still be on the stack (user was in the dialer
    // when they answered). Pop everything back to the root tabs. Using the
    // root navigator so we do not stop at an inner navigator like a
    // bottom-sheet route.
    Navigator.of(context, rootNavigator: true).popUntil((r) => r.isFirst);
  }

  /// The wallet's own SMS said the money went: the same outcome as the user
  /// tapping Done, recorded as SMS-confirmed.
  void _applySmsConfirmation(String historyEntryId) {
    if (!mounted) return;
    ref.read(decisionAlertSchedulerProvider).cancel(historyEntryId);
    ref
        .read(historyProvider.notifier)
        .setStatus(
          historyEntryId,
          HistoryStatus.done,
          confirmedBy: ConfirmationSource.sms,
        );
    ref.read(paymentDraftProvider.notifier).reset();
    Navigator.of(context, rootNavigator: true).popUntil((r) => r.isFirst);
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
