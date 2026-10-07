import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../l10n/generated/app_localizations.dart';
import '../providers/app_providers.dart';
import '../theme/app_theme.dart';

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
            const SizedBox(height: AppTheme.gapXl),
            _SectionHeader(title: l10n.data),
            const _SettingsCard(child: _ClearHistoryTile()),
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
