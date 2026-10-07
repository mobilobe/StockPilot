import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:inventory/core/data_mode.dart';
import 'package:inventory/services/account_deletion_service.dart';
import 'package:inventory/services/firebase_initializer.dart';
import 'package:inventory/services/migration_state_store.dart';
import 'package:inventory/services/hive_data.dart';
import 'package:inventory/core/app_theme.dart';
import 'package:inventory/core/firebase_platform.dart';

/// Lets users sign in, sync Hive data to Firebase (local to cloud), sign out, or delete an account.
class BackupSyncPage extends StatefulWidget {
  final Future<bool> Function(String userId)? onMigrationVerified;

  const BackupSyncPage({this.onMigrationVerified, super.key});

  @override
  State<BackupSyncPage> createState() => _BackupSyncPageState();
}

/// Tracks authentication state and protects asynchronous account operations
class _BackupSyncPageState extends State<BackupSyncPage> {
  static Future<void>? _googleSignInInitialization;
  static const _signInTimeout = Duration(seconds: 45);
  static const _firebaseOperationTimeout = Duration(seconds: 60);
  User? _currentUser;
  bool _isCheckingSession = true;
  bool _isSigningIn = false;

  @override
  void initState() {
    super.initState();
    _loadCurrentUser();
  }

  Future<void> _loadCurrentUser() async {
    if (!supportsFirebaseAuthentication) {
      if (mounted) setState(() => _isCheckingSession = false);
      return;
    }

    try {
      await FirebaseInitializer.ensureInitialized();
      _currentUser = FirebaseAuth.instance.currentUser;
    } catch (_) {
      // The sign-in action will show a recoverable error if initialization fails.
    } finally {
      if (mounted) setState(() => _isCheckingSession = false);
    }
  }

