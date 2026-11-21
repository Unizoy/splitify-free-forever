import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:splitify/data/remote/groups_remote.dart';
import 'package:splitify/domain/rules/invite_code.dart';
import 'package:splitify/features/account/presentation/upi_scan_screen.dart';
import 'package:splitify/features/groups/application/groups_providers.dart';
import 'package:splitify/features/groups/presentation/group_visuals.dart';
import 'package:splitify/l10n/app_localizations.dart';
import 'package:splitify/ui/components/components.dart';
import 'package:splitify/ui/theme/theme.dart';

/// Opens the camera and returns the first QR's text, or null (tests inject a value).
typedef QrScanner = Future<String?> Function(BuildContext context);

final qrScannerProvider = Provider<QrScanner>(
  (ref) => (context) {
    final l = AppLocalizations.of(context);
    return Navigator.of(context).push<String>(
      MaterialPageRoute(
        builder: (_) => QrScanScreen(title: l.joinScanTitle, hint: l.joinScanHint),
      ),
    );
  },
);

/// Join (`/join`, `/join/:code`, deep link `splitify://join?code=`; 08 #3/#4, 532 + 602): enter or scan the
/// code → preview (cover, name, members) → claim a name-only spot or "I'm new here" → the group opens.
/// Online only: the server checks the code, the rate limit and the claim.
class JoinScreen extends ConsumerStatefulWidget {
  const JoinScreen({this.code, super.key});

  /// From the QR / deep link; looked up right away.
  final String? code;

  @override
  ConsumerState<JoinScreen> createState() => _JoinScreenState();
}

class _JoinScreenState extends ConsumerState<JoinScreen> {
  final _field = TextEditingController();
  String? _code;
  JoinPreview? _preview;
  String? _error;
  bool _busy = false;

  /// Picked spot on the claim step (index into `unclaimed`).
  int _carousel = 0;

  /// null = nothing picked yet, true = "I'm new here", false = claim [_carousel].
  bool? _newHere;

