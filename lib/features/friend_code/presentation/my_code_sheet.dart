import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:splitify/data/remote/friends_remote.dart';
import 'package:splitify/features/friend_code/application/friend_code_providers.dart';
import 'package:splitify/features/friend_code/domain/friend_code.dart';
import 'package:splitify/features/friend_code/presentation/friend_code_copy.dart';
import 'package:splitify/features/groups/presentation/group_visuals.dart'
    show confirmAction, showGroupMessage;
import 'package:splitify/features/groups/presentation/invite_sheet.dart'
    show QrRing, textSharerProvider;
import 'package:splitify/l10n/app_localizations.dart';
import 'package:splitify/ui/components/components.dart';
import 'package:splitify/ui/theme/theme.dart';

/// "My friend code" (D-034 B4, Splitwise's "My code"): the QR of `splitify://friend?code=…`, the code with
/// Copy, the link with Copy link, Share and Reset — the same sheet as a group invite. Needs internet the first
/// time; then the cached code shows offline.
Future<void> showMyFriendCode(BuildContext context) {
  final container = ProviderScope.containerOf(context, listen: false);
  return showAppSheet<void>(
    context,
    title: AppLocalizations.of(context).friendCodeMyTitle,
    // The sheet sits on the root navigator: keep it on the page's providers (D-032 LEARNINGS).
    builder: (sheet) =>
        UncontrolledProviderScope(container: container, child: const MyFriendCodeBody()),
  );
}

class MyFriendCodeBody extends ConsumerStatefulWidget {
  const MyFriendCodeBody({super.key});

  @override
  ConsumerState<MyFriendCodeBody> createState() => _MyFriendCodeBodyState();
}

class _MyFriendCodeBodyState extends ConsumerState<MyFriendCodeBody> {
  bool _resetting = false;
  bool _copied = false;
  bool _linkCopied = false;
  Timer? _copiedTimer;

  @override
  void dispose() {
    _copiedTimer?.cancel();
    super.dispose();
  }

  Future<void> _copy(String text, {required bool link}) async {
    await Clipboard.setData(ClipboardData(text: text));
    if (!mounted) return;
    setState(() {
      _copied = !link;
      _linkCopied = link;
    });
    final l = AppLocalizations.of(context);
    showGroupMessage(context, link ? l.linkCopied : l.codeCopied);
    _copiedTimer?.cancel();
    _copiedTimer = Timer(const Duration(seconds: 2), () {
      if (mounted) {
        setState(() {
          _copied = false;
          _linkCopied = false;
        });
      }
    });
  }

