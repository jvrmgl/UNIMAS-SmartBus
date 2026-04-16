import 'package:firebase_auth/firebase_auth.dart' as firebase_auth;
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';
import '../models/user_model.dart';
import '../firebase_options.dart';

class AdminCreateUserResult {
  final String? error;
  final User? user;

  const AdminCreateUserResult({this.error, this.user});

  bool get isSuccess => error == null && user != null;
}

class AuthService {
  final firebase_auth.FirebaseAuth _auth = firebase_auth.FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseFunctions _functions =
      FirebaseFunctions.instanceFor(region: 'asia-southeast1');

  // Get current user
  firebase_auth.User? get currentUser => _auth.currentUser;

  // Stream of auth state changes
  Stream<firebase_auth.User?> get authStateChanges => _auth.authStateChanges();

  String _friendlySignInError(firebase_auth.FirebaseAuthException e) {
    switch (e.code) {
      case 'invalid-credential':
      case 'wrong-password':
      case 'user-not-found':
        return 'Incorrect email or password.';
      case 'invalid-email':
        return 'Please enter a valid email address.';
      case 'user-disabled':
        return 'This account has been disabled. Please contact admin.';
      case 'network-request-failed':
        return 'Network error. Check your internet and try again.';
      case 'too-many-requests':
        return 'Too many attempts. Please try again later.';
      default:
        return 'Unable to sign in right now. Please try again.';
    }
  }

  String _friendlySignUpError(firebase_auth.FirebaseAuthException e) {
    switch (e.code) {
      case 'email-already-in-use':
        return 'This email is already registered. Please sign in instead.';
      case 'invalid-email':
        return 'Please enter a valid email address.';
      case 'weak-password':
        return 'Password is too weak. Use at least 6 characters.';
      case 'network-request-failed':
        return 'Network error. Check your internet and try again.';
      default:
        return e.message ?? 'Unable to create account right now.';
    }
  }

  // Sign up with email and password
  Future<String?> signUp({
    required String email,
    required String password,
    required String fullName,
    required UserRole role,
  }) async {
    try {
      firebase_auth.UserCredential userCredential;
      final existingUser = _auth.currentUser;

      // Migration-safe path: if this device still has a legacy anonymous
      // session, link credentials so the UID stays the same and existing data
      // (reports/trips) remains accessible after signup.
      if (existingUser != null && existingUser.isAnonymous) {
        final credential = firebase_auth.EmailAuthProvider.credential(
          email: email,
          password: password,
        );
        userCredential = await existingUser.linkWithCredential(credential);
      } else {
        // Default path: create a new Firebase Auth user.
        userCredential = await _auth.createUserWithEmailAndPassword(
          email: email,
          password: password,
        );
      }

      final uid = userCredential.user!.uid;

      // Create user document in Firestore
      final userModel = User(
        uid: uid,
        email: email,
        fullName: fullName,
        role: role,
        createdAt: DateTime.now(),
      );

      await _firestore.collection('users').doc(uid).set(userModel.toMap());

      return null; // Success
    } on firebase_auth.FirebaseAuthException catch (e) {
      return _friendlySignUpError(e);
    } catch (e) {
      return 'Error: ${e.toString()}';
    }
  }

  // Sign in with email and password
  Future<String?> signIn({
    required String email,
    required String password,
  }) async {
    try {
      await _auth.signInWithEmailAndPassword(
        email: email,
        password: password,
      );
      return null; // Success
    } on firebase_auth.FirebaseAuthException catch (e) {
      return _friendlySignInError(e);
    } catch (e) {
      return 'Error: ${e.toString()}';
    }
  }

  Future<String?> sendCurrentUserEmailVerification() async {
    try {
      final user = _auth.currentUser;
      if (user == null) return 'No authenticated user found.';
      await user.sendEmailVerification();
      return null;
    } on firebase_auth.FirebaseAuthException catch (e) {
      return e.message ?? 'Unable to send verification email.';
    } catch (e) {
      return 'Error: ${e.toString()}';
    }
  }

