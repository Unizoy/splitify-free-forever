// Auto-category (D-028) helpers for tests: the shipped keyword file, read straight from disk.
import 'dart:convert';
import 'dart:io';

import 'package:splitify/domain/rules/category_suggester.dart';

/// The suggester built from `assets/category_keywords.json`.
final suggester = CategorySuggester.fromJson(
  (jsonDecode(File('assets/category_keywords.json').readAsStringSync()) as Map)
      .cast<String, Object?>(),
);
