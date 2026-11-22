import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:splitify/core/money/currencies.dart';
import 'package:splitify/core/money/money_error.dart';
import 'package:splitify/core/utils/uuid.dart';
import 'package:splitify/data/data_providers.dart';
import 'package:splitify/domain/rules/group_rules.dart';
import 'package:splitify/features/expenses/application/category_providers.dart';
import 'package:splitify/features/groups/application/groups_providers.dart';
import 'package:splitify/features/import_splitwise/application/import_providers.dart';
import 'package:splitify/features/import_splitwise/domain/import_csv.dart';
import 'package:splitify/features/import_splitwise/domain/import_mapping.dart';
import 'package:splitify/features/import_splitwise/domain/import_plan.dart';
import 'package:splitify/features/import_splitwise/domain/splitwise_csv_parser.dart';
import 'package:splitify/features/import_splitwise/domain/splitwise_reconstruction.dart';

/// Steps of the import flow (08 X1). [group] only when started from Account.
enum ImportStep { file, group, people, preview, running, done }

/// Largest file the importer reads (a Splitwise export of several thousand rows is ~1 MB).
const maxImportBytes = 5 * 1024 * 1024;

/// Placeholder member id for "you" in a group that is created by the import.
const newGroupMeId = '_me';

/// Why a file was refused: a parser code (`IMPORT_BAD_HEADER` …) or `IMPORT_TOO_LARGE`,
/// `IMPORT_NO_ROWS`, `IMPORT_UNSUPPORTED_CURRENCY`; [row] is 1-based (0 = whole file).
typedef ImportProblem = ({String code, int row, String? value});

/// The file with the skipped people taken out and what it rebuilds into.
typedef ImportPreview = ({SplitwiseCsv file, int dropped, SplitwiseImport? result});

/// What an import wrote.
typedef ImportResult = ({String batchId, String groupId, int expenses, int payments});

/// State of one import run.
final class ImportState {
  const ImportState({
    required this.step,
    this.groupId,
    this.fileName,
    this.parsed,
    this.problem,
    this.newGroupName,
    this.members = const [],
    this.mapping = const {},
    this.preview,
    this.acceptMismatch = false,
    this.done = 0,
    this.total = 0,
    this.result,
    this.deleting = false,
    this.deleted = false,
  });

  final ImportStep step;

  /// Target group (null until chosen, or when [newGroupName] is set).
  final String? groupId;
  final String? fileName;
  final ImportCsv? parsed;
  final ImportProblem? problem;

  /// Name of the group the import creates (Account entry, "New group").
  final String? newGroupName;

  /// Members of the target group (only "you" for a new group).
  final List<MappingMember> members;

  /// File name → choice, in file order.
  final Map<String, MemberChoice> mapping;
  final ImportPreview? preview;
  final bool acceptMismatch;

  /// Records written so far / to write (running step).
  final int done;
  final int total;
  final ImportResult? result;
  final bool deleting;
  final bool deleted;

  bool get creatingGroup => newGroupName != null;

  MappingProblem? get mappingProblem =>
      checkMapping(mapping, currentMembers: members.length, maxMembers: GroupRules.maxMembers);

  List<TotalsMismatch> get mismatches => preview?.file.totalsMismatches ?? const [];

  int get recordCount =>
      (preview?.result?.expenses.length ?? 0) + (preview?.result?.payments.length ?? 0);

  bool get canImport =>
      preview?.result != null &&
      mappingProblem == null &&
      recordCount > 0 &&
      (mismatches.isEmpty || acceptMismatch);

  ImportState copyWith({
    ImportStep? step,
    String? groupId,
    String? fileName,
    ImportCsv? parsed,
    ImportProblem? Function()? problem,
    String? Function()? newGroupName,
    List<MappingMember>? members,
    Map<String, MemberChoice>? mapping,
    ImportPreview? preview,
    bool? acceptMismatch,
    int? done,
    int? total,
    ImportResult? result,
    bool? deleting,
    bool? deleted,
  }) => ImportState(
    step: step ?? this.step,
    groupId: groupId ?? this.groupId,
    fileName: fileName ?? this.fileName,
    parsed: parsed ?? this.parsed,
    problem: problem == null ? this.problem : problem(),
    newGroupName: newGroupName == null ? this.newGroupName : newGroupName(),
    members: members ?? this.members,
    mapping: mapping ?? this.mapping,
    preview: preview ?? this.preview,
    acceptMismatch: acceptMismatch ?? this.acceptMismatch,
    done: done ?? this.done,
    total: total ?? this.total,
    result: result ?? this.result,
    deleting: deleting ?? this.deleting,
    deleted: deleted ?? this.deleted,
  );
}

