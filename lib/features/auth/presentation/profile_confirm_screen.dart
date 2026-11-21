import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:splitify/data/repositories/profile_repository.dart';
import 'package:splitify/features/account/presentation/profile_form.dart';
import 'package:splitify/features/auth/application/auth_providers.dart';
import 'package:splitify/features/auth/presentation/auth_page.dart';
import 'package:splitify/l10n/app_localizations.dart';
import 'package:splitify/ui/components/components.dart';
import 'package:splitify/ui/theme/theme.dart';

/// First sign-in (`/sign-in/profile`): confirm the name, optionally add a UPI ID.
class ProfileConfirmScreen extends ConsumerStatefulWidget {
  const ProfileConfirmScreen({super.key});

  @override
  ConsumerState<ProfileConfirmScreen> createState() => _ProfileConfirmScreenState();
}

class _ProfileConfirmScreenState extends ConsumerState<ProfileConfirmScreen> {
  ProfileDraft? _draft;
  bool _saving = false;

  @override
  void dispose() {
    _draft?.dispose();
    super.dispose();
  }

  Future<void> _continue() async {
    final draft = _draft!;
    if (!draft.validate()) {
      setState(() {});
      return;
    }
    final profile = ref.read(profileProvider).value;
    if (profile == null) {
      context.go('/groups');
      return;
    }
    setState(() => _saving = true);
    try {
      await ref.read(profileProvider.notifier).save(draft.apply(profile));
      if (mounted) context.go('/groups');
    } on ProfileFailure {
      if (!mounted) return;
      setState(() => _saving = false);
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(AppLocalizations.of(context).needsInternet)));
    }
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final profile = ref.watch(profileProvider).value;
    final draft = (_draft ??= ProfileDraft(null))..fillOnce(profile);
    final name = draft.name.text.trim();
    return AuthPage(
      title: l.profileConfirmTitle,
      subtitle: l.profileConfirmSubtitle,
      leading: Avatar(
        name: name.isEmpty ? l.you : name,
        seed: profile?.id ?? 'me',
        size: AvatarSize.s96,
        ring: true,
      ),
      children: [
        ProfileFields(draft: draft, showCurrency: false),
        const SizedBox(height: AppSpacing.s8),
        PillButton(
          key: const Key('profile-continue'),
          label: l.continueLabel,
          loading: _saving,
          onPressed: () => unawaited(_continue()),
        ),
      ],
    );
  }
}
