import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/attempts.dart';
import '../core/formatting.dart';
import '../l10n/generated/app_localizations.dart';
import '../models/favorite.dart';
import '../models/history_entry.dart';
import '../models/wallet.dart';
import '../providers/app_providers.dart';
import '../services/dialer_service.dart';
import '../services/phone_normalizer.dart';
import '../theme/app_theme.dart';
import '../widgets/save_favorite_dialog.dart';
import '../widgets/ussd_preview.dart';

/// The mandatory review step.
///
/// This screen is the reason the app exists. There is no path to the dialer
/// that skips it, and nothing on it dials automatically: the user reads the
/// recipient, the amount, and the literal code, then chooses.
class ConfirmScreen extends ConsumerStatefulWidget {
  const ConfirmScreen({
    super.key,
    required this.wallet,
    required this.recipientType,
    required this.phone,
    required this.amount,
    required this.ussdCode,
    this.recipientName,
    this.note = '',
  });

  final Wallet wallet;
  final String recipientType;
  final NormalizedPhone phone;
  final num amount;
  final String ussdCode;
  final String? recipientName;

  /// Optional user-supplied label. Never enters the dialed code.
  final String note;

  @override
  ConsumerState<ConfirmScreen> createState() => _ConfirmScreenState();
}

class _ConfirmScreenState extends ConsumerState<ConfirmScreen> {
  bool _dialing = false;

  /// The row written by the most recent dial/copy on this screen, so the
  /// AppBar Done button can mark it as done.
  HistoryEntry? _lastEntry;

  /// Writes a history row for this attempt and returns it. Recorded before
  /// any hand-off, because once the dialer takes over the app may be
  /// backgrounded and never told what happened. The row starts as cancelled
  /// and becomes done only when the user says so (notification Done or the
  /// AppBar Done button) -- an unanswered payment is not claimed as sent.
  Future<HistoryEntry> _writeHistoryEntry() async {
    final entry = HistoryEntry(
      dialedAtUtc: DateTime.now().toUtc(),
      walletId: widget.wallet.id,
      recipientType: widget.recipientType,
      recipientNumber: widget.phone.local,
      recipientName: widget.recipientName,
      amount: widget.amount,
      ussdCode: widget.ussdCode,
      note: widget.note.trim().isEmpty ? null : widget.note.trim(),
    );
    await ref.read(historyProvider.notifier).add(entry);
    _lastEntry = entry;
    return entry;
  }

  String _notificationBody(AppLocalizations l10n) {
    final localeCode = ref.read(settingsProvider).locale?.languageCode ?? 'ar';
    return l10n.notifPaymentDecisionBody(
      widget.wallet.nameFor(localeCode),
      formatAmountDisplay(widget.amount),
      l10n.currencySymbol,
    );
  }

  /// The ongoing Done/Cancel prompt, answered from the pulldown;
  /// PaymentDecisionListener applies the choice.
  ///
  /// Posted quietly at once -- in the pulldown, but no banner over the USSD
  /// screen the user is about to read -- and raised as a banner by
  /// DecisionAlertScheduler once they have been away for a few seconds.
  Future<void> _showDecisionNotification(HistoryEntry entry) async {
    final l10n = AppLocalizations.of(context);
    final notifications = ref.read(notificationServiceProvider);
    final scheduler = ref.read(decisionAlertSchedulerProvider);
    final body = _notificationBody(l10n);

    Future<void> post({required bool quiet}) =>
        notifications.showPaymentDecision(
          historyEntryId: entry.id,
          title: l10n.notifPaymentDecisionTitle,
          body: body,
          doneLabel: l10n.notifActionDone,
          cancelLabel: l10n.notifActionCancel,
          quiet: quiet,
        );

    await post(quiet: true);
    final lifecycle = WidgetsBinding.instance.lifecycleState;
    scheduler.arm(
      entryId: entry.id,
      inBackground:
          lifecycle == AppLifecycleState.hidden ||
          lifecycle == AppLifecycleState.paused,
      alert: () async {
        // Answered or swiped away in the meantime: do not bring it back.
        if (await notifications.isDecisionShowing()) {
          await post(quiet: false);
        }
      },
    );
  }

