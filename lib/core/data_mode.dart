import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Selects the persistence source used for application data.
enum DataMode { guestHiveOnly, syncedFirestore }

/// Persists the selected mode outside Hive, which may be cleared after migration.
class DataModeStore {
  DataModeStore._();

  static const _key = 'data_mode';
  static const _syncedFirestoreValue = 'syncedFirestore';
  static final ValueNotifier<DataMode?> changes = ValueNotifier<DataMode?>(
    null,
  );

  /// Defaults new installs and unknown stored values to local-only guest mode.
  static Future<DataMode> get() async {
    final preferences = await SharedPreferences.getInstance();
    return switch (preferences.getString(_key)) {
      _syncedFirestoreValue => DataMode.syncedFirestore,
      _ => DataMode.guestHiveOnly,
    };
  }

  /// Saves mode to Shared Preferances
  static Future<bool> set(DataMode mode) async {
    final preferences = await SharedPreferences.getInstance();
    final saved = await preferences.setString(_key, mode.name);
    if (saved) {
      changes.value = mode;
    }
    return saved;
  }
}
