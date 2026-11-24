import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:splitify/app/app_route.dart';
import 'package:splitify/core/money/money_formatter.dart';
import 'package:splitify/data/device/capture_bridge.dart';
import 'package:splitify/domain/entities/payment_capture.dart';
import 'package:splitify/domain/rules/capture_validator.dart';
import 'package:splitify/features/capture/application/capture_providers.dart';
import 'package:splitify/features/capture/presentation/capture_settings_screen.dart';
import 'package:splitify/features/capture/presentation/payments_to_add.dart';
import 'package:splitify/features/expenses/application/expense_editor_controller.dart'
    show currentUserIdProvider;
import 'package:splitify/features/groups/presentation/group_visuals.dart'
    show PageTitle, SectionLabel;
import 'package:splitify/l10n/app_localizations.dart';
import 'package:splitify/ui/components/components.dart';
import 'package:splitify/ui/theme/theme.dart';

/// Payment bubble routes (phase 18b, S-228).
abstract final class CaptureRoutes {
  static const settings = '/account/payment-bubble';

  /// "Add this payment" (picks the group unless [groupId] is given).
  static String add(String captureId, {String? groupId}) =>
      Uri(path: '/capture', queryParameters: {'id': captureId, 'group': ?groupId}).toString();

  /// The editor prefilled from the capture, in [groupId].
  static String editor(String captureId, String groupId) => Uri(
    path: '/expense/new',
    queryParameters: {'group': groupId, 'capture': captureId},
  ).toString();
}

List<RouteBase> captureRoutes() => [
  AppRoute(
    path: '/capture',
    builder: (context, state) => CaptureScreen(
      captureId: state.uri.queryParameters['id'] ?? '',
      groupId: state.uri.queryParameters['group'],
    ),
  ),
  AppRoute(
    path: CaptureRoutes.settings,
    builder: (context, state) => const CaptureSettingsScreen(),
  ),
];

/// Where the capture can go: recent groups and friends first.
final capturePlacesProvider = FutureProvider.autoDispose<List<CaptureChip>>(
  (ref) => ref
      .watch(captureRepositoryProvider)
      .recentChips(myUserId: ref.watch(currentUserIdProvider), limit: 60),
);

/// The capture behind a link, after pulling the newest captures from the native store.
final captureLinkProvider = FutureProvider.autoDispose.family<PaymentCapture?, String>((
  ref,
  id,
) async {
  if (!CaptureValidator.isId(id)) return null;
  final repo = ref.watch(captureRepositoryProvider);
  await repo.importNow();
  return repo.get(id);
});

/// `/capture?id=&group=`: the bubble's Add (or a chip, which brings the group) and "Payments to add" land here.
class CaptureScreen extends ConsumerStatefulWidget {
  const CaptureScreen({required this.captureId, this.groupId, super.key});

  final String captureId;
  final String? groupId;

  @override
  ConsumerState<CaptureScreen> createState() => _CaptureScreenState();
}

class _CaptureScreenState extends ConsumerState<CaptureScreen> {
  bool _routed = false;

