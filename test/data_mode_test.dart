import 'package:flutter_test/flutter_test.dart';
import 'package:inventory/core/data_mode.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  setUp(() async {
    SharedPreferences.setMockInitialValues(<String, Object>{});
  });

  group('DataModeStore', () {
    test('defaults to guest mode when no value has been stored', () async {
      expect(await DataModeStore.get(), DataMode.guestHiveOnly);
    });

    test('reads the persisted Firestore mode', () async {
      SharedPreferences.setMockInitialValues(<String, Object>{
        'data_mode': 'syncedFirestore',
      });

      expect(await DataModeStore.get(), DataMode.syncedFirestore);
    });

    test('persists the requested mode', () async {
      await DataModeStore.set(DataMode.syncedFirestore);

      expect(await DataModeStore.get(), DataMode.syncedFirestore);
    });
  });
}
