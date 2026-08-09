import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../l10n/generated/app_localizations.dart';
import '../providers/app_providers.dart';
import '../theme/app_theme.dart';
import '../widgets/wallet_card.dart';
import 'payment_screen.dart';

class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final wallets = ref.watch(walletsProvider);
    final localeCode = ref.watch(settingsProvider).locale?.languageCode ?? 'ar';

    return wallets.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      // A broken wallets.json means no code can be built safely, so the screen
      // says so instead of showing an empty list the user cannot act on.
      error: (error, _) => _ConfigError(
        message: '${l10n.loadFailedBody}\n\n$error',
        onRetry: () => ref.invalidate(walletsProvider),
      ),
      data: (list) => ListView(
        padding: const EdgeInsets.fromLTRB(
          AppTheme.screenPadding,
          AppTheme.gapXl,
          AppTheme.screenPadding,
          AppTheme.gapXxl,
        ),
        children: [
          Text(l10n.chooseWallet, style: theme.textTheme.headlineSmall),
          const SizedBox(height: AppTheme.gapXs),
          Text(l10n.chooseWalletSubtitle, style: theme.textTheme.bodyMedium),
          const SizedBox(height: AppTheme.gapXl),
          for (final wallet in list) ...[
            WalletCard(
              wallet: wallet,
              localeCode: localeCode,
              onTap: () {
                ref.read(paymentDraftProvider.notifier).start(wallet);
                Navigator.of(context).push(
                  MaterialPageRoute<void>(
                    builder: (_) => PaymentScreen(wallet: wallet),
                  ),
                );
              },
            ),
            const SizedBox(height: AppTheme.gapLg),
          ],
          const SizedBox(height: AppTheme.gapSm),
          _PinNotice(text: l10n.pinNotice),
        ],
      ),
    );
  }
}

/// Shown on the home screen, not buried in settings: the single most valuable
/// thing a user of a payment app can know is that it will never ask for a PIN,
/// so no imitation of it can either.
class _PinNotice extends StatelessWidget {
  const _PinNotice({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    return Container(
      padding: const EdgeInsets.all(AppTheme.gapLg),
      decoration: BoxDecoration(
        color: scheme.primaryContainer.withValues(alpha: 0.35),
        borderRadius: BorderRadius.circular(AppTheme.radiusLg),
        border: Border.all(color: scheme.primary.withValues(alpha: 0.25)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(AppTheme.gapSm),
            decoration: BoxDecoration(
              color: scheme.primary.withValues(alpha: 0.15),
              shape: BoxShape.circle,
            ),
            child: Icon(Icons.lock_rounded, size: 20, color: scheme.primary),
          ),
          const SizedBox(width: AppTheme.gapMd),
          Expanded(child: Text(text, style: theme.textTheme.bodySmall)),
        ],
      ),
    );
  }
}

class _ConfigError extends StatelessWidget {
  const _ConfigError({required this.message, required this.onRetry});

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    return Padding(
      padding: const EdgeInsets.all(AppTheme.gapXl),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 96,
            height: 96,
            decoration: BoxDecoration(
              color: scheme.errorContainer,
              shape: BoxShape.circle,
            ),
            child: Icon(Icons.error_outline_rounded,
                size: 48, color: scheme.onErrorContainer),
          ),
          const SizedBox(height: AppTheme.gapXl),
          Text(
            l10n.loadFailedTitle,
            textAlign: TextAlign.center,
            style: theme.textTheme.titleLarge,
          ),
          const SizedBox(height: AppTheme.gapMd),
          Text(
            message,
            textAlign: TextAlign.center,
            style: theme.textTheme.bodyMedium,
          ),
          const SizedBox(height: AppTheme.gapXl),
          FilledButton.icon(
            onPressed: onRetry,
            icon: const Icon(Icons.refresh_rounded),
            label: Text(l10n.retry),
          ),
        ],
      ),
    );
  }
}