  Future<void> _signInWithGoogle() async {
    if (!supportsFirebaseAuthentication) return;
    setState(() => _isSigningIn = true);

    try {
      // Keep local mode active until the remote copy has been verified.
      await DataModeStore.set(DataMode.guestHiveOnly);
      await FirebaseInitializer.ensureInitialized().timeout(
        _firebaseOperationTimeout,
      );
      final userCredential = kIsWeb
          ? await FirebaseAuth.instance
                .signInWithPopup(GoogleAuthProvider())
                .timeout(_firebaseOperationTimeout)
          : await _signInWithGoogleCredential();
      final user = userCredential.user;
      if (user == null) {
        throw StateError('Google sign-in did not return a Firebase user.');
      }
      _currentUser = user;
      await MigrationStateStore.setPendingUserId(user.uid);

      final migrationVerified = await widget.onMigrationVerified
          ?.call(user.uid)
          .timeout(_firebaseOperationTimeout);
      if (migrationVerified == true) {
        await HiveService().clearAll();
        await DataModeStore.set(DataMode.syncedFirestore);
        await MigrationStateStore.clearPendingUserId();
      }

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            migrationVerified == true
                ? 'Your inventory is backed up and synced.'
                : 'Backup incomplete - we will retry automatically.',
          ),
        ),
      );
    } on GoogleSignInException catch (exception) {
      await DataModeStore.set(DataMode.guestHiveOnly);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Google sign-in failed: ${exception.description}'),
        ),
      );
    } on FirebaseAuthException catch (exception) {
      await DataModeStore.set(DataMode.guestHiveOnly);
      debugPrint(
        'Firebase Google sign-in failed: ${exception.code}: ${exception.message}',
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Sign-in failed (${exception.code}): ${exception.message ?? 'Try again.'}',
          ),
        ),
      );
    } catch (error) {
      await DataModeStore.set(DataMode.guestHiveOnly);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Sign-in failed or backup timed out: $error')),
      );
    } finally {
      if (mounted) setState(() => _isSigningIn = false);
    }
  }

  Future<void> _continueWithoutAccount() async {
    await DataModeStore.set(DataMode.guestHiveOnly);
    await MigrationStateStore.clearPendingUserId();
    if (mounted) Navigator.of(context).pop();
  }

  Future<void> _signOut() async {
    setState(() => _isSigningIn = true);
    try {
      final wasSynced = await DataModeStore.get() == DataMode.syncedFirestore;
      if (wasSynced) {
        await HiveService().clearAll();
      }
      await FirebaseAuth.instance.signOut();
      await GoogleSignIn.instance.signOut();
      await DataModeStore.set(DataMode.guestHiveOnly);
      await MigrationStateStore.clearPendingUserId();
      if (mounted) setState(() => _currentUser = null);
    } finally {
      if (mounted) setState(() => _isSigningIn = false);
    }
  }

  Future<void> _deleteAccount() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Delete account?'),
        content: const Text(
          'This permanently deletes your Firebase account and cloud inventory, orders, sales, and folder settings. Local data on this device will remain available in guest mode.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('Delete account'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;

    setState(() => _isSigningIn = true);
    try {
      await FirebaseInitializer.ensureInitialized();
      final currentUser = FirebaseAuth.instance.currentUser;
      if (currentUser == null) {
        throw StateError(
          'No signed-in user is available for reauthentication.',
        );
      }
      if (kIsWeb) {
        await currentUser
            .reauthenticateWithPopup(GoogleAuthProvider())
            .timeout(_firebaseOperationTimeout);
      } else {
        final credential = await _getGoogleCredential();
        await currentUser
            .reauthenticateWithCredential(credential)
            .timeout(_firebaseOperationTimeout);
      }
      await AccountDeletionService().deleteAccount();
      await HiveService().clearAll();
      await DataModeStore.set(DataMode.guestHiveOnly);
      await MigrationStateStore.clearPendingUserId();
      await GoogleSignIn.instance.signOut();
      if (!mounted) return;
      setState(() => _currentUser = null);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Your account has been deleted.')),
      );
    } on FirebaseAuthException catch (exception) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Account deletion failed: ${exception.message ?? 'Please try again.'}',
          ),
        ),
      );
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Account deletion failed: $error')),
      );
    } finally {
      if (mounted) setState(() => _isSigningIn = false);
    }
  }

  Future<UserCredential> _signInWithGoogleCredential() async {
    final credential = await _getGoogleCredential();
    return FirebaseAuth.instance
        .signInWithCredential(credential)
        .timeout(_firebaseOperationTimeout);
  }

  Future<AuthCredential> _getGoogleCredential() async {
    await (_googleSignInInitialization ??= GoogleSignIn.instance.initialize());
    final googleAccount = await GoogleSignIn.instance.authenticate().timeout(
      _signInTimeout,
    );
    final idToken = googleAccount.authentication.idToken;
    if (idToken == null || idToken.isEmpty) {
      throw StateError('Google sign-in did not return an ID token.');
    }
    return GoogleAuthProvider.credential(idToken: idToken);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Back up & sync')),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 460),
          child: ListView(
            padding: const EdgeInsets.all(24),
            children: [
              const Icon(
                Icons.cloud_sync_outlined,
                color: AppColors.primary,
                size: 48,
              ),
              const SizedBox(height: 20),
              Text(
                'Back up & sync your inventory',
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.headlineSmall,
              ),
              const SizedBox(height: 10),
              const Text(
                'Sign in to prepare your inventory for secure backup and sync across devices.',
                textAlign: TextAlign.center,
                style: TextStyle(color: AppColors.textSecondary),
              ),
              const SizedBox(height: 32),
              if (supportsFirebaseAuthentication)
                if (_isCheckingSession)
                  const Center(child: CircularProgressIndicator())
                else if (_currentUser != null)
                  Column(
                    children: [
                      Text(
                        'Signed in as ${_currentUser!.email}',
                        textAlign: TextAlign.center,
                        style: const TextStyle(color: AppColors.textSecondary),
                      ),
                      const SizedBox(height: 12),
                      OutlinedButton(
                        onPressed: _isSigningIn ? null : _signOut,
                        child: const Text('Sign out'),
                      ),
                      TextButton(
                        onPressed: _isSigningIn ? null : _deleteAccount,
                        child: const Text('Delete account'),
                      ),
                    ],
                  )
                else
                  FilledButton.icon(
                    onPressed: _isSigningIn ? null : _signInWithGoogle,
                    icon: _isSigningIn
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.g_mobiledata),
                    label: const Text('Continue with Google'),
                  )
              else
                const Text(
                  'Cloud backup is currently available on iOS and Android.',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: AppColors.textSecondary),
                ),
              const SizedBox(height: 12),
              TextButton(
                onPressed: _isSigningIn ? null : _continueWithoutAccount,
                child: const Text('Continue without an account'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
