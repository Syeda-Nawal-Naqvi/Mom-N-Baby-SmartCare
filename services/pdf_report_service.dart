import 'dart:typed_data';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

import 'firebase_service.dart';

/// ═══════════════════════════════════════════════════════════════════
/// PdfReportService
/// ───────────────────────────────────────────────────────────────────
/// Builds a professional, branded PDF report from the user's Firestore
/// data — one for the mother's own records, one per baby profile.
/// Pure data → bytes; does NOT touch email or the file system, so it
/// can be reused (preview, save, or attach to an email) anywhere.
///
/// NOTE: PDF generation itself needs internet (it reads live Firestore
/// data), which is exactly why the calling screens check
/// `FirestoreService.isOnline.value` and show "No Internet" BEFORE
/// calling generateMotherReport()/generateBabyReport() at all.
/// ═══════════════════════════════════════════════════════════════════
class PdfReportService {
  PdfReportService._();

  static const PdfColor _brandPink = PdfColor.fromInt(0xFFE91E8C);
  static const PdfColor _brandPurple = PdfColor.fromInt(0xFF7A2790);
  static const PdfColor _grey = PdfColor.fromInt(0xFF64748B);

  // ── MOTHER REPORT ───────────────────────────────────────────────
  static Future<Uint8List> generateMotherReport() async {
    final user = FirebaseAuth.instance.currentUser;
    final userName =
        user?.displayName ?? user?.email?.split('@').first ?? 'User';

    final weight = await _fetchDocs('mother_weight');
    final bp = await _fetchDocs('blood_pressure');
    // NOTE: these two collection names must match exactly what
    // glucose_screen.dart / medical_history_screen.dart actually write
    // to (FirestoreService.add('glucose', ...) / .add('medical_history',
    // ...)) and what firestore.rules' isKnownUserSubcollection() allows.
    // They previously read 'glucose_records' / 'mother_medical_history'
    // — collections that were never written to and aren't in the rules'
    // allow-list — which made every Share/Export of the mother report
    // fail with permission-denied.
    final glucose = await _fetchDocs('glucose');
    final medical = await _fetchDocs('medical_history');

    final doc = pw.Document();
    doc.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        header: (context) => _buildHeader('Mother Health Report', userName),
        footer: (context) => _buildFooter(context),
        build: (context) => [
          _section('Weight', weight, ['weight'], ['Weight (kg)']),
          _section('Blood Pressure', bp, ['systolic', 'diastolic'],
              ['Systolic', 'Diastolic']),
          _section(
              'Glucose Level', glucose, ['glucoseLevel'], ['Glucose (mg/dL)']),
          _section('Medical History', medical, ['diseaseName'], ['Condition']),
        ],
      ),
    );
    return doc.save();
  }

  // ── BABY REPORT (one specific baby) ─────────────────────────────
  static Future<Uint8List> generateBabyReport({
    required String babyId,
    required String babyName,
  }) async {
    final DocumentSnapshot<Map<String, dynamic>> babyDoc;
    try {
      babyDoc = await FirestoreService.collection('babies').doc(babyId).get();
    } catch (e) {
      throw Exception('Failed to load baby profile "$babyId": $e');
    }
    final babyData = babyDoc.data() ?? {};
    final gender = (babyData['gender'] ?? '').toString();
    final bloodGroup = (babyData['bloodGroup'] ?? '').toString();
    final subtitle =
        [gender, bloodGroup].where((e) => e.isNotEmpty).join(' • ');

    final weight = await _fetchDocsByBaby('baby_weight', babyId);
    final vaccination = await _fetchDocsByBaby('vaccinations', babyId);
    final allergy = await _fetchDocsByBaby('allergies', babyId);
    final milestone = await _fetchDocsByBaby('milestones', babyId);
    final medical = await _fetchDocsByBaby('baby_medical_history', babyId);

    final doc = pw.Document();
    doc.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        header: (context) =>
            _buildHeader('$babyName — Health Report', subtitle),
        footer: (context) => _buildFooter(context),
        build: (context) => [
          _section('Weight', weight, ['weight'], ['Weight (kg)']),
          _section('Vaccinations', vaccination, ['vaccineName'], ['Vaccine']),
          _section('Allergies', allergy, ['allergyName'], ['Allergy']),
          _section('Milestones', milestone, ['title'], ['Milestone']),
          _section('Medical History', medical, ['disease'], ['Condition']),
        ],
      ),
    );
    return doc.save();
  }

  // ── Firestore fetch helpers (one-time .get(), not a live stream) ─
  static Future<List<Map<String, dynamic>>> _fetchDocs(
      String collection) async {
    try {
      final snap = await FirestoreService.collection(collection)
          .orderBy('createdAt', descending: false)
          .get();
      return snap.docs.map((d) => d.data()).toList();
    } catch (e) {
      // Re-thrown with the collection name attached so the "Send
      // Failed" dialog shows exactly which subcollection was denied,
      // instead of a bare [permission-denied] with no way to tell
      // which of the report's several collections caused it.
      throw Exception('Failed to load "$collection": $e');
    }
  }

  static Future<List<Map<String, dynamic>>> _fetchDocsByBaby(
      String collection, String babyId) async {
    // Same reasoning as FirestoreService.streamByBaby(): filter only,
    // sort on the client — avoids needing a manual composite index.
    try {
      final snap = await FirestoreService.collection(collection)
          .where('babyId', isEqualTo: babyId)
          .get();
      final list = snap.docs.map((d) => d.data()).toList();
      list.sort((a, b) =>
          _resolveDate(a['createdAt']).compareTo(_resolveDate(b['createdAt'])));
      return list;
    } catch (e) {
      throw Exception('Failed to load "$collection" for baby "$babyId": $e');
    }
  }

  static DateTime _resolveDate(dynamic value) {
    if (value is Timestamp) return value.toDate();
    if (value is String) return DateTime.tryParse(value) ?? DateTime.now();
    return DateTime.now();
  }

  // ── PDF layout building blocks ──────────────────────────────────
  static pw.Widget _buildHeader(String title, String subtitle) {
    return pw.Container(
      margin: const pw.EdgeInsets.only(bottom: 16),
      padding: const pw.EdgeInsets.only(bottom: 10),
      decoration: const pw.BoxDecoration(
        border: pw.Border(bottom: pw.BorderSide(color: _brandPink, width: 2)),
      ),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Text(
            'Mother And Baby SmartCare',
            style: pw.TextStyle(
              fontSize: 11,
              color: _brandPurple,
              fontWeight: pw.FontWeight.bold,
            ),
          ),
          pw.SizedBox(height: 6),
          pw.Text(
            title,
            style: pw.TextStyle(fontSize: 20, fontWeight: pw.FontWeight.bold),
          ),
          if (subtitle.isNotEmpty)
            pw.Text(subtitle,
                style: const pw.TextStyle(fontSize: 11, color: _grey)),
          pw.SizedBox(height: 4),
          pw.Text(
            'Generated on ${DateFormat('dd MMM yyyy, hh:mm a').format(DateTime.now())}',
            style: const pw.TextStyle(fontSize: 9, color: _grey),
          ),
        ],
      ),
    );
  }

  static pw.Widget _buildFooter(pw.Context context) {
    return pw.Container(
      alignment: pw.Alignment.centerRight,
      margin: const pw.EdgeInsets.only(top: 8),
      child: pw.Text(
        'Page ${context.pageNumber} of ${context.pagesCount}  ·  Mother And Baby SmartCare , Confidential Health Record',
        style: const pw.TextStyle(fontSize: 8, color: _grey),
      ),
    );
  }

  static pw.Widget _section(
    String title,
    List<Map<String, dynamic>> docs,
    List<String> fields,
    List<String> labels,
  ) {
    if (docs.isEmpty) {
      return pw.Container(
        margin: const pw.EdgeInsets.only(bottom: 18),
        child: pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            pw.Text(
              title,
              style: pw.TextStyle(
                  fontSize: 14,
                  fontWeight: pw.FontWeight.bold,
                  color: _brandPurple),
            ),
            pw.SizedBox(height: 6),
            pw.Text('No records available.',
                style: const pw.TextStyle(fontSize: 10, color: _grey)),
          ],
        ),
      );
    }

    final headers = ['Date', ...labels];
    final rows = docs.map((data) {
      final dt = _resolveDate(data['createdAt']);
      return [
        DateFormat('dd MMM yyyy').format(dt),
        for (final f in fields) (data[f] ?? '-').toString(),
      ];
    }).toList();

    return pw.Container(
      margin: const pw.EdgeInsets.only(bottom: 18),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Text(
            title,
            style: pw.TextStyle(
                fontSize: 14,
                fontWeight: pw.FontWeight.bold,
                color: _brandPurple),
          ),
          pw.SizedBox(height: 6),
          pw.TableHelper.fromTextArray(
            headers: headers,
            data: rows,
            headerStyle: pw.TextStyle(
                fontSize: 9,
                fontWeight: pw.FontWeight.bold,
                color: PdfColors.white),
            headerDecoration: const pw.BoxDecoration(color: _brandPink),
            cellStyle: const pw.TextStyle(fontSize: 9),
            cellAlignment: pw.Alignment.centerLeft,
            border: pw.TableBorder.all(color: PdfColors.grey300, width: 0.5),
            cellPadding:
                const pw.EdgeInsets.symmetric(horizontal: 6, vertical: 5),
          ),
        ],
      ),
    );
  }
}
