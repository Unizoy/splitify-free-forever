import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:splitify/data/repositories/auth_repository.dart';
import 'package:splitify/features/auth/application/auth_providers.dart';
import 'package:splitify/features/auth/application/sign_in_controller.dart';
import 'package:splitify/features/auth/presentation/auth_page.dart';
import 'package:splitify/l10n/app_localizations.dart';
import 'package:splitify/ui/components/components.dart';
import 'package:splitify/ui/theme/theme.dart';

/// Code entry (`/sign-in/code`): one box per digit (`EMAIL_OTP_LENGTH`, 6 by
/// default), Verify, resend after 60 s and "Change email". A wrong code
/// empties the boxes (red until the next digit) so the next try starts clean.
class CodeScreen extends ConsumerStatefulWidget {
  const CodeScreen({this.email, super.key});

  /// Shown in the hint; the controller keeps the real value.
  final String? email;

  @override
  ConsumerState<CodeScreen> createState() => _CodeScreenState();
}

class _CodeScreenState extends ConsumerState<CodeScreen> {
  final _code = TextEditingController();
  final _focus = FocusNode();
  Timer? _tick;

  @override
  void initState() {
    super.initState();
    _tick = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _tick?.cancel();
    _code.dispose();
    _focus.dispose();
    super.dispose();
  }

  int get _length => ref.read(emailCodeLengthProvider);

  Future<void> _verify() async {
    if (_code.text.length != _length) return;
    final ok = await ref.read(signInControllerProvider.notifier).verify(_code.text);
    if (!mounted) return;
    if (ok) {
      context.go('/sign-in/profile');
      return;
    }
    // Wrong, used or expired code: empty the boxes and keep the keyboard up for the next try (offline keeps
    // the digits, the same code works once back online).
    if (_refused(ref.read(signInControllerProvider).failure)) {
      _code.clear();
      _focus.requestFocus();
      setState(() {});
    }
  }

  static bool _refused(AuthFailureCode? f) =>
      f == AuthFailureCode.invalidCode ||
      f == AuthFailureCode.expiredCode ||
      f == AuthFailureCode.tooManyTries;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final state = ref.watch(signInControllerProvider);
    final controller = ref.read(signInControllerProvider.notifier);
    final length = ref.watch(emailCodeLengthProvider);
    final email = state.email.isEmpty ? (widget.email ?? '') : state.email;
    final left = controller.resendSecondsLeft();
    final failure = state.failure;
    return AuthPage(
      title: l.codeTitle(length),
      subtitle: l.codeSentTo(email),
      onBack: () => context.go('/sign-in'),
      children: [
        CodeBoxes(
          controller: _code,
          focusNode: _focus,
          length: length,
          error: _refused(failure) && _code.text.isEmpty,
          onChanged: (v) {
            controller.clearFailure();
            setState(() {});
            if (v.length == length) unawaited(_verify());
          },
        ),
        if (failure != null) AuthMessage(authFailureText(l, failure)),
        const SizedBox(height: AppSpacing.s8),
        PillButton(
          key: const Key('code-verify'),
          label: l.verifyCode,
          loading: state.busy,
          onPressed: _code.text.length == length ? _verify : null,
        ),
        const SizedBox(height: AppSpacing.s3),
        PillButton(
          key: const Key('code-resend'),
          label: left > 0 ? l.resendIn(left) : l.resendCode,
          variant: PillVariant.ghost,
          onPressed: left > 0 || state.busy
              ? null
              : () {
                  _code.clear();
                  unawaited(controller.resend());
                },
        ),
        PillButton(
          key: const Key('code-change-email'),
          label: l.changeEmail,
          variant: PillVariant.ghost,
          onPressed: () => context.go('/sign-in'),
        ),
      ],
    );
  }
}

/// One box per digit over one hidden text field (keeps paste and autofill).
/// [error] draws every box in the "owe" red (the last code was refused).
class CodeBoxes extends StatelessWidget {
  const CodeBoxes({
    required this.controller,
    required this.focusNode,
    required this.onChanged,
    this.length = 6,
    this.error = false,
    super.key,
  });

  final TextEditingController controller;
  final FocusNode focusNode;
  final ValueChanged<String> onChanged;
  final int length;
  final bool error;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final c = context.colors;
    final text = controller.text;
    // Eight or more boxes get a tighter gap and digit so they still fit a 360 dp phone.
    final wide = length > 6;
    return Semantics(
      label: l.codeBoxes(text.length, length),
      child: Stack(
        children: [
          Opacity(
            opacity: 0,
            child: TextField(
              key: const Key('code-input'),
              controller: controller,
              focusNode: focusNode,
              autofocus: true,
              keyboardType: TextInputType.number,
              autofillHints: const [AutofillHints.oneTimeCode],
              inputFormatters: [
                FilteringTextInputFormatter.digitsOnly,
                LengthLimitingTextInputFormatter(length),
              ],
              onChanged: onChanged,
              showCursor: false,
            ),
          ),
          GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: focusNode.requestFocus,
            child: ExcludeSemantics(
              child: Row(
                children: [
                  for (var i = 0; i < length; i++) ...[
                    if (i > 0) SizedBox(width: wide ? AppSpacing.s1 : AppSpacing.s2),
                    Expanded(
                      child: AspectRatio(
                        aspectRatio: 0.82,
                        child: DecoratedBox(
                          decoration: BoxDecoration(
                            color: c.surface,
                            borderRadius: wide
                                ? BorderRadius.circular(AppRadii.r12)
                                : AppRadii.all16,
                            border: Border.all(
                              color: error
                                  ? c.oweText
                                  : i == text.length
                                  ? c.primary
                                  : c.border,
                              width: error || i == text.length ? 2 : 1,
                            ),
                          ),
                          child: Center(
                            child: MediaQuery.withClampedTextScaling(
                              maxScaleFactor: 1.4,
                              child: Text(
                                i < text.length ? text[i] : '',
                                style: wide ? context.text.headline : context.text.amountLarge,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
