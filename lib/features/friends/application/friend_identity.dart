/// Who a member is across groups (W2-X F11, S-421). A person picked from another group into a several-friends
/// (`adhoc`) group gets the member id `origin member id XOR ad-hoc group id` (the server does the same, 0028
/// `private.uuid_xor`), so every phone that knows the origin shows them as the same friend, without a new column.
library;

import 'package:splitify/data/local/app_database.dart';

/// Bitwise XOR of two UUIDs, as lower-case `8-4-4-4-12` text (the same as 0028 `private.uuid_xor`).
String uuidXor(String a, String b) {
  final x = a.replaceAll('-', '').toLowerCase();
  final y = b.replaceAll('-', '').toLowerCase();
  if (x.length != 32 || y.length != 32) throw FormatException('not a uuid', '$a / $b');
  final out = StringBuffer();
  for (var i = 0; i < 32; i++) {
    if (i == 8 || i == 12 || i == 16 || i == 20) out.write('-');
    final v = int.parse(x[i], radix: 16) ^ int.parse(y[i], radix: 16);
    out.write(v.toRadixString(16));
  }
  return out.toString();
}

/// The member id of the person [originMemberId] in the ad-hoc group [groupId].
String derivedMemberId(String originMemberId, String groupId) => uuidXor(originMemberId, groupId);

/// The member [m] was picked from (another group's member whose id XOR [m]'s group id is [m]'s id), when this
/// phone has it; null otherwise.
LocalMember? originOf(LocalMember m, Map<String, LocalMember> byId) {
  final String id;
  try {
    id = uuidXor(m.id, m.groupId);
  } on FormatException {
    return null;
  }
  final o = byId[id];
  return o == null || o.groupId == m.groupId ? null : o;
}

/// The friend key of [m] (`u:<user id>`, or `m:<member id>` for name-only people): a name-only member picked
/// from another group is that member's friend (followed up to a few steps), so one person is one friend.
String friendKeyIn(LocalMember m, Map<String, LocalMember> byId) {
  var cur = m;
  for (var i = 0; i < 4; i++) {
    if (cur.userId != null) return 'u:${cur.userId}';
    final o = originOf(cur, byId);
    if (o == null) break;
    cur = o;
  }
  return cur.userId != null ? 'u:${cur.userId}' : 'm:${cur.id}';
}

/// Every member of [groups] by id.
Map<String, LocalMember> membersById(Iterable<List<LocalMember>> groups) => {
  for (final g in groups)
    for (final m in g) m.id: m,
};
