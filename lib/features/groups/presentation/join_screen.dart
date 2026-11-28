import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:splitify/data/remote/groups_remote.dart';
import 'package:splitify/domain/rules/invite_code.dart';
import 'package:splitify/features/account/presentation/upi_scan_screen.dart';
import 'package:splitify/features/expenses/presentation/editor/editor_fields.dart' show ToolChip;
import 'package:splitify/features/groups/application/groups_providers.dart';
import 'package:splitify/features/groups/presentation/group_visuals.dart';
import 'package:splitify/features/notifications/application/notifications_providers.dart';
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

/// Join (`/join`, `/join/:code`, deep link `splitify://join?code=`; 08 #3/#4, 532 + 602), minimal (D-033):
/// one code field that takes a typed code, a pasted link or the whole shared message, with Paste and Scan
/// beside it → preview (cover, name, members) → claim a name-only spot or "I'm new here" → Join. A pasted
/// or scanned code is looked up at once. Online only: the server checks the code, the rate limit and the
/// claim. Signed out, the router keeps the code through sign-in (S-283).
class JoinScreen extends ConsumerStatefulWidget {
  const JoinScreen({this.code, super.key});

  /// From the QR / deep link; looked up right away.
  final String? code;

  @override
  ConsumerState<JoinScreen> createState() => _JoinScreenState();
}

