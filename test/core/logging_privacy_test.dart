// R4-PRIV-01…03: "Export debug log" carries ids and codes, never what people typed (04 §9). A SQLite error's
// text quotes the failing statement AND its parameters (descriptions, names, notes, UPI IDs); a
// FormatException quotes its source text.
import 'package:drift/drift.dart' show Variable;
import 'package:flutter_test/flutter_test.dart';
import 'package:logging/logging.dart';
import 'package:splitify/core/logging/log_buffer.dart';
import 'package:splitify/core/logging/logger.dart';
import 'package:splitify/data/remote/remote_api.dart';
import 'package:splitify/data/sync/sync_engine.dart';

import '../data/sync/sync_fakes.dart';

const _typed = 'Asha SECRET-NOTE asha@okaxis';

void main() {
  tearDown(Logger.root.clearListeners);

  test('R4-PRIV-01 a SQLite error keeps its code, not the statement or its parameters', () async {
    final db = memoryDb();
    addTearDown(db.close);
    Object? error;
    try {
      await db.customInsert(
        'INSERT INTO expenses (id, group_id, description, date, currency, total, payers, shares) '
        'VALUES (?, ?, ?, ?, ?, ?, ?, NULL)',
        variables: [
          for (final v in ['e1', gid, _typed, '2026-11-28', 'INR']) Variable<String>(v),
          const Variable<int>(100),
          const Variable<String>('{}'),
        ],
      );
    } on Exception catch (e) {
      error = e;
    }
    expect('$error', contains(_typed), reason: 'the raw text does quote the row');
    final line = formatRecord(LogRecord(Level.WARNING, 'sync failed: $error', 'sync', error));
    expect(line, isNot(contains('SECRET')));
    expect(line, isNot(contains('asha@')));
    expect(line, contains('NOT NULL constraint failed: expenses.shares'));
  });

  test(
    'R4-PRIV-02 a pull page that fails to store leaves nothing typed in the debug log',
    () async {
      final buffer = LogBuffer();
      initLogging(buffer: buffer, toConsole: false);
      final db = memoryDb();
      final remote = FakeRemoteApi();
      final engine = SyncEngine(
        db: db,
        remote: remote,
        clock: FakeClock(remote.serverTime),
        timer: ManualTimers().call,
      );
      addTearDown(() async {
        await engine.dispose();
        await db.close();
      });
      final bad = serverExpense('e1', description: _typed)..['shares'] = null;
      remote.pullScript.add(
        (c, u) => PullPage(
          serverTime: remote.serverTime,
          rows: {
            'groups': [serverGroup()],
            'expenses': [bad],
          },
          nextCursors: const {gid: 3},
          userSeq: 0,
        ),
      );
      await engine.sync();
      expect(engine.lastError, 'LOCAL_ERROR');
      expect(buffer.lines.where((l) => l.contains('sync failed')), isNotEmpty);
      expect(buffer.export(), isNot(contains('SECRET')));
    },
  );

  test('R4-PRIV-03 a FormatException keeps its message, not the text it quotes', () {
    final e = FormatException('Unexpected character', '{"note": "$_typed"', 3);
    final line = formatRecord(LogRecord(Level.WARNING, 'decode failed: $e', 'sync', e));
    expect(line, contains('Unexpected character'));
    expect(line, isNot(contains('SECRET')));
    // Ordinary multi-line messages stay whole.
    expect(formatRecord(LogRecord(Level.INFO, 'a\nb', 'x')), endsWith('a\nb'));
  });
}
