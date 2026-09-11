import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter/foundation.dart';
import 'account_cleanup_service.dart';
import 'session_service.dart';
import '../models/user_profile_model.dart';

class AuthService {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final GoogleSignIn _googleSignIn = GoogleSignIn.instance;
  final SessionService _sessionService = SessionService();

  // ═══════════════════════════════════════════════════════════════════
  // HARDCODED ADMIN ALLOWLIST
  // ───────────────────────────────────────────────────────────────────
  // Per product decision: there is no "Register as Admin" flow, no
  // invite code, and no in-app "promote user to admin" feature anymore.
  // The ONLY way an account becomes an admin is if its email address is
  // listed here, hardcoded at build time. Add/remove admin emails by
  // editing this list and shipping a new build — nothing else in the
  // app (no UI, no Firestore field a user can edit themselves) can ever
  // grant the admin role.
  //
  // IMPORTANT: put the REAL admin email(s) here before release. Emails
  // are compared lower-cased/trimmed, so casing/whitespace never matters.
  static const List<String> _adminEmails = [
    'motherandbabysmartcare@gmail.com',
  ];

  static bool isAdminEmail(String? email) {
    if (email == null) return false;
    return _adminEmails.contains(email.trim().toLowerCase());
  }

  /// Idempotent: makes sure [uid]'s Firestore role matches what it
  /// should be for [email] — forced to 'admin' when the email is on the
  /// hardcoded allowlist above, left untouched otherwise. Safe to call
  /// on every login; it's a no-op once the role already matches.
  Future<void> _syncAdminRole(String uid, String? email) async {
    if (!isAdminEmail(email)) return;
    try {
      final docRef = _firestore.collection('users').doc(uid);
      final doc = await docRef.get();
      if (doc.exists && doc.data()?['role'] == 'admin') return;
      await docRef.set({'role': 'admin'}, SetOptions(merge: true));
    } catch (e) {
      debugPrint('AuthService: _syncAdminRole failed for $uid: $e');
    }
  }

  bool _googleInitialized = false;

  Future<void> _ensureGoogleInitialized() async {
    if (_googleInitialized) return;
    await _googleSignIn.initialize();
    _googleInitialized = true;
  }

  User? get currentUser => _auth.currentUser;

  bool get hasPasswordProvider {
    final user = _auth.currentUser;
    if (user == null) return false;
    return user.providerData.any((p) => p.providerId == 'password');
  }

  bool get hasGoogleProvider {
    final user = _auth.currentUser;
    if (user == null) return false;
    return user.providerData.any((p) => p.providerId == 'google.com');
  }

  String _mapError(String code) {
    switch (code) {
      case 'email-already-in-use':
        return 'This email is already registered.';
      case 'invalid-email':
        return 'Enter a valid email address.';
      case 'weak-password':
        return 'Password is too weak.';
      case 'user-not-found':
        return 'No account found with this email.';
      case 'wrong-password':
      case 'invalid-credential':
        return 'Incorrect email or password.';
      case 'user-disabled':
        return 'This account has been disabled.';
      case 'too-many-requests':
        return 'Too many attempts. Please wait a moment and try again.';
      case 'network-request-failed':
        return 'Network error. Check your internet connection.';
      case 'user-blocked':
        return 'Your account has been blocked. Contact admin.';
      case 'requires-recent-login':
        return 'For security, please sign in again to continue.';
      case 'account-exists-with-different-credential':
        return 'An account already exists with this email using a different sign-in method.';
      case 'credential-already-in-use':
        return 'This Google account is already linked to another user.';
      case 'provider-already-linked':
        return 'A password is already set for this account.';
      case 'permission-denied':
        return 'Access denied by server rules.';
      default:
        return 'Something went wrong. Please try again.';
    }
  }

  Future<UserCredential> _doEmailLogin(String email, String password) {
    return _auth.signInWithEmailAndPassword(
      email: email.trim(),
      password: password.trim(),
    );
  }

