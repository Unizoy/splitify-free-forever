import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:splitify/domain/entities/payment_capture.dart';
import 'package:splitify/features/capture/application/capture_providers.dart';
import 'package:splitify/features/groups/presentation/group_visuals.dart'
    show PageTitle, SectionLabel;
import 'package:splitify/l10n/app_localizations.dart';
import 'package:splitify/ui/components/components.dart';
import 'package:splitify/ui/theme/theme.dart';

/// Account → Payment bubble (`/account/payment-bubble`, X4 TC-X4-08): master switch (off by default), the
/// sources, live permission state with Grant buttons that open the exact Android screen, the "Allow restricted
/// settings" guide, per-app switches and a sample bubble. Permissions are read again on every resume.
class CaptureSettingsScreen extends ConsumerStatefulWidget {
  const CaptureSettingsScreen({super.key});

  @override
  ConsumerState<CaptureSettingsScreen> createState() => _CaptureSettingsScreenState();
}

class _CaptureSettingsScreenState extends ConsumerState<CaptureSettingsScreen> {
  late final AppLifecycleListener _life;

  @override
  void initState() {
    super.initState();
    _life = AppLifecycleListener(onResume: () => ref.invalidate(capturePermissionsProvider));
  }

  @override
  void dispose() {
    _life.dispose();
    super.dispose();
  }

  Future<void> _set(CaptureSettings Function(CaptureSettings s) change) =>
      ref.read(captureSettingsProvider.notifier).change(change);

