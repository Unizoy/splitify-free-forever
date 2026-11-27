import 'package:splitify/data/remote/friends_remote.dart';

/// A [FriendsRemote] for the friend-code tests: a fixed code, a switch for being offline, and the codes added.
class FakeFriendCodeRemote extends UnconfiguredFriendsRemote {
  FakeFriendCodeRemote({this.code = 'ABCD2345', this.offline = false, this.addFailure});

  String code;
  bool offline;
  FriendCodeFailureCode? addFailure;
  int fetches = 0;
  int rotations = 0;
  final added = <String>[];

  /// What `add_friend_by_code` answers.
  FriendByCode answer = (
    groupId: 'g-direct',
    friendUserId: 'u2',
    friendMemberId: 'c2',
    friendName: 'Asha Rao',
    created: true,
  );

  @override
  Future<String> myFriendCode() async {
    fetches++;
    if (offline) throw const FriendCodeFailure(FriendCodeFailureCode.offline);
    return code;
  }

  @override
  Future<String> rotateFriendCode() async {
    if (offline) throw const FriendCodeFailure(FriendCodeFailureCode.offline);
    rotations++;
    code = 'WXYZ6789';
    return code;
  }

  @override
  Future<FriendByCode> addFriendByCode(String code) async {
    added.add(code);
    if (offline) throw const FriendCodeFailure(FriendCodeFailureCode.offline);
    final failure = addFailure;
    if (failure != null) throw FriendCodeFailure(failure);
    return answer;
  }
}