/// One import run per entry: a group's settings (group id) or Account (null → pick a group).
final importControllerProvider = NotifierProvider.autoDispose
    .family<ImportController, ImportState, String?>(ImportController.new);

/// Pick file → (group) → match people → preview with the totals check → import through the outbox
/// (`source = 'import'`, one batch id) → result with "Delete this import" (08 X1, phase 18 T3).
class ImportController extends Notifier<ImportState> {
  ImportController(this.startGroupId);

  final String? startGroupId;

  @override
  ImportState build() => ImportState(step: ImportStep.file, groupId: startGroupId);

  /// Opens the system file picker; nothing happens when the user cancels.
  /// Auto-category for rows the file left uncategorised (D-028); null when the keyword list cannot load.
  Future<String? Function(String description)?> _categorySuggester() async {
    try {
      final suggester = await ref.read(categorySuggesterProvider.future);
      final learned = ref.read(categoryMemoryProvider).entries;
      return (String description) => suggester.suggest(description, learned: learned);
    } on Object {
      return null;
    }
  }

  /// [categoryKeys]: lower-case category label → key, for Splitify's own export (S-184).
  Future<void> pickFile({Map<String, String> categoryKeys = const {}}) async {
    final file = await ref.read(importFilePickerProvider).pick();
    if (file == null) return;
    await loadFile(file.name, file.bytes, categoryKeys: categoryKeys);
  }

  /// Reads [bytes] (UTF-8, BOM allowed) as an import file.
  Future<void> loadFile(
    String name,
    Uint8List bytes, {
    Map<String, String> categoryKeys = const {},
  }) async {
    ImportProblem? problem;
    ImportCsv? parsed;
    if (bytes.length > maxImportBytes) {
      problem = (code: 'IMPORT_TOO_LARGE', row: 0, value: null);
    } else {
      try {
        parsed = parseImportCsv(
          utf8.decode(bytes, allowMalformed: true),
          categoryKeys: categoryKeys,
        );
        final unsupported = parsed.file.currencies.where((c) => !Currencies.all.containsKey(c));
        if (unsupported.isNotEmpty) {
          problem = (code: 'IMPORT_UNSUPPORTED_CURRENCY', row: 0, value: unsupported.first);
        } else if (parsed.file.rows.isEmpty) {
          problem = (code: 'IMPORT_NO_ROWS', row: 0, value: null);
        }
      } on SplitwiseCsvError catch (e) {
        problem = (code: e.code, row: e.row, value: _valueOf(e));
      }
    }
    if (problem != null || parsed == null) {
      state = state.copyWith(fileName: name, problem: () => problem);
      return;
    }
    state = state.copyWith(fileName: name, parsed: parsed, problem: () => null);
    if (state.groupId == null) {
      state = state.copyWith(step: ImportStep.group, newGroupName: () => groupNameFromFile(name));
    } else {
      await _useGroup(state.groupId!);
    }
  }

  /// Account entry: import into an existing group.
  Future<void> chooseGroup(String groupId) async {
    state = state.copyWith(groupId: groupId, newGroupName: () => null);
    await _useGroup(groupId);
  }

  /// Account entry: import into a new group called [name].
  void chooseNewGroup(String name, {required String myName}) {
    final members = <MappingMember>[(id: newGroupMeId, name: myName, isMe: true)];
    state = ImportState(
      step: ImportStep.people,
      fileName: state.fileName,
      parsed: state.parsed,
      newGroupName: name.trim(),
      members: members,
    );
    _remap(suggestMapping(state.parsed!.file.members, members));
  }

  void setChoice(String name, MemberChoice choice) => _remap({...state.mapping, name: choice});

  void setAcceptMismatch({required bool value}) => state = state.copyWith(acceptMismatch: value);

  /// Moves to [step] (back navigation or the step header); forward only when allowed.
  void goTo(ImportStep step) {
    if (state.step == ImportStep.running || state.step == ImportStep.done) return;
    if (step == ImportStep.preview && state.mappingProblem != null) return;
    if (step.index > ImportStep.file.index && state.parsed == null) return;
    state = state.copyWith(step: step);
  }