  Future<void> _sample() async {
    final l = AppLocalizations.of(context);
    final messenger = ScaffoldMessenger.of(context);
    final shown = await ref
        .read(captureBridgeProvider)
        .showSample(payee: l.captureSamplePayee, app: l.appTitle);
    final perms = ref.read(capturePermissionsProvider).value;
    messenger
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(
            shown
                ? l.captureSampleShown
                : (perms?.postNotifications ?? false)
                ? l.captureSampleNotified
                : l.captureSampleOff,
          ),
        ),
      );
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final c = context.colors;
    final s = ref.watch(captureSettingsProvider).value ?? const CaptureSettings();
    final perms = ref.watch(capturePermissionsProvider).value ?? const CapturePermissions();
    final apps = ref.watch(captureAppsProvider).value ?? const <CaptureApp>[];
    final bridge = ref.read(captureBridgeProvider);
    final supported = perms.supported;
    final needed = <CaptureAccess>[
      if (s.notifications) CaptureAccess.notifications,
      if (s.bubble) CaptureAccess.overlay,
      if (s.smart) CaptureAccess.accessibility,
      CaptureAccess.postNotifications,
    ];
    final missing = needed.where((a) => !perms.granted(a) && a != CaptureAccess.postNotifications);

    return Scaffold(
      body: SafeArea(
        child: ListView(
          key: const Key('capture-settings'),
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.screen,
            AppSpacing.s2,
            AppSpacing.screen,
            AppSpacing.s8,
          ),
          children: [
            Align(
              alignment: AlignmentDirectional.centerStart,
              child: IconButton(
                tooltip: l.back,
                icon: const Icon(AppIcons.back),
                onPressed: () => Navigator.of(context).maybePop(),
              ),
            ),
            const SizedBox(height: AppSpacing.s2),
            PageTitle(title: l.captureTitle, subtitle: l.captureHint),
            const SizedBox(height: AppSpacing.s6),
            _Note(icon: AppIcons.shieldCheck, text: l.capturePrivacy, keyName: 'capture-privacy'),
            if (!supported) ...[
              const SizedBox(height: AppSpacing.s3),
              _Note(
                icon: AppIcons.info,
                text: l.captureUnsupported,
                keyName: 'capture-unsupported',
              ),
            ],
            const SizedBox(height: AppSpacing.s4),
            ToggleRow(
              key: const Key('capture-master'),
              icon: AppIcons.payment,
              title: l.captureMaster,
              subtitle: s.enabled ? l.captureMasterOn : l.captureMasterOff,
              value: s.enabled,
              showDivider: false,
              onChanged: supported ? (on) => unawaited(_set((x) => x.copyWith(enabled: on))) : null,
            ),
            if (s.enabled) ...[
              const SizedBox(height: AppSpacing.s6),
              SectionLabel(l.captureSectionSources),
              ToggleRow(
                key: const Key('capture-source-alerts'),
                icon: AppIcons.bell,
                title: l.captureSourceAlerts,
                subtitle: l.captureSourceAlertsHint,
                value: s.notifications,
                onChanged: (on) => unawaited(_set((x) => x.copyWith(notifications: on))),
              ),
              ToggleRow(
                key: const Key('capture-source-bubble'),
                icon: AppIcons.chat,
                title: l.captureSourceBubble,
                subtitle: l.captureSourceBubbleHint,
                value: s.bubble,
                onChanged: (on) => unawaited(_set((x) => x.copyWith(bubble: on))),
              ),
              ToggleRow(
                key: const Key('capture-source-smart'),
                icon: AppIcons.sparkle,
                title: l.captureSourceSmart,
                subtitle: l.captureSourceSmartHint,
                value: s.smart,
                onChanged: (on) => unawaited(
                  _set((x) => x.copyWith(smart: on, duringPayment: on && x.duringPayment)),
                ),
              ),
              ToggleRow(
                key: const Key('capture-during-payment'),
                icon: AppIcons.clock,
                title: l.captureDuringPayment,
                subtitle: l.captureDuringPaymentHint,
                value: s.smart && s.duringPayment,
                showDivider: false,
                onChanged: s.smart && s.bubble
                    ? (on) => unawaited(_set((x) => x.copyWith(duringPayment: on)))
                    : null,
              ),
              const SizedBox(height: AppSpacing.s6),
              SectionLabel(l.captureSectionAccess),
              const SizedBox(height: AppSpacing.s2),
              for (final a in needed)
                _AccessRow(
                  access: a,
                  granted: perms.granted(a),
                  showDivider: a != needed.last,
                  onGrant: () => unawaited(bridge.open(a.name)),
                ),
              if (missing.isNotEmpty) ...[
                const SizedBox(height: AppSpacing.s4),
                _RestrictedGuide(onAppInfo: () => unawaited(bridge.open('appInfo'))),
              ],
              if (apps.isNotEmpty) ...[
                const SizedBox(height: AppSpacing.s8),
                SectionLabel(l.captureSectionApps),
                const SizedBox(height: AppSpacing.s1),
                Text(
                  l.captureAppsHint,
                  style: context.text.bodySmall.copyWith(color: c.textSecondary),
                ),
                for (final a in apps)
                  ToggleRow(
                    key: Key('capture-app-${a.package}'),
                    leading: Avatar(name: a.name, seed: a.package, size: AvatarSize.s32),
                    title: a.name,
                    subtitle: a.installed ? _kind(l, a.kind) : l.captureAppNotInstalled,
                    value: s.appOn(a),
                    showDivider: a != apps.last,
                    onChanged: (on) =>
                        unawaited(_set((x) => x.copyWith(apps: {...x.apps, a.package: on}))),
                  ),
              ],
              const SizedBox(height: AppSpacing.s8),
              PillButton(
                key: const Key('capture-sample'),
                label: l.captureSample,
                icon: AppIcons.sparkle,
                variant: PillVariant.outline,
                onPressed: () => unawaited(_sample()),
              ),
            ],
          ],
        ),
      ),
    );
  }

  static String _kind(AppLocalizations l, String kind) => switch (kind) {
    'sms' => l.captureKindSms,
    'bank' => l.captureKindBank,
    _ => l.captureKindUpi,
  };
}

class _Note extends StatelessWidget {
  const _Note({required this.icon, required this.text, required this.keyName});

  final IconData icon;
  final String text;
  final String keyName;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Container(
      key: Key(keyName),
      padding: const EdgeInsets.all(AppSpacing.s4),
      decoration: BoxDecoration(color: c.primaryContainer, borderRadius: AppRadii.all24),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 22, color: c.onPrimaryContainer),
          const SizedBox(width: AppSpacing.s3),
          Expanded(
            child: Text(text, style: context.text.body.copyWith(color: c.onPrimaryContainer)),
          ),
        ],
      ),
    );
  }
}

/// One Android access: name, why, and "Allowed" or **Grant**.
class _AccessRow extends StatelessWidget {
  const _AccessRow({
    required this.access,
    required this.granted,
    required this.onGrant,
    this.showDivider = true,
  });

