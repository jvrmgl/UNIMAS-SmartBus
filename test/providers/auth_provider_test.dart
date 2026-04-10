import 'dart:async';

import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart' as firebase_auth;
import 'package:flutter_test/flutter_test.dart';
import 'package:unimas_smartbus/models/user_model.dart';
import 'package:unimas_smartbus/providers/auth_provider.dart';
import 'package:unimas_smartbus/services/auth_service.dart';
import 'package:unimas_smartbus/services/device_service.dart';
import 'package:unimas_smartbus/services/firestore_service.dart';

class FakeAuthService extends Fake implements AuthService {
  final StreamController<firebase_auth.User?> _authStateController =
      StreamController<firebase_auth.User?>.broadcast();

  String? signUpResult;
  String? signInResult;
  String? verificationResult;
  int signUpCalls = 0;
  int signInCalls = 0;
  int verificationCalls = 0;
  int signOutCalls = 0;
  String? lastSignUpEmail;
  firebase_auth.User? currentUserValue;

  @override
  firebase_auth.User? get currentUser => currentUserValue;

  @override
  Stream<firebase_auth.User?> get authStateChanges => _authStateController.stream;

  @override
  Future<String?> signUp({
    required String email,
    required String password,
    required String fullName,
    required UserRole role,
  }) async {
    signUpCalls++;
    lastSignUpEmail = email;
    return signUpResult;
  }

  @override
  Future<String?> sendCurrentUserEmailVerification() async {
    verificationCalls++;
    return verificationResult;
  }

  @override
  Future<void> signOut() async {
    signOutCalls++;
  }

  @override
  Future<String?> signIn({
    required String email,
    required String password,
  }) async {
    signInCalls++;
    return signInResult;
  }

  @override
  Future<String?> updateUserProfile({
    required String uid,
    String? fullName,
  }) async {
    return null;
  }

  @override
  Future<String?> resetPassword(String email) async {
    return null;
  }

  @override
  Future<String?> updatePassword({
    required String currentPassword,
    required String newPassword,
  }) async {
    return null;
  }

  Future<void> disposeController() async {
    await _authStateController.close();
  }
}

class FakeFirebaseUser extends Fake implements firebase_auth.User {
  FakeFirebaseUser({
    required this.uid,
    required this.emailVerified,
    required this.email,
  });

  @override
  final String uid;

  @override
  final bool emailVerified;

  @override
  final String? email;
}

class FakeFirestoreService extends FirestoreService {
  FakeFirestoreService() : super(firestore: FakeFirebaseFirestore());

  bool isStaffEmail = false;
  int staffEmailChecks = 0;
  String? lastCheckedEmail;
  final Map<String, User> usersByUid = {};
  StudentDeviceBindingResult bindingResult =
      const StudentDeviceBindingResult.allowed();
  int ensureBindingCalls = 0;
  String? lastBindingUid;
  String? lastBindingDeviceId;
  bool? lastAllowTransfer;

  @override
  Future<bool> isEmailRegisteredAsStaff(String email) async {
    staffEmailChecks++;
    lastCheckedEmail = email;
    return isStaffEmail;
  }

  @override
  Future<User?> getUserData(String uid) async {
    return usersByUid[uid];
  }

  @override
  Future<StudentDeviceBindingResult> ensureStudentDeviceBinding({
    required String uid,
    required String deviceId,
    bool allowTransfer = false,
  }) async {
    ensureBindingCalls++;
    lastBindingUid = uid;
    lastBindingDeviceId = deviceId;
    lastAllowTransfer = allowTransfer;
    return bindingResult;
  }
}

class FakeDeviceService implements DeviceService {
  String deviceId = 'device-test-1';
  int getDeviceIdCalls = 0;

  @override
  Future<void> initialize() async {}

  @override
  Future<String> getDeviceId() async {
    getDeviceIdCalls++;
    return deviceId;
  }

  @override
  Future<void> clearDeviceId() async {}
}

