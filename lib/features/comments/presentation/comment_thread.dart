import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:splitify/domain/rules/comment_rules.dart';
import 'package:splitify/features/comments/application/comments_providers.dart';
import 'package:splitify/features/expenses/presentation/expense_copy.dart';
import 'package:splitify/features/groups/presentation/group_visuals.dart';
import 'package:splitify/l10n/app_localizations.dart';
import 'package:splitify/ui/components/components.dart';
import 'package:splitify/ui/theme/theme.dart';

/// Comments on an expense or payment (08 #13, 636): oldest first, the viewer's own on the right in indigo,
/// others on the left with their avatar; "not synced yet" until the server has them. An author can delete
/// their own comment (tap it). Empty: soft blobs with "No comments yet".
class CommentThread extends ConsumerWidget {
  const CommentThread({required this.target, super.key});

  final CommentTarget target;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = AppLocalizations.of(context);
    final comments = ref.watch(commentThreadProvider(target)).value;
    if (comments == null) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: AppSpacing.s6),
        child: Center(
          child: DotsPulse(color: context.colors.primary, semanticLabel: l.loading),
        ),
      );
    }
    if (comments.isEmpty) {
      return ClipRRect(
        key: const Key('comments-empty'),
        borderRadius: AppRadii.all24,
        child: BlobBackground(
          child: SizedBox(
            width: double.infinity,
            child: EmptyState(icon: AppIcons.chat, title: l.cmtEmptyTitle, message: l.cmtEmptyBody),
          ),
        ),
      );
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (var i = 0; i < comments.length; i++) ...[
          if (i > 0) const SizedBox(height: AppSpacing.s4),
          _Bubble(view: comments[i]),
        ],
      ],
    );
  }
}

class _Bubble extends ConsumerWidget {
  const _Bubble({required this.view});

  final CommentView view;

  Future<void> _options(BuildContext context, WidgetRef ref) async {
    final l = AppLocalizations.of(context);
    final messenger = ScaffoldMessenger.of(context);
    final ok = await confirmAction(
      context,
      title: l.cmtDeleteTitle,
      body: l.cmtDeleteBody,
      confirm: l.cmtDelete,
      icon: AppIcons.trash,
    );
    if (!ok) return;
    await ref.read(commentActionsProvider).delete(view.comment);
    unawaited(HapticFeedback.lightImpact());
    messenger
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(l.cmtDeleted)));
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = AppLocalizations.of(context);
    final c = context.colors;
    final mine = view.mine;
    final name = mine ? l.you : (view.authorName ?? l.histFormerMember);
    final when = _when(context, view.comment.createdAt);
    final body = view.comment.body;
    const tail = Radius.circular(6);
    const round = Radius.circular(AppRadii.r24);
    final bubble = Container(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.s4, vertical: AppSpacing.s3),
      decoration: BoxDecoration(
        color: mine ? c.primaryFill : c.surfaceMuted,
        borderRadius: BorderRadiusDirectional.only(
          topStart: mine ? round : tail,
          topEnd: mine ? tail : round,
          bottomStart: round,
          bottomEnd: round,
        ),
      ),
      child: Text(
        body,
        style: context.text.body.copyWith(color: mine ? c.onPrimaryFill : c.textPrimary),
      ),
    );
    final meta = Wrap(
      crossAxisAlignment: WrapCrossAlignment.center,
      spacing: AppSpacing.s2,
      children: [
        Text(name, style: context.text.bodySmall.w(600).copyWith(color: c.textPrimary)),
        if (when != null) Text(when, style: context.text.caption.copyWith(color: c.textSecondary)),
        if (view.unsynced) const SyncMarker(compact: true),
      ],
    );
    final content = Column(
      crossAxisAlignment: mine ? CrossAxisAlignment.end : CrossAxisAlignment.start,
      children: [
        meta,
        const SizedBox(height: AppSpacing.s1),
        bubble,
      ],
    );
    final semantics = l.cmtA11y(name, when ?? '', body);
    if (mine) {
      return Semantics(
        container: true,
        button: true,
        label: semantics,
        onTapHint: l.cmtDelete,
        excludeSemantics: true,
        onTap: () => unawaited(_options(context, ref)),
        child: Padding(
          padding: const EdgeInsetsDirectional.only(start: AppSpacing.s12),
          child: Align(
            alignment: AlignmentDirectional.centerEnd,
            child: InkWell(
              key: Key('comment-${view.comment.id}'),
              borderRadius: AppRadii.all16,
              onTap: () => unawaited(_options(context, ref)),
              onLongPress: () => unawaited(_options(context, ref)),
              child: content,
            ),
          ),
        ),
      );
    }
    return Semantics(
      container: true,
      label: semantics,
      excludeSemantics: true,
      child: Padding(
        key: Key('comment-${view.comment.id}'),
        padding: const EdgeInsetsDirectional.only(end: AppSpacing.s10),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Avatar(
              name: name,
              seed: view.authorMemberId ?? view.comment.createdBy ?? view.comment.id,
              size: AvatarSize.s32,
            ),
            const SizedBox(width: AppSpacing.s3),
            Flexible(child: content),
          ],
        ),
      ),
    );
  }

  static String? _when(BuildContext context, String? createdAt) {
    final at = createdAt == null ? null : DateTime.tryParse(createdAt)?.toLocal();
    if (at == null) return null;
    final locale = Localizations.localeOf(context).toLanguageTag();
    return '${dayMonth(context, at)}, ${unbroken(DateFormat.jm(locale).format(at))}';
  }
}

