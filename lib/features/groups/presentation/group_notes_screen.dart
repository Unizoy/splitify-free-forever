import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:splitify/data/local/app_database.dart';
import 'package:splitify/data/sync/sync_types.dart';
import 'package:splitify/features/groups/application/group_extras_providers.dart';
import 'package:splitify/features/groups/application/groups_providers.dart';
import 'package:splitify/features/groups/presentation/group_visuals.dart';
import 'package:splitify/l10n/app_localizations.dart';
import 'package:splitify/ui/components/components.dart';
import 'package:splitify/ui/theme/theme.dart';

/// Group page routes owned by the groups feature (D-034 WP-C).
abstract final class GroupRoutes {
  /// The group notes (whiteboard, C5).
  static String notes(String groupId) => '/groups/$groupId/notes';
}

/// Longest notes the server takes (0026 `groups_whiteboard_check`).
const whiteboardMax = 5000;

/// The group notes (`/groups/:id/notes`, D-034 C5, Splitwise's whiteboard): one full-screen text field for the
/// address, Wi-Fi, door codes and contacts, "Last edited by Asha · 21 Nov", and Save above the keyboard. Works
/// offline (a group edit through the outbox; a conflicting edit keeps both versions in the history).
class GroupNotesScreen extends ConsumerStatefulWidget {
  const GroupNotesScreen({required this.groupId, super.key});

  final String groupId;

  @override
  ConsumerState<GroupNotesScreen> createState() => _GroupNotesScreenState();
}

class _GroupNotesScreenState extends ConsumerState<GroupNotesScreen> {
  final _text = TextEditingController();
  final _focus = FocusNode(debugLabel: 'group notes');
  bool _filled = false;
  bool _dirty = false;
  bool _saving = false;
  bool _saved = false;
  bool _showError = false;

  @override
  void dispose() {
    _text.dispose();
    _focus.dispose();
    super.dispose();
  }

  bool get _tooLong => _text.text.characters.length > whiteboardMax;

