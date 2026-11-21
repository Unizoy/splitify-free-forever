// TC-13-04 (comment thread and composer): bubbles, author-only delete, add, limits, archived read-only.
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';
import 'package:splitify/data/local/app_database.dart';
import 'package:splitify/domain/rules/comment_rules.dart';
import 'package:splitify/features/comments/application/comments_providers.dart';
import 'package:splitify/features/comments/presentation/comment_thread.dart';
import 'package:splitify/ui/components/components.dart';

import '../../expenses/expense_fixtures.dart';
import '../../expenses/presentation/presentation_harness.dart';
import '../../history/presentation/history_fixtures.dart';

const CommentTarget _target = (groupId: gid, targetType: 'expense', targetId: 'e1');

/// Records adds and deletes instead of touching the database.
class _RecordingActions extends CommentActions {
  _RecordingActions(super.ref);

  final added = <String>[];
  final deleted = <String>[];

  @override
  Future<bool> add(CommentTarget t, String text) async {
    final body = CommentRules.clean(text);
    if (body == null) return false;
    added.add(body);
    return true;
  }

  @override
  Future<void> delete(LocalComment c) async => deleted.add(c.id);
}

class _Host extends StatelessWidget {
  const _Host({this.readOnly = false});

  final bool readOnly;

  @override
  Widget build(BuildContext context) => Scaffold(
    body: const SingleChildScrollView(child: CommentThread(target: _target)),
    bottomNavigationBar: CommentComposer(target: _target, readOnly: readOnly),
  );
}

Future<_RecordingActions> _pump(
  WidgetTester t, {
  AsyncValue<List<CommentView>> thread = const AsyncData([]),
  bool readOnly = false,
}) async {
  usePhone(t);
  await t.pumpWidget(const SizedBox());
  final overrides = <Override>[
    commentThreadProvider(_target).overrideWithValue(thread),
    commentActionsProvider.overrideWith(_RecordingActions.new),
  ];
  await t.pumpWidget(expenseApp(_Host(readOnly: readOnly), overrides: overrides));
  await settle(t);
  final container = ProviderScope.containerOf(t.element(find.byType(CommentThread)));
  return container.read(commentActionsProvider) as _RecordingActions;
}

VoidCallback? _sendTap(WidgetTester t) =>
    t.widget<InkWell>(find.byKey(const Key('comment-send'))).onTap;

