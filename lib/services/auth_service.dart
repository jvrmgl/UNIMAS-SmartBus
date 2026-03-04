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

  // Sign up with email and password
  Future<String?> signUp({
    required String email,
    required String password,
    required String fullName,
    required String phoneNumber,
    required UserRole role,
  }) async {
    try {
      // Create user in Firebase Auth
      firebase_auth.UserCredential userCredential = await _auth.createUserWithEmailAndPassword(
        email: email,
        password: password,
      );

      final uid = userCredential.user!.uid;

      // Create user document in Firestore
      final userModel = User(
        uid: uid,
        email: email,
        fullName: fullName,
        phoneNumber: phoneNumber,
        role: role,
        createdAt: DateTime.now(),
      );

      await _firestore.collection('users').doc(uid).set(userModel.toMap());

      return null; // Success
    } on firebase_auth.FirebaseAuthException catch (e) {
      return e.message ?? 'An error occurred during sign up';
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
      return e.message ?? 'An error occurred during sign in';
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
    String? phoneNumber,
  }) async {
    try {
      Map<String, dynamic> updateData = {};
      if (fullName != null) updateData['fullName'] = fullName;
      if (phoneNumber != null) updateData['phoneNumber'] = phoneNumber;

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

  // Check if user exists
  Future<bool> userExists(String uid) async {
    try {
      final doc = await _firestore.collection('users').doc(uid).get();
      return doc.exists;
    } catch (e) {
      return false;
    }
  }

  // Admin: create a user account without affecting the currently signed-in admin session
  Future<String?> createUserAsAdmin({
    required String email,
    required String password,
    required String fullName,
    required String phoneNumber,
    required UserRole role,
  }) async {
    final result = await createUserAsAdminWithResult(
      email: email,
      password: password,
      fullName: fullName,
      phoneNumber: phoneNumber,
      role: role,
    );
    return result.error;
  }

  // Admin: create a user account and return the created user profile so UI can
  // update immediately without waiting for a full list reload.
  Future<AdminCreateUserResult> createUserAsAdminWithResult({
    required String email,
    required String password,
    required String fullName,
    required String phoneNumber,
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
        phoneNumber: phoneNumber,
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

  // Delete a Firebase Auth account by re-authenticating with user credentials
  Future<String?> deleteUserAccountWithReauth({
    required String email,
    required String password,
  }) async {
    FirebaseApp? secondaryApp;
    firebase_auth.FirebaseAuth? secondaryAuth;

    try {
      final appName = 'adminDelete_${DateTime.now().microsecondsSinceEpoch}';
      secondaryApp = await Firebase.initializeApp(
        name: appName,
        options: DefaultFirebaseOptions.currentPlatform,
      );
      secondaryAuth = firebase_auth.FirebaseAuth.instanceFor(app: secondaryApp);

      final credential = await secondaryAuth.signInWithEmailAndPassword(
        email: email,
        password: password,
      );

      final user = credential.user;
      if (user == null) {
        return 'Unable to verify account credentials';
      }

      await user.delete();
      return null;
    } on firebase_auth.FirebaseAuthException catch (e) {
      return e.message ?? 'Unable to delete account';
    } catch (e) {
      return 'Error: ${e.toString()}';
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
