import 'package:splitify/data/remote/friends_remote.dart';
import 'package:splitify/l10n/app_localizations.dart';

/// The friendly line for a friend-code failure (D-034 B4).
String friendCodeFailureText(AppLocalizations l, FriendCodeFailureCode code) => switch (code) {
  FriendCodeFailureCode.offline => l.friendCodeOffline,
  FriendCodeFailureCode.invalidCode => l.friendCodeInvalid,
  FriendCodeFailureCode.ownCode => l.friendCodeOwn,
  FriendCodeFailureCode.rateLimited => l.friendCodeRateLimited,
  FriendCodeFailureCode.unknown => l.friendCodeFailed,
};
