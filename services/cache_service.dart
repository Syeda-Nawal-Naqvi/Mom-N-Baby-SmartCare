import 'dart:convert';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// ═══════════════════════════════════════════════════════════════════
/// CacheService
/// ───────────────────────────────────────────────────────────────────
/// A thin, generic wrapper around SharedPreferences used to mirror
/// Firestore data locally so screens can render something meaningful
/// when the device is offline, instead of an empty state or an
/// infinite spinner.
///
/// PATTERN USED IN THIS APP:
///   1. Whenever a Firestore StreamBuilder/Future successfully returns
///      data WHILE ONLINE, call `CacheService.saveList(...)` in the
///      background (fire-and-forget) to mirror it.
///   2. When `FirestoreService.isOnline.value == false`, screens read
///      from `CacheService.loadList(...)` instead of hitting Firestore
///      at all.
///
/// Firestore documents can contain `Timestamp` objects, which are NOT
/// JSON-serializable — `_sanitize` converts them to ISO-8601 strings
/// before saving, and `resolveDate` (see below) can read either format
/// back when rendering.
/// ═══════════════════════════════════════════════════════════════════
class CacheService {
  CacheService._();

  static const String _prefix = 'cache_';

  // ── Lists (e.g. "all babies", "all weight records") ──────────────
  static Future<void> saveList(
    String key,
    List<Map<String, dynamic>> data,
  ) async {
    final prefs = await SharedPreferences.getInstance();
    final sanitized = data.map(_sanitize).toList();
    await prefs.setString('$_prefix$key', jsonEncode(sanitized));
  }

  static Future<List<Map<String, dynamic>>> loadList(String key) async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString('$_prefix$key');
    if (raw == null || raw.isEmpty) return [];
    try {
      final decoded = jsonDecode(raw) as List<dynamic>;
      return decoded.cast<Map<String, dynamic>>();
    } catch (_) {
      return [];
    }
  }

  // ── Single objects (e.g. "last verified email") ──────────────────
  static Future<void> saveMap(String key, Map<String, dynamic> data) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('$_prefix$key', jsonEncode(_sanitize(data)));
  }

  static Future<Map<String, dynamic>?> loadMap(String key) async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString('$_prefix$key');
    if (raw == null || raw.isEmpty) return null;
    try {
      return jsonDecode(raw) as Map<String, dynamic>;
    } catch (_) {
      return null;
    }
  }

  static Future<void> clear(String key) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('$_prefix$key');
  }

  // ── Helpers ────────────────────────────────────────────────────
  static Map<String, dynamic> _sanitize(Map<String, dynamic> data) {
    return data.map((k, v) {
      if (v is Timestamp) return MapEntry(k, v.toDate().toIso8601String());
      return MapEntry(k, v);
    });
  }

  /// Reads a date back regardless of whether it's still a live
  /// Firestore [Timestamp] (online path) or the ISO-8601 string that
  /// was cached offline.
  static DateTime resolveDate(dynamic value) {
    if (value is Timestamp) return value.toDate();
    if (value is String) return DateTime.tryParse(value) ?? DateTime.now();
    return DateTime.now();
  }
}
