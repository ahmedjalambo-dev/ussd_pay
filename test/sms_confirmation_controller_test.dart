import 'dart:async';
import 'dart:io';

import 'package:fake_async/fake_async.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ussd_pay/models/history_entry.dart';
import 'package:ussd_pay/models/wallet.dart';
import 'package:ussd_pay/services/sms_confirmation_controller.dart';
import 'package:ussd_pay/services/sms_notification_source.dart';
import 'package:ussd_pay/services/wallet_repository.dart';

class _FakeSource implements SmsNotificationSource {
  final StreamController<SmsNotification> _controller =
      StreamController<SmsNotification>.broadcast();
  List<String>? watched;

  void post(String sender, String text, DateTime at) =>
      _controller.add(SmsNotification(sender: sender, text: text, postedAtUtc: at));

  @override
  bool get isSupported => true;
  @override
  Future<bool> isAccessGranted() async => true;
  @override
  Future<void> openAccessSettings() async {}
  @override
  Future<bool> isIgnoringBatteryOptimizations() async => true;
  @override
  Future<void> openBatterySettings() async {}
  @override
  Future<void> watch(List<String> senders) async => watched = senders;
  @override
  Future<void> unwatch() async => watched = null;
  @override
  Stream<SmsNotification> get notifications => _controller.stream;
}