  Future<String?> login({
    required String email,
    required String password,
  }) async {
    try {
      await _auth.signOut();
    } catch (_) {}

    Future<String?> attempt() async {
      try {
        final cred = await _doEmailLogin(email, password);
        debugPrint('✅ Auth succeeded, uid: ${cred.user!.uid}');
        debugPrint('🔥 Reading users/${cred.user!.uid} on project '
            '${Firebase.app().options.projectId}');

        final doc =
            await _firestore.collection('users').doc(cred.user!.uid).get();

        if (doc.exists && (doc.data()?['blocked'] == true)) {
          await _auth.signOut();
          return _mapError('user-blocked');
        }
        if (!doc.exists) {
          await ensureUserDoc();
        }
        // Hardcoded-admin-email self-heal (see `_adminEmails` above) —
        // guarantees this exact email is always treated as admin, even
        // if the Firestore doc was created manually in the console
        // without a role field, or with a stale/wrong one.
        await _syncAdminRole(cred.user!.uid, cred.user!.email);
        final prefs = await SharedPreferences.getInstance();
        await prefs.setBool('isFirstTime', false);
        await prefs.setBool('isLoggedIn', true);
        try {
          await _sessionService.registerSession(cred.user!.uid);
        } catch (e) {
          debugPrint('AuthService: registerSession failed (non-fatal): $e');
        }
        return null;
      } on FirebaseAuthException catch (e) {
        debugPrint('❌ FirebaseAuthException: ${e.code} — ${e.message}');
        return _mapError(e.code);
      } on FirebaseException catch (e) {
        debugPrint('❌ FirebaseException (Firestore): ${e.code} — ${e.message}');
        return '${_mapError(e.code)} (${e.code})';
      } catch (e) {
        debugPrint('❌ Unknown login error: $e');
        return 'Login failed: ${e.toString()}';
      }
    }

    final result = await attempt();
    if (result != null && result.contains('Too many attempts')) {
      await Future.delayed(const Duration(seconds: 4));
      return await attempt();
    }
    return result;
  }

  Future<Map<String, dynamic>> signInWithGoogle({
    String? defaultRole,
    String defaultCountry = '',
  }) async {
    try {
      await _ensureGoogleInitialized();
      await _googleSignIn.signOut();
      await _auth.signOut();
    } catch (_) {}

    try {
      final googleUser = await _googleSignIn.authenticate();
      final String? idToken = googleUser.authentication.idToken;

      String? accessToken;
      try {
        final authz = await googleUser.authorizationClient
            .authorizeScopes(['email', 'profile']);
        accessToken = authz.accessToken;
      } catch (_) {}

      if (idToken == null) {
        return {'error': 'Google authentication failed. Please try again.'};
      }

      final credential = GoogleAuthProvider.credential(
        accessToken: accessToken,
        idToken: idToken,
      );

      final userCred = await _auth.signInWithCredential(credential);
      final user = userCred.user!;
      final isNewUser = userCred.additionalUserInfo?.isNewUser ?? false;

      final docRef = _firestore.collection('users').doc(user.uid);
      final doc = await docRef.get();
      String role;
      bool securityNotice = false;

      if (!doc.exists) {
        role = defaultRole ?? 'mother';
        if (isAdminEmail(user.email)) role = 'admin';
        await docRef.set({
          ...UserProfileModel(
            uid: user.uid,
            name: user.displayName ?? googleUser.displayName ?? '',
            email: user.email ?? googleUser.email,
            role: role,
            accountVerified: true,
            country: defaultCountry.trim(),
          ).toMap(),
          'createdAt': FieldValue.serverTimestamp(),
        });
      } else {
        if (doc.data()?['blocked'] == true) {
          await _auth.signOut();
          await _googleSignIn.signOut();
          return {'error': _mapError('user-blocked')};
        }
        role = doc.data()?['role'] ?? 'mother';

        // Hardcoded-admin-email self-heal — see `_adminEmails` above.
        if (isAdminEmail(user.email) && role != 'admin') {
          role = 'admin';
          await docRef.set({'role': 'admin'}, SetOptions(merge: true));
        }

        final wasVerified = doc.data()?['accountVerified'] == true;
        if (!wasVerified) {
          if (hasPasswordProvider && user.email != null) {
            try {
              await _auth.sendPasswordResetEmail(email: user.email!);
              securityNotice = true;
            } catch (_) {}
          }
          await docRef.update({'accountVerified': true});
        }
      }

      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool('isFirstTime', false);
      await prefs.setBool('isLoggedIn', true);
      try {
        await _sessionService.registerSession(user.uid);
      } catch (e) {
        debugPrint('AuthService: registerSession failed (non-fatal): $e');
      }
      return {
        'error': null,
        'role': role,
        'isNewUser': isNewUser,
        'securityNotice': securityNotice,
      };
    } on GoogleSignInException catch (e) {
      if (e.code == GoogleSignInExceptionCode.canceled) {
        return {'error': 'Google sign-in was cancelled.'};
      }
      try {
        await _googleSignIn.signOut();
        await _auth.signOut();
      } catch (_) {}
      return {'error': 'Google sign-in failed. Please try again.'};
    } on FirebaseAuthException catch (e) {
      try {
        await _googleSignIn.signOut();
        await _auth.signOut();
      } catch (_) {}
      return {'error': _mapError(e.code)};
    } on FirebaseException catch (e) {
      try {
        await _googleSignIn.signOut();
        await _auth.signOut();
      } catch (_) {}
      return {'error': '${_mapError(e.code)} (${e.code})'};
    } catch (e) {
      try {
        await _googleSignIn.signOut();
        await _auth.signOut();
      } catch (_) {}
      return {'error': 'Google sign-in failed: ${e.toString()}'};
    }
  }