void main() {
  group('CommentThread', () {
    // TC-13-04
    testWidgets('an empty thread says "No comments yet"', (t) async {
      await _pump(t);
      expect(find.byKey(const Key('comments-empty')), findsOneWidget);
      expect(find.text('No comments yet'), findsOneWidget);
      expect(find.text('Start the conversation'), findsOneWidget);
    });

    // TC-13-04
    testWidgets('loading shows the pulse', (t) async {
      await _pump(t, thread: const AsyncLoading());
      expect(find.byType(DotsPulse), findsOneWidget);
      expect(find.byKey(const Key('comments-empty')), findsNothing);
    });

    // TC-13-04
    testWidgets('shows each comment with its author, mine as "You", unsynced marked', (t) async {
      await _pump(t, thread: AsyncData(sampleThread()));
      expect(find.text('Did we include the service charge?'), findsOneWidget);
      expect(find.text('Yes, it is in the total.'), findsOneWidget);
      expect(find.text('Great, thanks both!'), findsOneWidget);
      expect(find.text('Asha Rao'), findsOneWidget);
      expect(find.text('Rahul Mehta'), findsOneWidget);
      expect(find.text('You'), findsOneWidget);
      expect(find.text('Mohit Bindal'), findsNothing);
      // Others get an avatar; only my pending comment carries the marker.
      expect(find.byType(Avatar), findsNWidgets(2));
      expect(find.byType(SyncMarker), findsOneWidget);
    });

    // TC-13-04
    testWidgets('a comment by someone who left reads "A former member"', (t) async {
      await _pump(t, thread: AsyncData([commentView(sampleComment('c9', 'Bye all', by: 'u9'))]));
      expect(find.text('A former member'), findsOneWidget);
    });

    // TC-13-04
    testWidgets('each comment is read out as "name, time: text"', (t) async {
      final handle = t.ensureSemantics();
      await _pump(t, thread: AsyncData(sampleThread()));
      expect(
        find.bySemanticsLabel(RegExp(r'^Asha Rao, .*: Did we include the service charge\?$')),
        findsOneWidget,
      );
      handle.dispose();
    });

    // TC-13-04
    testWidgets('tapping my comment asks to confirm, then deletes it', (t) async {
      final actions = await _pump(t, thread: AsyncData(sampleThread()));
      await t.tap(find.byKey(const Key('comment-c3')));
      await settle(t);
      expect(find.text('Delete this comment?'), findsOneWidget);
      expect(actions.deleted, isEmpty);
      await t.tap(find.byKey(const Key('confirm-action')));
      await settle(t);
      expect(actions.deleted, ['c3']);
      expect(find.text('Comment deleted'), findsOneWidget);
    });

    // TC-13-04
    testWidgets('cancelling the confirmation keeps the comment', (t) async {
      final actions = await _pump(t, thread: AsyncData(sampleThread()));
      await t.tap(find.byKey(const Key('comment-c3')));
      await settle(t);
      await t.tap(find.text('Cancel'));
      await settle(t);
      expect(actions.deleted, isEmpty);
      expect(find.text('Delete this comment?'), findsNothing);
    });

    // TC-13-04
    testWidgets("other people's comments cannot be deleted", (t) async {
      final actions = await _pump(t, thread: AsyncData(sampleThread()));
      await t.tap(find.byKey(const Key('comment-c1')));
      await settle(t);
      expect(find.text('Delete this comment?'), findsNothing);
      expect(
        find.descendant(of: find.byKey(const Key('comment-c1')), matching: find.byType(InkWell)),
        findsNothing,
      );
      expect(actions.deleted, isEmpty);
    });
  });

  group('CommentComposer', () {
    // TC-13-04
    testWidgets('Send is disabled until there is text', (t) async {
      final handle = t.ensureSemantics();
      await _pump(t);
      expect(find.byKey(const Key('comment-field')), findsOneWidget);
      expect(find.text('Add a comment'), findsOneWidget);
      expect(_sendTap(t), isNull);
      expect(find.bySemanticsLabel('Send comment'), findsOneWidget);

      await t.enterText(find.byKey(const Key('comment-field')), '   ');
      await t.pump();
      expect(_sendTap(t), isNull);

      await t.enterText(find.byKey(const Key('comment-field')), 'Hello');
      await t.pump();
      expect(_sendTap(t), isNotNull);
      handle.dispose();
    });

    // TC-13-04
    testWidgets('Send saves the trimmed text and clears the field', (t) async {
      final actions = await _pump(t);
      await t.enterText(find.byKey(const Key('comment-field')), '  Paid the tip in cash  ');
      await t.pump();
      await t.tap(find.byKey(const Key('comment-send')));
      await settle(t);
      expect(actions.added, ['Paid the tip in cash']);
      expect(t.widget<TextField>(find.byKey(const Key('comment-field'))).controller!.text, '');
      expect(_sendTap(t), isNull);
    });

    // TC-13-04
    testWidgets('text over 1000 characters shows the limit and cannot be sent', (t) async {
      final actions = await _pump(t);
      await t.enterText(find.byKey(const Key('comment-field')), 'a' * 1001);
      await t.pump();
      expect(find.text('Keep it under 1000 characters.'), findsOneWidget);
      expect(_sendTap(t), isNull);
      expect(actions.added, isEmpty);

      await t.enterText(find.byKey(const Key('comment-field')), 'a' * 1000);
      await t.pump();
      expect(find.text('Keep it under 1000 characters.'), findsNothing);
      expect(_sendTap(t), isNotNull);
    });

    // TC-13-04
    testWidgets('an archived group shows a read-only note instead of the field', (t) async {
      await _pump(t, readOnly: true);
      expect(find.byKey(const Key('comment-read-only')), findsOneWidget);
      expect(find.text('This group is archived, so comments are read-only.'), findsOneWidget);
      expect(find.byKey(const Key('comment-field')), findsNothing);
      expect(find.byKey(const Key('comment-send')), findsNothing);
    });
  });
}
