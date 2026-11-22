import 'dart:convert';

import 'package:flutter/services.dart' show rootBundle;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:splitify/core/config/preferences.dart';
import 'package:splitify/data/local/category_memory.dart';
import 'package:splitify/domain/rules/category_suggester.dart';
import 'package:splitify/features/expenses/application/expense_editor_controller.dart'
    show currentUserIdProvider;

/// The versioned keyword list for auto-category (D-028).
const categoryKeywordsAsset = 'assets/category_keywords.json';

/// The keyword list, read once from the app bundle.
final categorySuggesterProvider = FutureProvider<CategorySuggester>((ref) async {
  // Parsed once and kept here; no copy in the bundle's string cache.
  final text = await rootBundle.loadString(categoryKeywordsAsset, cache: false);
  return CategorySuggester.fromJson((jsonDecode(text) as Map).cast<String, Object?>());
});

/// What the signed-in user taught auto-category on this phone (never synced).
final categoryMemoryProvider = Provider<CategoryMemory>((ref) {
  final userId = ref.watch(currentUserIdProvider);
  SharedPreferences? prefs;
  try {
    prefs = ref.watch(sharedPreferencesProvider);
  } on Object {
    // Not set up (some widget tests): learn for this run only.
    prefs = null;
  }
  return CategoryMemory(prefs, userId: userId);
});

/// The suggested category for [description] right now (null while the list loads, or no match).
String? suggestedCategoryNow(Ref ref, String description) {
  final suggester = ref.read(categorySuggesterProvider).value;
  if (suggester == null) return null;
  return suggester.suggest(description, learned: ref.read(categoryMemoryProvider).entries);
}

/// Like [suggestedCategoryNow], waiting for the keyword list first (prefills: payment bubble, imports).
Future<String?> suggestedCategory(Ref ref, String description) async {
  try {
    await ref.read(categorySuggesterProvider.future);
  } on Object {
    return null;
  }
  return suggestedCategoryNow(ref, description);
}