  void _open(String groupId) {
    _routed = true;
    unawaited(
      GoRouter.of(context).pushReplacement(CaptureRoutes.editor(widget.captureId, groupId)),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final capture = ref.watch(captureLinkProvider(widget.captureId));
    final places = ref.watch(capturePlacesProvider);
    final c = capture.value;
    final list = places.value;
    // A chip in the bubble already chose the group: straight to the editor.
    final g = widget.groupId;
    if (!_routed && c != null && list != null && g != null && list.any((p) => p.id == g)) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted && !_routed) _open(g);
      });
    }

    final Widget body;
    if (capture.isLoading || places.isLoading) {
      body = Padding(
        padding: const EdgeInsets.only(top: AppSpacing.s10),
        child: Center(child: DotsPulse(color: context.colors.primary)),
      );
    } else if (c == null) {
      body = Padding(
        padding: const EdgeInsets.only(top: AppSpacing.s8),
        child: EmptyState(
          key: const Key('capture-gone'),
          icon: AppIcons.checkCircle,
          title: l.captureGoneTitle,
          message: l.captureGoneBody,
        ),
      );
    } else {
      final groups = [
        for (final p in list ?? const <CaptureChip>[])
          if (!p.friend) p,
      ];
      final friends = [
        for (final p in list ?? const <CaptureChip>[])
          if (p.friend) p,
      ];
      body = Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          PageTitle(title: l.captureAddTitle, subtitle: l.captureAddHint),
          const SizedBox(height: AppSpacing.s6),
          CaptureSummaryCard(capture: c),
          if (groups.isEmpty && friends.isEmpty) ...[
            const SizedBox(height: AppSpacing.s6),
            EmptyState(
              icon: AppIcons.groups,
              title: l.captureNoGroups,
              actions: [
                PillButton(
                  key: const Key('capture-new-group'),
                  label: l.newGroup,
                  onPressed: () => context.push('/groups/new'),
                ),
              ],
            ),
          ],
          for (final (label, items) in [
            (l.captureSectionGroups, groups),
            (l.captureSectionFriends, friends),
          ])
            if (items.isNotEmpty) ...[
              const SizedBox(height: AppSpacing.s8),
              SectionLabel(label),
              const SizedBox(height: AppSpacing.s3),
              for (final p in items) ...[
                OptionTile(
                  key: Key('capture-place-${p.id}'),
                  label: p.name,
                  leading: Avatar(name: p.name, seed: p.id, size: AvatarSize.s32),
                  onTap: () => _open(p.id),
                ),
                const SizedBox(height: AppSpacing.s3),
              ],
            ],
        ],
      );
    }
    return Scaffold(
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.screen,
            AppSpacing.s2,
            AppSpacing.screen,
            AppSpacing.s8,
          ),
          children: [
            Align(
              alignment: AlignmentDirectional.centerStart,
              child: AppIconButton(
                tooltip: l.back,
                icon: const Icon(AppIcons.back),
                onPressed: () => context.canPop() ? context.pop() : context.go('/groups'),
              ),
            ),
            const SizedBox(height: AppSpacing.s2),
            body,
          ],
        ),
      ),
    );
  }
}

/// The captured payment as a card: serif amount, payee, app · time · source.
class CaptureSummaryCard extends StatelessWidget {
  const CaptureSummaryCard({required this.capture, super.key});

  final PaymentCapture capture;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final c = context.colors;
    return Semantics(
      container: true,
      label: capturePaidText(l, capture),
      child: Container(
        key: const Key('capture-summary'),
        padding: const EdgeInsets.all(AppSpacing.s5),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [c.heroTop, c.heroBottom],
          ),
          borderRadius: AppRadii.all28,
          boxShadow: AppShadows.float(c, dark: context.isDark),
        ),
        child: ExcludeSemantics(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    width: 36,
                    height: 36,
                    decoration: BoxDecoration(color: c.onHero, shape: BoxShape.circle),
                    child: Icon(AppIcons.payment, size: 18, color: c.primaryFill),
                  ),
                  const SizedBox(width: AppSpacing.s3),
                  Expanded(
                    child: Text(
                      captureViaText(l, capture, DateTime.now()).toUpperCase(),
                      style: context.text.labelCaps.copyWith(color: c.onHeroMuted),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: AppSpacing.s4),
              FittedBox(
                fit: BoxFit.scaleDown,
                alignment: AlignmentDirectional.centerStart,
                child: Text(
                  MoneyFormatter.list.format(capture.amount, capture.currency),
                  style: context.text.amountHero.copyWith(color: c.onHero),
                ),
              ),
              if (capture.payee != null) ...[
                const SizedBox(height: AppSpacing.s1),
                Text(capture.payee!, style: context.text.title.w(600).copyWith(color: c.onHero)),
              ],
              if (capture.ref != null) ...[
                const SizedBox(height: AppSpacing.s3),
                StatusPill(label: l.captureRef(capture.ref!), tone: StatusPillTone.glass),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
