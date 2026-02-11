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
  String? _error;

  User? get currentUser => _currentUser;
  firebase_auth.User? get firebaseUser => _firebaseUser;
  bool get isLoading => _isLoading;
  String? get error => _error;
  bool get isAuthenticated => _firebaseUser != null;

  AuthProvider() {
    _initializeAuth();
  }

  void _initializeAuth() {
    _authService.authStateChanges.listen((firebaseUser) async {
      _firebaseUser = firebaseUser;
      if (firebaseUser != null) {
        _currentUser = await _firestoreService.getUserData(firebaseUser.uid);
      } else {
        _currentUser = null;
      }
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
}
