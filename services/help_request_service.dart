import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/services.dart' show MissingPluginException;
import 'package:flutter_email_sender/flutter_email_sender.dart';

import '../models/help_request_model.dart';

/// Thrown when there's no email app set up on the device to hand the
/// compose request to. Mirrors EmailShareService's exception so callers
/// can show the same kind of message.
class NoEmailAppException implements Exception {
  final String message;
  NoEmailAppException([
    this.message = 'No email app is set up on this device.',
  ]);
  @override
  String toString() => message;
}

/// ═══════════════════════════════════════════════════════════════════
/// HelpRequestService
/// ───────────────────────────────────────────────────────────────────
/// Backs the "Need Help?" flow for users who cannot sign in at all.
///
///  USER SIDE (no auth required — see firestore_rules.txt):
///    submitHelpRequest() just needs a name + valid-looking email +
///    message. No FirebaseAuth.currentUser check anywhere in this file.
///
///  ADMIN SIDE:
///    streamPending()/streamAll() power AdminHelpRequestsScreen.
///    replyViaEmail() opens the device's native mail composer (the same
///    one signed in as the app's own support Gmail on the admin's
///    phone — see EmailShareService's doc comment for the setup that
///    makes this work) addressed to the requester's email, so the
///    reply actually reaches them even though they have no account to
///    receive an in-app notification.
/// ═══════════════════════════════════════════════════════════════════
class HelpRequestService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  CollectionReference get _col => _firestore.collection('help_requests');

  // ── PUBLIC SIDE (no sign-in) ────────────────────────────────────────

  Future<String?> submitHelpRequest({
    required String name,
    required String email,
    required String message,
  }) async {
    try {
      await _col.add({
        ...HelpRequestModel(
          name: name.trim(),
          email: email.trim(),
          message: message.trim(),
        ).toMap(),
        'createdAt': FieldValue.serverTimestamp(),
        'resolvedAt': null,
      });
      return null;
    } catch (e) {
      return 'Could not send your request. Please check your internet '
          'connection and try again.';
    }
  }

  // ── ADMIN SIDE ───────────────────────────────────────────────────────

  Stream<List<QueryDocumentSnapshot>> streamAll() {
    return _col
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((snap) => snap.docs);
  }

  /// Single-field filter only (no composite index needed), sorted on
  /// the client — same reasoning as FeedbackService.getPendingFeedback().
  Stream<List<QueryDocumentSnapshot>> streamPending() {
    return _col.where('status', isEqualTo: 'pending').snapshots().map((snap) {
      DateTime resolve(dynamic value) =>
          value is Timestamp ? value.toDate() : DateTime.now();
      final docs = snap.docs.toList()
        ..sort((a, b) =>
            resolve((b.data() as Map<String, dynamic>)['createdAt']).compareTo(
                resolve((a.data() as Map<String, dynamic>)['createdAt'])));
      return docs;
    });
  }

  Future<void> markResolved(String id) async {
    await _col.doc(id).update({
      'status': 'resolved',
      'resolvedAt': FieldValue.serverTimestamp(),
    });
  }

  Future<void> deleteHelpRequest(String id) async {
    await _col.doc(id).delete();
  }

  /// Opens the native mail composer addressed to [recipientEmail], with
  /// a pre-filled subject/body the admin can edit before sending. Marks
  /// the request resolved automatically once the app hands off to the
  /// mail app successfully — the admin can always reopen it from "All"
  /// if a reply bounces or needs a follow-up.
  Future<void> replyViaEmail({
    required String requestId,
    required String recipientEmail,
    required String recipientName,
  }) async {
    final EmailCapabilities capabilities;
    try {
      capabilities = await FlutterEmailSender.getCapabilities();
    } on MissingPluginException {
      throw Exception(
        'Email plugin not registered on this build. Run "flutter clean", '
        '"flutter pub get", then fully stop and re-run the app.',
      );
    }
    if (!capabilities.canSend) {
      throw NoEmailAppException();
    }

    final email = Email(
      recipients: [recipientEmail],
      subject: 'Re: Your help request — Mother And Baby SmartCare',
      body: 'Hi $recipientName,\n\n'
          'Thanks for reaching out to Mother And Baby SmartCare support.\n\n'
          '\n\n'
          '— Mother And Baby SmartCare Team',
      isHTML: false,
    );

    try {
      await FlutterEmailSender.send(email);
    } on FlutterEmailSenderNotAvailableException {
      throw NoEmailAppException();
    } on FlutterEmailSenderPlatformException catch (e) {
      throw Exception('Could not open the email app. ${e.message}');
    } catch (e) {
      throw Exception('Could not open the email app. $e');
    }

    await markResolved(requestId);
  }
}