void main() {
  group('AuthProvider signUp', () {
    late FakeAuthService authService;
    late FakeFirestoreService firestoreService;
    late FakeDeviceService deviceService;
    late AuthProvider provider;

    setUp(() {
      authService = FakeAuthService();
      firestoreService = FakeFirestoreService();
      deviceService = FakeDeviceService();
      provider = AuthProvider(
        authService: authService,
        firestoreService: firestoreService,
        deviceService: deviceService,
        autoInitialize: false,
      );
    });

    tearDown(() async {
      await authService.disposeController();
    });

    test('rejects non-student signup role', () async {
      final result = await provider.signUp(
        email: 'driver@unimas.my',
        password: 'password123',
        fullName: 'Driver User',
        role: UserRole.driver,
      );

      expect(result, false);
      expect(provider.error,
          'Staff accounts are created by admin. Please contact administrator or sign in.');
      expect(provider.isLoading, false);
      expect(firestoreService.staffEmailChecks, 0);
      expect(authService.signUpCalls, 0);
    });

    test('rejects email already registered as staff', () async {
      firestoreService.isStaffEmail = true;

      final result = await provider.signUp(
        email: 'Staff@UNIMAS.MY',
        password: 'password123',
        fullName: 'Staff User',
        role: UserRole.student,
      );

      expect(result, false);
      expect(provider.error,
          'This email has already been registered as a staff account. Please sign in with staff access.');
      expect(firestoreService.staffEmailChecks, 1);
      expect(firestoreService.lastCheckedEmail, 'staff@unimas.my');
      expect(authService.signUpCalls, 0);
    });

    test('returns auth signup error when signup fails', () async {
      authService.signUpResult = 'This email is already registered.';

      final result = await provider.signUp(
        email: 'student@unimas.my',
        password: 'password123',
        fullName: 'Student User',
        role: UserRole.student,
      );

      expect(result, false);
      expect(provider.error, 'This email is already registered.');
      expect(provider.isLoading, false);
      expect(authService.signUpCalls, 1);
      expect(authService.lastSignUpEmail, 'student@unimas.my');
      expect(authService.signOutCalls, 0);
    });

    test('successful student signup sends verification and signs out', () async {
      authService.signUpResult = null;
      authService.verificationResult = null;

      final result = await provider.signUp(
        email: 'Student@Unimas.My',
        password: 'password123',
        fullName: 'Student User',
        role: UserRole.student,
      );

      expect(result, true);
      expect(provider.error, isNull);
      expect(provider.isLoading, false);
      expect(authService.signUpCalls, 1);
      expect(authService.lastSignUpEmail, 'student@unimas.my');
      expect(authService.signOutCalls, 1);
    });

    test('signup success returns warning when verification email fails', () async {
      authService.signUpResult = null;
      authService.verificationResult = 'send-failed';

      final result = await provider.signUp(
        email: 'student@unimas.my',
        password: 'password123',
        fullName: 'Student User',
        role: UserRole.student,
      );

      expect(result, true);
      expect(provider.error,
          'Account created, but failed to send verification email. Please try signing in to resend it.');
      expect(authService.signOutCalls, 1);
    });
  });

  group('AuthProvider signIn', () {
    late FakeAuthService authService;
    late FakeFirestoreService firestoreService;
    late FakeDeviceService deviceService;
    late AuthProvider provider;

    User buildUser({
      required String uid,
      required UserRole role,
      String email = 'user@unimas.my',
    }) {
      return User(
        uid: uid,
        email: email,
        fullName: 'User Test',
        role: role,
        createdAt: DateTime(2026, 4, 11),
      );
    }

    setUp(() {
      authService = FakeAuthService();
      firestoreService = FakeFirestoreService();
      deviceService = FakeDeviceService();
      provider = AuthProvider(
        authService: authService,
        firestoreService: firestoreService,
        deviceService: deviceService,
        autoInitialize: false,
      );
    });

    tearDown(() async {
      await authService.disposeController();
    });

    test('fails when sign-in service returns an error', () async {
      authService.signInResult = 'Incorrect email or password.';

      final result = await provider.signIn(
        email: 'student@unimas.my',
        password: 'wrong-password',
      );

      expect(result, false);
      expect(provider.error, 'Incorrect email or password.');
      expect(provider.requiresDeviceTransfer, false);
      expect(provider.requiresEmailVerification, false);
      expect(authService.signInCalls, 1);
      expect(authService.signOutCalls, 0);
    });

    test('requires email verification for unverified student accounts',
        () async {
      authService.signInResult = null;
      authService.currentUserValue = FakeFirebaseUser(
        uid: 'student-1',
        emailVerified: false,
        email: 'student@unimas.my',
      );
      firestoreService.usersByUid['student-1'] = buildUser(
        uid: 'student-1',
        role: UserRole.student,
        email: 'student@unimas.my',
      );

      final result = await provider.signIn(
        email: 'student@unimas.my',
        password: 'password123',
      );

      expect(result, false);
      expect(provider.requiresEmailVerification, true);
      expect(provider.requiresDeviceTransfer, false);
      expect(
        provider.error,
        'Please verify your email before signing in. A verification link has been sent to your inbox.',
      );
      expect(authService.verificationCalls, 1);
      expect(authService.signOutCalls, 1);
      expect(firestoreService.ensureBindingCalls, 0);
    });

    test('requires device transfer when binding blocks login', () async {
      authService.signInResult = null;
      authService.currentUserValue = FakeFirebaseUser(
        uid: 'student-1',
        emailVerified: true,
        email: 'student@unimas.my',
      );
      firestoreService.usersByUid['student-1'] = buildUser(
        uid: 'student-1',
        role: UserRole.student,
        email: 'student@unimas.my',
      );
      firestoreService.bindingResult =
          const StudentDeviceBindingResult.transferRequired(
        message: 'Transfer required for this account.',
      );

      final result = await provider.signIn(
        email: 'student@unimas.my',
        password: 'password123',
      );

      expect(result, false);
      expect(provider.requiresDeviceTransfer, true);
      expect(provider.requiresEmailVerification, false);
      expect(provider.error, 'Transfer required for this account.');
      expect(firestoreService.ensureBindingCalls, 1);
      expect(firestoreService.lastBindingUid, 'student-1');
      expect(firestoreService.lastBindingDeviceId, 'device-test-1');
      expect(firestoreService.lastAllowTransfer, false);
      expect(deviceService.getDeviceIdCalls, 1);
      expect(authService.signOutCalls, 1);
    });

    test('student sign-in succeeds when transfer is allowed', () async {
      authService.signInResult = null;
      authService.currentUserValue = FakeFirebaseUser(
        uid: 'student-1',
        emailVerified: true,
        email: 'student@unimas.my',
      );
      firestoreService.usersByUid['student-1'] = buildUser(
        uid: 'student-1',
        role: UserRole.student,
        email: 'student@unimas.my',
      );
      firestoreService.bindingResult =
          const StudentDeviceBindingResult.allowed();

      final result = await provider.signIn(
        email: 'student@unimas.my',
        password: 'password123',
        allowDeviceTransfer: true,
      );

      expect(result, true);
      expect(provider.error, isNull);
      expect(provider.requiresDeviceTransfer, false);
      expect(provider.requiresEmailVerification, false);
      expect(provider.currentUser?.uid, 'student-1');
      expect(provider.firebaseUser?.uid, 'student-1');
      expect(firestoreService.ensureBindingCalls, 1);
      expect(firestoreService.lastAllowTransfer, true);
      expect(authService.signOutCalls, 0);
    });

    test('admin sign-in succeeds without device binding checks', () async {
      authService.signInResult = null;
      authService.currentUserValue = FakeFirebaseUser(
        uid: 'admin-1',
        emailVerified: false,
        email: 'admin@unimas.my',
      );
      firestoreService.usersByUid['admin-1'] = buildUser(
        uid: 'admin-1',
        role: UserRole.admin,
        email: 'admin@unimas.my',
      );

      final result = await provider.signIn(
        email: 'admin@unimas.my',
        password: 'password123',
      );

      expect(result, true);
      expect(provider.error, isNull);
      expect(provider.currentUser?.role, UserRole.admin);
      expect(firestoreService.ensureBindingCalls, 0);
      expect(deviceService.getDeviceIdCalls, 0);
      expect(authService.signOutCalls, 0);
    });
  });
}
