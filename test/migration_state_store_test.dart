import 'package:flutter_test/flutter_test.dart';
import 'package:inventory/services/migration_state_store.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues(<String, Object>{});
  });

  group('MigrationStateStore', () {
    test('defaults to not migrated for a new account', () async {
      expect(await MigrationStateStore.hasMigrated('user-a'), isFalse);
    });

    test('tracks migration state independently for each account', () async {
      await MigrationStateStore.setMigrated('user-a', true);
      await MigrationStateStore.setMigrated('user-b', false);

      expect(await MigrationStateStore.hasMigrated('user-a'), isTrue);
      expect(await MigrationStateStore.hasMigrated('user-b'), isFalse);
    });

    test('records and clears an explicitly started migration retry', () async {
      expect(await MigrationStateStore.getPendingUserId(), isNull);

      await MigrationStateStore.setPendingUserId('user-a');
      expect(await MigrationStateStore.getPendingUserId(), 'user-a');

      await MigrationStateStore.clearPendingUserId();
      expect(await MigrationStateStore.getPendingUserId(), isNull);
    });
  });
}
