/// Matching the people of an import file to group members (X1 mapping step, phase 18 T3).
///
/// Each file name becomes an existing member, a new name-only member (rule 8) or is skipped.
/// Skipping someone leaves out every row that moves their balance (their share can't be put on
/// anyone else without changing what people owe), see [withoutSkipped].
library;

import 'package:splitify/features/import_splitwise/domain/splitwise_csv_parser.dart';

/// What happens to one person of the file.
sealed class MemberChoice {
  const MemberChoice();
}

/// Use this existing group member.
final class UseMember extends MemberChoice {
  const UseMember(this.memberId);

  final String memberId;

  @override
  bool operator ==(Object other) => other is UseMember && other.memberId == memberId;

  @override
  int get hashCode => memberId.hashCode;
}

/// Add a new name-only member with this name.
final class NewMember extends MemberChoice {
  const NewMember(this.name);

  final String name;

  @override
  bool operator ==(Object other) => other is NewMember && other.name == name;

  @override
  int get hashCode => name.hashCode;
}

/// Leave this person (and the rows that involve them) out.
final class SkipPerson extends MemberChoice {
  const SkipPerson();

  @override
  bool operator ==(Object other) => other is SkipPerson;

  @override
  int get hashCode => 0;
}

/// A member of the target group, as the mapping step sees it.
typedef MappingMember = ({String id, String name, bool isMe});

/// Longest name a member can have (server check, `group_members.display_name`).
const maxMemberName = 50;

/// First guess for every name of the file, in file order: the same name (ignoring case and
/// spaces), else a unique first-name match, else a new member. A member is suggested once.
Map<String, MemberChoice> suggestMapping(List<String> names, List<MappingMember> members) {
  String norm(String s) => s.trim().toLowerCase().replaceAll(RegExp(r'\s+'), ' ');
  String first(String s) => norm(s).split(' ').first;
  final used = <String>{};
  final out = <String, MemberChoice>{};
  for (final name in names) {
    final free = members.where((m) => !used.contains(m.id)).toList();
    var hit = free.where((m) => norm(m.name) == norm(name)).firstOrNull;
    if (hit == null) {
      final byFirst = free.where((m) => first(m.name) == first(name)).toList();
      if (byFirst.length == 1) hit = byFirst.single;
    }
    if (hit != null) {
      used.add(hit.id);
      out[name] = UseMember(hit.id);
    } else {
      out[name] = NewMember(clipName(name));
    }
  }
  return out;
}

/// [name] trimmed to what a member name may hold.
String clipName(String name) {
  final t = name.trim();
  return t.length <= maxMemberName ? t : t.substring(0, maxMemberName).trim();
}

/// Why a mapping can't be imported yet.
enum MappingProblem {
  /// Two people of the file point at the same member.
  sameMemberTwice,

  /// A new member's name is empty.
  emptyName,

  /// Everyone is skipped.
  nobodyLeft,

  /// The group would have more than [maxMembers] members.
  tooManyMembers,
}

/// The first problem of [mapping], or null when it can be imported. [currentMembers] is the
/// group's member count today.
MappingProblem? checkMapping(
  Map<String, MemberChoice> mapping, {
  required int currentMembers,
  required int maxMembers,
}) {
  final targets = [
    for (final c in mapping.values)
      if (c is UseMember) c.memberId,
  ];
  if (targets.toSet().length != targets.length) return MappingProblem.sameMemberTwice;
  final fresh = mapping.values.whereType<NewMember>().toList();
  if (fresh.any((n) => n.name.trim().isEmpty)) return MappingProblem.emptyName;
  if (mapping.values.every((c) => c is SkipPerson)) return MappingProblem.nobodyLeft;
  if (currentMembers + fresh.length > maxMembers) return MappingProblem.tooManyMembers;
  return null;
}

/// [file] without the [skipped] people: their columns go, and so does every row where their cell
/// isn't 0. The file's "Total balance" rows stay only when no row was left out (they can't be
/// checked otherwise). [dropped] counts the rows left out.
({SplitwiseCsv file, int dropped}) withoutSkipped(SplitwiseCsv file, Set<String> skipped) {
  if (skipped.isEmpty) return (file: file, dropped: 0);
  final members = [
    for (final m in file.members)
      if (!skipped.contains(m)) m,
  ];
  final rows = <SplitwiseRow>[];
  var dropped = 0;
  final sums = <String, Map<String, int>>{};
  for (final r in file.rows) {
    if (skipped.any((m) => (r.nets[m] ?? 0) != 0)) {
      dropped++;
      continue;
    }
    final nets = {for (final m in members) m: r.nets[m] ?? 0};
    final sum = sums.putIfAbsent(r.currency, () => {for (final m in members) m: 0});
    nets.forEach((m, v) => sum[m] = sum[m]! + v);
    rows.add(
      SplitwiseRow(
        row: r.row,
        date: r.date,
        description: r.description,
        category: r.category,
        isPayment: r.isPayment,
        currency: r.currency,
        cost: r.cost,
        nets: nets,
        notes: r.notes,
      ),
    );
  }
  final totals = dropped > 0
      ? const <String, Map<String, int>>{}
      : {
          for (final t in file.totals.entries) t.key: {for (final m in members) m: t.value[m] ?? 0},
        };
  return (
    file: SplitwiseCsv(members: members, rows: rows, columnSums: sums, totals: totals),
    dropped: dropped,
  );
}
