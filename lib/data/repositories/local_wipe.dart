import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:logging/logging.dart';
import 'package:shared_preferences/shared_preferences.dart';

final _log = Logger('auth');

/// Removes everything this phone stored for the signed-in person (phase 05 T8, 04 §7): the local database,
/// secure storage and preferences, except the theme choice.
class LocalWipe {
  LocalWipe({
    required this.prefs,
    FlutterSecureStorage? secure,
    this.clearDatabase,
    this.keep = const {'theme_mode'},
  }) : _secure = secure ?? const FlutterSecureStorage();

  final SharedPreferences prefs;
  final FlutterSecureStorage _secure;

  /// Deletes every row of the local database (Drift); null when there is none (tests).
  final Future<void> Function()? clearDatabase;

  /// Preference keys that survive a sign-out.
  final Set<String> keep;

  Future<void> wipe() async {
    try {
      await clearDatabase?.call();
    } on Exception catch (e) {
      // Keep going: the sign-in data below must go even if the database is broken.
      _log.warning('local database wipe failed: $e');
    }
    await _secure.deleteAll();
    for (final key in prefs.getKeys().toList()) {
      if (!keep.contains(key)) await prefs.remove(key);
    }
  }
}
