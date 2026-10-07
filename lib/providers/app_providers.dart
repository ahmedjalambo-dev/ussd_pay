import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/favorite.dart';
import '../models/history_entry.dart';
import '../models/payment_draft.dart';
import '../models/wallet.dart';
import '../services/notification_service.dart';
import '../services/storage_service.dart';
import '../services/wallet_repository.dart';

/// Overridden in `main` once storage is open, so the rest of the app can read
/// it synchronously.
final storageServiceProvider = Provider<StorageService>(
  (ref) =>
      throw UnimplementedError('storageServiceProvider must be overridden'),
);

/// Overridden in `main` after `NotificationService.init()` resolves.
final notificationServiceProvider = Provider<NotificationService>(
  (ref) => throw UnimplementedError(
    'notificationServiceProvider must be overridden',
  ),
);

final walletRepositoryProvider = Provider<WalletRepository>(
  (ref) => WalletRepository(),
);

/// The wallets and their USSD templates, read once from `assets/wallets.json`.
///
/// Left as an [AsyncValue] on purpose: if the config cannot be parsed, the home
/// screen shows an error rather than an empty list. A missing template is a
/// reason to stop, not to carry on with nothing.
final walletsProvider = FutureProvider<List<Wallet>>((ref) async {
  final config = await ref.watch(walletRepositoryProvider).load();
  return config.wallets;
});

// --- Settings --------------------------------------------------------------

class AppSettings {
  const AppSettings({required this.locale, required this.themeMode});

  /// `null` means "follow the device locale".
  final Locale? locale;
  final ThemeMode themeMode;

  AppSettings copyWith({
    Locale? locale,
    ThemeMode? themeMode,
    bool clearLocale = false,
  }) => AppSettings(
    locale: clearLocale ? null : (locale ?? this.locale),
    themeMode: themeMode ?? this.themeMode,
  );
}

class SettingsNotifier extends Notifier<AppSettings> {
  @override
  AppSettings build() {
    final storage = ref.read(storageServiceProvider);
    final code = storage.localeCode();
    return AppSettings(
      // Arabic-first: with nothing saved, the app opens in Arabic rather than
      // deferring to a device locale that is often English on cheap handsets.
      locale: Locale(code ?? 'ar'),
      themeMode: _themeModeFrom(storage.themeModeName()),
    );
  }

  Future<void> setLocale(Locale locale) async {
    state = state.copyWith(locale: locale);
    await ref.read(storageServiceProvider).setLocaleCode(locale.languageCode);
  }

  Future<void> setThemeMode(ThemeMode mode) async {
    state = state.copyWith(themeMode: mode);
    await ref.read(storageServiceProvider).setThemeModeName(mode.name);
  }

  /// Dark by default: it saves battery on OLED panels and is easier to read at
  /// night, which is when the power is more likely to be on.
  static ThemeMode _themeModeFrom(String? name) => switch (name) {
    'light' => ThemeMode.light,
    'system' => ThemeMode.system,
    _ => ThemeMode.dark,
  };
}

final settingsProvider = NotifierProvider<SettingsNotifier, AppSettings>(
  SettingsNotifier.new,
);

// --- Favorites -------------------------------------------------------------

class FavoritesNotifier extends Notifier<List<Favorite>> {
  @override
  List<Favorite> build() => ref.read(storageServiceProvider).favorites();

  Future<void> save(Favorite favorite) async {
    await ref.read(storageServiceProvider).saveFavorite(favorite);
    _refresh();
  }

  Future<void> deleteMany(Iterable<String> ids) async {
    await ref.read(storageServiceProvider).deleteFavorites(ids);
    _refresh();
  }

  Future<void> restore(List<Favorite> favorites) async {
    await ref.read(storageServiceProvider).restoreFavorites(favorites);
    _refresh();
  }

  void _refresh() => state = ref.read(storageServiceProvider).favorites();
}

final favoritesProvider = NotifierProvider<FavoritesNotifier, List<Favorite>>(
  FavoritesNotifier.new,
);

/// Favorites picked for deletion. A provider for the same reason as
/// [HistorySelection]: the root AppBar shows the count and the delete action.
class FavoritesSelectionNotifier extends Notifier<Set<String>> {
  @override
  Set<String> build() {
    // Drop ids whose rows are gone, so a stale selection can never outlive
    // its rows.
    ref.listen(favoritesProvider, (_, favorites) {
      if (state.isEmpty) return;
      final alive = favorites.map((f) => f.id).toSet();
      final kept = state.where(alive.contains).toSet();
      if (kept.length != state.length) state = kept;
    });
    return const <String>{};
  }

  void toggle(String id) {
    final ids = {...state};
    if (!ids.remove(id)) ids.add(id);
    state = ids;
  }

  void selectAll() =>
      state = {for (final f in ref.read(favoritesProvider)) f.id};

  void clear() {
    if (state.isNotEmpty) state = const <String>{};
  }
}

final favoritesSelectionProvider =
    NotifierProvider<FavoritesSelectionNotifier, Set<String>>(
      FavoritesSelectionNotifier.new,
    );

/// Favorites for one wallet, for the picker on the payment screen.
final favoritesForWalletProvider = Provider.family<List<Favorite>, String>((
  ref,
  walletId,
) {
  return ref
      .watch(favoritesProvider)
      .where((favorite) => favorite.walletId == walletId)
      .toList(growable: false);
});

// --- History ---------------------------------------------------------------

