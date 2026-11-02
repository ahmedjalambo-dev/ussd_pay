import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../l10n/generated/app_localizations.dart';
import '../models/history_entry.dart';
import '../models/wallet.dart';
import '../providers/app_providers.dart';
import '../theme/app_theme.dart';
import '../widgets/empty_state.dart';
import '../widgets/history_tile.dart';
import '../widgets/payment_details_sheet.dart';

class HistoryScreen extends ConsumerStatefulWidget {
  const HistoryScreen({super.key});

  /// Deletes every selected row at once and offers Undo, rather than asking
  /// first: selecting rows and pressing delete is already two deliberate
  /// steps, and Undo puts the rows back exactly as they were (same id,
  /// timestamp and status, so the same place in the same tab). Public so the
  /// root AppBar, which owns the delete action, can call it.
  static Future<void> deleteSelected(
    BuildContext context,
    WidgetRef ref,
  ) async {
    final l10n = AppLocalizations.of(context);
    final messenger = ScaffoldMessenger.of(context);
    final ids = ref.read(historySelectionProvider).ids;
    final removed = ref
        .read(historyProvider)
        .where((e) => ids.contains(e.id))
        .toList(growable: false);
    if (removed.isEmpty) return;

    final notifier = ref.read(historyProvider.notifier);
    ref.read(historySelectionProvider.notifier).clear();
    await notifier.deleteMany(removed.map((e) => e.id));

    messenger
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(l10n.historyEntriesDeleted(removed.length)),
          action: SnackBarAction(
            label: l10n.undo,
            onPressed: () => notifier.restore(removed),
          ),
        ),
      );
  }

  @override
  ConsumerState<HistoryScreen> createState() => _HistoryScreenState();
}

class _HistoryScreenState extends ConsumerState<HistoryScreen>
    with SingleTickerProviderStateMixin {
  static const _tabs = [HistoryStatus.done, HistoryStatus.cancelled];

  // Created in initState, not as a lazy `late final`: with empty history the
  // TabBar is never built, so the first touch would be dispose() itself,
  // creating a ticker on an already-deactivated element.
  late final TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: _tabs.length, vsync: this)
      ..addListener(_onTabChanged);
  }

  void _onTabChanged() {
    ref
        .read(historySelectionProvider.notifier)
        .setTab(_tabs[_tabController.index]);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final hasAny = ref.watch(historyProvider).isNotEmpty;
    final done = ref.watch(historyByStatusProvider(HistoryStatus.done));
    final cancelled = ref.watch(
      historyByStatusProvider(HistoryStatus.cancelled),
    );

    if (!hasAny) {
      return EmptyState(
        icon: Icons.history_rounded,
        title: l10n.emptyHistoryTitle,
        body: l10n.emptyHistoryBody,
      );
    }

    return Column(
      children: [
        TabBar(
          controller: _tabController,
          tabs: [
            Tab(text: l10n.historyTabDone(done.length)),
            Tab(text: l10n.historyTabCancelled(cancelled.length)),
          ],
        ),
        Expanded(
          child: TabBarView(
            controller: _tabController,
            children: [
              _HistoryList(
                entries: done,
                emptyIcon: Icons.check_circle_outline_rounded,
                emptyTitle: l10n.emptyDoneTitle,
                emptyBody: l10n.emptyDoneBody,
              ),
              _HistoryList(
                entries: cancelled,
                emptyIcon: Icons.cancel_outlined,
                emptyTitle: l10n.emptyCancelledTitle,
                emptyBody: l10n.emptyCancelledBody,
              ),
            ],
          ),
        ),
      ],
    );
  }
}

/// One tab's worth of history rows. Long-press starts selecting; while
/// selecting, a tap toggles a row instead of opening it.
class _HistoryList extends ConsumerWidget {
  const _HistoryList({
    required this.entries,
    required this.emptyIcon,
    required this.emptyTitle,
    required this.emptyBody,
  });

  final List<HistoryEntry> entries;
  final IconData emptyIcon;
  final String emptyTitle;
  final String emptyBody;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final wallets = ref.watch(walletsProvider).value ?? const <Wallet>[];
    final localeCode = ref.watch(settingsProvider).locale?.languageCode ?? 'ar';
    final selection = ref.watch(historySelectionProvider);
    final selector = ref.read(historySelectionProvider.notifier);

    if (entries.isEmpty) {
      return EmptyState(icon: emptyIcon, title: emptyTitle, body: emptyBody);
    }

    return ListView.separated(
      padding: const EdgeInsets.symmetric(vertical: AppTheme.gapSm),
      itemCount: entries.length,
      separatorBuilder: (_, _) => const Divider(
        height: 1,
        indent: AppTheme.screenPadding,
        endIndent: AppTheme.screenPadding,
      ),
      itemBuilder: (context, index) {
        final entry = entries[index];
        final wallet = wallets.where((w) => w.id == entry.walletId).firstOrNull;

        return HistoryTile(
          entry: entry,
          walletName: wallet?.nameFor(localeCode),
          walletColor: wallet != null ? Color(wallet.colorValue) : null,
          localeCode: localeCode,
          selecting: selection.active,
          selected: selection.ids.contains(entry.id),
          onLongPress: () => selector.toggle(entry.id),
          onTap: selection.active
              ? () => selector.toggle(entry.id)
              : () => PaymentDetailsSheet.show(
                  context,
                  entry: entry,
                  wallet: wallet,
                  localeCode: localeCode,
                ),
        );
      },
    );
  }
}
