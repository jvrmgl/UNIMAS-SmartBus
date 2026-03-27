import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart' as firebase_auth;
import '../models/user_model.dart';
import '../services/auth_service.dart';
import '../services/firestore_service.dart';

class AuthProvider extends ChangeNotifier {
  final AuthService _authService = AuthService();
  final FirestoreService _firestoreService = FirestoreService();

  User? _currentUser;
  firebase_auth.User? _firebaseUser;
  bool _isLoading = false;
  bool _isInitialized = false;
  String? _error;

  User? get currentUser => _currentUser;
  firebase_auth.User? get firebaseUser => _firebaseUser;
  bool get isLoading => _isLoading;
  String? get error => _error;
  bool get isAuthenticated => _firebaseUser != null && _isInitialized;
  bool get isInitialized => _isInitialized;

  AuthProvider() {
    _initializeAuth();
  }

  void _initializeAuth() {
    // Listen to Firebase auth state changes.
    // _isInitialized becomes true only after the first event is fully
    // processed (including the Firestore user-data fetch), so callers
    // can rely on both _firebaseUser and _currentUser being up-to-date.
    _authService.authStateChanges.listen((firebaseUser) async {
      _firebaseUser = firebaseUser;
      if (firebaseUser == null) {
        _currentUser = null;
        // Keep guest UX login-free while still enforcing auth-based rules.
        final anonReady = await _authService.signInAnonymouslyIfNeeded();
        if (!anonReady) {
          _isInitialized = true;
          notifyListeners();
        }
        return;
      }

      _currentUser = await _firestoreService.getUserData(firebaseUser.uid);
      _isInitialized = true;
      notifyListeners();
    });
  }

  Future<bool> signUp({
    required String email,
    required String password,
    required String fullName,
    required String phoneNumber,
    required UserRole role,
  }) async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    final result = await _authService.signUp(
      email: email,
      password: password,
      fullName: fullName,
      phoneNumber: phoneNumber,
      role: role,
    );

    _isLoading = false;
    if (result != null) {
      _error = result;
      notifyListeners();
      return false;
    }
    notifyListeners();
    return true;
  }

  Future<bool> signIn({
    required String email,
    required String password,
  }) async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    final result = await _authService.signIn(
      email: email,
      password: password,
    );

    _isLoading = false;
    if (result != null) {
      _error = result;
      notifyListeners();
      return false;
    }
    notifyListeners();
    return true;
  }

  Future<void> signOut() async {
    await _authService.signOut();
    _currentUser = null;
    notifyListeners();
  }

  Future<bool> ensureUserProfile({
    required UserRole role,
    String? fullName,
    String? phoneNumber,
  }) async {
    if (_firebaseUser == null) return false;

    final uid = _firebaseUser!.uid;
    final email = _firebaseUser!.email ?? '';

    final existing = await _firestoreService.getUserData(uid);
    if (existing != null) {
      _currentUser = existing;
      notifyListeners();
      return true;
    }

    final fallbackName = fullName ?? email.split('@').first;
    final user = User(
      uid: uid,
      email: email,
      fullName: fallbackName.isEmpty ? 'User' : fallbackName,
      phoneNumber: phoneNumber ?? '',
      role: role,
      createdAt: DateTime.now(),
    );

    final result = await _firestoreService.createUserProfile(user);
    if (result != null) {
      _error = result;
      notifyListeners();
      return false;
    }

    _currentUser = user;
    notifyListeners();
    return true;
  }

  Future<bool> updateUserRole(UserRole role) async {
    if (_firebaseUser == null || _currentUser == null) return false;

    final result = await _firestoreService.updateUserRole(
      uid: _firebaseUser!.uid,
      role: role,
    );

    if (result != null) {
      _error = result;
      notifyListeners();
      return false;
    }

    _currentUser = _currentUser!.copyWith(role: role);
    notifyListeners();
    return true;
  }

  Future<bool> updateProfile({
    String? fullName,
    String? phoneNumber,
  }) async {
    if (_firebaseUser == null) return false;

    final result = await _authService.updateUserProfile(
      uid: _firebaseUser!.uid,
      fullName: fullName,
      phoneNumber: phoneNumber,
    );

    if (result == null) {
      // Refresh user data
      _currentUser = await _firestoreService.getUserData(_firebaseUser!.uid);
      notifyListeners();
      return true;
    } else {
      _error = result;
      notifyListeners();
      return false;
    }
  }

  Future<bool> resetPassword(String email) async {
    final result = await _authService.resetPassword(email);
    if (result == null) {
      return true;
    } else {
      _error = result;
      notifyListeners();
      return false;
    }
  }

  Future<bool> updatePassword({
    required String currentPassword,
    required String newPassword,
  }) async {
    final result = await _authService.updatePassword(
      currentPassword: currentPassword,
      newPassword: newPassword,
    );
    
    if (result == null) {
      return true;
    } else {
      _error = result;
      notifyListeners();
      return false;
    }
  }
}
