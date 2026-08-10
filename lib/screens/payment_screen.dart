import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/formatting.dart';
import '../l10n/generated/app_localizations.dart';
import '../models/favorite.dart';
import '../models/wallet.dart';
import '../providers/app_providers.dart';
import '../services/contact_picker_service.dart';
import '../services/phone_normalizer.dart';
import '../services/ussd_service.dart';
import '../theme/app_theme.dart';
import '../widgets/amount_field.dart';
import '../widgets/phone_field.dart';
import '../widgets/recipient_type_toggle.dart';
import 'confirm_screen.dart';

class PaymentScreen extends ConsumerStatefulWidget {
  const PaymentScreen({super.key, required this.wallet});

  final Wallet wallet;

  @override
  ConsumerState<PaymentScreen> createState() => _PaymentScreenState();
}

class _PaymentScreenState extends ConsumerState<PaymentScreen> {
  final _phoneController = TextEditingController();
  final _amountController = TextEditingController();

  /// Errors stay hidden until the user has typed something or tried to
  /// continue, so the screen does not open already scolding them.
  bool _showPhoneIssue = false;

  @override
  void initState() {
    super.initState();
    // A draft may already be populated -- from a favorite, or from coming back
    // to this screen after cancelling a confirmation.
    final draft = ref.read(paymentDraftProvider);
    _phoneController.text = draft.rawPhoneInput;
    if (draft.amountInput.isNotEmpty) {
      final amount = num.tryParse(draft.amountInput);
      _amountController.text = amount != null
          ? formatAmountDisplay(amount)
          : draft.amountInput;
    }
    _showPhoneIssue = draft.rawPhoneInput.isNotEmpty;
  }

  @override
  void dispose() {
    _phoneController.dispose();
    _amountController.dispose();
    super.dispose();
  }

  Future<void> _pickContact() async {
    final result = await ContactPickerService.pick();
    if (!mounted) return;

    final l10n = AppLocalizations.of(context);
    final contact = result.contact;
    if (contact != null) {
      _phoneController.text = contact.number;
      ref
          .read(paymentDraftProvider.notifier)
          .setRecipient(phone: contact.number, name: contact.name);
      setState(() => _showPhoneIssue = true);
      return;
    }

    final message = switch (result.failure) {
      ContactPickFailure.permissionDenied => l10n.contactsPermissionDenied,
      ContactPickFailure.noPhoneNumber => l10n.contactHasNoNumber,
      // Backing out of the picker is not an error worth a message.
      _ => null,
    };
    if (message != null) _snack(message);
  }

