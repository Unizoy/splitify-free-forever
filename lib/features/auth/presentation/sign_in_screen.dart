import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:splitify/features/auth/application/auth_providers.dart';
import 'package:splitify/features/auth/application/sign_in_controller.dart';
import 'package:splitify/features/auth/presentation/auth_page.dart';
import 'package:splitify/l10n/app_localizations.dart';
import 'package:splitify/ui/components/components.dart';
import 'package:splitify/ui/theme/theme.dart';

/// Sign-in (`/sign-in`, 532 + 602): Google pill, "or", email underline field
/// and "Send code"; "Developer sign-in" in debug builds only.
class SignInScreen extends ConsumerStatefulWidget {
  const SignInScreen({super.key});

  @override
  ConsumerState<SignInScreen> createState() => _SignInScreenState();
}

class _SignInScreenState extends ConsumerState<SignInScreen> {
  final _email = TextEditingController();

  /// The Google sheet is open: the spinner goes on the Google button, not on "Send code".
  bool _googleBusy = false;

  @override
  void initState() {
    super.initState();
    _email.text = ref.read(signInControllerProvider).email;
  }

  @override
  void dispose() {
    _email.dispose();
    super.dispose();
  }

  Future<void> _send() async {
    final ok = await ref.read(signInControllerProvider.notifier).sendCode(_email.text);
    if (!ok || !mounted) return;
    await context.push(
      Uri(path: '/sign-in/code', queryParameters: {'email': _email.text.trim()}).toString(),
    );
  }

  Future<void> _google() async {
    if (!ref.read(googleConfiguredProvider)) {
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(SnackBar(content: Text(AppLocalizations.of(context).googleSoon)));
      return;
    }
    setState(() => _googleBusy = true);
    try {
      await ref.read(signInControllerProvider.notifier).google();
    } finally {
      if (mounted) setState(() => _googleBusy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final c = context.colors;
    final state = ref.watch(signInControllerProvider);
    final google = ref.watch(googleConfiguredProvider);
    final failure = state.failure;
    return AuthPage(
      title: l.signInTitle,
      subtitle: l.signInSubtitle,
      onBack: () => context.go('/welcome'),
      children: [
        PillButton(
          key: const Key('sign-in-google'),
          label: l.continueWithGoogle,
          icon: AppIcons.globe,
          variant: PillVariant.outline,
          loading: _googleBusy,
          onPressed: state.busy ? null : _google,
        ),
        if (!google) ...[
          const SizedBox(height: AppSpacing.s2),
          Center(
            child: StatusPill(label: l.comingSoon, icon: AppIcons.sparkle),
          ),
        ],
        const SizedBox(height: AppSpacing.s6),
        Row(
          children: [
            Expanded(child: DashedDivider(color: c.border)),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: AppSpacing.s3),
              child: Text(
                l.orDivider.toUpperCase(),
                style: context.text.labelCaps.copyWith(color: c.textTertiary),
              ),
            ),
            Expanded(child: DashedDivider(color: c.border)),
          ],
        ),
        const SizedBox(height: AppSpacing.s4),
        UnderlineField(
          key: const Key('sign-in-email'),
          label: l.emailLabel,
          hint: l.emailHint,
          controller: _email,
          keyboardType: TextInputType.emailAddress,
          textInputAction: TextInputAction.send,
          onChanged: (_) => ref.read(signInControllerProvider.notifier).clearFailure(),
          onSubmitted: (_) => _send(),
          errorText: failure == null ? null : authFailureText(l, failure),
        ),
        const SizedBox(height: AppSpacing.s6),
        PillButton(
          key: const Key('sign-in-send'),
          label: l.sendCode,
          loading: state.busy && !_googleBusy,
          onPressed: _googleBusy ? null : _send,
        ),
        if (ref.watch(devLoginProvider)) ...[
          const SizedBox(height: AppSpacing.s4),
          PillButton(
            key: const Key('sign-in-dev'),
            label: l.devSignIn,
            icon: AppIcons.device,
            variant: PillVariant.ghost,
            onPressed: () => context.push('/debug/login'),
          ),
        ],
      ],
    );
  }
}
