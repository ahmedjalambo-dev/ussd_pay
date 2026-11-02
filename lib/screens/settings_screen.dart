import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../l10n/generated/app_localizations.dart';
import '../models/confirmation_modes.dart';
import '../models/wallet.dart';
import '../providers/app_providers.dart';
import '../theme/app_theme.dart';
import '../widgets/wallet_card.dart';

class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final settings = ref.watch(settingsProvider);
    final notifier = ref.read(settingsProvider.notifier);
    final localeCode = settings.locale?.languageCode ?? 'ar';

    return Scaffold(
      appBar: AppBar(title: Text(l10n.settings)),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(
            AppTheme.screenPadding,
            AppTheme.gapLg,
            AppTheme.screenPadding,
            AppTheme.gapXl,
          ),
          children: [
            _SectionHeader(title: l10n.language),
            _SettingsCard(
              // RadioGroup, not a segmented control: it keeps the selected
              // state announced to screen readers, and the two labels are long
              // enough that a segmented row would truncate them.
              child: RadioGroup<String>(
                groupValue: localeCode,
                onChanged: (code) {
                  if (code != null) notifier.setLocale(Locale(code));
                },
                child: const Column(
                  children: [
                    _LanguageTile(value: 'ar'),
                    Divider(indent: AppTheme.gapLg, endIndent: AppTheme.gapLg),
                    _LanguageTile(value: 'en'),
                  ],
                ),
              ),
            ),
            const SizedBox(height: AppTheme.gapXl),
            _SectionHeader(title: l10n.appearance),
            _SettingsCard(
              child: RadioGroup<ThemeMode>(
                groupValue: settings.themeMode,
                onChanged: (mode) {
                  if (mode != null) notifier.setThemeMode(mode);
                },
                child: const Column(
                  children: [
                    _ThemeTile(
                      value: ThemeMode.dark,
                      icon: Icons.dark_mode_outlined,
                    ),
                    Divider(indent: AppTheme.gapLg, endIndent: AppTheme.gapLg),
                    _ThemeTile(
                      value: ThemeMode.light,
                      icon: Icons.light_mode_outlined,
                    ),
                    Divider(indent: AppTheme.gapLg, endIndent: AppTheme.gapLg),
                    _ThemeTile(
                      value: ThemeMode.system,
                      icon: Icons.brightness_auto_outlined,
                    ),
                  ],
                ),
              ),
            ),
            const _ConfirmationSection(),
            const SizedBox(height: AppTheme.gapXl),
            _SectionHeader(title: l10n.data),
            const _SettingsCard(child: _ClearHistoryTile()),
            const SizedBox(height: AppTheme.gapXl),
            _SectionHeader(title: l10n.help),
            _SettingsCard(
              child: ListTile(
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: AppTheme.gapLg,
                ),
                leading: const Icon(Icons.tour_outlined, size: 24),
                title: Text(l10n.appTour, style: theme.textTheme.titleSmall),
                subtitle: Text(
                  l10n.appTourSubtitle,
                  style: theme.textTheme.bodySmall,
                ),
                // The tour runs on the main tabs, so Settings closes and
                // the root screen starts it.
                onTap: () => Navigator.of(context).pop(true),
              ),
            ),
            const SizedBox(height: AppTheme.gapXl),
            _SectionHeader(title: l10n.about),
            _SettingsCard(
              child: Padding(
                padding: const EdgeInsets.all(AppTheme.gapLg),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _AboutLine(
                      icon: Icons.wifi_off_rounded,
                      text: l10n.aboutOffline,
                    ),
                    const SizedBox(height: AppTheme.gapLg),
                    _AboutLine(
                      icon: Icons.lock_outline_rounded,
                      text: l10n.aboutNoPin,
                    ),
                    const SizedBox(height: AppTheme.gapLg),
                    Divider(
                      color: scheme.outlineVariant.withValues(alpha: 0.5),
                    ),
                    const SizedBox(height: AppTheme.gapMd),
                    Text(l10n.appTitle, style: theme.textTheme.labelSmall),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _LanguageTile extends StatelessWidget {
  const _LanguageTile({required this.value});

  final String value;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return RadioListTile<String>(
      value: value,
      contentPadding: const EdgeInsets.symmetric(horizontal: AppTheme.gapMd),
      title: Text(
        value == 'ar' ? l10n.languageArabic : l10n.languageEnglish,
        style: Theme.of(context).textTheme.titleSmall,
      ),
    );
  }
}

class _ThemeTile extends StatelessWidget {
  const _ThemeTile({required this.value, required this.icon});

  final ThemeMode value;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final label = switch (value) {
      ThemeMode.dark => l10n.themeDark,
      ThemeMode.light => l10n.themeLight,
      ThemeMode.system => l10n.themeSystem,
    };

    return RadioListTile<ThemeMode>(
      value: value,
      contentPadding: const EdgeInsets.symmetric(horizontal: AppTheme.gapMd),
      secondary: Icon(icon, size: 24),
      title: Text(label, style: Theme.of(context).textTheme.titleSmall),
    );
  }
}

/// Wipes every history row in both tabs. Lives here rather than on the
/// history screen: it is rare and irreversible, so it sits away from the
/// everyday list, behind a confirmation.
class _ClearHistoryTile extends ConsumerWidget {
  const _ClearHistoryTile();

  Future<void> _confirmClear(BuildContext context, WidgetRef ref) async {
    final l10n = AppLocalizations.of(context);
    final messenger = ScaffoldMessenger.of(context);
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(l10n.clearHistory),
        content: Text(l10n.clearHistoryMessage),
        actions: [
          TextButton(
            style: TextButton.styleFrom(minimumSize: AppTheme.dialogActionSize),
            onPressed: () => Navigator.of(context).pop(false),
            child: Text(l10n.cancel),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              minimumSize: AppTheme.dialogActionSize,
            ),
            onPressed: () => Navigator.of(context).pop(true),
            child: Text(l10n.clear),
          ),
        ],
      ),
    );
    if (confirmed ?? false) {
      await ref.read(historyProvider.notifier).clear();
      messenger
        ..hideCurrentSnackBar()
        ..showSnackBar(SnackBar(content: Text(l10n.historyCleared)));
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final hasAny = ref.watch(historyProvider).isNotEmpty;

    return ListTile(
      enabled: hasAny,
      contentPadding: const EdgeInsets.symmetric(horizontal: AppTheme.gapLg),
      iconColor: theme.colorScheme.error,
      textColor: theme.colorScheme.error,
      leading: const Icon(Icons.delete_sweep_outlined, size: 24),
      title: Text(l10n.clearHistory, style: theme.textTheme.titleSmall),
      subtitle: Text(
        l10n.clearHistoryMessage,
        style: theme.textTheme.bodySmall,
      ),
      onTap: () => _confirmClear(context, ref),
    );
  }
}

