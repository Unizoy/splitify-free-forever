import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:splitify/data/data_providers.dart';
import 'package:splitify/data/local/app_database.dart';
import 'package:splitify/features/groups/presentation/group_visuals.dart' show showGroupMessage;
import 'package:splitify/l10n/app_localizations.dart';
import 'package:splitify/ui/components/components.dart';
import 'package:splitify/ui/theme/theme.dart';

/// Turns simplify debts on or off for a group (#17, rule 12): an offline group edit through the outbox;
/// the server logs it as `settings_changed` (0014).
Future<void> setSimplifyDebts(WidgetRef ref, String groupId, {required bool on}) =>
    ref.read(groupsRepositoryProvider).update(groupId, {'simplify_debts': on});

/// Group settings row "Simplify debts" with its help text and a switch (off by default, 08 #17).
class SimplifySettingRow extends ConsumerWidget {
  const SimplifySettingRow({required this.group, super.key});

  final LocalGroup group;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = AppLocalizations.of(context);
    final c = context.colors;
    final on = group.simplifyDebts;
    void toggle(bool value) {
      unawaited(
        setSimplifyDebts(ref, group.id, on: value).then((_) {
          if (context.mounted) {
            showGroupMessage(context, value ? l.simplifyOnDone : l.simplifyOffDone);
          }
        }),
      );
    }

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        const DashedDivider(),
        MergeSemantics(
          child: InkWell(
            key: const Key('settings-simplify'),
            onTap: () => toggle(!on),
            child: ConstrainedBox(
              constraints: const BoxConstraints(minHeight: 72),
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: AppSpacing.s3),
                child: Row(
                  children: [
                    Icon(AppIcons.swap, size: 24, color: c.textPrimary),
                    const SizedBox(width: AppSpacing.s4),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(l.simplifyTitle, style: context.text.body.w(600)),
                          const SizedBox(height: 2),
                          Text(
                            l.simplifyHelp,
                            style: context.text.bodySmall.copyWith(color: c.textSecondary),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: AppSpacing.s3),
                    Switch(
                      key: const Key('settings-simplify-switch'),
                      value: on,
                      onChanged: toggle,
                      activeThumbColor: c.onPrimaryFill,
                      activeTrackColor: c.primary,
                      inactiveThumbColor: c.textSecondary,
                      inactiveTrackColor: c.surfaceMuted,
                      trackOutlineColor: WidgetStatePropertyAll(c.border),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}
