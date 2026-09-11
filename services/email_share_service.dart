import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/services.dart' show MissingPluginException;
import 'package:flutter_email_sender/flutter_email_sender.dart';
import 'package:path_provider/path_provider.dart';

import 'firebase_service.dart';

/// Thrown whenever the device has no internet connection at the moment
/// the user tries to send a report. Screens catch this specifically to
/// show the "No internet connection" message the user asked for.
class NoInternetException implements Exception {
  final String message;
  NoInternetException([this.message = 'No internet connection']);
  @override
  String toString() => message;
}

/// Thrown when there's no email app (Gmail, Outlook, Mail, etc.) set up
/// on the device to hand the compose request to.
class NoEmailAppException implements Exception {
  final String message;
  NoEmailAppException([
    this.message = 'No email app is set up on this device.',
  ]);
  @override
  String toString() => message;
}

/// ═══════════════════════════════════════════════════════════════════
/// EmailShareService
/// ───────────────────────────────────────────────────────────────────
/// Opens the device's native email compose screen (Gmail on Android,
/// Mail on iOS via MFMailComposeViewController, Mail app on macOS) with
/// the recipient, subject, body, and PDF attachment already filled in.
/// The user reviews and taps Send themselves inside that app.
///
/// IMPORTANT SETUP (do this once, or you'll see
/// "MissingPluginException: getTemporaryDirectory"):
///   1. pubspec.yaml must have: path_provider, flutter_email_sender
///   2. After adding those, run: flutter clean && flutter pub get
///   3. FULLY STOP and re-run the app (flutter run) — hot reload/
///      hot restart does NOT register new native plugins. This is the
///      single most common cause of "MissingPluginException" for a
///      plugin you just added.
///   4. Android only: declare a FileProvider in AndroidManifest.xml
///      + a res/xml/file_paths.xml, otherwise attachments silently
///      fail even once the temp-dir error is gone.
///   5. iOS only: add LSApplicationQueriesSchemes (mailto) to
///      Info.plist so canSend detection works.
/// ═══════════════════════════════════════════════════════════════════
class EmailShareService {
  EmailShareService._();

  /// Writes [pdfBytes] to a temp file and opens the native email
  /// composer pre-filled with [recipientEmail], [subject], [bodyText],
  /// and the PDF attached.
  ///
  /// Throws:
  /// - [NoInternetException] if the device is offline.
  /// - [NoEmailAppException] if no mail app/account is available.
  /// - [Exception] for any other failure, with a human-readable reason.
  static Future<void> sendReportEmail({
    required String recipientEmail,
    required String subject,
    required String bodyText,
    required Uint8List pdfBytes,
    required String fileName,
  }) async {
    // Re-checked right before sending — connectivity_plus's cached
    // value could be a few hundred ms stale, this is the real gate.
    if (!FirestoreService.isOnline.value) {
      throw NoInternetException();
    }

    // Ask the platform up front whether it can even show a composer
    // right now (no mail account configured, simulator, etc.) so we
    // can fail with a clear, specific message instead of a generic one.
    final EmailCapabilities capabilities;
    try {
      capabilities = await FlutterEmailSender.getCapabilities();
    } on MissingPluginException {
      throw Exception(
        'Email plugin not registered on this build. Run "flutter clean", '
        '"flutter pub get", then fully stop and re-run the app '
        '(not hot reload/hot restart).',
      );
    }
    if (!capabilities.canSend) {
      throw NoEmailAppException();
    }

    final file = await _writeTempPdf(pdfBytes, fileName);

    final email = Email(
      recipients: [recipientEmail],
      subject: subject,
      body: bodyText,
      attachmentPaths: capabilities.supportsAttachments ? [file.path] : null,
      isHTML: false,
    );

    try {
      await FlutterEmailSender.send(email);
    } on FlutterEmailSenderNotAvailableException {
      throw NoEmailAppException();
    } on FlutterEmailSenderUnsupportedFeatureException catch (e) {
      throw Exception(
          'Your mail app does not support: ${e.unsupportedFeatures.join(', ')}.');
    } on FlutterEmailSenderPlatformException catch (e) {
      throw Exception('Could not open the email app. ${e.message}');
    } catch (e) {
      throw Exception('Could not open the email app. $e');
    } finally {
      // Best-effort cleanup — don't let a delete failure surface as a
      // send failure to the user; the OS temp dir gets swept anyway.
      try {
        if (await file.exists()) await file.delete();
      } catch (_) {}
    }
  }

  /// Writes [pdfBytes] to disk so it can be attached to the email.
  ///
  /// Tries the temp directory first (the normal path). If that throws
  /// [MissingPluginException] — meaning `path_provider`'s native plugin
  /// channel isn't registered, almost always because the app was hot
  /// reloaded/restarted after adding the plugin instead of being fully
  /// stopped and re-run — this surfaces a clear, actionable error.
  ///
  /// For any *other* failure reading the temp directory (e.g. a
  /// sandboxing quirk on a specific device/OS version), it falls back
  /// to the app's documents directory before giving up, so a single
  /// platform oddity doesn't hard-fail the whole send flow.
  static Future<File> _writeTempPdf(Uint8List pdfBytes, String fileName) async {
    Directory dir;
    try {
      dir = await getTemporaryDirectory();
    } on MissingPluginException {
      throw Exception(
        'PDF storage plugin not registered on this build. Run "flutter '
        'clean", "flutter pub get", then fully stop and re-run the app '
        '(not hot reload/hot restart) — new native plugins are only '
        'registered on a full app restart.',
      );
    } catch (_) {
      // Non-plugin failure reading the temp dir — fall back rather
      // than failing the whole send.
      try {
        dir = await getApplicationDocumentsDirectory();
      } on MissingPluginException {
        throw Exception(
          'PDF storage plugin not registered on this build. Run "flutter '
          'clean", "flutter pub get", then fully stop and re-run the app '
          '(not hot reload/hot restart).',
        );
      } catch (e) {
        throw Exception(
            'Could not access device storage to prepare the PDF. $e');
      }
    }

    try {
      final file = File('${dir.path}/$fileName');
      await file.writeAsBytes(pdfBytes, flush: true);
      return file;
    } catch (e) {
      throw Exception('Could not prepare the PDF file. $e');
    }
  }
}
