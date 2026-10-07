import 'package:shared_preferences/shared_preferences.dart';

class MigrationStateStore {
  MigrationStateStore._();

  static const _pendingUserIdKey = 'pending_migration_user_id';

  static String _keyFor(String userId) => 'migrated_uid_$userId';

  static Future<bool> hasMigrated(String userId) async {
    final preferences = await SharedPreferences.getInstance();
    return preferences.getBool(_keyFor(userId)) ?? false;
  }

  static Future<bool> setMigrated(String userId, bool migrated) async {
    final preferences = await SharedPreferences.getInstance();
    return preferences.setBool(_keyFor(userId), migrated);
  }

  static Future<bool> setPendingUserId(String userId) async {
    final preferences = await SharedPreferences.getInstance();
    return preferences.setString(_pendingUserIdKey, userId);
  }

  static Future<String?> getPendingUserId() async {
    final preferences = await SharedPreferences.getInstance();
    return preferences.getString(_pendingUserIdKey);
  }

  static Future<bool> clearPendingUserId() async {
    final preferences = await SharedPreferences.getInstance();
    return preferences.remove(_pendingUserIdKey);
  }
}
