import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/formatting.dart';
import '../l10n/generated/app_localizations.dart';
import '../models/favorite.dart';
import '../models/wallet.dart';
import '../providers/app_providers.dart';
import '../services/contact_picker_service.dart';
import '../services/phone_normalizer.dart';
import '../theme/app_theme.dart';
import '../widgets/choice_tile.dart';
import '../widgets/form_section.dart';
import '../widgets/phone_field.dart';
import '../widgets/recipient_type_toggle.dart';
import '../widgets/wallet_choice_tile.dart';

/// Saves a recipient without first making a payment to them, or edits one
/// already saved when [initial] is given.
///
/// Only what a favorite stores: wallet, recipient type, number, name. No
/// amount and never a PIN.
class AddFavoriteScreen extends ConsumerStatefulWidget {
  const AddFavoriteScreen({super.key, this.initial});

  /// The favorite being edited, or null to add a new one. Saving an edit
  /// keeps its id, so the stored row is overwritten in place.
  final Favorite? initial;

  @override
  ConsumerState<AddFavoriteScreen> createState() => _AddFavoriteScreenState();
}

class _AddFavoriteScreenState extends ConsumerState<AddFavoriteScreen> {
  final _phoneController = TextEditingController();
  final _nameController = TextEditingController();
  final _nameFocus = FocusNode();

  /// Null until the user picks one; the first wallet is used until then.
  String? _walletId;
  String? _recipientType;

  /// Errors stay hidden until the user has typed something or tried to save,
  /// so the screen does not open already scolding them.
  bool _showPhoneIssue = false;

  @override
  void initState() {
    super.initState();
    final initial = widget.initial;
    if (initial != null) {
      _phoneController.text = initial.number;
      _nameController.text = initial.name;
      _walletId = initial.walletId;
      _recipientType = initial.defaultType;
      // A saved number with an unusual prefix should still show its warning.
      _showPhoneIssue = true;
    }
  }

  /// The favorite with the same number on this wallet, other than the one
  /// being edited: an unchanged favorite must not count as its own duplicate.
  Favorite? _duplicateOf(String number, String walletId) {
    final existing = ref
        .read(favoritesProvider.notifier)
        .existing(number: number, walletId: walletId);
    return existing != null && existing.id != widget.initial?.id
        ? existing
        : null;
  }

  @override
  void dispose() {
    _phoneController.dispose();
    _nameController.dispose();
    _nameFocus.dispose();
    super.dispose();
  }

  Wallet _walletFrom(List<Wallet> wallets) =>
      wallets.where((w) => w.id == _walletId).firstOrNull ?? wallets.first;

  /// The selected type if this wallet offers it, else the wallet's first, so
  /// switching wallets can never leave a type the template map lacks.
  String _typeFor(Wallet wallet) {
    final type = _recipientType;
    return type != null && wallet.recipientTypes.contains(type)
        ? type
        : wallet.recipientTypes.first;
  }

  Future<void> _pickContact() async {
    final result = await ContactPickerService.pick();
    if (!mounted) return;

    final l10n = AppLocalizations.of(context);
    final contact = result.contact;
    if (contact != null) {
      _phoneController.text = contact.number;
      // Fills the name only if the user has not typed one: picking a number
      // should not silently overwrite a name they chose.
      final name = contact.name;
      if (name != null && _nameController.text.trim().isEmpty) {
        _nameController.text = name;
      }
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

  Future<void> _save(Wallet wallet) async {
    final l10n = AppLocalizations.of(context);
    final name = _nameController.text.trim();
    final normalized = PhoneNormalizer.normalize(_phoneController.text);

    setState(() => _showPhoneIssue = true);

    // Same rule as the payment screen: an unknown prefix is only a warning,
    // anything else means there is no number worth saving.
    if (normalized.local.isEmpty ||
        (normalized.issue != null && !isWarningOnly(normalized.issue))) {
      _snack(phoneIssueMessage(l10n, normalized.issue) ?? l10n.errorPhoneEmpty);
      return;
    }
    if (name.isEmpty) return;

    // Also checked live in build; kept here as the guard of record.
    final existing = _duplicateOf(normalized.local, wallet.id);
    if (existing != null) {
      _snack(l10n.favoriteAlreadyExists(existing.name));
      return;
    }

    final messenger = ScaffoldMessenger.of(context);
    final navigator = Navigator.of(context);
    final initial = widget.initial;
    // copyWith keeps the id, so the edit overwrites the stored row, and
    // keeps defaultAmount, which this form does not show.
    final favorite = initial == null
        ? Favorite(
            name: name,
            number: normalized.local,
            walletId: wallet.id,
            defaultType: _typeFor(wallet),
          )
        : initial.copyWith(
            name: name,
            number: normalized.local,
            walletId: wallet.id,
            defaultType: _typeFor(wallet),
          );
    await ref.read(favoritesProvider.notifier).save(favorite);
    if (!mounted) return;
    navigator.pop();
    messenger
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(
            initial == null ? l10n.savedAsFavorite : l10n.favoriteUpdated,
          ),
        ),
      );
  }

  String _title(AppLocalizations l10n) =>
      widget.initial == null ? l10n.addFavorite : l10n.editFavorite;

  void _snack(String message) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final title = _title(l10n);

