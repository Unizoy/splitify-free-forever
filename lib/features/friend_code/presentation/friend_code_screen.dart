import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:splitify/data/remote/friends_remote.dart';
import 'package:splitify/domain/rules/invite_code.dart';
import 'package:splitify/features/account/presentation/upi_scan_screen.dart';
import 'package:splitify/features/expenses/presentation/editor/editor_fields.dart' show ToolChip;
import 'package:splitify/features/friend_code/application/friend_code_providers.dart';
import 'package:splitify/features/friend_code/domain/friend_code.dart';
import 'package:splitify/features/friend_code/presentation/friend_code_copy.dart';
import 'package:splitify/features/friends/presentation/friend_routes.dart';
import 'package:splitify/l10n/app_localizations.dart';
import 'package:splitify/ui/components/components.dart';
import 'package:splitify/ui/theme/theme.dart';

/// Opens the camera and returns the first QR's text, or null (tests inject a value).
typedef FriendQrScanner = Future<String?> Function(BuildContext context);

final friendQrScannerProvider = Provider<FriendQrScanner>(
  (ref) => (context) {
    final l = AppLocalizations.of(context);
    return Navigator.of(context).push<String>(
      MaterialPageRoute(
        builder: (_) => QrScanScreen(title: l.friendCodeScanTitle, hint: l.friendCodeScanHint2),
      ),
    );
  },
);

/// Add a friend by code (`/friends/code`, `/friends/code/:code`, deep link `splitify://friend?code=…`; D-034 B4),
/// minimal like the join screen: one code field that takes a typed code, a pasted link or the shared message,
/// with Paste and Scan QR beside it, and "Add friend" above the keyboard. A scan or a paste adds at once; a code
/// from a link waits for one tap. A group invite link goes to the join screen. Online only: the server checks
/// the code and the rate limit. Then the friend's page opens.
class FriendCodeScreen extends ConsumerStatefulWidget {
  const FriendCodeScreen({this.code, super.key});

  /// From a deep link: filled in, added with one tap.
  final String? code;

  @override
  ConsumerState<FriendCodeScreen> createState() => _FriendCodeScreenState();
}