  Future<void> _reset() async {
    final l = AppLocalizations.of(context);
    final ok = await confirmAction(
      context,
      title: l.friendCodeResetTitle,
      body: l.friendCodeResetBody,
      confirm: l.resetCode,
      icon: AppIcons.refresh,
    );
    if (!ok || !mounted) return;
    setState(() => _resetting = true);
    try {
      await ref.read(myFriendCodeProvider.notifier).rotate();
      if (mounted) showGroupMessage(context, l.friendCodeResetDone);
    } on FriendCodeFailure catch (e) {
      if (mounted) showGroupMessage(context, friendCodeFailureText(l, e.code));
    } finally {
      if (mounted) setState(() => _resetting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final c = context.colors;
    final async = ref.watch(myFriendCodeProvider);
    final raw = async.value;
    if (raw == null) {
      if (async.isLoading) {
        return Padding(
          padding: const EdgeInsets.all(AppSpacing.s8),
          child: Center(
            child: DotsPulse(color: c.primary, semanticLabel: l.loading),
          ),
        );
      }
      final error = async.error;
      final offline = error is! FriendCodeFailure || error.code == FriendCodeFailureCode.offline;
      return Column(
        key: const Key('friend-code-offline'),
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Icon(AppIcons.unsynced, size: 32, color: c.unsynced),
          const SizedBox(height: AppSpacing.s3),
          Text(
            offline ? l.friendCodeNeedsInternet : l.friendCodeFailed,
            textAlign: TextAlign.center,
            style: context.text.body.copyWith(color: c.textSecondary),
          ),
          const SizedBox(height: AppSpacing.s5),
          PillButton(
            key: const Key('friend-code-retry'),
            label: l.retryLabel,
            icon: AppIcons.refresh,
            variant: PillVariant.outline,
            onPressed: () => ref.invalidate(myFriendCodeProvider),
          ),
        ],
      );
    }
    final code = FriendCode.display(raw);
    final link = FriendCode.link(raw);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          l.friendCodeMyBody,
          textAlign: TextAlign.center,
          style: context.text.body.copyWith(color: c.textSecondary),
        ),
        const SizedBox(height: AppSpacing.s6),
        Center(
          child: QrRing(data: link, label: l.friendCodeQrLabel(code)),
        ),
        const SizedBox(height: AppSpacing.s6),
        Text(
          l.friendCodeLabel.toUpperCase(),
          textAlign: TextAlign.center,
          style: context.text.labelCaps.copyWith(color: c.textSecondary),
        ),
        const SizedBox(height: AppSpacing.s2),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const SizedBox(width: AppSpacing.minTouch + AppSpacing.s1),
            Flexible(
              child: FittedBox(
                fit: BoxFit.scaleDown,
                child: Text(
                  code,
                  key: const Key('friend-code'),
                  maxLines: 1,
                  style: context.text.amountHero.copyWith(letterSpacing: 2),
                ),
              ),
            ),
            const SizedBox(width: AppSpacing.s1),
            AppIconButton(
              key: const Key('friend-code-copy'),
              tooltip: _copied ? l.codeCopied : l.copyCode,
              icon: Icon(_copied ? AppIcons.check : AppIcons.copy, color: c.primary),
              onPressed: () => unawaited(_copy(code, link: false)),
            ),
          ],
        ),
        const SizedBox(height: AppSpacing.s4),
        CodeLinkRow(
          link: link,
          copied: _linkCopied,
          onCopy: () => unawaited(_copy(link, link: true)),
        ),
        const SizedBox(height: AppSpacing.s6),
        PillButton(
          key: const Key('friend-code-share'),
          label: l.friendCodeShare,
          icon: AppIcons.share,
          onPressed: () =>
              unawaited(ref.read(textSharerProvider)(l.friendCodeShareText(code, link))),
        ),
        const SizedBox(height: AppSpacing.s2),
        PillButton(
          key: const Key('friend-code-reset'),
          label: l.resetCode,
          icon: AppIcons.refresh,
          variant: PillVariant.ghost,
          loading: _resetting,
          onPressed: () => unawaited(_reset()),
        ),
      ],
    );
  }
}

/// The link on a muted pill with "Copy link" (like the group invite sheet's).
class CodeLinkRow extends StatelessWidget {
  const CodeLinkRow({required this.link, required this.copied, required this.onCopy, super.key});

  final String link;
  final bool copied;
  final VoidCallback onCopy;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final c = context.colors;
    return Container(
      key: const Key('friend-code-link'),
      padding: const EdgeInsetsDirectional.only(start: AppSpacing.s4, end: AppSpacing.s1),
      decoration: BoxDecoration(color: c.surfaceMuted, borderRadius: AppRadii.allPill),
      child: Row(
        children: [
          Icon(AppIcons.link, size: 18, color: c.textSecondary),
          const SizedBox(width: AppSpacing.s2),
          Expanded(
            child: Text(
              link,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: context.text.bodySmall.copyWith(color: c.textPrimary),
            ),
          ),
          TextButton(
            key: const Key('friend-code-copy-link'),
            onPressed: onCopy,
            child: Text(
              copied ? l.linkCopied : l.copyLink,
              style: context.text.bodySmall.w(700).copyWith(color: c.primary),
            ),
          ),
        ],
      ),
    );
  }
}