    return ref
        .watch(walletsProvider)
        .when(
          loading: () => Scaffold(
            appBar: AppBar(title: Text(title)),
            body: const Center(child: CircularProgressIndicator()),
          ),
          // A broken wallets.json is a build error, but the screen must still
          // say so rather than spin forever.
          error: (error, _) => Scaffold(
            appBar: AppBar(title: Text(title)),
            body: Center(
              child: Padding(
                padding: const EdgeInsets.all(AppTheme.screenPadding),
                child: Text('$error', textAlign: TextAlign.center),
              ),
            ),
          ),
          data: (wallets) => _form(context, wallets),
        );
  }

  Widget _form(BuildContext context, List<Wallet> wallets) {
    final l10n = AppLocalizations.of(context);
    final localeCode = ref.watch(settingsProvider).locale?.languageCode ?? 'ar';
    // Watched so the duplicate check below re-runs if favorites change.
    ref.watch(favoritesProvider);

    final wallet = _walletFrom(wallets);
    final normalized = PhoneNormalizer.normalize(_phoneController.text);
    final name = _nameController.text;

    // Live, not only on Save: the user learns the recipient is already saved
    // while looking at the number, and switching wallet re-checks at once.
    final duplicate = normalized.local.isEmpty
        ? null
        : _duplicateOf(normalized.local, wallet.id);

    // An edit that changes nothing has nothing to save. The number compares
    // normalized, so retyping 0599… as +970599… is not a change.
    final initial = widget.initial;
    final changed =
        initial == null ||
        normalized.local != initial.number ||
        name.trim() != initial.name ||
        wallet.id != initial.walletId ||
        _typeFor(wallet) != initial.defaultType;
    final canSave = name.trim().isNotEmpty && duplicate == null && changed;

    // Branded like the payment screen, and re-branded as the wallet changes,
    // so the colour on screen always matches the wallet being saved to.
    return Theme(
      data: AppTheme.branded(context, Color(wallet.colorValue)),
      child: Scaffold(
        appBar: AppBar(title: Text(_title(l10n))),
        // The Save bar is part of the body, not a bottomNavigationBar: the
        // body shrinks above the keyboard, so Save stays reachable while
        // typing instead of hiding under it.
        body: Column(
          children: [
            Expanded(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(
                  AppTheme.screenPadding,
                  AppTheme.gapXl,
                  AppTheme.screenPadding,
                  AppTheme.gapXl,
                ),
                children: [
                  FormSection(
                    title: l10n.walletLabel,
                    child: ChoiceTileRows(
                      children: [
                        for (final w in wallets)
                          WalletChoiceTile(
                            wallet: w,
                            localeCode: localeCode,
                            selected: w.id == wallet.id,
                            onTap: () => setState(() => _walletId = w.id),
                          ),
                      ],
                    ),
                  ),
                  const SizedBox(height: AppTheme.gapXl),
                  FormSection(
                    title: l10n.recipientTypeSection,
                    child: RecipientTypeToggle(
                      types: wallet.recipientTypes,
                      selected: _typeFor(wallet),
                      onChanged: (type) =>
                          setState(() => _recipientType = type),
                    ),
                  ),
                  const SizedBox(height: AppTheme.gapXl),
                  FormSection(
                    title: l10n.recipientLabel,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        PhoneField(
                          controller: _phoneController,
                          normalized: normalized,
                          showIssue: _showPhoneIssue,
                          // Only when adding: on an edit the keyboard would
                          // cover the pre-filled form the user came to check.
                          autofocus: widget.initial == null,
                          textInputAction: TextInputAction.next,
                          onSubmitted: (_) => _nameFocus.requestFocus(),
                          onChanged: (value) => setState(
                            () => _showPhoneIssue = value.isNotEmpty,
                          ),
                          onPickContact: _pickContact,
                        ),
                        const SizedBox(height: AppTheme.gapLg),
                        TextField(
                          controller: _nameController,
                          focusNode: _nameFocus,
                          textCapitalization: TextCapitalization.words,
                          textInputAction: TextInputAction.done,
                          // A name the user typed: a Latin or numeric one
                          // would otherwise be reordered by bidi inside the
                          // Arabic layout. Empty keeps the ambient direction
                          // so the cursor starts on the reading side.
                          textDirection: name.isEmpty
                              ? null
                              : directionOf(name),
                          onChanged: (_) => setState(() {}),
                          onSubmitted: (_) {
                            if (canSave) _save(wallet);
                          },
                          decoration: InputDecoration(
                            labelText: l10n.favoriteNameLabel,
                            prefixIcon: const Icon(Icons.person_outline),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            _SaveBar(
              duplicateOf: duplicate?.name,
              onSave: canSave ? () => _save(wallet) : null,
            ),
          ],
        ),
      ),
    );
  }
}

/// Pinned under the form: the Save button, and why it is disabled when the
/// recipient is already saved.
class _SaveBar extends StatelessWidget {
  const _SaveBar({required this.duplicateOf, required this.onSave});

  /// Name of the favorite this one would duplicate, if any.
  final String? duplicateOf;
  final VoidCallback? onSave;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final duplicateOf = this.duplicateOf;

    return DecoratedBox(
      decoration: BoxDecoration(
        color: theme.scaffoldBackgroundColor,
        border: Border(top: BorderSide(color: scheme.outlineVariant)),
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(
            AppTheme.screenPadding,
            AppTheme.gapMd,
            AppTheme.screenPadding,
            AppTheme.gapMd,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (duplicateOf != null) ...[
                Row(
                  children: [
                    const Icon(
                      Icons.info_outline,
                      size: 20,
                      color: AppTheme.warning,
                    ),
                    const SizedBox(width: AppTheme.gapSm),
                    Expanded(
                      child: Text(
                        l10n.favoriteAlreadyExists(duplicateOf),
                        style: theme.textTheme.bodySmall,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: AppTheme.gapMd),
              ],
              FilledButton.icon(
                onPressed: onSave,
                icon: const Icon(Icons.star_rounded),
                label: Text(l10n.save),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