/// Per wallet: confirm payments from the wallet's SMS, by asking, or both.
///
/// Hidden entirely off Android and for wallets whose `wallets.json` entry
/// has no `smsConfirmation` patterns -- there is no choice to make there.
class _ConfirmationSection extends ConsumerStatefulWidget {
  const _ConfirmationSection();

  @override
  ConsumerState<_ConfirmationSection> createState() =>
      _ConfirmationSectionState();
}

class _ConfirmationSectionState extends ConsumerState<_ConfirmationSection>
    with WidgetsBindingObserver {
  /// `null` until the first check returns.
  bool? _accessGranted;

  /// True when Android still applies battery optimization to the app.
  bool _batteryRestricted = false;

  /// The wallet whose SMS switch the user tried to turn on before granting
  /// access. Turned on when they come back from system settings with access
  /// granted -- and left off if they come back without it.
  String? _enableOnReturn;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _refreshAccess();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) _refreshAccess();
  }

  Future<void> _refreshAccess() async {
    final source = ref.read(smsNotificationSourceProvider);
    final granted = await source.isAccessGranted();
    final batteryFree = await source.isIgnoringBatteryOptimizations();
    if (!mounted) return;
    setState(() {
      _accessGranted = granted;
      _batteryRestricted = !batteryFree;
    });

    final walletId = _enableOnReturn;
    _enableOnReturn = null;
    if (granted && walletId != null) _update(walletId, sms: true);
  }

  void _update(String walletId, {bool? sms, bool? manual}) {
    final settings = ref.read(settingsProvider);
    ref
        .read(settingsProvider.notifier)
        .setConfirmationModes(
          walletId,
          settings.modesFor(walletId).copyWith(sms: sms, manual: manual),
        );
  }

  Future<void> _turnOnSms(Wallet wallet, String walletName) async {
    if (_accessGranted ?? false) {
      _update(wallet.id, sms: true);
      return;
    }
    final l10n = AppLocalizations.of(context);
    final open = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(l10n.smsAccessTitle),
        content: Text(l10n.smsAccessBody(walletName)),
        actions: [
          TextButton(
            style: TextButton.styleFrom(minimumSize: AppTheme.dialogActionSize),
            onPressed: () => Navigator.of(context).pop(false),
            child: Text(l10n.cancel),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              minimumSize: AppTheme.dialogActionSize,
            ),
            onPressed: () => Navigator.of(context).pop(true),
            child: Text(l10n.smsAccessOpenSettings),
          ),
        ],
      ),
    );
    if (!(open ?? false) || !mounted) return;
    _enableOnReturn = wallet.id;
    await ref.read(smsNotificationSourceProvider).openAccessSettings();
  }

  @override
  Widget build(BuildContext context) {
    final source = ref.watch(smsNotificationSourceProvider);
    if (!source.isSupported) return const SizedBox.shrink();

    final wallets = (ref.watch(walletsProvider).value ?? const <Wallet>[])
        .where((w) => w.smsConfirmation != null)
        .toList(growable: false);
    if (wallets.isEmpty) return const SizedBox.shrink();

    final l10n = AppLocalizations.of(context);
    final settings = ref.watch(settingsProvider);
    final localeCode = settings.locale?.languageCode ?? 'ar';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const SizedBox(height: AppTheme.gapXl),
        _SectionHeader(title: l10n.confirmationSection),
        for (final (i, wallet) in wallets.indexed) ...[
          if (i > 0) const SizedBox(height: AppTheme.gapMd),
          _SettingsCard(
            child: _WalletConfirmationTiles(
              wallet: wallet,
              walletName: wallet.nameFor(localeCode),
              modes: settings.modesFor(wallet.id),
              accessMissing: _accessGranted == false,
              batteryRestricted: _batteryRestricted,
              onSmsChanged: (on) => on
                  ? _turnOnSms(wallet, wallet.nameFor(localeCode))
                  : _update(wallet.id, sms: false),
              onManualChanged: (on) => _update(wallet.id, manual: on),
              onGrantAccess: () =>
                  _turnOnSms(wallet, wallet.nameFor(localeCode)),
              onOpenBattery: ref
                  .read(smsNotificationSourceProvider)
                  .openBatterySettings,
            ),
          ),
        ],
      ],
    );
  }
}

