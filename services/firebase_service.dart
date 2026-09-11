import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';

/// Every read/write in the app goes through this class.
/// Data is stored under users/{uid}/{collectionName}, so:
///  - each user only ever sees their own records
///  - Firestore security rules become a one-line check
///  - Firestore's built-in offline cache + auto-sync just works,
///    no extra local-storage layer needed.
///
/// USED BY THE SHARE-PDF FEATURE (share_records_screen.dart,
/// share_mother_record_screen.dart, share_baby_record_screen.dart,
/// email_share_service.dart) via exactly three members:
///   - `FirestoreService.isOnline`        → `ValueNotifier<bool>`, read
///     synchronously right before compiling/sending a PDF, and listened
///     to by ShareBabyPickerScreen to switch between the live stream and
///     the SharedPreferences-backed offline cache.
///   - `FirestoreService.collection(name)` → used by PdfReportService to
///     fetch a specific baby doc and by anything doing a one-off .get().
///   - `FirestoreService.stream(name)`     → used by ShareBabyPickerScreen
///     for the live "babies" list.
/// Nothing else in this file needs to change for that feature to work —
/// it was written to already match this shape.
class FirestoreService {
  FirestoreService._();

  static final FirebaseFirestore _db = FirebaseFirestore.instance;

  static String? get _uid => FirebaseAuth.instance.currentUser?.uid;

  /// Reflects whether the device currently has network connectivity.
  /// Purely informational for most of the app — screens can listen to
  /// this to show an "offline — changes will sync" banner, and Firestore
  /// already queues writes in its local cache while offline and syncs
  /// them automatically once connectivity returns.
  ///
  /// The Share-PDF feature is the one place that treats this as a hard
  /// gate rather than just informational: sending an email requires an
  /// actual live connection (to compile fresh PDF data and to hand off
  /// to the mail app), so those screens check `.value` before doing
  /// either and show a "No Internet Connection" dialog if it's false.
  static final ValueNotifier<bool> isOnline = ValueNotifier<bool>(true);
  static StreamSubscription<List<ConnectivityResult>>? _connSub;
  static bool _initialized = false;

  /// Call once in main(), right after Firebase.initializeApp() and before
  /// runApp(). Safe to call multiple times.
  static Future<void> init() async {
    if (_initialized) return;
    _initialized = true;

    // Explicit for clarity — persistence is already on by default on
    // mobile, but stating it here documents the behavior the rest of the
    // app relies on.
    //
    // Wrapped in try/catch on purpose: setting `.settings` THROWS if
    // Firestore has already started in this process — which happens on
    // every Flutter *hot restart* during development, since hot restart
    // re-runs main() but keeps the native Firestore SDK alive underneath.
    // An uncaught throw here would abort the rest of main() — including
    // AlarmClockService().init() right after it — which is exactly what
    // can silently break alarms while iterating on code. A full
    // stop-and-rerun doesn't hit this, only hot restart does, which is
    // why it can look like "random" breakage tied to unrelated edits.
    try {
      _db.settings = const Settings(
        persistenceEnabled: true,
        cacheSizeBytes: Settings.CACHE_SIZE_UNLIMITED,
      );
    } catch (e) {
      debugPrint(
          'FirestoreService: skipping settings (already initialized): $e');
    }

    final connectivity = Connectivity();
    final initial = await connectivity.checkConnectivity();
    isOnline.value = !initial.contains(ConnectivityResult.none);

    _connSub = connectivity.onConnectivityChanged.listen((results) {
      isOnline.value = !results.contains(ConnectivityResult.none);
    });
  }

  static void dispose() => _connSub?.cancel();

  static CollectionReference<Map<String, dynamic>> collection(String name) {
    final uid = _uid;
    if (uid == null) {
      throw StateError('No authenticated user — cannot access "$name"');
    }
    return _db.collection('users').doc(uid).collection(name);
  }

  /// Streams a collection, newest-first by default.
  ///
  /// `includeMetadataChanges: true` makes the stream re-emit when a
  /// document's sync status changes (e.g. moves from "pending write" to
  /// "confirmed by server"), which is what lets the UI show a live
  /// "waiting to sync" indicator via `doc.metadata.hasPendingWrites`.
  static Stream<QuerySnapshot<Map<String, dynamic>>> stream(
    String name, {
    String orderBy = 'createdAt',
    bool descending = true,
  }) {
    return collection(name)
        .orderBy(orderBy, descending: descending)
        .snapshots(includeMetadataChanges: true);
  }