  Future<String?> register({
    required String name,
    required String email,
    required String password,
    required String role,
    String country = '',
  }) async {
    // Hardcoded-admin-email override — see `_adminEmails` above. There is
    // no UI path left that can set role to 'admin' (the old "Register as
    // Admin" toggle + invite code is gone); this is the only way an
    // account ever becomes admin, and it only fires for the exact
    // email(s) hardcoded in this file.
    final effectiveRole = isAdminEmail(email) ? 'admin' : role;
    UserCredential? cred;
    try {
      cred = await _auth.createUserWithEmailAndPassword(
        email: email.trim(),
        password: password.trim(),
      );
      await _firestore.collection('users').doc(cred.user!.uid).set({
        ...UserProfileModel(
          uid: cred.user!.uid,
          name: name.trim(),
          email: email.trim(),
          role: effectiveRole,
          accountVerified: false,
          country: country.trim(),
        ).toMap(),
        'createdAt': FieldValue.serverTimestamp(),
      });
      await cred.user!.sendEmailVerification();
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool('isFirstTime', false);
      try {
        await _sessionService.registerSession(cred.user!.uid);
      } catch (e) {
        debugPrint('AuthService: registerSession failed (non-fatal): $e');
      }
      return null;
    } on FirebaseAuthException catch (e) {
      return _mapError(e.code);
    } on FirebaseException catch (e) {
      await _rollbackOrphanedAuthAccount(cred);
      return '${_mapError(e.code)} (${e.code}) — please try registering again.';
    } catch (e) {
      await _rollbackOrphanedAuthAccount(cred);
      return 'Registration failed: ${e.toString()}';
    }
  }

  Future<void> _rollbackOrphanedAuthAccount(UserCredential? cred) async {
    try {
      await cred?.user?.delete();
    } catch (e) {
      debugPrint('AuthService: could not roll back orphaned Auth user: $e');
    }
  }

  Future<void> ensureUserDoc({String fallbackRole = 'mother'}) async {
    final user = _auth.currentUser;
    if (user == null) return;
    try {
      final docRef = _firestore.collection('users').doc(user.uid);
      final doc = await docRef.get();
      if (doc.exists) return;
      await docRef.set({
        ...UserProfileModel(
          uid: user.uid,
          name: user.displayName ?? '',
          email: user.email ?? '',
          role: fallbackRole,
          accountVerified: user.emailVerified,
        ).toMap(),
        'createdAt': FieldValue.serverTimestamp(),
      });
      debugPrint('AuthService: self-healed missing users/${user.uid} doc.');
    } catch (e) {
      debugPrint('AuthService: ensureUserDoc failed: $e');
    }
  }

  Future<bool> checkEmailVerified() async {
    try {
      await _auth.currentUser?.reload();
      final verified = _auth.currentUser?.emailVerified ?? false;
      if (verified) {
        final user = _auth.currentUser;
        if (user != null) {
          final docRef = _firestore.collection('users').doc(user.uid);
          final doc = await docRef.get();
          if (doc.exists && doc.data()?['accountVerified'] != true) {
            await docRef.update({'accountVerified': true});
          }
        }
      }
      return verified;
    } catch (_) {
      return false;
    }
  }

  Future<String?> resendVerificationEmail() async {
    try {
      final user = _auth.currentUser;
      if (user == null) return 'No user logged in.';
      await user.sendEmailVerification();
      return null;
    } on FirebaseAuthException catch (e) {
      return _mapError(e.code);
    } catch (e) {
      return 'Failed to resend email: ${e.toString()}';
    }
  }

  Future<void> logout() async {
    final uid = _auth.currentUser?.uid;
    if (uid != null) {
      try {
        await _sessionService.revokeCurrentSessionOnLogout(uid);
      } catch (_) {}
    }
    try {
      await _auth.signOut();
    } catch (_) {}
    try {
      await _googleSignIn.signOut();
    } catch (_) {}
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('isLoggedIn', false);
  }