/// Composer pinned under the record (636): a pill text field and a round send button. Comments are saved on
/// the phone first and sent when online (TC-13-03). Archived groups are read-only.
class CommentComposer extends ConsumerStatefulWidget {
  const CommentComposer({required this.target, this.readOnly = false, super.key});

  final CommentTarget target;
  final bool readOnly;

  @override
  ConsumerState<CommentComposer> createState() => _CommentComposerState();
}

class _CommentComposerState extends ConsumerState<CommentComposer> {
  final _text = TextEditingController();
  bool _sending = false;

  @override
  void dispose() {
    _text.dispose();
    super.dispose();
  }

  Future<void> _send() async {
    if (_sending || CommentRules.clean(_text.text) == null) return;
    setState(() => _sending = true);
    try {
      final saved = await ref.read(commentActionsProvider).add(widget.target, _text.text);
      if (saved) {
        _text.clear();
        unawaited(HapticFeedback.lightImpact());
      }
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final c = context.colors;
    final canSend = !_sending && CommentRules.clean(_text.text) != null;
    final tooLong = CommentRules.tooLong(_text.text);
    final Widget child;
    if (widget.readOnly) {
      child = Text(
        l.cmtArchived,
        key: const Key('comment-read-only'),
        textAlign: TextAlign.center,
        style: context.text.bodySmall.copyWith(color: c.textSecondary),
      );
    } else {
      child = Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (tooLong) ...[
            Text(
              l.cmtTooLong(CommentRules.maxLength),
              style: context.text.bodySmall.copyWith(color: c.oweText),
            ),
            const SizedBox(height: AppSpacing.s2),
          ],
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Expanded(
                child: Container(
                  constraints: const BoxConstraints(minHeight: AppSpacing.buttonLarge),
                  padding: const EdgeInsetsDirectional.fromSTEB(
                    AppSpacing.s5,
                    AppSpacing.s1,
                    AppSpacing.s4,
                    AppSpacing.s1,
                  ),
                  decoration: BoxDecoration(
                    color: c.surface,
                    borderRadius: BorderRadius.circular(AppRadii.r28),
                    border: Border.all(color: c.border),
                  ),
                  alignment: AlignmentDirectional.centerStart,
                  child: TextField(
                    key: const Key('comment-field'),
                    controller: _text,
                    minLines: 1,
                    maxLines: 4,
                    keyboardType: TextInputType.multiline,
                    textCapitalization: TextCapitalization.sentences,
                    style: context.text.body.copyWith(color: c.textPrimary),
                    cursorColor: c.primary,
                    decoration: pillInputDecoration(
                      context: context,
                      hint: l.cmtHint,
                      style: context.text.body,
                      hintStyle: context.text.body.copyWith(color: c.textSecondary),
                    ),
                    onChanged: (_) => setState(() {}),
                  ),
                ),
              ),
              const SizedBox(width: AppSpacing.s2),
              _SendButton(enabled: canSend, label: l.cmtSend, onPressed: _send),
            ],
          ),
        ],
      );
    }
    return DecoratedBox(
      decoration: BoxDecoration(
        color: c.bg,
        border: Border(top: BorderSide(color: c.border)),
      ),
      child: Padding(
        // Rides above the keyboard; the safe area applies when the keyboard is closed.
        padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
        child: SafeArea(
          top: false,
          minimum: const EdgeInsets.only(bottom: AppSpacing.s3),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.screen,
              AppSpacing.s3,
              AppSpacing.screen,
              AppSpacing.s1,
            ),
            child: child,
          ),
        ),
      ),
    );
  }
}

class _SendButton extends StatelessWidget {
  const _SendButton({required this.enabled, required this.label, required this.onPressed});

  final bool enabled;
  final String label;
  final Future<void> Function() onPressed;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Semantics(
      button: true,
      enabled: enabled,
      label: label,
      excludeSemantics: true,
      onTap: enabled ? () => unawaited(onPressed()) : null,
      child: Material(
        color: enabled ? c.primary : c.textTertiary,
        shape: const CircleBorder(),
        child: InkWell(
          key: const Key('comment-send'),
          customBorder: const CircleBorder(),
          onTap: enabled ? () => unawaited(onPressed()) : null,
          child: SizedBox.square(
            dimension: AppSpacing.buttonLarge,
            child: Icon(AppIcons.send, size: 22, color: c.surface),
          ),
        ),
      ),
    );
  }
}
