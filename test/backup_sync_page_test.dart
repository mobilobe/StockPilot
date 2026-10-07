import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:inventory/core/data_mode.dart';
import 'package:inventory/features/backup_sync/screens/backup_sync_page.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  setUp(() async {
    SharedPreferences.setMockInitialValues(<String, Object>{});
  });

  testWidgets('offers Google sign-in and a local-only option', (tester) async {
    await tester.pumpWidget(const MaterialApp(home: BackupSyncPage()));

    expect(find.text('Continue without an account'), findsOneWidget);

    await tester.tap(find.text('Continue without an account'));
    await tester.pumpAndSettle();

    expect(await DataModeStore.get(), DataMode.guestHiveOnly);
  });

  testWidgets('returns a revisiting user to guest mode', (tester) async {
    await DataModeStore.set(DataMode.syncedFirestore);
    await tester.pumpWidget(const MaterialApp(home: BackupSyncPage()));

    await tester.tap(find.text('Continue without an account'));
    await tester.pumpAndSettle();

    expect(await DataModeStore.get(), DataMode.guestHiveOnly);
  });
}