  Future<void> _pickFavorite() async {
    final favorites = ref.read(favoritesForWalletProvider(widget.wallet.id));
    final l10n = AppLocalizations.of(context);

    if (favorites.isEmpty) {
      _snack(l10n.emptyFavoritesBody);
      return;
    }

    final chosen = await showModalBottomSheet<Favorite>(
      context: context,
      // Re-apply the branded theme inside the sheet: the sheet is opened from
      // State.context, which lives above the Theme wrapper in build(), so its
      // subtree would otherwise fall back to the app-level primary.
      builder: (context) => Theme(
        data: AppTheme.branded(context, Color(widget.wallet.colorValue)),
        child: SafeArea(
          child: ListView(
            shrinkWrap: true,
            padding: const EdgeInsets.fromLTRB(
              AppTheme.gapMd,
              0,
              AppTheme.gapMd,
              AppTheme.gapLg,
            ),
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(
                  AppTheme.gapSm,
                  0,
                  AppTheme.gapSm,
                  AppTheme.gapMd,
                ),
                child: Text(
                  l10n.pickFromFavorites,
                  style: Theme.of(context).textTheme.titleMedium,
                ),
              ),
              for (final favorite in favorites)
                ListTile(
                  leading: CircleAvatar(
                    backgroundColor: Theme.of(
                      context,
                    ).colorScheme.primaryContainer,
                    child: Icon(
                      Icons.star_rounded,
                      size: 22,
                      color: Theme.of(context).colorScheme.onPrimaryContainer,
                    ),
                  ),
                  title: Text(favorite.name),
                  subtitle: Align(
                    alignment: AlignmentDirectional.centerStart,
                    child: Directionality(
                      textDirection: TextDirection.ltr,
                      child: Text(formatPhoneDisplay(favorite.number)),
                    ),
                  ),
                  onTap: () => Navigator.of(context).pop(favorite),
                ),
            ],
          ),
        ),
      ),
    );

    if (chosen == null || !mounted) return;

    _phoneController.text = chosen.number;
    final notifier = ref.read(paymentDraftProvider.notifier);
    notifier.setRecipient(phone: chosen.number, name: chosen.name);
    notifier.setRecipientType(chosen.defaultType);
    if (chosen.defaultAmount != null) {
      _amountController.text = formatAmountDisplay(chosen.defaultAmount!);
      notifier.setAmountInput(chosen.defaultAmount!.toString());
    }
    setState(() => _showPhoneIssue = true);
  }

  void _snack(String message) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }

  void _review() {
    final l10n = AppLocalizations.of(context);
    final draft = ref.read(paymentDraftProvider);
    final normalized = PhoneNormalizer.normalize(_phoneController.text);
    final amount = AmountField.parse(_amountController.text);

    setState(() => _showPhoneIssue = true);

    // An unknown prefix is a warning, not a blocker -- the user has already
    // been shown it under the field. Anything else means there is no number to
    // build a code from.
    if (normalized.local.isEmpty ||
        (normalized.issue != null && !isWarningOnly(normalized.issue))) {
      _snack(phoneIssueMessage(l10n, normalized.issue) ?? l10n.errorPhoneEmpty);
      return;
    }
    if (amount == null) {
      _snack(l10n.errorAmountRequired);
      return;
    }

    final type = draft.recipientType ?? widget.wallet.recipientTypes.first;

    final String code;
    try {
      code = UssdService.buildForWallet(
        wallet: widget.wallet,
        recipientType: type,
        localPhone: normalized.local,
        amount: amount,
      );
    } on UssdBuildException catch (e) {
      // Refusing to continue is the correct outcome: we cannot vouch for a
      // code we could not build.
      _snack(e.message);
      return;
    }

    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => ConfirmScreen(
          wallet: widget.wallet,
          recipientType: type,
          phone: normalized,
          recipientName: draft.recipientName,
          amount: amount,
          ussdCode: code,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final draft = ref.watch(paymentDraftProvider);
    final localeCode = ref.watch(settingsProvider).locale?.languageCode ?? 'ar';
    final normalized = PhoneNormalizer.normalize(_phoneController.text);

    // A scoped Theme so every primary-family surface on this screen (step
    // circles, focus rings, the Review button, the recipient-type toggle,
    // the currency symbol) picks up the wallet's brand color. Neutrals stay
    // the app's, so the scaffold does not flicker between wallets.
    return Theme(
      data: AppTheme.branded(context, Color(widget.wallet.colorValue)),
      child: Scaffold(
        appBar: AppBar(title: Text(widget.wallet.nameFor(localeCode))),
        body: SafeArea(
          child: ListView(
            padding: const EdgeInsets.fromLTRB(
              AppTheme.screenPadding,
              AppTheme.gapXl,
              AppTheme.screenPadding,
              AppTheme.gapXl,
            ),
            children: [
              _Section(
                step: '1',
                title: l10n.recipientTypeQuestion,
                child: RecipientTypeToggle(
                  types: widget.wallet.recipientTypes,
                  selected: draft.recipientType,
                  onChanged: (type) => ref
                      .read(paymentDraftProvider.notifier)
                      .setRecipientType(type),
                ),
              ),
              const SizedBox(height: AppTheme.gapXl),
              _Section(
                step: '2',
                title: l10n.phoneNumberLabel,
                child: PhoneField(
                  controller: _phoneController,
                  normalized: normalized,
                  recipientName: draft.recipientName,
                  showIssue: _showPhoneIssue,
                  onChanged: (value) {
                    ref
                        .read(paymentDraftProvider.notifier)
                        .setPhoneInput(value);
                    setState(() => _showPhoneIssue = value.isNotEmpty);
                  },
                  onPickContact: _pickContact,
                  onPickFavorite: _pickFavorite,
                ),
              ),
              const SizedBox(height: AppTheme.gapXl),
              _Section(
                step: '3',
                title: l10n.amountLabel,
                child: AmountField(
                  controller: _amountController,
                  onChanged: (value) {
                    final amount = AmountField.parse(value);
                    ref
                        .read(paymentDraftProvider.notifier)
                        .setAmountInput(amount?.toString() ?? '');
                    setState(() {});
                  },
                ),
              ),
              const SizedBox(height: AppTheme.gapXxl),
              FilledButton.icon(
                onPressed: _review,
                icon: const Icon(Icons.arrow_forward_rounded),
                label: Text(l10n.reviewPayment),
              ),
              const SizedBox(height: AppTheme.gapMd),
              Text(
                l10n.reviewPaymentHint,
                textAlign: TextAlign.center,
                style: theme.textTheme.bodySmall,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// One numbered step of the payment form, on its own card.
class _Section extends StatelessWidget {
  const _Section({
    required this.step,
    required this.title,
    required this.child,
  });

  final String step;
  final String title;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    return Container(
      padding: const EdgeInsets.all(AppTheme.gapLg),
      decoration: AppTheme.surface(context),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 26,
                height: 26,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: scheme.primary,
                  shape: BoxShape.circle,
                ),
                child: Text(
                  step,
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: scheme.onPrimary,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              const SizedBox(width: AppTheme.gapMd),
              Expanded(child: Text(title, style: theme.textTheme.titleMedium)),
            ],
          ),
          const SizedBox(height: AppTheme.gapLg),
          child,
        ],
      ),
    );
  }
}