  /// Records an in-app answer for [entry] and takes down everything still
  /// asking about it: the prompt, its pending banner, any SMS wait.
  Future<void> _settle(HistoryEntry entry, HistoryStatus status) async {
    await ref.read(notificationServiceProvider).cancelPaymentDecision();
    ref.read(decisionAlertSchedulerProvider).cancel(entry.id);
    // A manual answer wins over a later SMS.
    await ref.read(smsConfirmationControllerProvider).clear();
    await ref
        .read(historyProvider.notifier)
        .setStatus(entry.id, status, confirmedBy: ConfirmationSource.user);
  }

  /// Cancel (AppBar or system back).
  ///
  /// Before any dial there is nothing to record: just go back to the form.
  /// After a dial whose outcome nobody answered yet, leaving means "it did not
  /// go through" -- recorded as cancelled, after asking, since a payment that
  /// did go through would then be listed as not sent. Either way the user
  /// lands back on the payment form (draft kept) to fix the number or amount.
  Future<void> _cancel() async {
    if (_dialing) return;
    final last = _lastEntry;
    final entry = last == null
        ? null
        : ref.read(historyProvider).where((e) => e.id == last.id).firstOrNull;

    // Same "unanswered" rule as the double-pay guard (lib/core/attempts.dart).
    if (entry == null || entry.confirmedBy != null) {
      Navigator.of(context).pop();
      return;
    }

    final l10n = AppLocalizations.of(context);
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => Theme(
        data: AppTheme.branded(dialogContext, Color(widget.wallet.colorValue)),
        child: AlertDialog(
          title: Text(l10n.cancelPaymentTitle),
          content: Text(l10n.cancelPaymentBody),
          actions: [
            TextButton(
              style: TextButton.styleFrom(
                minimumSize: AppTheme.dialogActionSize,
              ),
              onPressed: () => Navigator.of(dialogContext).pop(false),
              child: Text(l10n.cancelPaymentStay),
            ),
            FilledButton(
              style: FilledButton.styleFrom(
                minimumSize: AppTheme.dialogActionSize,
              ),
              onPressed: () => Navigator.of(dialogContext).pop(true),
              child: Text(l10n.cancelPaymentConfirm),
            ),
          ],
        ),
      ),
    );
    if (!(confirmed ?? false) || !mounted) return;