class _WalletConfirmationTiles extends StatelessWidget {
  const _WalletConfirmationTiles({
    required this.wallet,
    required this.walletName,
    required this.modes,
    required this.accessMissing,
    required this.batteryRestricted,
    required this.onSmsChanged,
    required this.onManualChanged,
    required this.onGrantAccess,
    required this.onOpenBattery,
  });

  final Wallet wallet;
  final String walletName;
  final ConfirmationModes modes;
  final bool accessMissing;
  final bool batteryRestricted;
  final ValueChanged<bool> onSmsChanged;
  final ValueChanged<bool> onManualChanged;
  final VoidCallback onGrantAccess;
  final VoidCallback onOpenBattery;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    const tilePadding = EdgeInsets.symmetric(horizontal: AppTheme.gapLg);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(
            AppTheme.gapLg,
            AppTheme.gapLg,
            AppTheme.gapLg,
            AppTheme.gapSm,
          ),
          child: Row(
            children: [
              WalletMark(
                wallet: wallet,
                onBrand: Color(wallet.colorValue),
                size: 32,
              ),
              const SizedBox(width: AppTheme.gapMd),
              Expanded(
                child: Text(walletName, style: theme.textTheme.titleSmall),
              ),
            ],
          ),
        ),
        // The switch that is the last one on is disabled rather than allowed
        // to turn off: with neither, a payment could never leave Cancelled.
        SwitchListTile(
          contentPadding: tilePadding,
          value: modes.sms,
          onChanged: modes.sms && !modes.manual ? null : onSmsChanged,
          secondary: const Icon(Icons.mark_chat_read_outlined, size: 24),
          title: Text(l10n.confirmBySms, style: theme.textTheme.titleSmall),
          subtitle: Text(
            l10n.confirmBySmsSubtitle(walletName),
            style: theme.textTheme.bodySmall,
          ),
        ),
        if (modes.sms && accessMissing)
          _InlineNotice(
            text: l10n.smsAccessMissing,
            actionLabel: l10n.smsAccessGrant,
            onPressed: onGrantAccess,
            color: scheme.error,
          )
        // Access first: battery only matters once there is something to
        // deliver.
        else if (modes.sms && batteryRestricted)
          _InlineNotice(
            text: l10n.batteryRestricted,
            actionLabel: l10n.batteryOpen,
            onPressed: onOpenBattery,
            color: scheme.tertiary,
          ),
        const Divider(indent: AppTheme.gapLg, endIndent: AppTheme.gapLg),
        SwitchListTile(
          contentPadding: tilePadding,
          value: modes.manual,
          onChanged: modes.manual && !modes.sms ? null : onManualChanged,
          secondary: const Icon(Icons.touch_app_outlined, size: 24),
          title: Text(l10n.confirmManually, style: theme.textTheme.titleSmall),
          subtitle: Text(
            modes.sms
                ? l10n.confirmManuallyFallbackSubtitle
                : l10n.confirmManuallySubtitle,
            style: theme.textTheme.bodySmall,
          ),
        ),
      ],
    );
  }
}