  Future<void> _save() async {
    if (_saving) return;
    if (_tooLong) {
      setState(() => _showError = true);
      _focus.requestFocus();
      return;
    }
    final l = AppLocalizations.of(context);
    final router = GoRouter.of(context);
    setState(() => _saving = true);
    try {
      await ref.read(groupActionsProvider).saveNotes(widget.groupId, _text.text);
      _saved = true;
      if (!mounted) return;
      showGroupMessage(context, l.boardSaved);
      if (router.canPop()) {
        router.pop();
      } else {
        router.go('/groups/${widget.groupId}');
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _back() async {
    final l = AppLocalizations.of(context);
    if (_dirty && !_saved) {
      FocusManager.instance.primaryFocus?.unfocus();
      final ok = await confirmAction(
        context,
        title: l.expDiscardEditTitle,
        body: l.boardDiscardBody,
        confirm: l.discardLabel,
        icon: AppIcons.trash,
      );
      if (!ok || !mounted) return;
    }
    if (!mounted) return;
    final navigator = Navigator.of(context);
    if (navigator.canPop()) {
      navigator.pop();
    } else {
      context.go('/groups/${widget.groupId}');
    }
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final c = context.colors;
    final group = ref.watch(groupProvider(widget.groupId)).value;
    if (!_filled && group != null) {
      _filled = true;
      _text.text = group.whiteboard ?? '';
    }
    final readOnly = group?.archivedAt != null;
    final count = _text.text.characters.length;
    final error = _showError && _tooLong ? l.boardTooLong(_number(context, whiteboardMax)) : null;
    return PopScope(
      canPop: _saved || !_dirty,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) unawaited(_back());
      },
      child: Scaffold(
        appBar: AppBar(
          leading: AppIconButton(
            tooltip: l.back,
            icon: const Icon(AppIcons.back),
            onPressed: () => unawaited(_back()),
          ),
          title: Text(l.boardTitle),
        ),
        body: group == null || group.deletedAt != null
            ? EmptyState(icon: AppIcons.groups, title: l.groupNotFound)
            : Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(
                      AppSpacing.screen,
                      AppSpacing.s2,
                      AppSpacing.screen,
                      0,
                    ),
                    child: _EditedLine(group: group),
                  ),
                  Expanded(
                    child: Container(
                      margin: const EdgeInsets.fromLTRB(
                        AppSpacing.screen,
                        AppSpacing.s3,
                        AppSpacing.screen,
                        AppSpacing.s3,
                      ),
                      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.s4),
                      decoration: BoxDecoration(
                        color: c.surfaceMuted,
                        borderRadius: AppRadii.all16,
                      ),
                      child: TextField(
                        key: const Key('board-text'),
                        controller: _text,
                        focusNode: _focus,
                        readOnly: readOnly,
                        expands: true,
                        maxLines: null,
                        minLines: null,
                        textAlignVertical: TextAlignVertical.top,
                        keyboardType: TextInputType.multiline,
                        textCapitalization: TextCapitalization.sentences,
                        style: context.text.body.copyWith(color: c.textPrimary, height: 1.5),
                        decoration: InputDecoration(
                          hintText: l.boardHint,
                          hintMaxLines: 3,
                          border: InputBorder.none,
                          enabledBorder: InputBorder.none,
                          focusedBorder: InputBorder.none,
                          filled: false,
                          contentPadding: const EdgeInsets.symmetric(vertical: AppSpacing.s4),
                        ),
                        onChanged: (_) => setState(() {
                          _dirty = true;
                          if (!_tooLong) _showError = false;
                        }),
                      ),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: AppSpacing.screen),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: Semantics(
                            liveRegion: error != null,
                            child: Text(
                              error ?? (readOnly ? l.boardReadOnly : l.boardHelp),
                              key: const Key('board-help'),
                              style: context.text.bodySmall.copyWith(
                                color: error != null ? c.oweText : c.textSecondary,
                              ),
                            ),
                          ),
                        ),
                        // The count shows once the notes get long (or too long).
                        if (count * 5 > whiteboardMax * 4)
                          Padding(
                            padding: const EdgeInsets.only(left: AppSpacing.s3),
                            child: Text(
                              l.boardCount(
                                _number(context, count),
                                _number(context, whiteboardMax),
                              ),
                              key: const Key('board-count'),
                              style: context.text.bodySmall
                                  .w(600)
                                  .copyWith(
                                    color: count > whiteboardMax ? c.oweText : c.textSecondary,
                                  ),
                            ),
                          ),
                      ],
                    ),
                  ),
                  if (!readOnly)
                    // In the body (not bottomNavigationBar): the Scaffold lifts it above the keyboard (D-032).
                    StickyActionBar(
                      primary: PillButton(
                        key: const Key('board-save'),
                        label: l.saveLabel,
                        loading: _saving,
                        onPressed: () => unawaited(_save()),
                      ),
                    )
                  else
                    SizedBox(height: AppSpacing.s6 + MediaQuery.paddingOf(context).bottom),
                ],
              ),
      ),
    );
  }

  static String _number(BuildContext context, int n) =>
      NumberFormat.decimalPattern(Localizations.localeOf(context).toLanguageTag()).format(n);
}

/// "Last edited by Asha · 21 Nov" (the newest notes change; "you" for mine), with "Not synced yet" while my
/// change waits in the outbox. Nothing before the first edit.
class _EditedLine extends ConsumerWidget {
  const _EditedLine({required this.group});

  final LocalGroup group;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = AppLocalizations.of(context);
    final c = context.colors;
    final edit = ref.watch(groupNotesEditProvider(group.id)).value;
    final members = ref.watch(groupMembersProvider(group.id)).value ?? const <LocalMember>[];
    final me = ref.watch(currentUserIdProvider);
    final pending = group.syncState != SyncState.synced && (edit?.pending ?? false);
    if (edit == null) return const SizedBox(height: AppSpacing.s2);
    final member =
        members.where((m) => m.id == edit.memberId).firstOrNull ??
        members.where((m) => edit.userId != null && m.userId == edit.userId).firstOrNull;
    final isMe = edit.pending || (me != null && (member?.userId == me || edit.userId == me));
    final name = isMe
        ? l.youLower
        : (member?.displayName.trim().isNotEmpty ?? false)
        ? member!.displayName
        : l.someone;
    final locale = Localizations.localeOf(context).toLanguageTag();
    final date = DateFormat('d MMM', locale).format(edit.at).replaceAll(' ', ' ');
    return Wrap(
      spacing: AppSpacing.s3,
      runSpacing: AppSpacing.s1,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        Text(
          l.boardLastEdited(name, date),
          key: const Key('board-edited'),
          style: context.text.bodySmall.copyWith(color: c.textSecondary),
        ),
        if (pending) const SyncMarker(),
      ],
    );
  }
}
