import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:hive_ce_flutter/hive_flutter.dart';

import '../models/favorite.dart';
import '../models/history_entry.dart';

/// Local persistence. Everything stays on the device; nothing is ever uploaded.
///
/// Favorites and history are encrypted at rest with AES-256. The key is
/// generated once, kept in the Android Keystore via `flutter_secure_storage`,
/// and never written into the Hive files themselves.
class StorageService {
  StorageService._(this._favorites, this._history, this._settings);

  static const String _favoritesBoxName = 'favorites';
  static const String _historyBoxName = 'history';
  static const String _settingsBoxName = 'settings';

  /// Versioned so a future key-rotation can be told apart from a first run.
  static const String _encryptionKeyName = 'ussd_pay.hive_key.v1';

  /// History is capped: this is a convenience log, not an archive, and an
  /// unbounded box on a low-end device is a slow startup waiting to happen.
  static const int maxHistoryEntries = 200;

  static const String _localeKey = 'localeCode';
  static const String _themeKey = 'themeMode';

  final Box<dynamic> _favorites;
  final Box<dynamic> _history;
  final Box<dynamic> _settings;

  /// Initialises Hive and opens every box. Call once, before `runApp`.
  static Future<StorageService> open({
    FlutterSecureStorage secureStorage = const FlutterSecureStorage(),
  }) async {
    await Hive.initFlutter();
    final cipher = HiveAesCipher(await _readOrCreateKey(secureStorage));

    return StorageService._(
      await Hive.openBox<dynamic>(_favoritesBoxName, encryptionCipher: cipher),
      await Hive.openBox<dynamic>(_historyBoxName, encryptionCipher: cipher),
      // Locale and theme are not sensitive, and keeping them in the clear means
      // the app can still start in the right language if the Keystore entry is
      // ever lost.
      await Hive.openBox<dynamic>(_settingsBoxName),
    );
  }

  static Future<List<int>> _readOrCreateKey(FlutterSecureStorage store) async {
    final existing = await store.read(key: _encryptionKeyName);
    if (existing != null) {
      try {
        final key = base64Url.decode(existing);
        if (key.length == 32) return key;
        debugPrint('Stored Hive key had the wrong length; regenerating.');
      } on FormatException {
        debugPrint('Stored Hive key was unreadable; regenerating.');
      }
    }
    final key = Hive.generateSecureKey();
    await store.write(key: _encryptionKeyName, value: base64UrlEncode(key));
    return key;
  }

  // --- Favorites ---------------------------------------------------------

  /// Saved recipients, most recently added first.
  List<Favorite> favorites() {
    final result = <Favorite>[];
    for (final raw in _favorites.values) {
      final favorite = Favorite.fromMap(raw);
      if (favorite != null) result.add(favorite);
    }
    return result.reversed.toList(growable: false);
  }

  Future<void> saveFavorite(Favorite favorite) =>
      _favorites.put(favorite.id, favorite.toMap());

  Future<void> deleteFavorite(String id) => _favorites.delete(id);

  /// Finds a saved recipient by normalized number and wallet, so the payment
  /// screen can show a name instead of a bare number.
  Favorite? findFavorite({required String number, required String walletId}) {
    for (final favorite in favorites()) {
      if (favorite.number == number && favorite.walletId == walletId) {
        return favorite;
      }
    }
    return null;
  }

  // --- History -----------------------------------------------------------

  /// Dialed payments, newest first.
  List<HistoryEntry> history() {
    final result = <HistoryEntry>[];
    for (final raw in _history.values) {
      final entry = HistoryEntry.fromMap(raw);
      if (entry != null) result.add(entry);
    }
    result.sort((a, b) => b.dialedAtUtc.compareTo(a.dialedAtUtc));
    return List.unmodifiable(result);
  }

  Future<void> addHistoryEntry(HistoryEntry entry) async {
    await _history.put(entry.id, entry.toMap());
    await _trimHistory();
  }

  /// Records the user's answer for one row. A row that is gone (deleted, or
  /// trimmed past the cap) or unreadable is left alone rather than recreated.
  Future<void> setHistoryStatus(String id, HistoryStatus status) async {
    final entry = HistoryEntry.fromMap(_history.get(id));
    if (entry == null) return;
    await _history.put(id, entry.copyWith(status: status).toMap());
  }

  Future<void> deleteHistoryEntry(String id) => _history.delete(id);

  Future<void> clearHistory() => _history.clear();

  Future<void> _trimHistory() async {
    if (_history.length <= maxHistoryEntries) return;
    final entries = history(); // newest first
    final stale = entries.skip(maxHistoryEntries).map((e) => e.id);
    await _history.deleteAll(stale);
  }

  // --- Settings ----------------------------------------------------------

  /// `'ar'` or `'en'`; `null` until the user chooses.
  String? localeCode() {
    final value = _settings.get(_localeKey);
    return value is String && value.isNotEmpty ? value : null;
  }

  Future<void> setLocaleCode(String code) => _settings.put(_localeKey, code);

  /// `'dark'`, `'light'`, or `'system'`; `null` until the user chooses.
  String? themeModeName() {
    final value = _settings.get(_themeKey);
    return value is String && value.isNotEmpty ? value : null;
  }

  Future<void> setThemeModeName(String name) => _settings.put(_themeKey, name);
}