class _FriendCodeScreenState extends ConsumerState<FriendCodeScreen> {
  final _field = TextEditingController();
  final _focus = FocusNode(debugLabel: 'friend code');
  String? _error;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    final raw = widget.code;
    if (raw != null) _field.text = InviteCode.display(raw);
  }

  @override
  void dispose() {
    _field.dispose();
    _focus.dispose();
    super.dispose();
  }

  /// Handles what a scan, a paste or the field holds. False when it is not a code.
  bool _take(CodeRead? read) {
    switch (read) {
      case FriendCodeRead(:final code):
        _field.text = FriendCode.display(code);
        unawaited(_add(code));
        return true;
      case GroupInviteRead(:final code):
        unawaited(GoRouter.of(context).pushReplacement('/join/$code'));
        return true;
      case null:
        return false;
    }
  }

  Future<void> _add(String code) async {
    if (_busy) return;
    final l = AppLocalizations.of(context);
    final router = GoRouter.of(context);
    final messenger = ScaffoldMessenger.of(context);
    _focus.unfocus();
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final added = await ref.read(friendCodeActionsProvider).add(code);
      if (!mounted) return;
      unawaited(HapticFeedback.mediumImpact());
      final name = added.friendName;
      router.pushReplacement(FriendRoutes.page('u:${added.friendUserId}'));
      messenger
        ..hideCurrentSnackBar()
        ..showSnackBar(
          SnackBar(
            content: Text(added.created ? l.friendCodeAdded(name) : l.friendCodeAlready(name)),
          ),
        );
    } on FriendCodeFailure catch (e) {
      if (mounted) setState(() => _error = friendCodeFailureText(l, e.code));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  void _submit() {
    final l = AppLocalizations.of(context);
    if (!_take(FriendCode.read(_field.text))) setState(() => _error = l.friendCodeInvalid);
  }

  Future<void> _paste() async {
    final l = AppLocalizations.of(context);
    final data = await Clipboard.getData(Clipboard.kTextPlain);
    if (!mounted) return;
    final text = data?.text;
    if (!_take(text == null ? null : FriendCode.read(text))) {
      setState(() => _error = l.friendCodePasteEmpty);
    }
  }

  Future<void> _scan() async {
    final l = AppLocalizations.of(context);
    final raw = await ref.read(friendQrScannerProvider)(context);
    if (raw == null || !mounted) return;
    if (!_take(FriendCode.read(raw))) setState(() => _error = l.friendCodeQrInvalid);
  }

  void _back() {
    if (context.canPop()) {
      context.pop();
    } else {
      context.go('/friends');
    }
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final c = context.colors;
    return Scaffold(
      appBar: AppBar(
        leading: AppIconButton(tooltip: l.back, icon: const Icon(AppIcons.back), onPressed: _back),
        title: Text(l.friendCodeAddTitle),
      ),
      body: Column(
        children: [
          Expanded(
            child: ListView(
              key: const Key('friend-code-form'),
              keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.screen,
                AppSpacing.s3,
                AppSpacing.screen,
                AppSpacing.s8,
              ),
              children: [
                Text(
                  l.friendCodeAddBody,
                  style: context.text.body.copyWith(color: c.textSecondary),
                ),
                const SizedBox(height: AppSpacing.s6),
                UnderlineField(
                  key: const Key('friend-code-field'),
                  label: l.friendCodeField,
                  hint: l.inviteCodeHint,
                  controller: _field,
                  focusNode: _focus,
                  keyboardType: TextInputType.visiblePassword,
                  textInputAction: TextInputAction.go,
                  inputFormatters: [_FriendCodeFormatter(onPasted: _take)],
                  errorText: _error,
                  onChanged: (_) {
                    if (_error != null) setState(() => _error = null);
                  },
                  onSubmitted: (_) => _submit(),
                ),
                const SizedBox(height: AppSpacing.s4),
                Wrap(
                  spacing: AppSpacing.s2,
                  runSpacing: AppSpacing.s2,
                  children: [
                    ToolChip(
                      key: const Key('friend-code-paste'),
                      icon: AppIcons.copy,
                      label: l.joinPaste,
                      semanticLabel: l.joinPaste,
                      onTap: _busy ? null : () => unawaited(_paste()),
                    ),
                    ToolChip(
                      key: const Key('friend-code-scan'),
                      icon: AppIcons.scan,
                      label: l.scanQr,
                      semanticLabel: l.scanQr,
                      onTap: _busy ? null : () => unawaited(_scan()),
                    ),
                  ],
                ),
              ],
            ),
          ),
          // In the body (not bottomNavigationBar): the Scaffold lifts it above the keyboard (D-032).
          StickyActionBar(
            primary: PillButton(
              key: const Key('friend-code-add'),
              label: l.addFriend,
              icon: AppIcons.userPlus,
              loading: _busy,
              onPressed: _submit,
            ),
          ),
        ],
      ),
    );
  }
}

/// Shows the code as `ABCD-EFGH`; more than one character arriving at once that holds a friend code (a paste,
/// a link, the shared message) is handed to [onPasted] right away.
class _FriendCodeFormatter extends TextInputFormatter {
  _FriendCodeFormatter({required this.onPasted});

  final bool Function(CodeRead? read) onPasted;

  @override
  TextEditingValue formatEditUpdate(TextEditingValue oldValue, TextEditingValue newValue) {
    final added = newValue.text.length - oldValue.text.length;
    final read = added > 1 ? FriendCode.read(newValue.text) : null;
    final text = switch (read) {
      FriendCodeRead(:final code) || GroupInviteRead(:final code) => InviteCode.display(code),
      null => InviteCode.display(newValue.text),
    };
    if (read != null) WidgetsBinding.instance.addPostFrameCallback((_) => onPasted(read));
    return TextEditingValue(
      text: text,
      selection: TextSelection.collapsed(offset: text.length),
    );
  }
}
