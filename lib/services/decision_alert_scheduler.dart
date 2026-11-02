import 'dart:async';

/// Raises the Done/Cancel prompt as a banner once the user has been away from
/// the app for [awayDelay].
///
/// The prompt itself is posted quietly the moment the code is handed off, so
/// it is in the pulldown no matter what happens next. Only the banner waits:
/// right after "Open dialer" the carrier's USSD screen is up, and a banner on
/// top of it -- while the user reads the recipient and types the PIN -- is the
/// worst possible moment to ask anything.
///
/// The delay counts *continuous* time away. Coming back cancels the countdown
/// (the user is in the app, where the Done button is); leaving again starts a
/// fresh one. The banner fires at most once per attempt.
///
/// If Android freezes the app in the background the timer simply does not
/// fire, and the quiet prompt is still there -- nothing is lost. On return,
/// [appResumed] cancels the late banner.
///
/// Pure Dart (timers only) so it is testable with fake_async; the app's
/// lifecycle is fed in by PaymentDecisionListener.
class DecisionAlertScheduler {
  static const Duration awayDelay = Duration(seconds: 7);

  String? _entryId;
  Future<void> Function()? _alert;
  Timer? _timer;
  bool _inBackground = false;

  /// The history row whose banner is still pending, if any.
  String? get armedEntryId => _entryId;

  /// Arms the banner for [entryId], replacing any earlier arm. [inBackground]
  /// is the app's state right now: after "Open dialer" it usually already is,
  /// and the countdown starts at once.
  void arm({
    required String entryId,
    required bool inBackground,
    required Future<void> Function() alert,
  }) {
    cancel();
    _entryId = entryId;
    _alert = alert;
    _inBackground = inBackground;
    if (inBackground) _startCountdown();
  }

  void appBackgrounded() {
    _inBackground = true;
    if (_entryId != null && _timer == null) _startCountdown();
  }

  void appResumed() {
    _inBackground = false;
    _timer?.cancel();
    _timer = null;
  }

  /// Disarms. With [entryId], only if that row is the armed one, so answering
  /// an older prompt cannot cancel a newer payment's banner.
  void cancel([String? entryId]) {
    if (entryId != null && entryId != _entryId) return;
    _timer?.cancel();
    _timer = null;
    _entryId = null;
    _alert = null;
  }

  void _startCountdown() {
    _timer = Timer(awayDelay, () {
      final alert = _alert;
      // Once per attempt: disarm before alerting.
      _timer = null;
      _entryId = null;
      _alert = null;
      if (_inBackground) alert?.call();
    });
  }
}
