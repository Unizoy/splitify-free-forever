import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Removes everything this phone stored for the signed-in person (T8): secure
/// storage and preferences, except the theme choice. Phase 06+ also clears the
/// local database here.
class LocalWipe {
  LocalWipe({required this.prefs, FlutterSecureStorage? secure, this.keep = const {'theme_mode'}})
    : _secure = secure ?? const FlutterSecureStorage();

  final SharedPreferences prefs;
  final FlutterSecureStorage _secure;

  /// Preference keys that survive a sign-out.
  final Set<String> keep;

  Future<void> wipe() async {
    await _secure.deleteAll();
    for (final key in prefs.getKeys().toList()) {
      if (!keep.contains(key)) await prefs.remove(key);
    }
  }
}
