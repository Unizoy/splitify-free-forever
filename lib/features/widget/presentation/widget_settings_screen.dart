import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:splitify/features/widget/application/home_widget_sync.dart';
import 'package:splitify/features/widget/domain/widget_data.dart';
import 'package:splitify/l10n/app_localizations.dart';
import 'package:splitify/ui/components/components.dart';
import 'package:splitify/ui/theme/theme.dart';

/// Home-screen widget (`/account/widget`, X3): how to add it, a live preview of what it shows,
/// and "Hide amounts".
class WidgetSettingsScreen extends ConsumerWidget {
  const WidgetSettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = AppLocalizations.of(context);
    final c = context.colors;
    final hide = ref.watch(widgetHideAmountsProvider);
    final data = ref.watch(homeWidgetDataProvider);
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
              child: Text(l.widgetTitle, style: context.text.sheetTitle),
            ),
          ),
          const SizedBox(height: AppSpacing.s2),
          Text(l.widgetHowTo, style: context.text.body.copyWith(color: c.textSecondary)),
          const SizedBox(height: AppSpacing.s6),
          if (data != null) WidgetPreview(data: data),
          const SizedBox(height: AppSpacing.s6),
          ToggleRow(
            key: const Key('widget-hide-amounts'),
            icon: AppIcons.eyeSlash,
            title: l.widgetHideAmounts,
            subtitle: l.widgetHideAmountsSub,
            value: hide,
            showDivider: false,
            onChanged: (v) => unawaited(ref.read(widgetHideAmountsProvider.notifier).set(hide: v)),
          ),
        ],
      ),
    );
  }
}

/// The 4×2 widget drawn with the app's tokens (the native layout mirrors it).
class WidgetPreview extends StatelessWidget {
  const WidgetPreview({required this.data, super.key});

  final Map<String, Object> data;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final c = context.colors;
    String text(String key) => (data[key] as String?) ?? '';
    final tone = switch (text(WidgetKeys.tone)) {
      'owed' => c.owedText,
      'owe' => c.oweText,
      'mixed' => c.primary,
      _ => c.settled,
    };
    final pending = text(WidgetKeys.pending);
    final updated = int.tryParse(text(WidgetKeys.updatedAt)) ?? 0;
    final footer = pending.isNotEmpty
        ? pending
        : updated > 0
        ? l.widgetUpdated(
            MaterialLocalizations.of(
              context,
            ).formatTimeOfDay(TimeOfDay.fromDateTime(DateTime.fromMillisecondsSinceEpoch(updated))),
          )
        : '';
    return Semantics(
      container: true,
      child: Container(
        key: const Key('widget-preview'),
        padding: const EdgeInsets.fromLTRB(
          AppSpacing.s5,
          AppSpacing.s4,
          AppSpacing.s5,
          AppSpacing.s4,
        ),
        decoration: BoxDecoration(
          color: c.surface,
          borderRadius: AppRadii.all24,
          border: Border.all(color: c.border),
          boxShadow: AppShadows.card(c, dark: context.isDark),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 10,
                  height: 10,
                  decoration: BoxDecoration(color: c.primary, shape: BoxShape.circle),
                ),
                const SizedBox(width: AppSpacing.s2),
                Expanded(
                  child: Text(
                    text(WidgetKeys.brand),
                    style: context.text.bodySmall.w(600).copyWith(color: c.textSecondary),
                  ),
                ),
                Flexible(
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: AppSpacing.s1),
                    decoration: BoxDecoration(
                      color: c.primaryContainer,
                      borderRadius: AppRadii.allPill,
                    ),
                    child: Text(
                      text(WidgetKeys.status),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: context.text.labelCaps.copyWith(color: tone),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.s6),
            Wrap(
              spacing: AppSpacing.s3,
              crossAxisAlignment: WrapCrossAlignment.end,
              children: [
                MediaQuery.withClampedTextScaling(
                  maxScaleFactor: AppText.maxSerifScale,
                  child: Text(
                    text(WidgetKeys.line1),
                    style: context.text.amount.copyWith(color: c.textPrimary),
                  ),
                ),
                if (text(WidgetKeys.line2).isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(bottom: AppSpacing.s1),
                    child: Text(
                      text(WidgetKeys.line2),
                      style: context.text.title.copyWith(color: c.textSecondary),
                    ),
                  ),
              ],
            ),
            if (footer.isNotEmpty) ...[
              const SizedBox(height: AppSpacing.s2),
              Text(
                footer,
                style: context.text.caption.copyWith(
                  color: pending.isNotEmpty ? c.unsynced : c.textSecondary,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
