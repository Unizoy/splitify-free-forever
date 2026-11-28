import 'package:drift/drift.dart';
import 'package:splitify/core/utils/uuid.dart';
import 'package:splitify/data/local/app_database.dart';
import 'package:splitify/data/local/media_files.dart';
import 'package:splitify/data/sync/local_writer.dart';
import 'package:splitify/data/sync/sync_types.dart';
import 'package:splitify/domain/entities/attachment.dart';

/// Photos and PDFs of expenses (D-034 P-7, W2-Y, 0029). Offline first like every write: the files are staged
/// on the phone, then ONE local transaction writes the rows, their outbox mutations and the upload queue
/// (`pending_uploads`, sent by [UploadQueue] once the row is on the server). Removing is a soft delete with
/// restore (rule 9); a removed file's upload still goes, so Undo never loses it.
class AttachmentsRepository {
  AttachmentsRepository({required this.db, required this.writer, required this.files});

  final AppDatabase db;
  final LocalWriter writer;
  final MediaFiles files;

  SimpleSelectStatement<ExpenseAttachments, LocalAttachment> _live(String expenseId) =>
      db.select(db.expenseAttachments)
        ..where((a) => a.expenseId.equals(expenseId) & a.deletedAt.isNull())
        ..orderBy([
          (a) => OrderingTerm.asc(a.position),
          (a) => OrderingTerm.asc(a.createdAt),
          (a) => OrderingTerm.asc(a.id),
        ]);

  /// The live files of an expense, in their order.
  Stream<List<LocalAttachment>> watchForExpense(String expenseId) => _live(expenseId).watch();

  Future<List<LocalAttachment>> forExpense(String expenseId) => _live(expenseId).get();

  /// Every attachment (removed ones too) of [groupIds], for the backup.
  Future<List<LocalAttachment>> forGroups(Iterable<String> groupIds) =>
      (db.select(db.expenseAttachments)
            ..where((a) => a.groupId.isIn(groupIds))
            ..orderBy([
              (a) => OrderingTerm.asc(a.expenseId),
              (a) => OrderingTerm.asc(a.position),
              (a) => OrderingTerm.asc(a.id),
            ]))
          .get();

  /// Saves an expense ([expenseRow], snake_case) together with its new files [added] and the removal of saved
  /// files [removedIds], all in one transaction. New files are numbered from [firstPosition].
  Future<void> saveWithExpense({
    required String groupId,
    required String expenseId,
    required Map<String, Object?> expenseRow,
    List<NewAttachment> added = const [],
    Iterable<String> removedIds = const [],
    int firstPosition = 0,
  }) => _write(
    groupId,
    expenseId,
    [
      (
        entity: SyncEntity.expense,
        op: SyncOp.upsert,
        id: expenseId,
        groupId: groupId,
        data: expenseRow,
      ),
    ],
    added,
    removedIds,
    firstPosition,
  );

  /// Adds [added] to a saved expense (the expense page's "Add").
  Future<void> add(
    String groupId,
    String expenseId,
    List<NewAttachment> added, {
    required int firstPosition,
  }) => _write(groupId, expenseId, const [], added, const [], firstPosition);

  /// Removes one file (soft; the expense page offers Undo).
  Future<void> remove(LocalAttachment a) =>
      writer.write(SyncEntity.attachment, SyncOp.delete, a.id, a.groupId, _about(a));

  /// Brings a removed file back.
  Future<void> restore(LocalAttachment a) =>
      writer.write(SyncEntity.attachment, SyncOp.restore, a.id, a.groupId, _about(a));

  /// What the activity feed needs about a queued removal or restore (the server reads only the id).
  static Map<String, Object?> _about(LocalAttachment a) => {
    'expense_id': a.expenseId,
    'kind': a.kind,
  };

  Future<void> _write(
    String groupId,
    String expenseId,
    List<LocalWrite> first,
    List<NewAttachment> added,
    Iterable<String> removedIds,
    int firstPosition,
  ) async {
    final uploads = <({String path, String rel, String recordId})>[];
    try {
      for (final a in added) {
        final path = AttachmentPaths.file(groupId, expenseId, a.id, a.kind);
        if (a.image case final image?) {
          final thumb = AttachmentPaths.thumb(groupId, expenseId, a.id);
          // The thumbnail goes up first: other phones show the tile before the big photo arrives.
          uploads
            ..add((
              path: thumb,
              rel: await files.stageFile(AttachmentPaths.bucket, thumb, image.thumb),
              recordId: a.id,
            ))
            ..add((
              path: path,
              rel: await files.stageFile(AttachmentPaths.bucket, path, image.full),
              recordId: a.id,
            ));
        } else {
          uploads.add((
            path: path,
            rel: await files.stageFile(AttachmentPaths.bucket, path, a.pdf!),
            recordId: a.id,
          ));
        }
      }
      final removed = removedIds.isEmpty
          ? const <LocalAttachment>[]
          : await (db.select(db.expenseAttachments)..where((a) => a.id.isIn(removedIds))).get();
      final writes = <LocalWrite>[
        ...first,
        for (final (i, a) in added.indexed)
          (
            entity: SyncEntity.attachment,
            op: SyncOp.upsert,
            id: a.id,
            groupId: groupId,
            data: a.row(groupId, expenseId, position: firstPosition + i),
          ),
        for (final a in removed)
          (
            entity: SyncEntity.attachment,
            op: SyncOp.delete,
            id: a.id,
            groupId: groupId,
            data: _about(a),
          ),
      ];
      await writer.writeAll(
        writes,
        alongside: () async {
          for (final u in uploads) {
            await db
                .into(db.pendingUploads)
                .insert(
                  PendingUploadsCompanion.insert(
                    id: newId(),
                    bucket: AttachmentPaths.bucket,
                    localPath: u.rel,
                    remotePath: u.path,
                    recordId: u.recordId,
                  ),
                );
          }
        },
      );
    } on Object {
      // Nothing was saved: the staged copies go too.
      for (final u in uploads) {
        await files.discard(AttachmentPaths.bucket, u.path);
      }
      rethrow;
    }
  }
}