  /// Writes everything (offline is fine: it all goes through the outbox).
  Future<void> runImport({required String ownerName, required String fallbackDescription}) async {
    final s = state;
    final rebuilt = s.preview?.result;
    if (!s.canImport || rebuilt == null) return;
    state = s.copyWith(step: ImportStep.running, done: 0, total: s.recordCount);
    final members = ref.read(membersRepositoryProvider);
    var groupId = s.groupId;
    String? me;
    if (s.creatingGroup) {
      final file = s.parsed!.file;
      groupId = await ref
          .read(groupActionsProvider)
          .create(
            name: s.newGroupName!,
            type: 'other',
            currency: file.currencies.length == 1 ? file.currencies.single : 'INR',
            ownerName: ownerName,
          );
      final uid = ref.read(currentUserIdProvider);
      final owner = await members.watchForGroup(groupId).first;
      me = owner.where((m) => m.userId == uid).firstOrNull?.id ?? owner.firstOrNull?.id;
    }
    final ids = <String, String>{};
    final created = <String>[];
    for (final e in s.mapping.entries) {
      switch (e.value) {
        case UseMember(:final memberId):
          ids[e.key] = memberId == newGroupMeId ? me! : memberId;
        case NewMember(:final name):
          final id = await members.addNameOnly(groupId!, name);
          created.add(id);
          ids[e.key] = id;
        case SkipPerson():
          break;
      }
    }
    final rows = buildImportRows(
      import: rebuilt,
      memberIds: ids,
      batchId: newId(),
      format: s.parsed!.format,
      fallbackDescription: fallbackDescription,
      newId: newId,
      suggestCategory: await _categorySuggester(),
    );
    var last = 0;
    await ref
        .read(importRepositoryProvider)
        .run(
          batchId: rows.batchId,
          groupId: groupId!,
          source: s.parsed!.format.name,
          fileName: s.fileName,
          payments: rows.payments,
          expenses: rows.expenses,
          memberIds: created,
          onProgress: (done, total) {
            // A redraw per ~2 % keeps a 5,000-row import from rebuilding the screen 5,000 times.
            if (done == total || done - last >= (total ~/ 50).clamp(1, 100)) {
              last = done;
              if (ref.mounted) state = state.copyWith(done: done);
            }
          },
        );
    if (!ref.mounted) return;
    state = state.copyWith(
      step: ImportStep.done,
      groupId: groupId,
      result: (
        batchId: rows.batchId,
        groupId: groupId,
        expenses: rows.expenses.length,
        payments: rows.payments.length,
      ),
    );
  }

  /// "Delete this import" on the result screen.
  Future<void> deleteImport() async {
    final r = state.result;
    if (r == null || state.deleting || state.deleted) return;
    state = state.copyWith(deleting: true);
    await ref.read(importRepositoryProvider).deleteBatch(r.batchId);
    if (ref.mounted) state = state.copyWith(deleting: false, deleted: true);
  }

  Future<void> _useGroup(String groupId) async {
    final uid = ref.read(currentUserIdProvider);
    final rows = await ref.read(membersRepositoryProvider).watchForGroup(groupId).first;
    final members = [
      for (final m in rows) (id: m.id, name: m.displayName, isMe: uid != null && m.userId == uid),
    ];
    if (!ref.mounted) return;
    state = state.copyWith(step: ImportStep.people, members: members);
    _remap(suggestMapping(state.parsed!.file.members, members));
  }

  void _remap(Map<String, MemberChoice> mapping) {
    final file = state.parsed!.file;
    final skipped = {
      for (final e in mapping.entries)
        if (e.value is SkipPerson) e.key,
    };
    final cut = withoutSkipped(file, skipped);
    SplitwiseImport? result;
    if (cut.file.members.isNotEmpty) {
      try {
        result = reconstructSplitwise(cut.file, acceptTotalsMismatch: true);
      } on MoneyError {
        result = null;
      }
    }
    state = state.copyWith(
      mapping: mapping,
      preview: (file: cut.file, dropped: cut.dropped, result: result),
    );
  }
}

String? _valueOf(SplitwiseCsvError e) => switch (e) {
  InvalidDate(:final value) => value,
  InvalidCurrency(:final value) => value,
  InvalidAmount(:final value) => value,
  DuplicateTotals(:final currency) => currency,
  _ => null,
};

/// A group name from a Splitwise export's file name (`goa-trip_2026-11-21_export.csv` → `Goa trip`).
String groupNameFromFile(String fileName) {
  var base = fileName.replaceAll(RegExp(r'\.csv$', caseSensitive: false), '');
  base = base
      .replaceAll(RegExp(r'_\d{4}-\d{2}-\d{2}.*$'), '')
      .replaceAll(RegExp('[-_]+'), ' ')
      .trim();
  if (base.isEmpty) return '';
  final name = base[0].toUpperCase() + base.substring(1);
  return name.length <= GroupRules.nameMax ? name : name.substring(0, GroupRules.nameMax).trim();
}
