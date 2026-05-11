import 'dart:async';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart' as firebase_auth;
import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/user_model.dart';
import '../services/auth_service.dart';
import '../services/device_service.dart';
import '../services/firestore_service.dart';
import '../services/notification_service.dart';

class AuthProvider extends ChangeNotifier {
  AuthProvider({
    AuthService? authService,
    FirestoreService? firestoreService,
    DeviceService? deviceService,
    bool autoInitialize = true,
  })  : _authService = authService ?? AuthService(),
        _firestoreService = firestoreService ?? FirestoreService(),
        _deviceService = deviceService ?? DeviceService() {
    if (autoInitialize) {
      _initializeAuth();
    }
  }

  final AuthService _authService;
  final FirestoreService _firestoreService;
  final DeviceService _deviceService;
  final NotificationService _notificationService = NotificationService();

  User? _currentUser;
  firebase_auth.User? _firebaseUser;
  bool _isLoading = false;
  bool _isInitialized = false;
  bool _requiresDeviceTransfer = false;
  bool _requiresEmailVerification = false;
  String? _error;

  User? get currentUser => _currentUser;
  firebase_auth.User? get firebaseUser => _firebaseUser;
  bool get isLoading => _isLoading;
  String? get error => _error;
  bool get isAuthenticated =>
      _firebaseUser != null && _currentUser != null && _isInitialized;
  bool get isInitialized => _isInitialized;
  bool get requiresDeviceTransfer => _requiresDeviceTransfer;
  bool get requiresEmailVerification => _requiresEmailVerification;

  Future<User?> _loadUserProfileWithRetry(String uid, {String? email}) async {
    User? profile;
    for (int attempt = 0; attempt < 3; attempt++) {
      profile = await _firestoreService.getUserData(
        uid,
        fallbackEmail: email,
      );
      if (profile != null) break;
      await Future.delayed(const Duration(milliseconds: 500));
    }
    return profile;
  }

  Future<void> _ensurePushRegistration(firebase_auth.User firebaseUser) async {
    try {
      await _notificationService.initializeNotifications();
      await _notificationService.subscribeToBusAnnouncements();
      await _notificationService.saveDeviceToken(userId: firebaseUser.uid);
    } catch (e) {
      debugPrint('AuthProvider: push registration sync failed: $e');
    }
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
        _isInitialized = true;
        notifyListeners();
        return;
      }

      final fetchedProfile = await _loadUserProfileWithRetry(
        firebaseUser.uid,
        email: firebaseUser.email,
      );
      if (fetchedProfile != null) {
        _currentUser = fetchedProfile;
        _error = null;
        unawaited(_ensurePushRegistration(firebaseUser));
      } else {
        // Avoid clobbering an already loaded profile for the same user when
        // Firestore briefly fails during auth-state propagation.
        if (_currentUser?.uid != firebaseUser.uid) {
          _currentUser = null;
        }
      }
      _isInitialized = true;
      notifyListeners();
    });
  }

  Future<bool> signUp({
    required String email,
    required String password,
    required String fullName,
    required UserRole role,
  }) async {
    final normalizedEmail = email.trim().toLowerCase();

    _isLoading = true;
    _error = null;
    _requiresDeviceTransfer = false;
    _requiresEmailVerification = false;
    notifyListeners();

    try {
      if (role != UserRole.student) {
        _error =
            'Staff accounts are created by admin. Please contact administrator or sign in.';
        return false;
      }

      final isStaffEmail =
          await _firestoreService.isEmailRegisteredAsStaff(normalizedEmail);
      if (isStaffEmail) {
        _error =
            'This email has already been registered as a staff account. Please sign in with staff access.';
        return false;
      }

      final result = await _authService.signUp(
        email: normalizedEmail,
        password: password,
        fullName: fullName,
        role: role,
      );

      if (result != null) {
        _error = result;
        return false;
      }

      if (role == UserRole.student) {
        final verificationError =
            await _authService.sendCurrentUserEmailVerification();
        await _authService.signOut();
        if (verificationError != null) {
          _error =
              'Account created, but failed to send verification email. Please try signing in to resend it.';
          return true;
        }
      }

      return true;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<bool> signIn({
    required String email,
    required String password,
    bool allowDeviceTransfer = false,
  }) async {
    _isLoading = true;
    _error = null;
    _requiresDeviceTransfer = false;
    _requiresEmailVerification = false;
    notifyListeners();

    try {
      final result = await _authService.signIn(
        email: email,
        password: password,
      );

      if (result != null) {
        _error = result;
        return false;
      }

      final signedInUser = _authService.currentUser;
      if (signedInUser == null) {
        _error = 'Sign-in succeeded, but no authenticated session was found.';
        return false;
      }

      // Load profile with short retries to handle transient Firestore/network lag.
      final profile = await _loadUserProfileWithRetry(
        signedInUser.uid,
        email: signedInUser.email,
      );

      if (profile == null) {
        _error =
            'Signed in, but unable to load your account profile. Check your internet connection and ensure this account exists in users collection.';
        await _authService.signOut();
        return false;
      }

      if (profile.role == UserRole.student && !signedInUser.emailVerified) {
        await _authService.sendCurrentUserEmailVerification();
        await _authService.signOut();
        _firebaseUser = null;
        _currentUser = null;
        _requiresEmailVerification = true;
        _error =
            'Please verify your email before signing in. A verification link has been sent to your inbox.';
        return false;
      }

      if (profile.role == UserRole.student) {
        final deviceId = await _deviceService.getDeviceId();
        final bindingResult =
            await _firestoreService.ensureStudentDeviceBinding(
          uid: signedInUser.uid,
          deviceId: deviceId,
          allowTransfer: allowDeviceTransfer,
        );
        if (!bindingResult.isAllowed) {
          await _authService.signOut();
          _firebaseUser = null;
          _currentUser = null;
          _requiresDeviceTransfer = bindingResult.requiresTransfer;
          _error = bindingResult.message ??
              'This account cannot be used on this device.';
          return false;
        }
      }

      _firebaseUser = signedInUser;
      _currentUser = profile;
      _error = null;
      unawaited(_ensurePushRegistration(signedInUser));
      return true;
    } catch (e) {
      _error = 'Sign-in failed: $e';
      return false;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> signOut() async {
    if (_firebaseUser != null) {
      try {
        await FirebaseFirestore.instance
            .collection('device_tokens')
            .doc(_firebaseUser!.uid)
            .update({'fcmToken': FieldValue.delete()});
      } catch (_) {
        // Ignore if document missing or permission denied
      }
    }
    await _authService.signOut();
    _currentUser = null;
    _requiresDeviceTransfer = false;
    _requiresEmailVerification = false;
    notifyListeners();
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
  }) async {
    if (_firebaseUser == null) return false;

    final result = await _authService.updateUserProfile(
      uid: _firebaseUser!.uid,
      fullName: fullName,
    );

    if (result == null) {
      // Refresh user data
      _currentUser = await _firestoreService.getUserData(
        _firebaseUser!.uid,
        fallbackEmail: _firebaseUser!.email,
      );
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
