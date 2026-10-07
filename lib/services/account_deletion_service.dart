import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class AccountDeletionService {
  AccountDeletionService({FirebaseFirestore? firestore, FirebaseAuth? auth})
    : _firestore = firestore ?? FirebaseFirestore.instance,
      _auth = auth ?? FirebaseAuth.instance;

  static const _batchSize = 400;
  static const _collections = <String>['inventory', 'orders', 'sales'];

  final FirebaseFirestore _firestore;
  final FirebaseAuth _auth;

  Future<void> deleteAccount() async {
    final user = _auth.currentUser;
    if (user == null) {
      throw StateError('No signed-in account is available.');
    }

    await _deleteUserData(user.uid);
    await user.delete();
  }

  Future<void> _deleteUserData(String userId) async {
    final user = _firestore.collection('users').doc(userId);
    for (final collectionName in _collections) {
      await _deleteCollection(user.collection(collectionName));
    }

    await user.collection('settings').doc('folders').delete();
    await user.delete();
  }

  Future<void> _deleteCollection(
    CollectionReference<Map<String, dynamic>> collection,
  ) async {
    while (true) {
      final snapshot = await collection.limit(_batchSize).get();
      if (snapshot.docs.isEmpty) {
        return;
      }

      final batch = _firestore.batch();
      for (final document in snapshot.docs) {
        batch.delete(document.reference);
      }
      await batch.commit();
    }
  }
}
