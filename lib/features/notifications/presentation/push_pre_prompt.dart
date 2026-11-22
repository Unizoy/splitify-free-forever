import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:splitify/features/notifications/application/notifications_providers.dart';
import 'package:splitify/l10n/app_localizations.dart';
import 'package:splitify/ui/components/components.dart';
import 'package:splitify/ui/theme/theme.dart';

/// After the first group create/join (08 #19, 07 flow 1): explains what pushes are for, then asks Android.
/// Shown once per install, only when push exists in this build and Android has not been asked yet.
Future<void> maybeShowPushPrePrompt(BuildContext context, WidgetRef ref) async {
  final prompt = ref.read(pushPrePromptProvider);
  if (!await prompt.shouldShow() || !context.mounted) return;
  // Let the navigation that asked for it finish first (create → the new group's page, join → the group): a
  // sheet pushed while "New group" is being replaced is removed with that page, and it was already marked
  // shown, so it never came (final QA, emulator: no pre-prompt after the first group).
  await Future<void>.delayed(const Duration(milliseconds: 300));
  await WidgetsBinding.instance.endOfFrame;
  if (!context.mounted) return;
  await prompt.markShown();
  if (!context.mounted) return;
  final l = AppLocalizations.of(context);
  final allow = await showAppSheet<bool>(
    context,
    title: l.notifPrePromptTitle,
    builder: (context) => const PushPrePromptBody(),
  );
  if (allow ?? false) {
    if (await prompt.allow()) await ref.read(pushRegistrationProvider).register();
    ref.invalidate(pushStateProvider);
  }
}

/// Sheet body: bell medallion, one line, three points, "Turn on notifications" / "Not now".
class PushPrePromptBody extends StatelessWidget {
  const PushPrePromptBody({super.key});

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final c = context.colors;
    Widget point(IconData icon, String text) => Padding(
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.s2),
      child: Row(
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(color: c.primaryContainer, shape: BoxShape.circle),
            child: Icon(icon, size: 18, color: c.onPrimaryContainer),
          ),
          const SizedBox(width: AppSpacing.s3),
          Expanded(child: Text(text, style: context.text.body.w(500))),
        ],
      ),
    );
    return Column(
      key: const Key('push-preprompt'),
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Center(
          child: ExcludeSemantics(
            child: Container(
              width: 72,
              height: 72,
              decoration: BoxDecoration(color: c.money, shape: BoxShape.circle),
              child: Icon(AppIcons.bell, size: 34, color: c.onMoney),
            ),
          ),
        ),
        const SizedBox(height: AppSpacing.s5),
        Text(
          l.notifPrePromptBody,
          textAlign: TextAlign.center,
          style: context.text.body.copyWith(color: c.textSecondary),
        ),
        const SizedBox(height: AppSpacing.s5),
        point(AppIcons.receipt, l.notifPrePromptPoint1),
        point(AppIcons.payment, l.notifPrePromptPoint2),
        point(AppIcons.chat, l.notifPrePromptPoint3),
        const SizedBox(height: AppSpacing.s6),
        PillButton(
          key: const Key('push-preprompt-allow'),
          label: l.notifPrePromptAllow,
          icon: AppIcons.bell,
          onPressed: () => Navigator.of(context).pop(true),
        ),
        const SizedBox(height: AppSpacing.s2),
        PillButton(
          key: const Key('push-preprompt-later'),
          label: l.notifPrePromptLater,
          variant: PillVariant.ghost,
          onPressed: () => Navigator.of(context).pop(false),
        ),
      ],
    );
  }
}
