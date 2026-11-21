import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:share_plus/share_plus.dart';
import 'package:splitify/data/remote/groups_remote.dart';
import 'package:splitify/domain/rules/invite_code.dart';
import 'package:splitify/features/groups/application/groups_providers.dart';
import 'package:splitify/features/groups/presentation/group_visuals.dart';
import 'package:splitify/l10n/app_localizations.dart';
import 'package:splitify/ui/components/components.dart';
import 'package:splitify/ui/painters/dashed.dart';
import 'package:splitify/ui/theme/theme.dart';

/// Opens the system share sheet with [text] (tests override).
typedef TextSharer = Future<void> Function(String text);

final textSharerProvider = Provider<TextSharer>(
  (ref) =>
      (text) async => SharePlus.instance.share(ShareParams(text: text)),
);

/// Invite sheet (08 #3, 455): QR of `splitify://join?code=…` inside a dashed circle, the code `ABCD-EFGH`,
/// Share invite, Reset code. The code comes from the server, so a group made offline shows a hint instead.
Future<void> showInviteSheet(BuildContext context, String groupId) => showAppSheet<void>(
  context,
  title: AppLocalizations.of(context).invitePeople,
  builder: (context) => InviteSheetBody(groupId: groupId),
);

class InviteSheetBody extends ConsumerStatefulWidget {
  const InviteSheetBody({required this.groupId, super.key});

  final String groupId;

  @override
  ConsumerState<InviteSheetBody> createState() => _InviteSheetBodyState();
}

class _InviteSheetBodyState extends ConsumerState<InviteSheetBody> {
  /// Code returned by Reset (shown before the next pull brings it).
  String? _fresh;
  bool _resetting = false;

  Future<void> _reset() async {
    final l = AppLocalizations.of(context);
    final ok = await confirmAction(
      context,
      title: l.resetCodeTitle,
      body: l.resetCodeBody,
      confirm: l.resetCode,
      icon: AppIcons.refresh,
    );
    if (!ok || !mounted) return;
    setState(() => _resetting = true);
    try {
      final code = await ref.read(groupActionsProvider).rotateCode(widget.groupId);
      if (!mounted) return;
      setState(() => _fresh = code);
      showGroupMessage(context, l.codeResetDone);
    } on GroupFailure catch (e) {
      if (mounted) showGroupMessage(context, groupFailureText(l, e.code));
    } finally {
      if (mounted) setState(() => _resetting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final c = context.colors;
    final group = ref.watch(groupProvider(widget.groupId)).value;
    final raw = _fresh ?? group?.inviteCode;
    if (raw == null) {
      return Column(
        key: const Key('invite-no-code'),
        children: [
          Icon(AppIcons.unsynced, size: 32, color: c.unsynced),
          const SizedBox(height: AppSpacing.s3),
          Text(
            l.inviteNoCode,
            textAlign: TextAlign.center,
            style: context.text.body.copyWith(color: c.textSecondary),
          ),
        ],
      );
    }
    final code = InviteCode.display(raw);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          l.inviteBody,
          textAlign: TextAlign.center,
          style: context.text.body.copyWith(color: c.textSecondary),
        ),
        const SizedBox(height: AppSpacing.s6),
        Center(
          child: QrRing(data: InviteCode.link(raw), label: l.inviteQrLabel(code)),
        ),
        const SizedBox(height: AppSpacing.s6),
        Text(
          l.inviteCodeLabel.toUpperCase(),
          textAlign: TextAlign.center,
          style: context.text.labelCaps.copyWith(color: c.textSecondary),
        ),
        const SizedBox(height: AppSpacing.s2),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // Balances the copy button so the code sits in the middle.
            const SizedBox(width: AppSpacing.minTouch + AppSpacing.s1),
            // One line always: large text shrinks the code to fit instead of breaking it.
            Flexible(
              child: FittedBox(
                fit: BoxFit.scaleDown,
                child: Text(
                  code,
                  key: const Key('invite-code'),
                  maxLines: 1,
                  style: context.text.amountHero.copyWith(letterSpacing: 2),
                ),
              ),
            ),
            const SizedBox(width: AppSpacing.s1),
            IconButton(
              tooltip: l.copyCode,
              icon: Icon(AppIcons.copy, color: c.primary),
              onPressed: () async {
                await Clipboard.setData(ClipboardData(text: code));
                if (context.mounted) showGroupMessage(context, l.codeCopied);
              },
            ),
          ],
        ),
        const SizedBox(height: AppSpacing.s6),
        PillButton(
          key: const Key('invite-share'),
          label: l.shareInvite,
          icon: AppIcons.share,
          onPressed: () =>
              unawaited(ref.read(textSharerProvider)(l.shareInviteText(group?.name ?? '', code))),
        ),
        const SizedBox(height: AppSpacing.s2),
        PillButton(
          key: const Key('invite-reset'),
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

/// A QR code on a white tile inside a slowly dashed ring (455 dashed circle). White in both modes so
/// every scanner reads it.
class QrRing extends StatelessWidget {
  const QrRing({required this.data, required this.label, super.key});

  final String data;
  final String label;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Semantics(
      label: label,
      image: true,
      excludeSemantics: true,
      child: SizedBox.square(
        dimension: 248,
        child: Stack(
          alignment: Alignment.center,
          children: [
            Positioned.fill(
              child: CustomPaint(
                painter: DashedBorderPainter(color: c.primary, circle: true, dash: 9, gap: 7),
              ),
            ),
            Container(
              width: 168,
              height: 168,
              padding: const EdgeInsets.all(AppSpacing.s3),
              decoration: BoxDecoration(
                color: AppPalette.white,
                borderRadius: AppRadii.all24,
                border: Border.all(color: c.border),
              ),
              child: QrImageView(
                data: data,
                padding: EdgeInsets.zero,
                eyeStyle: const QrEyeStyle(eyeShape: QrEyeShape.square, color: AppPalette.black),
                dataModuleStyle: const QrDataModuleStyle(
                  dataModuleShape: QrDataModuleShape.square,
                  color: AppPalette.black,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
