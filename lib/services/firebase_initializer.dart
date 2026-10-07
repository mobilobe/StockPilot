import 'package:firebase_core/firebase_core.dart';
import 'package:inventory/core/firebase_platform.dart';

class FirebaseInitializer {
  FirebaseInitializer._();

  static Future<void>? _initialization;

  static Future<void> ensureInitialized() {
    if (!supportsFirebaseAuthentication) {
      return Future<void>.value();
    }

    return _initialization ??= Firebase.initializeApp();
  }
}
