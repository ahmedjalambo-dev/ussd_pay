import 'dart:async';

import '../models/history_entry.dart';
import '../models/wallet.dart';
import 'sms_confirmation_parser.dart';
import 'sms_notification_source.dart';

/// Shows the Done/Cancel prompt. [whileWaiting] is true when the SMS wait is
/// still running, so the prompt must keep the wait's foreground service up
/// (the 3-minute fallback); false once the wait is over and the prompt must
/// outlive it.
typedef ShowManualPrompt = Future<void> Function({required bool whileWaiting});

/// Waits for the wallet's "money sent" SMS after a payment is handed to the
/// dialer, and reports the history row it confirms.
///
/// Timeline for one payment:
/// - at once: the "Waiting for SMS..." notification ([start]'s `showWaiting`),
///   which also starts the foreground service that keeps the app from being
///   frozen while the user is in the dialer;
/// - with "Ask me" also on, after [manualFallbackDelay]: the Done/Cancel
///   prompt, still as the service's notification;
/// - until [SmsConfirmationParser.window] has passed: a matching SMS marks
///   the row done, even if the Done/Cancel prompt is already showing;
/// - at the end of the window: the service stops and the Done/Cancel prompt
///   is posted on its own, so the user can always record the outcome.
///
/// Whenever the wait ends, `stopWaiting` runs *before* anything else is
/// posted: stopping the service removes its notification, and would take a
/// freshly posted one down with it.
///
/// A manual answer always wins: the Done/Cancel handlers call [clear], and an
/// SMS arriving after that is ignored.
///
/// Only lives as long as the app process. Nothing is persisted, so if the
/// app is killed while waiting, the payment stays as the user left it.
class SmsConfirmationController {
  SmsConfirmationController({required this._source});

  /// With both modes on, how long to wait for the SMS before also asking.
  static const Duration manualFallbackDelay = Duration(minutes: 3);

  final SmsNotificationSource _source;
  final StreamController<String> _confirmed =
      StreamController<String>.broadcast();

  PendingConfirmation? _pending;
  SmsConfirmationConfig? _config;
  StreamSubscription<SmsNotification>? _subscription;
  Timer? _fallbackTimer;
  Timer? _expiryTimer;
  ShowManualPrompt? _showManualPrompt;
  Future<void> Function()? _showConfirmed;
  Future<void> Function()? _stopWaiting;

  /// History ids confirmed by SMS. The listener marks them done.
  Stream<String> get confirmed => _confirmed.stream;

  PendingConfirmation? get pending => _pending;

  Future<void> start({
    required HistoryEntry entry,
    required SmsConfirmationConfig config,
    required bool askManually,
    required Future<void> Function() showWaiting,
    required ShowManualPrompt showManualPrompt,
    required Future<void> Function() showConfirmed,
    required Future<void> Function() stopWaiting,
  }) async {
    await clear();

    _pending = PendingConfirmation(
      historyEntryId: entry.id,
      walletId: entry.walletId,
      amountCents: SmsConfirmationParser.amountToCents(entry.amount),
      recipientNumber: entry.recipientNumber,
      // The row is written just before the hand-off, so this is the earliest
      // moment the carrier could have sent anything about this payment.
      startedAtUtc: entry.dialedAtUtc,
    );
    _config = config;
    _showManualPrompt = showManualPrompt;
    _showConfirmed = showConfirmed;
    _stopWaiting = stopWaiting;

    await showWaiting();
    _subscription = _source.notifications.listen(_onSms);
    await _source.watch(config.senders);

    if (askManually) {
      _fallbackTimer = Timer(
        manualFallbackDelay,
        () => _showManualPrompt?.call(whileWaiting: true),
      );
    }
    _expiryTimer = Timer(SmsConfirmationParser.window, _expire);
  }

  /// Stops waiting, and stops the wait's foreground service (which removes
  /// its notification). Called when the user answers by hand, when a new
  /// payment replaces this one, and by the controller itself when the wait
  /// ends.
  Future<void> clear() async {
    final stopWaiting = _stopWaiting;
    final wasWatching = _pending != null;
    _pending = null;
    _config = null;
    _fallbackTimer?.cancel();
    _expiryTimer?.cancel();
    _fallbackTimer = null;
    _expiryTimer = null;
    _showManualPrompt = null;
    _showConfirmed = null;
    _stopWaiting = null;
    // Not awaited: nothing depends on the cancel finishing, and a broadcast
    // subscription's cancel future may complete in another zone.
    unawaited(_subscription?.cancel());
    _subscription = null;
    if (!wasWatching) return;
    await _source.unwatch();
    await stopWaiting?.call();
  }

  Future<void> dispose() async {
    await clear();
    await _confirmed.close();
  }

  Future<void> _expire() async {
    final showManualPrompt = _showManualPrompt;
    await clear();
    // Posted after the service is gone, so it stays until answered.
    await showManualPrompt?.call(whileWaiting: false);
  }

  Future<void> _onSms(SmsNotification sms) async {
    final pending = _pending;
    final config = _config;
    if (pending == null || config == null) return;
    // The native side filters on sender already; checking again here keeps
    // the guarantee in testable Dart rather than only in Kotlin.
    if (!config.isSender(sms.sender)) return;

    final parsed = SmsConfirmationParser.parse(config, sms.text);
    if (parsed == null) return;
    if (!SmsConfirmationParser.matches(pending, parsed, sms.postedAtUtc)) {
      return;
    }

    final showConfirmed = _showConfirmed;
    // clear() drops the pending payment before its first await, so a second
    // matching SMS (messaging apps re-post notifications) cannot confirm
    // twice.
    await clear();
    await showConfirmed?.call();
    _confirmed.add(pending.historyEntryId);
  }
}
