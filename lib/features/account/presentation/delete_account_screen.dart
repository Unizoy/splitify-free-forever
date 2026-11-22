import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:splitify/data/repositories/auth_repository.dart';
import 'package:splitify/features/auth/application/auth_providers.dart';
import 'package:splitify/l10n/app_localizations.dart';
import 'package:splitify/ui/components/components.dart';
import 'package:splitify/ui/theme/theme.dart';

/// Delete account (`/account/delete`, B1): explains what happens, asks the
/// person to type DELETE, then calls the `delete-account` Edge Function.
class DeleteAccountScreen extends ConsumerStatefulWidget {
  const DeleteAccountScreen({super.key});

  @override
  ConsumerState<DeleteAccountScreen> createState() => _DeleteAccountScreenState();
}

class _DeleteAccountScreenState extends ConsumerState<DeleteAccountScreen> {
  final _confirm = TextEditingController();
  bool _busy = false;
  bool _failed = false;

  /// The last try failed for lack of network (rule 9: "Needs internet").
  bool _offline = false;

  @override
  void dispose() {
    _confirm.dispose();
    super.dispose();
  }

  Future<void> _delete() async {
    setState(() {
      _busy = true;
      _failed = false;
      _offline = false;
    });
    try {
      await ref.read(accountActionsProvider).deleteAccount();
    } on AuthFailure catch (e) {
      if (mounted) {
        setState(() {
          _failed = true;
          _offline = e.code == AuthFailureCode.offline;
        });
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final c = context.colors;
    final armed = _confirm.text.trim() == l.deleteWord;
    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          tooltip: l.back,
          icon: const Icon(AppIcons.back),
          onPressed: () => Navigator.of(context).maybePop(),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(
          AppSpacing.screen,
          AppSpacing.s2,
          AppSpacing.screen,
          AppSpacing.s8,
        ),
        children: [
          Semantics(
            header: true,
            child: MediaQuery.withClampedTextScaling(
              maxScaleFactor: AppText.maxSerifScale,
              child: Text(l.deleteAccountTitle, style: context.text.sheetTitle),
            ),
          ),
          const SizedBox(height: AppSpacing.s6),
          DecoratedBox(
            decoration: BoxDecoration(color: c.surfaceMuted, borderRadius: AppRadii.all16),
            child: Padding(
              padding: const EdgeInsets.all(AppSpacing.s5),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(AppIcons.warning, color: c.oweText, size: 28),
                  const SizedBox(height: AppSpacing.s3),
                  Text(l.deleteAccountBody, style: context.text.body),
                  const SizedBox(height: AppSpacing.s3),
                  Text(
                    l.deleteAccountWarning,
                    style: context.text.bodySmall.copyWith(color: c.textSecondary),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: AppSpacing.s8),
          UnderlineField(
            key: const Key('delete-confirm'),
            label: l.typeDeleteLabel,
            hint: l.deleteWord,
            controller: _confirm,
            onChanged: (_) => setState(() {}),
            errorText: _failed ? (_offline ? l.needsInternet : l.deleteAccountFailed) : null,
          ),
          const SizedBox(height: AppSpacing.s8),
          PillButton(
            key: const Key('delete-account'),
            label: l.deleteAccountButton,
            icon: AppIcons.trash,
            variant: PillVariant.danger,
            loading: _busy,
            onPressed: armed ? () => unawaited(_delete()) : null,
          ),
        ],
      ),
    );
  }
}
