import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:crypto/crypto.dart';
import 'dart:convert';
import 'package:firebase_auth/firebase_auth.dart' as fb_auth;
import 'package:cloud_firestore/cloud_firestore.dart';
import '../domain/user_model.dart';
import '../../../core/services/hive_service.dart';
import '../../transactions/data/transaction_repository.dart';
import '../../budget/data/budget_repository.dart';
import '../../goals/data/goal_repository.dart';

abstract class AuthRepository {
  Future<UserModel?> getCurrentUser();
  Future<UserModel> signInWithEmail(String email, String password);
  Future<UserModel> signUpWithEmail(String email, String password, String name);
  Future<UserModel> signInWithGoogle();
  Future<void> sendOtp(String phoneNumber);
  Future<UserModel> verifyOtp(String verificationId, String smsCode);
  Future<void> logOut();
  Future<void> savePin(String pin);
  Future<bool> verifyPin(String pin);
  Future<bool> hasPin();
  Future<void> setBiometricsEnabled(bool enabled);
  Future<bool> isBiometricsEnabled();
}

class AuthRepositoryImpl implements AuthRepository {
  final SharedPreferences _prefs;
  final Ref _ref;
  UserModel? _currentUser;

  AuthRepositoryImpl(this._prefs, this._ref) {
    _loadUserSession();
  }

  void _loadUserSession() {
    final userJson = _prefs.getString('user_session');
    if (userJson != null) {
      try {
        _currentUser = UserModel.fromMap(jsonDecode(userJson));
      } catch (_) {}
    }
  }

  Future<void> _saveUserSession(UserModel user) async {
    _currentUser = user;
    await _prefs.setString('user_session', jsonEncode(user.toMap()));
    await _prefs.setString('last_user_id', user.uid);
  }

  Future<void> _syncUserDataFromFirestore(String uid) async {
    try {
      // Clear boxes ONLY if the saved session is for a different user
      final lastUserId = _prefs.getString('last_user_id');
      if (lastUserId != null && lastUserId != uid) {
        await HiveService.clearAllBoxes();
      }
      
      // Open the user's specific database boxes
      await HiveService.openBoxesForUser(uid);
      
      // 2. Sync user profile
      final userDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(uid)
          .get()
          .timeout(const Duration(seconds: 2));
      if (userDoc.exists && userDoc.data() != null) {
        final user = UserModel.fromMap(userDoc.data()!);
        await _saveUserSession(user);
      }
      
      // 3. Sync transactions
      final txQuery = await FirebaseFirestore.instance
          .collection('users')
          .doc(uid)
          .collection('transactions')
          .get()
          .timeout(const Duration(seconds: 2));
      for (var doc in txQuery.docs) {
        await HiveService.saveItem(HiveService.expensesBoxName, doc.id, doc.data());
      }
      
      // 4. Sync budgets
      final budgetQuery = await FirebaseFirestore.instance
          .collection('users')
          .doc(uid)
          .collection('budgets')
          .get()
          .timeout(const Duration(seconds: 2));
      for (var doc in budgetQuery.docs) {
        await HiveService.saveItem(HiveService.budgetsBoxName, doc.id, doc.data());
      }
      
      // 5. Sync goals
      final goalQuery = await FirebaseFirestore.instance
          .collection('users')
          .doc(uid)
          .collection('goals')
          .get()
          .timeout(const Duration(seconds: 2));
      for (var doc in goalQuery.docs) {
        await HiveService.saveItem(HiveService.goalsBoxName, doc.id, doc.data());
      }
      
      print("Synced all data from Firestore successfully for user $uid");
      
      // Reload UI lists with the newly synced data
      _ref.read(transactionListProvider.notifier).loadTransactions();
      _ref.read(budgetListProvider.notifier).loadBudgets();
      _ref.read(goalListProvider.notifier).loadGoals();
    } catch (e) {
      print("Error syncing user data from Firestore: $e");
    }
  }

  @override
  Future<UserModel?> getCurrentUser() async {
    final fbUser = fb_auth.FirebaseAuth.instance.currentUser;
    if (fbUser == null) {
      _currentUser = null;
      await _prefs.remove('user_session');
      return null;
    }
    
    if (_currentUser != null && _currentUser!.uid == fbUser.uid) {
      return _currentUser;
    }
    
    _loadUserSession();
    if (_currentUser != null && _currentUser!.uid == fbUser.uid) {
      _syncUserDataFromFirestore(fbUser.uid);
      return _currentUser;
    }
    
    await _syncUserDataFromFirestore(fbUser.uid);
    if (_currentUser != null) {
      return _currentUser;
    }
    
    final user = UserModel(
      uid: fbUser.uid,
      email: fbUser.email ?? '',
      displayName: fbUser.displayName ?? (fbUser.email?.split('@').first.toUpperCase() ?? 'User'),
      photoUrl: fbUser.photoURL ?? 'https://api.dicebear.com/7.x/adventurer/png?seed=${fbUser.uid}',
      createdAt: DateTime.now(),
    );
    await _saveUserSession(user);
    return user;
  }

  @override
  Future<UserModel> signInWithEmail(String email, String password) async {
    try {
      final fb_auth.UserCredential credential = await fb_auth.FirebaseAuth.instance
          .signInWithEmailAndPassword(email: email, password: password);
      
      final fbUser = credential.user;
      if (fbUser == null) {
        throw Exception('User not found in Firebase');
      }
      
      await _syncUserDataFromFirestore(fbUser.uid);
      
      UserModel user;
      if (_currentUser != null) {
        user = _currentUser!;
      } else {
        user = UserModel(
          uid: fbUser.uid,
          email: email,
          displayName: fbUser.displayName ?? email.split('@').first.toUpperCase(),
          photoUrl: fbUser.photoURL ?? 'https://api.dicebear.com/7.x/adventurer/png?seed=${fbUser.uid}',
          createdAt: DateTime.now(),
        );
        try {
          await FirebaseFirestore.instance
              .collection('users')
              .doc(user.uid)
              .set(user.toMap())
              .timeout(const Duration(seconds: 2));
        } catch (_) {}
        await _saveUserSession(user);
      }
      
      final settingsBox = HiveService.getBox(HiveService.settingsBoxName);
      await settingsBox.put('user_$email', user.toMap());
      return user;
    } on fb_auth.FirebaseAuthException catch (e) {
      throw Exception(e.message ?? 'Login failed');
    }
  }