  // Sign out
  Future<void> signOut() async {
    await _auth.signOut();
  }

  // Get user data from Firestore
  Future<User?> getUserData(String uid) async {
    try {
      final doc = await _firestore.collection('users').doc(uid).get();
      if (doc.exists) {
        return User.fromMap(doc.data() as Map<String, dynamic>);
      }
      return null;
    } catch (e) {
      debugPrint('Error getting user data: $e');
      return null;
    }
  }

  // Update user profile
  Future<String?> updateUserProfile({
    required String uid,
    String? fullName,
  }) async {
    try {
      Map<String, dynamic> updateData = {};
      if (fullName != null) updateData['fullName'] = fullName;

      await _firestore.collection('users').doc(uid).update(updateData);
      return null; // Success
    } catch (e) {
      return 'Error updating profile: ${e.toString()}';
    }
  }

  // Reset password
  Future<String?> resetPassword(String email) async {
    try {
      await _auth.sendPasswordResetEmail(email: email);
      return null; // Success
    } on firebase_auth.FirebaseAuthException catch (e) {
      return e.message ?? 'An error occurred';
    }
  }

  // Update password
  Future<String?> updatePassword({
    required String currentPassword,
    required String newPassword,
  }) async {
    try {
      final user = _auth.currentUser;
      if (user == null) return 'No user signed in';

      // Re-authenticate user with current password
      final credential = firebase_auth.EmailAuthProvider.credential(
        email: user.email!,
        password: currentPassword,
      );
      await user.reauthenticateWithCredential(credential);

      // Update to new password
      await user.updatePassword(newPassword);
      return null; // Success
    } on firebase_auth.FirebaseAuthException catch (e) {
      if (e.code == 'wrong-password') {
        return 'Current password is incorrect';
      }
      return e.message ?? 'An error occurred';
    } catch (e) {
      return 'Error: ${e.toString()}';
    }
  }

  // Admin: create a user account and return the created user profile so UI can
  // update immediately without waiting for a full list reload.
  Future<AdminCreateUserResult> createUserAsAdminWithResult({
    required String email,
    required String password,
    required String fullName,
    required UserRole role,
  }) async {
    FirebaseApp? secondaryApp;
    firebase_auth.FirebaseAuth? secondaryAuth;

    try {
      final appName = 'adminCreate_${DateTime.now().microsecondsSinceEpoch}';
      secondaryApp = await Firebase.initializeApp(
        name: appName,
        options: DefaultFirebaseOptions.currentPlatform,
      );
      secondaryAuth = firebase_auth.FirebaseAuth.instanceFor(app: secondaryApp);

      final credential = await secondaryAuth.createUserWithEmailAndPassword(
        email: email,
        password: password,
      );

      final uid = credential.user?.uid;
      if (uid == null) {
        return const AdminCreateUserResult(
          error: 'Failed to create user account',
        );
      }

      final userModel = User(
        uid: uid,
        email: email,
        fullName: fullName,
        role: role,
        createdAt: DateTime.now(),
      );

      await _firestore.collection('users').doc(uid).set(userModel.toMap());
      return AdminCreateUserResult(user: userModel);
    } on firebase_auth.FirebaseAuthException catch (e) {
      return AdminCreateUserResult(
        error: e.message ?? 'An error occurred while creating the account',
      );
    } catch (e) {
      return AdminCreateUserResult(error: 'Error: ${e.toString()}');
    } finally {
      try {
        await secondaryAuth?.signOut();
      } catch (_) {}
      try {
        await secondaryApp?.delete();
      } catch (_) {}
    }
  }

  // Admin: delete a Firebase Auth account by UID via callable Cloud Function
  Future<String?> deleteUserAuthByUidAsAdmin(String uid) async {
    try {
      final callable = _functions.httpsCallable('deleteAuthUserByUid');
      await callable.call({'uid': uid});
      return null;
    } on FirebaseFunctionsException catch (e) {
      return e.message ?? 'Unable to delete auth account';
    } catch (e) {
      return 'Error: ${e.toString()}';
    }
  }
}
