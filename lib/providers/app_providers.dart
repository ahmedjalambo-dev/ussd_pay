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
  (ref) => throw UnimplementedError('storageServiceProvider must be overridden'),
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

  AppSettings copyWith({Locale? locale, ThemeMode? themeMode, bool clearLocale = false}) =>
      AppSettings(
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

final settingsProvider =
    NotifierProvider<SettingsNotifier, AppSettings>(SettingsNotifier.new);

// --- Favorites -------------------------------------------------------------

class FavoritesNotifier extends Notifier<List<Favorite>> {
  @override
  List<Favorite> build() => ref.read(storageServiceProvider).favorites();

  Future<void> save(Favorite favorite) async {
    await ref.read(storageServiceProvider).saveFavorite(favorite);
    _refresh();
  }

  Future<void> delete(String id) async {
    await ref.read(storageServiceProvider).deleteFavorite(id);
    _refresh();
  }

  void _refresh() => state = ref.read(storageServiceProvider).favorites();
}

final favoritesProvider =
    NotifierProvider<FavoritesNotifier, List<Favorite>>(FavoritesNotifier.new);

/// Favorites for one wallet, for the picker on the payment screen.
final favoritesForWalletProvider =
    Provider.family<List<Favorite>, String>((ref, walletId) {
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

  Future<void> delete(String id) async {
    await ref.read(storageServiceProvider).deleteHistoryEntry(id);
    _refresh();
  }

  Future<void> clear() async {
    await ref.read(storageServiceProvider).clearHistory();
    _refresh();
  }

  void _refresh() => state = ref.read(storageServiceProvider).history();
}

final historyProvider =
    NotifierProvider<HistoryNotifier, List<HistoryEntry>>(HistoryNotifier.new);

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
        PaymentDraftNotifier.new);