void main() {
  late SmsConfirmationConfig jawwal;

  setUpAll(() {
    jawwal = WalletRepository.parse(
      File(WalletRepository.assetPath).readAsStringSync(),
    ).byId('jawwalpay')!.smsConfirmation!;
  });

  final dialedAt = DateTime.utc(2026, 10, 20, 12);
  final entry = HistoryEntry(
    id: 'h1',
    dialedAtUtc: dialedAt,
    walletId: 'jawwalpay',
    recipientType: 'friend',
    recipientNumber: '0597501462',
    amount: 5,
    ussdCode: '*268*1*0597501462*5#',
  );
  const sentSms = 'تم تحويل ILS 5.00 الى 00970597501462 رصيدك الحالي ILS 21.00';

  /// Starts a wait and records what the controller asked the UI to show.
  ({
    _FakeSource source,
    SmsConfirmationController controller,
    List<String> shown,
    List<String> confirmed,
  })
  setUpRun(FakeAsync async, {required bool askManually}) {
    final source = _FakeSource();
    final controller = SmsConfirmationController(source: source);
    final shown = <String>[];
    final confirmed = <String>[];
    controller.confirmed.listen(confirmed.add);
    controller.start(
      entry: entry,
      config: jawwal,
      askManually: askManually,
      showWaiting: () async => shown.add('waiting'),
      // "manual+fgs" is the 3-minute fallback, still holding the wait's
      // foreground service; "manual" is posted on its own after the wait.
      showManualPrompt: ({required whileWaiting}) async =>
          shown.add(whileWaiting ? 'manual+fgs' : 'manual'),
      showConfirmed: () async => shown.add('confirmed'),
      stopWaiting: () async => shown.add('stop'),
    );
    async.flushMicrotasks();
    return (
      source: source,
      controller: controller,
      shown: shown,
      confirmed: confirmed,
    );
  }

  test('a matching SMS confirms the row and stops watching', () {
    fakeAsync((async) {
      final run = setUpRun(async, askManually: true);
      expect(run.shown, ['waiting']);
      expect(run.source.watched, jawwal.senders);

      run.source.post('Jawwal Pay', sentSms, dialedAt.add(const Duration(seconds: 30)));
      async.flushMicrotasks();

      expect(run.confirmed, ['h1']);
      // The service stops before "Confirmed" is posted, or the stop would
      // remove it too.
      expect(run.shown, ['waiting', 'stop', 'confirmed']);
      expect(run.source.watched, isNull);
      expect(run.controller.pending, isNull);

      // No fallback prompt after a confirmation.
      async.elapse(const Duration(minutes: 10));
      expect(run.shown, ['waiting', 'stop', 'confirmed']);
    });
  });

  test('SMS only: no SMS -> Done/Cancel at 5 minutes, then matching stops', () {
    fakeAsync((async) {
      final run = setUpRun(async, askManually: false);

      async.elapse(const Duration(minutes: 4, seconds: 59));
      expect(run.shown, ['waiting']);

      async.elapse(const Duration(seconds: 1));
      expect(run.shown, ['waiting', 'stop', 'manual']);
      expect(run.source.watched, isNull);

      run.source.post('Jawwal Pay', sentSms, dialedAt.add(const Duration(minutes: 5)));
      async.flushMicrotasks();
      expect(run.confirmed, isEmpty);
    });
  });

  test('both modes: Done/Cancel at 3 minutes, a late SMS still confirms', () {
    fakeAsync((async) {
      final run = setUpRun(async, askManually: true);

      async.elapse(const Duration(minutes: 3));
      // Still the service's notification: the app must stay awake for a
      // late SMS.
      expect(run.shown, ['waiting', 'manual+fgs']);

      async.elapse(const Duration(minutes: 1));
      run.source.post('Jawwal Pay', sentSms, dialedAt.add(const Duration(minutes: 4)));
      async.flushMicrotasks();

      expect(run.confirmed, ['h1']);
      expect(run.shown, ['waiting', 'manual+fgs', 'stop', 'confirmed']);
    });
  });

  test('both modes, no SMS: the prompt is re-posted when the wait ends', () {
    fakeAsync((async) {
      final run = setUpRun(async, askManually: true);
      async.elapse(const Duration(minutes: 5));
      expect(run.shown, ['waiting', 'manual+fgs', 'stop', 'manual']);
      expect(run.source.watched, isNull);
      expect(run.confirmed, isEmpty);
    });
  });

  test('a manual answer wins over a later SMS', () {
    fakeAsync((async) {
      final run = setUpRun(async, askManually: true);
      async.elapse(const Duration(minutes: 3));

      run.controller.clear();
      async.flushMicrotasks();
      run.source.post('Jawwal Pay', sentSms, dialedAt.add(const Duration(minutes: 4)));
      async.flushMicrotasks();

      expect(run.confirmed, isEmpty);
      expect(run.source.watched, isNull);
      expect(run.shown, ['waiting', 'manual+fgs', 'stop']);

      // Nothing more fires once the user has answered.
      async.elapse(const Duration(minutes: 5));
      expect(run.shown, ['waiting', 'manual+fgs', 'stop']);
    });
  });

  test('ignores other senders, receive messages and other amounts', () {
    fakeAsync((async) {
      final run = setUpRun(async, askManually: true);
      final at = dialedAt.add(const Duration(seconds: 30));

      run.source.post('Mum', sentSms, at);
      run.source.post(
        'Jawwal Pay',
        'استلمت مبلغ ILS 5.00 من 00970599806812 رصيدك الحالي ILS 108.00',
        at,
      );
      run.source.post(
        'Jawwal Pay',
        'تم تحويل ILS 6.00 الى 00970597501462 رصيدك الحالي ILS 20.00',
        at,
      );
      run.source.post(
        'Jawwal Pay',
        'تم تحويل ILS 5.00 الى 00970599000000 رصيدك الحالي ILS 20.00',
        at,
      );
      async.flushMicrotasks();

      expect(run.confirmed, isEmpty);
      expect(run.controller.pending, isNotNull);
    });
  });

  test('a duplicate notification confirms only once', () {
    fakeAsync((async) {
      final run = setUpRun(async, askManually: true);
      final at = dialedAt.add(const Duration(seconds: 30));
      run.source
        ..post('Jawwal Pay', sentSms, at)
        ..post('Jawwal Pay', sentSms, at);
      async.flushMicrotasks();
      expect(run.confirmed, ['h1']);
    });
  });
}