/// One-line warning under a switch, with the action that fixes it.
class _InlineNotice extends StatelessWidget {
  const _InlineNotice({
    required this.text,
    required this.actionLabel,
    required this.onPressed,
    required this.color,
  });

  final String text;
  final String actionLabel;
  final VoidCallback onPressed;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppTheme.gapLg,
        0,
        AppTheme.gapLg,
        AppTheme.gapSm,
      ),
      child: Row(
        children: [
          Icon(Icons.info_outline_rounded, size: 18, color: color),
          const SizedBox(width: AppTheme.gapSm),
          Expanded(
            child: Text(
              text,
              style: theme.textTheme.bodySmall?.copyWith(color: color),
            ),
          ),
          TextButton(
            style: TextButton.styleFrom(minimumSize: AppTheme.dialogActionSize),
            onPressed: onPressed,
            child: Text(actionLabel),
          ),
        ],
      ),
    );
  }
}

class _SettingsCard extends StatelessWidget {
  const _SettingsCard({required this.child});

  final Widget child;

  // A transparent Material sits inside the decorated container so the
  // RadioListTile's ink splash paints on top of the card fill instead of on
  // the Scaffold's Material behind it -- which the fill would hide, and which
  // is what Flutter's "ink splashes may be invisible" assertion warns about.
  @override
  Widget build(BuildContext context) => Container(
    decoration: AppTheme.surface(context),
    clipBehavior: Clip.antiAlias,
    child: Material(type: MaterialType.transparency, child: child),
  );
}

class _SectionHeader extends StatelessWidget {
  const _SectionHeader({required this.title});

  final String title;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppTheme.gapXs,
        0,
        AppTheme.gapXs,
        AppTheme.gapMd,
      ),
      child: Text(
        title,
        style: theme.textTheme.labelMedium?.copyWith(
          color: theme.colorScheme.primary,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

class _AboutLine extends StatelessWidget {
  const _AboutLine({required this.icon, required this.text});

  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          padding: const EdgeInsets.all(AppTheme.gapSm),
          decoration: BoxDecoration(
            color: scheme.primaryContainer.withValues(alpha: 0.5),
            borderRadius: BorderRadius.circular(AppTheme.radiusSm),
          ),
          child: Icon(icon, size: 20, color: scheme.onPrimaryContainer),
        ),
        const SizedBox(width: AppTheme.gapMd),
        Expanded(child: Text(text, style: theme.textTheme.bodyMedium)),
      ],
    );
  }
}