  @override
  void initState() {
    super.initState();
    final code = widget.code == null ? null : InviteCode.parse(widget.code!);
    if (widget.code != null) _field.text = InviteCode.display(widget.code!);
    if (code != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) => unawaited(_lookup(code)));
    }
  }

  @override
  void dispose() {
    _field.dispose();
    super.dispose();
  }

  String _failureText(AppLocalizations l, GroupFailureCode code) =>
      code == GroupFailureCode.offline ? l.joinNeedsInternet : groupFailureText(l, code);

  Future<void> _lookup(String code) async {
    final l = AppLocalizations.of(context);
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final p = await ref.read(groupActionsProvider).preview(code);
      if (!mounted) return;
      setState(() {
        _code = code;
        _preview = p;
        _carousel = 0;
        _newHere = p.unclaimed.isEmpty ? true : null;
      });
    } on GroupFailure catch (e) {
      if (mounted) setState(() => _error = _failureText(l, e.code));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _submitCode() async {
    final l = AppLocalizations.of(context);
    final code = InviteCode.parse(_field.text);
    if (code == null) {
      setState(() => _error = l.joinInvalidCode);
      return;
    }
    await _lookup(code);
  }

  Future<void> _scan() async {
    final l = AppLocalizations.of(context);
    final raw = await ref.read(qrScannerProvider)(context);
    if (raw == null || !mounted) return;
    final code = InviteCode.parse(raw);
    if (code == null) {
      setState(() => _error = l.joinQrInvalid);
      return;
    }
    _field.text = InviteCode.display(code);
    await _lookup(code);
  }

  Future<void> _join() async {
    final l = AppLocalizations.of(context);
    final router = GoRouter.of(context);
    final messenger = ScaffoldMessenger.of(context);
    final p = _preview!;
    final claim = p.alreadyMember || (_newHere ?? true) ? null : p.unclaimed[_carousel];
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final id = p.alreadyMember
          ? p.groupId
          : await ref.read(groupActionsProvider).join(_code!, claimMemberId: claim?.id);
      if (p.alreadyMember) unawaited(ref.read(syncNowProvider)().catchError((Object _) {}));
      router.go('/groups/$id');
      if (!p.alreadyMember) {
        messenger.showSnackBar(SnackBar(content: Text(l.joinedGroup(p.name))));
      }
    } on GroupFailure catch (e) {
      if (!mounted) return;
      final message = _failureText(l, e.code);
      // Someone else took the spot: refresh the list of free spots, then keep the message on screen.
      if (e.code == GroupFailureCode.alreadyClaimed) await _lookup(_code!);
      if (mounted) setState(() => _error = message);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  void _restart() => setState(() {
    _preview = null;
    _code = null;
    _error = null;
    _newHere = null;
  });

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final preview = _preview;
    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          tooltip: l.back,
          icon: const Icon(AppIcons.back),
          onPressed: () {
            if (preview != null && widget.code == null) {
              _restart();
            } else if (context.canPop()) {
              context.pop();
            } else {
              context.go('/groups');
            }
          },
        ),
      ),
      body: SafeArea(
        top: false,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.screen,
            AppSpacing.s2,
            AppSpacing.screen,
            AppSpacing.s10,
          ),
          children: [
            Semantics(
              header: true,
              child: MediaQuery.withClampedTextScaling(
                maxScaleFactor: AppText.maxSerifScale,
                child: Text(
                  preview == null ? l.joinGroup : preview.name,
                  textAlign: TextAlign.center,
                  style: context.text.sheetTitle,
                ),
              ),
            ),
            const SizedBox(height: AppSpacing.s2),
            if (preview == null) ..._enterStep(context) else ..._previewStep(context, preview),
          ],
        ),
      ),
    );
  }

  List<Widget> _enterStep(BuildContext context) {
    final l = AppLocalizations.of(context);
    final c = context.colors;
    return [
      Text(
        l.joinSubtitle,
        textAlign: TextAlign.center,
        style: context.text.body.copyWith(color: c.textSecondary),
      ),
      const SizedBox(height: AppSpacing.s8),
      Row(
        children: [
          Expanded(
            child: OptionTile(
              key: const Key('join-enter'),
              label: l.enterCode,
              selected: true,
              leading: Icon(AppIcons.edit, size: 18, color: c.primary),
              onTap: () {},
            ),
          ),
          const SizedBox(width: AppSpacing.s3),
          Expanded(
            child: OptionTile(
              key: const Key('join-scan'),
              label: l.scanQr,
              leading: Icon(AppIcons.scan, size: 18, color: c.primary),
              onTap: _busy ? null : () => unawaited(_scan()),
            ),
          ),
        ],
      ),
      const SizedBox(height: AppSpacing.s8),
      UnderlineField(
        key: const Key('join-code'),
        label: l.inviteCodeLabel,
        hint: l.inviteCodeHint,
        controller: _field,
        keyboardType: TextInputType.visiblePassword,
        textInputAction: TextInputAction.go,
        inputFormatters: [_InviteCodeFormatter()],
        errorText: _error,
        onChanged: (_) {
          if (_error != null) setState(() => _error = null);
        },
        onSubmitted: (_) => unawaited(_submitCode()),
      ),
      const SizedBox(height: AppSpacing.s8),
      PillButton(
        key: const Key('join-find'),
        label: l.findGroup,
        loading: _busy,
        onPressed: () => unawaited(_submitCode()),
      ),
    ];
  }

  List<Widget> _previewStep(BuildContext context, JoinPreview p) {
    final l = AppLocalizations.of(context);
    final c = context.colors;
    final claimPick = _newHere == false && p.unclaimed.isNotEmpty ? p.unclaimed[_carousel] : null;
    final ready = p.alreadyMember || _newHere != null;
    return [
      Text(
        l.groupMembersCount(p.memberCount),
        textAlign: TextAlign.center,
        style: context.text.body.copyWith(color: c.textSecondary),
      ),
      const SizedBox(height: AppSpacing.s6),
      CoverBanner(
        key: const Key('join-preview'),
        seed: p.groupId,
        type: p.type,
        name: p.name,
        caption: groupTypeLabel(l, p.type),
        showName: false,
        height: 136,
      ),
      if (p.archived) ...[
        const SizedBox(height: AppSpacing.s4),
        _Notice(icon: AppIcons.archive, text: l.joinArchivedNotice),
      ],
      if (p.alreadyMember) ...[
        const SizedBox(height: AppSpacing.s4),
        _Notice(icon: AppIcons.checkCircle, text: l.joinAlreadyMember),
      ] else if (p.unclaimed.isNotEmpty) ...[
        const SizedBox(height: AppSpacing.s8),
        Text(l.joinWhoAreYou, textAlign: TextAlign.center, style: context.text.title.w(600)),
        const SizedBox(height: AppSpacing.s1),
        Text(
          l.joinWhoAreYouBody,
          textAlign: TextAlign.center,
          style: context.text.body.copyWith(color: c.textSecondary),
        ),
        const SizedBox(height: AppSpacing.s5),
        Center(
          child: AvatarCarousel(
            key: const Key('join-carousel'),
            people: [for (final m in p.unclaimed) (name: m.name, seed: m.id, tint: m.tint)],
            onChanged: (i) => setState(() {
              _carousel = i;
              if (_newHere == null) _newHere = false;
            }),
          ),
        ),
        const SizedBox(height: AppSpacing.s5),
        OptionTile(
          key: const Key('join-claim'),
          label: l.joinAsName(p.unclaimed[_carousel].name),
          selected: _newHere == false,
          onTap: () => setState(() => _newHere = false),
        ),
        const SizedBox(height: AppSpacing.s3),
        OptionTile(
          key: const Key('join-new'),
          label: l.joinNewHere,
          selected: _newHere ?? false,
          onTap: () => setState(() => _newHere = true),
        ),
      ],
      if (_error != null) ...[
        const SizedBox(height: AppSpacing.s4),
        Text(
          _error!,
          key: const Key('join-error'),
          textAlign: TextAlign.center,
          style: context.text.body.copyWith(color: c.oweText),
        ),
      ],
      const SizedBox(height: AppSpacing.s8),
      PillButton(
        key: const Key('join-submit'),
        label: p.alreadyMember
            ? l.openGroup
            : claimPick != null
            ? l.joinAsCta(claimPick.name)
            : l.joinGroupShort,
        loading: _busy,
        onPressed: ready ? () => unawaited(_join()) : null,
      ),
      if (widget.code == null) ...[
        const SizedBox(height: AppSpacing.s2),
        PillButton(
          key: const Key('join-other-code'),
          label: l.joinOtherCode,
          variant: PillVariant.ghost,
          onPressed: _busy ? null : _restart,
        ),
      ],
    ];
  }
}

class _Notice extends StatelessWidget {
  const _Notice({required this.icon, required this.text});

  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Container(
      padding: const EdgeInsets.all(AppSpacing.s4),
      decoration: BoxDecoration(color: c.infoContainer, borderRadius: AppRadii.all16),
      child: Row(
        children: [
          Icon(icon, size: 20, color: c.info),
          const SizedBox(width: AppSpacing.s3),
          Expanded(
            child: Text(text, style: context.text.body.copyWith(color: c.textPrimary)),
          ),
        ],
      ),
    );
  }
}

/// Upper-cases, keeps code characters only and adds the dash: `abcdefgh` → `ABCD-EFGH`.
class _InviteCodeFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(TextEditingValue oldValue, TextEditingValue newValue) {
    final text = InviteCode.display(newValue.text);
    return TextEditingValue(
      text: text,
      selection: TextSelection.collapsed(offset: text.length),
    );
  }
}
