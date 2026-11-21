import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:splitify/features/auth/application/sign_in_controller.dart';
import 'package:splitify/features/auth/presentation/auth_page.dart';
import 'package:splitify/l10n/app_localizations.dart';
import 'package:splitify/ui/components/components.dart';
import 'package:splitify/ui/theme/theme.dart';

/// Debug-only developer sign-in (`/debug/login`, T4): one tap per e2e test
/// user. `?user=e2e-a` (deep link `splitify://dev/login?user=e2e-a`) signs in
/// straight away. The route is not registered in release builds.
class DevLoginScreen extends ConsumerStatefulWidget {
  const DevLoginScreen({this.user, super.key});

  static const users = ['e2e-a', 'e2e-b', 'e2e-c'];

  final String? user;

  @override
  ConsumerState<DevLoginScreen> createState() => _DevLoginScreenState();
}

class _DevLoginScreenState extends ConsumerState<DevLoginScreen> {
  @override
  void initState() {
    super.initState();
    final u = widget.user;
    if (u != null && DevLoginScreen.users.contains(u)) {
      WidgetsBinding.instance.addPostFrameCallback((_) => unawaited(_signIn(u)));
    }
  }

  Future<void> _signIn(String user) async {
    final ok = await ref.read(signInControllerProvider.notifier).devSignIn(user);
    if (ok && mounted) context.go('/groups');
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final state = ref.watch(signInControllerProvider);
    final failure = state.failure;
    return AuthPage(
      title: l.devSignIn,
      subtitle: l.devLoginSubtitle,
      onBack: () => context.go('/sign-in'),
      children: [
        for (final u in DevLoginScreen.users) ...[
          OptionTile(
            key: Key('dev-login-$u'),
            label: l.devLoginUser(u),
            leading: Avatar(name: u.substring(4).toUpperCase(), seed: u, size: AvatarSize.s32),
            onTap: state.busy ? null : () => unawaited(_signIn(u)),
          ),
          const SizedBox(height: AppSpacing.s3),
        ],
        if (failure != null) AuthMessage(authFailureText(l, failure)),
      ],
    );
  }
}