  Future<String?> sendPasswordResetEmail(String email) async {
    try {
      await _auth.sendPasswordResetEmail(email: email.trim());
      return null;
    } on FirebaseAuthException catch (e) {
      return _mapError(e.code);
    } catch (e) {
      return 'Failed to send reset email: ${e.toString()}';
    }
  }

  Future<String?> changePassword({
    required String oldPassword,
    required String newPassword,
  }) async {
    try {
      final user = _auth.currentUser;
      if (user == null || user.email == null) return 'No user logged in.';
      final cred = EmailAuthProvider.credential(
        email: user.email!,
        password: oldPassword,
      );
      await user.reauthenticateWithCredential(cred);
      await user.updatePassword(newPassword.trim());
      return null;
    } on FirebaseAuthException catch (e) {
      return _mapError(e.code);
    } catch (e) {
      return 'Failed to change password: ${e.toString()}';
    }
  }

  Future<String?> setInitialPassword(String newPassword) async {
    try {
      final user = _auth.currentUser;
      if (user == null || user.email == null) return 'No user logged in.';
      final cred = EmailAuthProvider.credential(
        email: user.email!,
        password: newPassword.trim(),
      );
      await user.linkWithCredential(cred);
      return null;
    } on FirebaseAuthException catch (e) {
      return _mapError(e.code);
    } catch (e) {
      return 'Failed to set password: ${e.toString()}';
    }
  }

  Future<String?> reauthenticateWithGoogle() async {
    try {
      await _ensureGoogleInitialized();
      final googleUser = await _googleSignIn.authenticate();
      final idToken = googleUser.authentication.idToken;
      String? accessToken;
      try {
        final authz = await googleUser.authorizationClient
            .authorizeScopes(['email', 'profile']);
        accessToken = authz.accessToken;
      } catch (_) {}
      if (idToken == null) {
        return 'Re-authentication failed. Please try again.';
      }
      final credential = GoogleAuthProvider.credential(
        accessToken: accessToken,
        idToken: idToken,
      );
      await _auth.currentUser?.reauthenticateWithCredential(credential);
      return null;
    } on GoogleSignInException catch (e) {
      if (e.code == GoogleSignInExceptionCode.canceled) {
        return 'Re-authentication was cancelled.';
      }
      return 'Re-authentication failed. Please try again.';
    } on FirebaseAuthException catch (e) {
      return _mapError(e.code);
    } catch (e) {
      return 'Re-authentication failed: ${e.toString()}';
    }
  }

  Future<String?> requestEmailChange(
      String newEmail, String currentPassword) async {
    try {
      final user = _auth.currentUser;
      if (user == null || user.email == null) return 'No user logged in.';
      final cred = EmailAuthProvider.credential(
        email: user.email!,
        password: currentPassword,
      );
      await user.reauthenticateWithCredential(cred);
      await user.verifyBeforeUpdateEmail(newEmail.trim());
      return null;
    } on FirebaseAuthException catch (e) {
      return _mapError(e.code);
    } catch (e) {
      return 'Failed to update email: ${e.toString()}';
    }
  }

  Future<void> syncEmailAfterVerification() async {
    try {
      final user = _auth.currentUser;
      if (user == null || user.email == null) return;
      await user.reload();
      final freshUser = _auth.currentUser;
      if (freshUser == null || freshUser.email == null) return;
      final docRef = _firestore.collection('users').doc(freshUser.uid);
      final doc = await docRef.get();
      if (doc.exists && doc.data()?['email'] != freshUser.email) {
        await docRef.update({'email': freshUser.email});
      }
    } catch (_) {}
  }

  Future<String> getUserRole(String uid) async {
    try {
      final doc = await _firestore.collection('users').doc(uid).get();
      return doc.exists ? (doc.data()?['role'] ?? 'mother') : 'mother';
    } catch (_) {
      return 'mother';
    }
  }

  Future<String?> deleteAccount() async {
    final user = _auth.currentUser;
    if (user == null) return 'No user logged in.';
    final uid = user.uid;

    try {
      await user.delete();
    } on FirebaseAuthException catch (e) {
      return _mapError(e.code);
    } catch (e) {
      return 'Failed to delete account: ${e.toString()}';
    }

    try {
      await AccountCleanupService.wipeAllUserData(uid);
    } catch (e) {
      debugPrint('AuthService.deleteAccount: Firestore wipe incomplete '
          'for $uid: $e');
    }

    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.clear();
    } catch (_) {}

    return null;
  }
}