    await _settle(entry, HistoryStatus.cancelled);
    if (mounted) Navigator.of(context).pop();
  }

  /// The double-pay guard, run before every new hand-off. Returns whether to
  /// go ahead.
  ///
  /// There is one prompt at a time, and a new attempt replaces it. So before
  /// a new attempt, the latest one nobody answered is settled:
  /// - The same payment (a retry after a USSD error, a second tap): if it
  ///   went through, dialing again would pay twice -- so "it went through"
  ///   ends here, and only "it failed" dials again.
  /// - A different payment (the wrong number was fixed, or a new payment
  ///   while an old prompt is up): the answer is recorded either way, and
  ///   the new payment goes ahead.
  ///
  /// Dismissing the dialog changes nothing and does not dial.
  Future<bool> _resolvePreviousAttempt() async {
    final previous = findUnansweredAttempt(
      ref.read(historyProvider),
      DateTime.now().toUtc(),
    );
    if (previous == null) return true;

    final same = isSamePayment(
      previous,
      walletId: widget.wallet.id,
      recipientNumber: widget.phone.local,
      amount: widget.amount,
    );
    final wentThrough = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => Theme(
        data: AppTheme.branded(dialogContext, Color(widget.wallet.colorValue)),
        child: _PreviousAttemptDialog(entry: previous, samePayment: same),
      ),
    );
    if (wentThrough == null || !mounted) return false;

    await _settle(
      previous,
      wentThrough ? HistoryStatus.done : HistoryStatus.cancelled,
    );
    if (!mounted) return false;

    if (same && wentThrough) {
      // This payment is already made: finish it exactly like Done.
      ref.read(paymentDraftProvider.notifier).reset();
      Navigator.of(context).popUntil((r) => r.isFirst);
      return false;
    }
    return true;
  }

  /// Starts the SMS wait if this wallet is set to "Confirm by SMS", and
  /// returns whether it did. When it did not, the caller shows the Done/Cancel
  /// prompt instead.
  ///
  /// SMS mode silently degrades to "Ask me" when it cannot work (no patterns
  /// for this wallet, notification access revoked): the user must always be
  /// left with a way to record the outcome.
  ///
  /// Called BEFORE the dialer hand-off: the wait runs as a foreground
  /// service, which Android 12+ only lets the app start while it is in
  /// front. Started after the hand-off, it could be refused -- and without it
  /// the app is frozen in the background and only sees the SMS on return.
  Future<bool> _startSmsWait(HistoryEntry entry) async {
    final l10n = AppLocalizations.of(context);
    final modes = ref.read(settingsProvider).modesFor(widget.wallet.id);
    final notifications = ref.read(notificationServiceProvider);
    final controller = ref.read(smsConfirmationControllerProvider);
    final source = ref.read(smsNotificationSourceProvider);
    final smsConfig = widget.wallet.smsConfirmation;
    final body = _notificationBody(l10n);

    final useSms =
        smsConfig != null &&
        modes.sms &&
        source.isSupported &&
        await source.isAccessGranted();

    if (!useSms) {
      // A wait left over from an earlier payment must not confirm this one.
      await controller.clear();
      return false;
    }

    await controller.start(
      entry: entry,
      config: smsConfig,
      askManually: modes.manual,
      showWaiting: () => notifications.showWaitingForSms(
        historyEntryId: entry.id,
        title: l10n.notifWaitingSmsTitle,
        body: body,
      ),
      showManualPrompt: ({required whileWaiting}) =>
          notifications.showPaymentDecision(
            historyEntryId: entry.id,
            title: l10n.notifPaymentDecisionTitle,
            body: body,
            doneLabel: l10n.notifActionDone,
            cancelLabel: l10n.notifActionCancel,
            keepAwake: whileWaiting,
          ),
      showConfirmed: () => notifications.showConfirmedBySms(
        title: l10n.notifConfirmedSmsTitle,
        body: body,
      ),
      stopWaiting: notifications.stopSmsWait,
    );
    return true;
  }

  Future<void> _dial() async {
    if (_dialing) return;
    setState(() => _dialing = true);

    if (!await _resolvePreviousAttempt()) {
      if (mounted) setState(() => _dialing = false);
      return;
    }
    if (!mounted) return;

    final l10n = AppLocalizations.of(context);
    final controller = ref.read(smsConfirmationControllerProvider);

    final entry = await _writeHistoryEntry();
    if (!mounted) return;

    final waitingForSms = await _startSmsWait(entry);

    final outcome = await DialerService.dial(widget.ussdCode);

    // Nothing was handed off, so there is nothing to wait for: stop the wait
    // (and its foreground service) rather than leave a prompt behind.
    if (outcome != DialOutcome.openedDialer && waitingForSms) {
      await controller.clear();
    }
    if (!mounted) return;

    // Show the decision prompt only if the dialer actually opened. If it did
    // not, the user is still in-app and the copy-fallback snack (below) is
    // enough -- no reason to bug them with an ongoing notification for a
    // payment they never handed off.
    if (outcome == DialOutcome.openedDialer && !waitingForSms) {
      await _showDecisionNotification(entry);
      if (!mounted) return;
    }

    setState(() => _dialing = false);
    _snack(
      outcome == DialOutcome.openedDialer
          ? l10n.dialerOpened
          : l10n.dialerUnavailable,
      duration: const Duration(seconds: 6),
    );
  }

  Future<void> _copyCode() async {
    final l10n = AppLocalizations.of(context);
    if (!await _resolvePreviousAttempt() || !mounted) return;
    await DialerService.copy(widget.ussdCode);
    if (!mounted) return;

    // Copy-code is the "I will paste this into the dialer myself" path -- the
    // user is about to leave the app just as they would with Open dialer, so
    // it gets the same treatment: write a history row now, start the SMS wait
    // or show the ongoing decision prompt, and let the user answer from the
    // pulldown. Still in front here, so the wait's service can start.
    final entry = await _writeHistoryEntry();
    if (!mounted) return;
    if (!await _startSmsWait(entry)) {
      if (!mounted) return;
      await _showDecisionNotification(entry);
    }
    if (!mounted) return;

    _snack(l10n.codeCopied);
  }

  Future<void> _saveFavorite() async {
    final l10n = AppLocalizations.of(context);

    // Checked before asking for a name, so the user is not made to type one
    // only to be told the recipient is already saved.
    final existing = ref
        .read(favoritesProvider.notifier)
        .existing(number: widget.phone.local, walletId: widget.wallet.id);
    if (existing != null) {
      _snack(l10n.favoriteAlreadyExists(existing.name));
      return;
    }

    // The dialog owns its own controller and disposes it itself. Doing that
    // here, right after the await, tore the controller down while the dialog
    // was still animating out and still using it.
    final name = await showDialog<String>(
      context: context,
      // Prefilled only from a real name. Seeding it with the number produced
      // favorites literally named "056 845 0493", which is no more useful than
      // the number already shown beneath it -- and, being digits in free text,
      // bidi reordered it in the list.
      // The dialog is opened from State.context (above the branded Theme in
      // build), so re-apply branding here to keep the Save button on-brand.
      builder: (dialogContext) => Theme(
        data: AppTheme.branded(dialogContext, Color(widget.wallet.colorValue)),
        child: SaveFavoriteDialog(initialName: widget.recipientName),
      ),
    );

    if (name == null || name.isEmpty || !mounted) return;

    await ref
        .read(favoritesProvider.notifier)
        .save(
          Favorite(
            name: name,
            number: widget.phone.local,
            walletId: widget.wallet.id,
            defaultType: widget.recipientType,
          ),
        );
    if (!mounted) return;
    _snack(l10n.savedAsFavorite);
  }

  void _snack(String message, {Duration? duration}) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(message),
          duration: duration ?? const Duration(seconds: 4),
        ),
      );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final localeCode = ref.watch(settingsProvider).locale?.languageCode ?? 'ar';

    // Same scoped branding as PaymentScreen so the review step feels like it
    // belongs to the same wallet the user just came from -- the amount hero
    // (primaryContainer), PIN lock icon, and Call now button all rebrand.
    //
    // `theme`/`scheme` MUST be read from a context BELOW this Theme wrapper
    // (via the Builder), otherwise `scheme.primaryContainer` on the amount
    // hero resolves to the app-default primary and the card stays blue.
    return Theme(
      data: AppTheme.branded(context, Color(widget.wallet.colorValue)),
      child: Builder(
        builder: (context) {
          final theme = Theme.of(context);
          final scheme = theme.colorScheme;
          // No silent way out: the system back gesture runs the same Cancel
          // logic as the AppBar button. Programmatic pops (Done, a
          // notification answer, an SMS confirmation) are not affected.
          return PopScope(
            canPop: false,
            onPopInvokedWithResult: (didPop, _) {
              if (!didPop) _cancel();
            },
            child: Scaffold(
              appBar: AppBar(
                title: Text(l10n.confirmTitle),
                // Cancel instead of a back arrow, so leaving after a dial is an
                // answer ("it did not go through") rather than an ambiguous
                // exit. Disabled while _dialing so it cannot race the history
                // write.
                automaticallyImplyLeading: false,
                leading: IconButton(
                  onPressed: _dialing ? null : _cancel,
                  tooltip: l10n.cancel,
                  icon: const Icon(Icons.close_rounded),
                ),
                actions: [
                  // Done ends the payment: it marks the dialed history row as
                  // done, clears the in-progress draft and returns to the home
                  // tabs. Disabled while _dialing so it cannot race the history
                  // write.
                  IconButton(
                    onPressed: _dialing
                        ? null
                        : () {
                            // The user answered in-app: _settle also drops the
                            // pulldown prompt, its pending banner and any SMS
                            // wait, which are no longer relevant.
                            final entry = _lastEntry;
                            if (entry != null) {
                              _settle(entry, HistoryStatus.done);
                            }
                            ref.read(paymentDraftProvider.notifier).reset();
                            Navigator.of(context).popUntil((r) => r.isFirst);
                          },
                    icon: const Icon(Icons.done_rounded),
                  ),
                ],
              ),
              body: SafeArea(
                child: ListView(
                  padding: const EdgeInsets.fromLTRB(
                    AppTheme.screenPadding,
                    AppTheme.gapMd,
                    AppTheme.screenPadding,
                    AppTheme.gapXl,
                  ),
                  children: [
                    _CautionBanner(text: l10n.confirmSubtitle),
                    const SizedBox(height: AppTheme.gapXl),

                    // The amount is the largest thing on the screen: it is the detail a
                    // hurried user is most likely to get wrong.
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(
                        horizontal: AppTheme.gapXl,
                        vertical: AppTheme.gapXxl,
                      ),
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                          colors: [
                            scheme.primaryContainer,
                            scheme.primaryContainer.withValues(alpha: 0.55),
                          ],
                        ),
                        borderRadius: BorderRadius.circular(AppTheme.radiusXl),
                      ),
                      child: Column(
                        children: [
                          Text(
                            l10n.amountLabel,
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: scheme.onPrimaryContainer.withValues(
                                alpha: 0.8,
                              ),
                            ),
                          ),
                          const SizedBox(height: AppTheme.gapSm),
                          Directionality(
                            textDirection: TextDirection.ltr,
                            child: Text(
                              '${formatAmountDisplay(widget.amount)} ${l10n.currencySymbol}',
                              style: theme.textTheme.displaySmall?.copyWith(
                                color: scheme.onPrimaryContainer,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: AppTheme.gapLg),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: AppTheme.gapLg,
                        vertical: AppTheme.gapXs,
                      ),
                      decoration: AppTheme.surface(context),
                      child: Column(
                        children: [
                          _DetailRow(
                            icon: Icons.person_outline_rounded,
                            label: l10n.recipientLabel,
                            value:
                                widget.recipientName ??
                                formatPhoneDisplay(widget.phone.local),
                            secondary: widget.recipientName != null
                                ? formatPhoneDisplay(widget.phone.local)
                                : carrierLabel(l10n, widget.phone.carrier),
                            trailing: IconButton(
                              onPressed: _saveFavorite,
                              tooltip: l10n.saveAsFavorite,
                              icon: const Icon(Icons.star_outline_rounded),
                            ),
                          ),
                          const Divider(),
                          _DetailRow(
                            icon: Icons.account_balance_wallet_outlined,
                            iconAsset: widget.wallet.iconAsset,
                            label: l10n.walletLabel,
                            value: widget.wallet.nameFor(localeCode),
                            secondary: recipientTypeLabel(
                              l10n,
                              widget.recipientType,
                            ),
                            accent: Color(widget.wallet.colorValue),
                          ),
                          if (widget.note.trim().isNotEmpty) ...[
                            const Divider(),
                            _DetailRow(
                              icon: Icons.notes_rounded,
                              label: l10n.notesLabel,
                              value: widget.note.trim(),
                            ),
                          ],
                        ],
                      ),
                    ),

                    if (!widget.phone.isValid) ...[
                      const SizedBox(height: AppTheme.gapMd),
                      _Warning(text: l10n.warnUnknownPrefix),
                    ],

                    const SizedBox(height: AppTheme.gapXl),
                    Text(l10n.codeLabel, style: theme.textTheme.bodySmall),
                    const SizedBox(height: AppTheme.gapMd),
                    UssdPreview(code: widget.ussdCode),
                    const SizedBox(height: AppTheme.gapMd),
                    _PinNoticeInline(text: l10n.pinNotice),

                    const SizedBox(height: AppTheme.gapXxl),
                    // Primary action beside the code utility: the user's next
                    // move is almost always "open dialer", occasionally "copy
                    // code" (dialer unavailable, or wanting to paste into
                    // another app). Pairing them keeps both within reach.
                    Row(
                      children: [
                        Expanded(
                          child: FilledButton.icon(
                            onPressed: _dialing ? null : _dial,
                            icon: const Icon(
                              Icons.phone_in_talk_rounded,
                              size: 22,
                            ),
                            label: Text(
                              l10n.callNow,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ),
                        const SizedBox(width: AppTheme.gapMd),
                        Expanded(
                          child: OutlinedButton.icon(
                            onPressed: _dialing ? null : _copyCode,
                            icon: const Icon(Icons.copy_rounded, size: 20),
                            label: Text(
                              l10n.copyCode,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: AppTheme.gapSm),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

class _CautionBanner extends StatelessWidget {
  const _CautionBanner({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    return Container(
      padding: const EdgeInsets.all(AppTheme.gapMd),
      decoration: BoxDecoration(
        color: AppTheme.warning.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(AppTheme.radiusMd),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(
            Icons.warning_amber_rounded,
            size: 24,
            color: AppTheme.warning,
          ),
          const SizedBox(width: AppTheme.gapMd),
          Expanded(
            child: Text(
              text,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: scheme.onSurface,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _DetailRow extends StatelessWidget {
  const _DetailRow({
    required this.icon,
    required this.label,
    required this.value,
    this.secondary,
    this.accent,
    this.iconAsset,
    this.trailing,
  });

  final IconData icon;
  final String label;
  final String value;
  final String? secondary;
  final Color? accent;

  /// Optional asset path shown instead of [icon]. When set (e.g. a wallet's
  /// brand mark) the image is clipped to the same rounded square as the icon
  /// badge so the row's vertical rhythm stays intact.
  final String? iconAsset;

  /// Optional trailing widget aligned to the row's end edge -- e.g. an inline
  /// action button. Sized to sit within the row without expanding it.
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final iconColor = accent ?? scheme.onSurfaceVariant;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppTheme.gapLg),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _DetailBadge(icon: icon, iconColor: iconColor, asset: iconAsset),
          const SizedBox(width: AppTheme.gapMd),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label, style: theme.textTheme.bodySmall),
                const SizedBox(height: AppTheme.gapXs),
                // Each line gets the direction its own content needs, while
                // the row itself stays in the app's direction. Wrapping these
                // in an LTR Directionality instead -- as this screen used to
                // -- also moved them to the left edge of an Arabic layout.
                Text(
                  value,
                  textDirection: directionOf(value),
                  style: theme.textTheme.titleMedium?.copyWith(fontSize: 20),
                ),
                if (secondary != null) ...[
                  const SizedBox(height: 2),
                  Text(
                    secondary!,
                    textDirection: directionOf(secondary!),
                    style: theme.textTheme.bodyMedium,
                  ),
                ],
              ],
            ),
          ),
          if (trailing != null) ...[
            const SizedBox(width: AppTheme.gapSm),
            trailing!,
          ],
        ],
      ),
    );
  }
}

class _DetailBadge extends StatelessWidget {
  const _DetailBadge({required this.icon, required this.iconColor, this.asset});

  final IconData icon;
  final Color iconColor;
  final String? asset;

  static const double _size = 40;

  @override
  Widget build(BuildContext context) {
    final tint = BoxDecoration(
      color: iconColor.withValues(alpha: 0.14),
      borderRadius: BorderRadius.circular(AppTheme.radiusSm),
    );

    if (asset == null) {
      return Container(
        width: _size,
        height: _size,
        decoration: tint,
        child: Icon(icon, size: 22, color: iconColor),
      );
    }

    return Container(
      width: _size,
      height: _size,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(AppTheme.radiusSm),
        border: Border.all(color: iconColor.withValues(alpha: 0.35), width: 1),
      ),
      clipBehavior: Clip.antiAlias,
      child: Image.asset(
        asset!,
        width: _size,
        height: _size,
        fit: BoxFit.cover,
        // A missing asset must not break the confirmation screen; fall back to
        // the tinted icon instead.
        errorBuilder: (_, _, _) => DecoratedBox(
          decoration: tint,
          child: Icon(icon, size: 22, color: iconColor),
        ),
      ),
    );
  }
}

class _Warning extends StatelessWidget {
  const _Warning({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      padding: const EdgeInsets.all(AppTheme.gapLg),
      decoration: BoxDecoration(
        color: AppTheme.warning.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(AppTheme.radiusMd),
        border: Border.all(color: AppTheme.warning, width: 1.5),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(
            Icons.warning_amber_rounded,
            size: 24,
            color: AppTheme.warning,
          ),
          const SizedBox(width: AppTheme.gapMd),
          Expanded(child: Text(text, style: theme.textTheme.bodyMedium)),
        ],
      ),
    );
  }
}

class _PinNoticeInline extends StatelessWidget {
  const _PinNoticeInline({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(Icons.lock_outline_rounded, size: 18, color: scheme.primary),
        const SizedBox(width: AppTheme.gapSm),
        Expanded(child: Text(text, style: theme.textTheme.bodySmall)),
      ],
    );
  }
}

/// Asks about the latest attempt nobody answered, before a new one replaces
/// its prompt. Pops `true` (it went through), `false` (it failed) or `null`
/// (dismissed: dial nothing, change nothing).
class _PreviousAttemptDialog extends ConsumerWidget {
  const _PreviousAttemptDialog({
    required this.entry,
    required this.samePayment,
  });

  final HistoryEntry entry;

  /// Same wallet, recipient and amount as the payment about to be dialed --
  /// the case where "it went through" means "do not pay again".
  final bool samePayment;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final localeCode = ref.watch(settingsProvider).locale?.languageCode ?? 'ar';
    final time = formatHistoryTimestamp(entry.dialedAtUtc, localeCode);
    final name = entry.recipientName;

    return AlertDialog(
      title: Text(
        samePayment ? l10n.prevAttemptSameTitle : l10n.prevAttemptOtherTitle,
      ),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // The details are what the user must recognise, so they get their
          // own lines rather than being spliced into a sentence, where an
          // Arabic paragraph would reorder the digits.
          Directionality(
            textDirection: TextDirection.ltr,
            child: Text(
              '${formatAmountDisplay(entry.amount)} ${l10n.currencySymbol}',
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
          if (name != null)
            Text(
              name,
              textDirection: directionOf(name),
              style: theme.textTheme.titleSmall,
            ),
          Directionality(
            textDirection: TextDirection.ltr,
            child: Text(
              formatPhoneDisplay(entry.recipientNumber),
              style: theme.textTheme.bodyMedium,
            ),
          ),
          const SizedBox(height: AppTheme.gapMd),
          Text(
            samePayment
                ? l10n.prevAttemptSameBody(time)
                : l10n.prevAttemptOtherBody(time),
            style: theme.textTheme.bodyMedium,
          ),
        ],
      ),
      actions: [
        TextButton(
          style: TextButton.styleFrom(minimumSize: AppTheme.dialogActionSize),
          onPressed: () => Navigator.of(context).pop(false),
          child: Text(
            samePayment ? l10n.prevAttemptTryAgain : l10n.prevAttemptNo,
          ),
        ),
        FilledButton(
          style: FilledButton.styleFrom(minimumSize: AppTheme.dialogActionSize),
          onPressed: () => Navigator.of(context).pop(true),
          child: Text(l10n.prevAttemptWentThrough),
        ),
      ],
    );
  }
}