  final CaptureAccess access;
  final bool granted;
  final VoidCallback onGrant;
  final bool showDivider;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final c = context.colors;
    final (icon, title, hint) = switch (access) {
      CaptureAccess.notifications => (
        AppIcons.bell,
        l.captureAccessAlerts,
        l.captureAccessAlertsHint,
      ),
      CaptureAccess.overlay => (AppIcons.chat, l.captureAccessOverlay, l.captureAccessOverlayHint),
      CaptureAccess.accessibility => (
        AppIcons.sparkle,
        l.captureAccessSmart,
        l.captureAccessSmartHint,
      ),
      CaptureAccess.postNotifications => (
        AppIcons.bell,
        l.captureAccessPost,
        l.captureAccessPostHint,
      ),
    };
    return Column(
      key: Key('capture-access-${access.name}'),
      mainAxisSize: MainAxisSize.min,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(vertical: AppSpacing.s3),
          child: Wrap(
            alignment: WrapAlignment.spaceBetween,
            crossAxisAlignment: WrapCrossAlignment.center,
            spacing: AppSpacing.s3,
            runSpacing: AppSpacing.s2,
            children: [
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 36,
                    height: 36,
                    decoration: BoxDecoration(color: c.primaryContainer, shape: BoxShape.circle),
                    child: Icon(icon, size: 18, color: c.onPrimaryContainer),
                  ),
                  const SizedBox(width: AppSpacing.s3),
                  ConstrainedBox(
                    constraints: BoxConstraints(maxWidth: MediaQuery.sizeOf(context).width * 0.55),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(title, style: context.text.title.w(500)),
                        Text(hint, style: context.text.bodySmall.copyWith(color: c.textSecondary)),
                      ],
                    ),
                  ),
                ],
              ),
              if (granted)
                StatusPill(
                  key: Key('capture-allowed-${access.name}'),
                  label: l.captureAllowed,
                  icon: AppIcons.checkCircle,
                  tone: StatusPillTone.positive,
                )
              else
                PillButton(
                  key: Key('capture-grant-${access.name}'),
                  label: l.captureGrant,
                  variant: PillVariant.outline,
                  size: PillSize.medium,
                  expand: false,
                  onPressed: onGrant,
                ),
            ],
          ),
        ),
        if (showDivider) const DashedDivider(),
      ],
    );
  }
}

/// Step-by-step "Allow restricted settings" (Android 13+ sideloaded APKs, S-220).
class _RestrictedGuide extends StatelessWidget {
  const _RestrictedGuide({required this.onAppInfo});

  final VoidCallback onAppInfo;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final c = context.colors;
    final steps = [l.captureRestrictedStep1, l.captureRestrictedStep2, l.captureRestrictedStep3];
    return Container(
      key: const Key('capture-restricted-guide'),
      padding: const EdgeInsets.all(AppSpacing.s5),
      decoration: BoxDecoration(
        color: c.bgSubtle,
        borderRadius: AppRadii.all24,
        border: Border.all(color: c.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(l.captureRestrictedTitle, style: context.text.title.w(600)),
          const SizedBox(height: AppSpacing.s2),
          Text(l.captureRestrictedBody, style: context.text.body.copyWith(color: c.textSecondary)),
          const SizedBox(height: AppSpacing.s4),
          for (var i = 0; i < steps.length; i++) ...[
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 28,
                  height: 28,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(color: c.ink, shape: BoxShape.circle),
                  child: Text(
                    '${i + 1}',
                    style: context.text.bodySmall.w(700).copyWith(color: c.onInk),
                  ),
                ),
                const SizedBox(width: AppSpacing.s3),
                Expanded(child: Text(steps[i], style: context.text.body)),
              ],
            ),
            const SizedBox(height: AppSpacing.s3),
          ],
          const SizedBox(height: AppSpacing.s1),
          PillButton(
            key: const Key('capture-app-info'),
            label: l.captureOpenAppInfo,
            icon: AppIcons.settings,
            variant: PillVariant.ink,
            size: PillSize.medium,
            onPressed: onAppInfo,
          ),
        ],
      ),
    );
  }
}
