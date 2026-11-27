import 'package:flutter_riverpod/flutter_riverpod.dart';

/// An invite opened while signed out (S-283): joining needs an account, so the router sends `/join[?code=]`
/// (the welcome's "Have an invite?" link, an invite QR or share link) to sign-in and keeps the join here.
/// Right after sign-in the router (Google) or the profile step (email code) opens it instead of Groups.
/// A personal friend-code link (`/friends/code[/X]`, D-034 B4) is kept the same way (S-404).
/// Memory only: a restarted app starts clean, and the invite link still works then.
class PendingJoin {
  String? _location;
  bool _friend = false;

  /// True while a join waits for sign-in.
  bool get waiting => _location != null;

  /// True when what waits is a friend code, not a group invite (the sign-in subtitle says so).
  bool get forFriend => _location != null && _friend;

  /// Keeps the join, with its invite [code] when there is one.
  void remember(String? code) {
    final c = code?.trim();
    _friend = false;
    _location = Uri(
      path: '/join',
      queryParameters: c == null || c.isEmpty ? null : {'code': c},
    ).toString();
  }

  /// Keeps a friend-code page ([location] = `/friends/code` or `/friends/code/<code>`).
  void rememberFriend(String location) {
    _friend = true;
    _location = location;
  }

  /// "Get started" means the plain sign-up path: forget a join without a code (an invite code survives).
  void dropCodeless() {
    if (_location == '/join') _location = null;
  }

  /// The join's location, once; null when none waits.
  String? take() {
    final location = _location;
    _location = null;
    _friend = false;
    return location;
  }
}

/// One per app run, shared by the router and the sign-in screens.
final pendingJoinProvider = Provider<PendingJoin>((ref) => PendingJoin());