  /// Streams every document in [name] whose `babyId` field matches
  /// [babyId] — i.e. the records that belong to one specific baby profile.
  ///
  /// Deliberately does NOT combine `where('babyId', ...)` with
  /// `orderBy(...)` in the query itself: Firestore would require a
  /// composite index to be created manually in the console for every such
  /// collection, which is easy to forget and breaks the app with a
  /// confusing error. Instead this returns the filtered, unsorted stream
  /// and callers sort the (small, per-baby) result set on the client using
  /// [sortByField].
  static Stream<QuerySnapshot<Map<String, dynamic>>> streamByBaby(
    String name,
    String babyId,
  ) {
    return collection(name)
        .where('babyId', isEqualTo: babyId)
        .snapshots(includeMetadataChanges: true);
  }

  /// Client-side sort helper used together with [streamByBaby]. Handles
  /// both Firestore [Timestamp] fields (e.g. `createdAt`) and ISO-8601
  /// date strings (e.g. `milestoneDate`, `vaccinationDate`), falling back
  /// to "now" for documents whose timestamp hasn't been confirmed by the
  /// server yet (brand-new offline writes), so newly added records still
  /// appear in the right place immediately instead of jumping around once
  /// synced.
  static List<QueryDocumentSnapshot<Map<String, dynamic>>> sortByField(
    List<QueryDocumentSnapshot<Map<String, dynamic>>> docs,
    String field,
    bool descending,
  ) {
    DateTime resolve(dynamic value) {
      if (value is Timestamp) return value.toDate();
      if (value is String) {
        final parsed = DateTime.tryParse(value);
        if (parsed != null) return parsed;
      }
      return DateTime.now();
    }

    final sorted = List<QueryDocumentSnapshot<Map<String, dynamic>>>.from(docs);
    sorted.sort((a, b) {
      final da = resolve(a.data()[field]);
      final db_ = resolve(b.data()[field]);
      return descending ? db_.compareTo(da) : da.compareTo(db_);
    });
    return sorted;
  }

  /// Adds a record. Works offline — Firestore queues the write locally
  /// and this Future resolves immediately with the local doc reference,
  /// then syncs to the server automatically once connectivity returns.
  ///
  /// `maxRecords`: rolling-window cap per collection per user. After a
  /// successful add, if the collection now has more than `maxRecords`
  /// documents, the oldest ones (by `createdAt`) are deleted so trackers
  /// like weight/blood-pressure/glucose don't grow unbounded. Pass `null`
  /// to skip capping for a given collection (e.g. one-off/admin data).
  static Future<DocumentReference<Map<String, dynamic>>> add(
    String name,
    Map<String, dynamic> data, {
    int? maxRecords = 30,
  }) async {
    final ref = await collection(name).add({
      ...data,
      'createdAt': FieldValue.serverTimestamp(),
    });

    if (maxRecords != null) {
      // Best-effort — if this fails (e.g. offline and the cache doesn't
      // have the full ordered set yet), it isn't fatal: the same trim
      // logic runs again on the very next add() for this collection.
      unawaited(_enforceCap(name, maxRecords));
    }

    return ref;
  }

  static Future<void> _enforceCap(String name, int maxRecords) async {
    try {
      final snap =
          await collection(name).orderBy('createdAt', descending: true).get();
      if (snap.docs.length <= maxRecords) return;

      final toDelete = snap.docs.sublist(maxRecords);
      final batch = _db.batch();
      for (final doc in toDelete) {
        batch.delete(doc.reference);
      }
      await batch.commit();
    } catch (e) {
      debugPrint('FirestoreService: cap enforcement skipped for '
          '"$name" (will retry on next add): $e');
    }
  }

  /// Updates an existing document's fields without touching `createdAt`,
  /// so edited records keep their original position in newest-first lists
  /// and their original position relative to other records of the same
  /// baby.
  static Future<void> update(
      String name, String docId, Map<String, dynamic> data) {
    return collection(name).doc(docId).update(data);
  }

  static Future<void> delete(String name, String docId) {
    return collection(name).doc(docId).delete();
  }

  /// True if [doc]'s write hasn't been confirmed by the server yet —
  /// i.e. it's still sitting in Firestore's local offline queue. Pair
  /// this with `stream()`'s `includeMetadataChanges: true` in
  /// `AppRecordCard`/`AppRecordStreamList` to drive the `pendingSync`
  /// badge directly off Firestore's own state, no separate tracker needed.
  static bool isPendingWrite(DocumentSnapshot doc) =>
      doc.metadata.hasPendingWrites;
}