  @override
  Future<UserModel> signUpWithEmail(String email, String password, String name) async {
    try {
      final fb_auth.UserCredential credential = await fb_auth.FirebaseAuth.instance
          .createUserWithEmailAndPassword(email: email, password: password);
      
      final fbUser = credential.user;
      if (fbUser != null) {
        await fbUser.updateDisplayName(name);
      }
      
      final user = UserModel(
        uid: fbUser?.uid ?? '',
        email: email,
        displayName: name,
        photoUrl: 'https://api.dicebear.com/7.x/adventurer/png?seed=$name',
        createdAt: DateTime.now(),
      );
      
      final lastUserId = _prefs.getString('last_user_id');
      if (lastUserId != null && lastUserId != user.uid) {
        await HiveService.clearAllBoxes();
      }
      await HiveService.openBoxesForUser(user.uid);
      
      try {
        await FirebaseFirestore.instance
            .collection('users')
            .doc(user.uid)
            .set(user.toMap())
            .timeout(const Duration(seconds: 2));
      } catch (e) {
        print("Firestore save user error: $e");
      }
      
      final settingsBox = HiveService.getBox(HiveService.settingsBoxName);
      await settingsBox.put('user_$email', user.toMap());
      await _saveUserSession(user);
      return user;
    } on fb_auth.FirebaseAuthException catch (e) {
      throw Exception(e.message ?? 'Signup failed');
    }
  }

  @override
  Future<UserModel> signInWithGoogle() async {
    await Future.delayed(const Duration(milliseconds: 1500));
    final user = UserModel(
      uid: 'google_mock_uid_123',
      email: 'finance.pro@gmail.com',
      displayName: 'Alex Mercer',
      photoUrl: 'https://api.dicebear.com/7.x/adventurer/png?seed=Alex',
      createdAt: DateTime.now(),
    );
    final lastUserId = _prefs.getString('last_user_id');
    if (lastUserId != null && lastUserId != user.uid) {
      await HiveService.clearAllBoxes();
    }
    await HiveService.openBoxesForUser(user.uid);
    await _saveUserSession(user);
    return user;
  }

  @override
  Future<void> sendOtp(String phoneNumber) async {
    await Future.delayed(const Duration(seconds: 1));
    // Simulate sending SMS
  }

  @override
  Future<UserModel> verifyOtp(String verificationId, String smsCode) async {
    await Future.delayed(const Duration(seconds: 1));
    final user = UserModel(
      uid: 'phone_mock_uid_999',
      email: 'phone.user@tracker.com',
      displayName: 'Phone User',
      photoUrl: 'https://api.dicebear.com/7.x/adventurer/png?seed=Phone',
      createdAt: DateTime.now(),
    );
    final lastUserId = _prefs.getString('last_user_id');
    if (lastUserId != null && lastUserId != user.uid) {
      await HiveService.clearAllBoxes();
    }
    await HiveService.openBoxesForUser(user.uid);
    await _saveUserSession(user);
    return user;
  }

  @override
  Future<void> logOut() async {
    try {
      await fb_auth.FirebaseAuth.instance.signOut();
    } catch (_) {}
    _currentUser = null;
    await _prefs.remove('user_session');
    // Keep local database boxes on logout to prevent automatic clearing of data
  }

  @override
  Future<void> savePin(String pin) async {
    final bytes = utf8.encode(pin);
    final digest = sha256.convert(bytes).toString();
    await _prefs.setString('app_pin_hash', digest);
    
    if (_currentUser != null) {
      final updated = _currentUser!.copyWith(pinHash: digest);
      await _saveUserSession(updated);
    }
  }

  @override
  Future<bool> verifyPin(String pin) async {
    final savedHash = _prefs.getString('app_pin_hash');
    if (savedHash == null) return false;
    final bytes = utf8.encode(pin);
    final digest = sha256.convert(bytes).toString();
    return savedHash == digest;
  }

  @override
  Future<bool> hasPin() async {
    return _prefs.getString('app_pin_hash') != null;
  }

  @override
  Future<void> setBiometricsEnabled(bool enabled) async {
    await _prefs.setBool('biometrics_enabled', enabled);
    if (_currentUser != null) {
      final updated = _currentUser!.copyWith(isBiometricEnabled: enabled);
      await _saveUserSession(updated);
    }
  }

  @override
  Future<bool> isBiometricsEnabled() async {
    return _prefs.getBool('biometrics_enabled') ?? false;
  }
}

// State Management Riverpod Providers
final sharedPreferencesProvider = Provider<SharedPreferences>((ref) {
  throw UnimplementedError('SharedPreferences must be overridden in main()');
});

final authRepositoryProvider = Provider<AuthRepository>((ref) {
  final prefs = ref.watch(sharedPreferencesProvider);
  return AuthRepositoryImpl(prefs, ref);
});

// A provider for the active current user
final currentUserProvider = StateProvider<UserModel?>((ref) {
  final authRepo = ref.watch(authRepositoryProvider);
  // Fetch initial value
  UserModel? user;
  authRepo.getCurrentUser().then((val) => user = val);
  return user;
});