class HistoryNotifier extends Notifier<List<HistoryEntry>> {
  @override
  List<HistoryEntry> build() => ref.read(storageServiceProvider).history();

  Future<void> add(HistoryEntry entry) async {
    await ref.read(storageServiceProvider).addHistoryEntry(entry);
    _refresh();
  }

  Future<void> setStatus(String id, HistoryStatus status) async {
    await ref.read(storageServiceProvider).setHistoryStatus(id, status);
    _refresh();
  }

  Future<void> delete(String id) async {
    await ref.read(storageServiceProvider).deleteHistoryEntry(id);
    _refresh();
  }

  Future<void> deleteMany(Iterable<String> ids) async {
    await ref.read(storageServiceProvider).deleteHistoryEntries(ids);
    _refresh();
  }

  Future<void> restore(List<HistoryEntry> entries) async {
    await ref.read(storageServiceProvider).restoreHistoryEntries(entries);
    _refresh();
  }

  Future<void> clear() async {
    await ref.read(storageServiceProvider).clearHistory();
    _refresh();
  }

  void _refresh() => state = ref.read(storageServiceProvider).history();
}

final historyProvider = NotifierProvider<HistoryNotifier, List<HistoryEntry>>(
  HistoryNotifier.new,
);

/// History for one tab (Done or Cancelled), still newest first.
final historyByStatusProvider =
    Provider.family<List<HistoryEntry>, HistoryStatus>((ref, status) {
      return ref
          .watch(historyProvider)
          .where((entry) => entry.status == status)
          .toList(growable: false);
    });

/// Rows picked for deletion in the history list, scoped to one tab.
///
/// Lives in a provider rather than in the list's State because the root
/// AppBar, a different widget, shows the selection count and the delete
/// action.
class HistorySelection {
  const HistorySelection({
    this.tab = HistoryStatus.done,
    this.ids = const <String>{},
  });

  final HistoryStatus tab;
  final Set<String> ids;

  bool get active => ids.isNotEmpty;
}

class HistorySelectionNotifier extends Notifier<HistorySelection> {
  @override
  HistorySelection build() {
    // Drop ids whose rows are gone (deleted, cleared from Settings, trimmed
    // past the cap), so a stale selection can never outlive its rows.
    ref.listen(historyProvider, (_, entries) {
      if (!state.active) return;
      final alive = entries.map((e) => e.id).toSet();
      final kept = state.ids.where(alive.contains).toSet();
      if (kept.length != state.ids.length) {
        state = HistorySelection(tab: state.tab, ids: kept);
      }
    });
    return const HistorySelection();
  }

  void toggle(String id) {
    final ids = {...state.ids};
    if (!ids.remove(id)) ids.add(id);
    state = HistorySelection(tab: state.tab, ids: ids);
  }

  void selectAll() {
    final entries = ref.read(historyByStatusProvider(state.tab));
    state = HistorySelection(
      tab: state.tab,
      ids: {for (final e in entries) e.id},
    );
  }

  void clear() {
    if (state.active) state = HistorySelection(tab: state.tab);
  }

  /// Switching tabs ends the selection: it only ever covers rows the user
  /// can see.
  void setTab(HistoryStatus tab) {
    if (tab != state.tab || state.active) state = HistorySelection(tab: tab);
  }
}

final historySelectionProvider =
    NotifierProvider<HistorySelectionNotifier, HistorySelection>(
      HistorySelectionNotifier.new,
    );

// --- The payment in progress ----------------------------------------------

class PaymentDraftNotifier extends Notifier<PaymentDraft> {
  @override
  PaymentDraft build() => const PaymentDraft();

  void start(Wallet wallet) {
    state = PaymentDraft(
      wallet: wallet,
      recipientType: wallet.recipientTypes.first,
    );
  }

  void setRecipientType(String type) =>
      state = state.copyWith(recipientType: type);

  /// Typing a number by hand detaches it from whatever name was attached to it,
  /// so the confirmation screen can never show a stale name beside a new
  /// number.
  void setPhoneInput(String raw) =>
      state = state.copyWith(rawPhoneInput: raw, clearRecipientName: true);

  void setRecipient({required String phone, String? name}) =>
      state = state.copyWith(
        rawPhoneInput: phone,
        recipientName: name,
        clearRecipientName: name == null,
      );

  void setAmountInput(String amount) =>
      state = state.copyWith(amountInput: amount);

  void setNote(String note) => state = state.copyWith(note: note);

  /// Re-runs a past payment. Returns the draft so the caller can navigate
  /// straight to confirmation.
  PaymentDraft repeat(HistoryEntry entry, Wallet wallet) {
    state = PaymentDraft(
      wallet: wallet,
      recipientType: entry.recipientType,
      rawPhoneInput: entry.recipientNumber,
      amountInput: entry.amount.toString(),
      recipientName: entry.recipientName,
      note: entry.note ?? '',
    );
    return state;
  }

  PaymentDraft fromFavorite(Favorite favorite, Wallet wallet) {
    state = PaymentDraft(
      wallet: wallet,
      recipientType: favorite.defaultType,
      rawPhoneInput: favorite.number,
      amountInput: favorite.defaultAmount?.toString() ?? '',
      recipientName: favorite.name,
    );
    return state;
  }

  void reset() => state = const PaymentDraft();
}

final paymentDraftProvider =
    NotifierProvider<PaymentDraftNotifier, PaymentDraft>(
      PaymentDraftNotifier.new,
    );