class _JoinScreenState extends ConsumerState<JoinScreen> {
  final _field = TextEditingController();
  final _focus = FocusNode(debugLabel: 'invite code');
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
    _focus.dispose();
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
      if (mounted) {
        AppHaptics.error();
        setState(() => _error = _failureText(l, e.code));
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _submitCode() async {
    final l = AppLocalizations.of(context);
    final code = InviteCode.parse(_field.text);
    if (code == null) {
      AppHaptics.error();
      setState(() => _error = l.joinInvalidCode);
      return;
    }
    await _lookup(code);
  }

  void _changed(String text) {
    if (_error != null) setState(() => _error = null);
  }

  /// A whole code arrived at once (pasted from the keyboard, the Paste chip): look it up without
  /// another tap.
  void _pasted(String code) {
    if (!mounted || _busy) return;
    _focus.unfocus();
    unawaited(_lookup(code));
  }

  Future<void> _paste() async {
    final l = AppLocalizations.of(context);
    final data = await Clipboard.getData(Clipboard.kTextPlain);
    if (!mounted) return;
    final code = data?.text == null ? null : InviteCode.find(data!.text!);
    if (code == null) {
      AppHaptics.error();
      setState(() => _error = l.joinPasteEmpty);
      return;
    }
    _field.text = InviteCode.display(code);
    _pasted(code);
  }

  Future<void> _scan() async {
    final l = AppLocalizations.of(context);
    final raw = await ref.read(qrScannerProvider)(context);
    if (raw == null || !mounted) return;
    final code = InviteCode.parse(raw);
    if (code == null) {
      AppHaptics.error();
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
      // First group: the shell may ask about push notifications (08 #19).
      if (!p.alreadyMember) ref.read(pushPrePromptRequestsProvider.notifier).request();
      router.go('/groups/$id');
      if (!p.alreadyMember) {
        messenger.showSnackBar(SnackBar(content: Text(l.joinedGroup(p.name))));
      }
    } on GroupFailure catch (e) {
      if (!mounted) return;
      final message = _failureText(l, e.code);
      // Someone else took the spot: refresh the list of free spots, then keep the message on screen.
      if (e.code == GroupFailureCode.alreadyClaimed) await _lookup(_code!);
      if (mounted) {
        AppHaptics.error();
        setState(() => _error = message);
      }
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

  void _back(JoinPreview? preview) {
    if (preview != null && widget.code == null) {
      _restart();
    } else if (context.canPop()) {
      context.pop();
    } else {
      context.go('/groups');
    }
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final preview = _preview;
    return PopScope(
      // Back from the preview returns to the code field first (when the code was typed here).
      canPop: preview == null || widget.code != null,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _restart();
      },
      child: Scaffold(
        appBar: AppBar(
          leading: AppIconButton(
            tooltip: l.back,
            icon: const Icon(AppIcons.back),
            onPressed: () => _back(preview),
          ),
          title: Text(l.joinGroup),
        ),
        body: PageBody(
          child: Column(
            children: [
              Expanded(
                child: ListView(
                  keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
                  padding: const EdgeInsets.fromLTRB(
                    AppSpacing.screen,
                    AppSpacing.s3,
                    AppSpacing.screen,
                    AppSpacing.s8,
                  ),
                  children: [
                    // Code → the group's preview (and back) cross-fade in place (S-451).
                    MotionSwitcher(
                      scale: false,
                      child: Column(
                        key: ValueKey(
                          preview == null ? 'motion-join-enter' : 'motion-join-preview',
                        ),
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: preview == null
                            ? _enterStep(context)
                            : _previewStep(context, preview),
                      ),
                    ),
                  ],
                ),
              ),
              // In the body (not bottomNavigationBar): the Scaffold lifts it above the keyboard (D-032).
              _submitBar(context, preview),
            ],
          ),
        ),
      ),
    );
  }

  List<Widget> _enterStep(BuildContext context) {
    final l = AppLocalizations.of(context);
    final c = context.colors;
    return [
      Text(l.joinSubtitle, style: context.text.body.copyWith(color: c.textSecondary)),
      const SizedBox(height: AppSpacing.s6),
      UnderlineField(
        key: const Key('join-code'),
        label: l.inviteCodeLabel,
        hint: l.inviteCodeHint,
        controller: _field,
        focusNode: _focus,
        autofocus: widget.code == null,
        keyboardType: TextInputType.visiblePassword,
        textInputAction: TextInputAction.go,
        inputFormatters: [_InviteCodeFormatter(onPasted: _pasted)],
        errorText: _error,
        onChanged: _changed,
        onSubmitted: (_) => unawaited(_submitCode()),
      ),
      const SizedBox(height: AppSpacing.s4),
      Wrap(
        spacing: AppSpacing.s2,
        runSpacing: AppSpacing.s2,
        children: [
          ToolChip(
            key: const Key('join-paste'),
            icon: AppIcons.copy,
            label: l.joinPaste,
            semanticLabel: l.joinPaste,
            onTap: _busy ? null : () => unawaited(_paste()),
          ),
          ToolChip(
            key: const Key('join-scan'),
            icon: AppIcons.scan,
            label: l.scanQr,
            semanticLabel: l.scanQr,
            onTap: _busy ? null : () => unawaited(_scan()),
          ),
        ],
      ),
    ];
  }

  /// Find group (code step) or Join / Join as … / Open group (preview), above the keyboard.
  Widget _submitBar(BuildContext context, JoinPreview? p) {
    final l = AppLocalizations.of(context);
    if (p == null) {
      return StickyActionBar(
        primary: PillButton(
          key: const Key('join-find'),
          label: l.findGroup,
          loading: _busy,
          onPressed: () => unawaited(_submitCode()),
        ),
      );
    }
    final claimPick = _newHere == false && p.unclaimed.isNotEmpty ? p.unclaimed[_carousel] : null;
    final ready = p.alreadyMember || _newHere != null;
    return StickyActionBar(
      primary: PillButton(
        key: const Key('join-submit'),
        label: p.alreadyMember
            ? l.openGroup
            : claimPick != null
            ? l.joinAsCta(claimPick.name)
            : l.joinGroupShort,
        loading: _busy,
        onPressed: ready ? () => unawaited(_join()) : null,
      ),
    );
  }

  List<Widget> _previewStep(BuildContext context, JoinPreview p) {
    final l = AppLocalizations.of(context);
    final c = context.colors;
    return [
      CoverBanner(
        key: const Key('join-preview'),
        seed: p.groupId,
        type: p.type,
        name: p.name,
        caption: groupTypeLabel(l, p.type),
        showName: false,
        height: 136,
      ),
      const SizedBox(height: AppSpacing.s4),
      Semantics(
        header: true,
        child: Text(p.name, textAlign: TextAlign.center, style: context.text.title.w(600)),
      ),
      const SizedBox(height: AppSpacing.s1),
      Text(
        l.groupMembersCount(p.memberCount),
        textAlign: TextAlign.center,
        style: context.text.body.copyWith(color: c.textSecondary),
      ),
      if (p.archived) ...[
        const SizedBox(height: AppSpacing.s4),
        _Notice(icon: AppIcons.archive, text: l.joinArchivedNotice),
      ],
      if (p.alreadyMember) ...[
        const SizedBox(height: AppSpacing.s4),
        _Notice(icon: AppIcons.checkCircle, text: l.joinAlreadyMember),
      ] else if (p.unclaimed.isNotEmpty) ...[
        const SizedBox(height: AppSpacing.s6),
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
      if (widget.code == null) ...[
        const SizedBox(height: AppSpacing.s4),
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

/// Upper-cases, keeps code characters only and adds the dash: `abcdefgh` → `ABCD-EFGH`. Pasted text
/// (the share message, the link) keeps just the code inside it (D-033) and reports it to [onPasted].
class _InviteCodeFormatter extends TextInputFormatter {
  _InviteCodeFormatter({required this.onPasted});

  final ValueChanged<String> onPasted;

  @override
  TextEditingValue formatEditUpdate(TextEditingValue oldValue, TextEditingValue newValue) {
    final added = newValue.text.length - oldValue.text.length;
    final found = added > 1 ? InviteCode.find(newValue.text) : null;
    final text = InviteCode.display(found ?? newValue.text);
    // More than one character at once that makes a whole code = a paste: look it up right away.
    if (found != null && InviteCode.normalize(oldValue.text) != found) {
      WidgetsBinding.instance.addPostFrameCallback((_) => onPasted(found));
    }
    return TextEditingValue(
      text: text,
      selection: TextSelection.collapsed(offset: text.length),
    );
  }
}
