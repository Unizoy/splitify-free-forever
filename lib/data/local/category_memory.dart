import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

/// What auto-category learned from this user's own picks (D-028): normalised description → category key, kept
/// on this phone per signed-in user (SharedPreferences, never synced). Newest last; the oldest go beyond
/// [maxEntries].
class CategoryMemory {
  /// Backed by [prefs]; without them (early start, some tests) it only lasts while the app runs.
  CategoryMemory(SharedPreferences? prefs, {required String? userId})
    : _prefs = prefs,
      _key = '$keyPrefix${userId ?? 'signed-out'}';

  /// Only in memory.
  CategoryMemory.inMemory() : this(null, userId: null);

  static const keyPrefix = 'category_memory.v1.';
  static const maxEntries = 300;

  final SharedPreferences? _prefs;
  final String _key;
  Map<String, String>? _cache;

  /// Learned phrase → category, oldest first.
  Map<String, String> get entries => Map.unmodifiable(_load());

  Map<String, String> _load() {
    final cached = _cache;
    if (cached != null) return cached;
    final raw = _prefs?.getString(_key);
    final out = <String, String>{};
    if (raw != null) {
      try {
        final decoded = jsonDecode(raw);
        if (decoded is Map) {
          for (final e in decoded.entries) {
            if (e.key is String && e.value is String) out[e.key as String] = e.value as String;
          }
        }
      } on FormatException {
        // A damaged value starts over.
      }
    }
    return _cache = out;
  }

  /// Remembers [lessons] (phrase → category); a phrase taught again moves to the newest end.
  Future<void> learn(Map<String, String> lessons) async {
    if (lessons.isEmpty) return;
    final map = _load();
    for (final e in lessons.entries) {
      map
        ..remove(e.key)
        ..[e.key] = e.value;
    }
    while (map.length > maxEntries) {
      map.remove(map.keys.first);
    }
    await _prefs?.setString(_key, jsonEncode(map));
  }

  /// Forgets everything this user taught (not used by the UI yet; tests).
  Future<void> clear() async {
    _cache = {};
    await _prefs?.remove(_key);
  }
}
