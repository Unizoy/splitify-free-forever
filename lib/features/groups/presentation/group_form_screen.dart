import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:splitify/core/money/currencies.dart';
import 'package:splitify/core/utils/uuid.dart';
import 'package:splitify/domain/rules/group_rules.dart';
import 'package:splitify/features/account/presentation/profile_form.dart';
import 'package:splitify/features/auth/application/auth_providers.dart';
import 'package:splitify/features/groups/application/groups_providers.dart';
import 'package:splitify/features/groups/presentation/group_visuals.dart';
import 'package:splitify/l10n/app_localizations.dart';
import 'package:splitify/ui/components/components.dart';
import 'package:splitify/ui/theme/theme.dart';

/// Create (`/groups/new`) or edit (`/groups/:id/edit`) a group (08 #1, 602): name, type, main currency and
/// the generated cover preview. Works offline (outbox). Photo covers come with the uploader (S-073).
class GroupFormScreen extends ConsumerStatefulWidget {
  const GroupFormScreen({this.groupId, super.key});

  /// Null = new group.
  final String? groupId;

  @override
  ConsumerState<GroupFormScreen> createState() => _GroupFormScreenState();
}

class _GroupFormScreenState extends ConsumerState<GroupFormScreen> {
  final _name = TextEditingController();
  late final String _seed = widget.groupId ?? newId();
  String _type = 'trip';
  String? _currency;
  bool _filled = false;
  bool _showErrors = false;
  bool _saving = false;

  bool get _isEdit => widget.groupId != null;

  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  String? _nameError(AppLocalizations l) {
    if (!_showErrors) return null;
    return switch (GroupRules.name(_name.text)) {
      GroupFieldError.required => l.groupNameRequired,
      GroupFieldError.tooLong => l.groupNameTooLong,
      null => null,
    };
  }

  Future<void> _save(String currency) async {
    final l = AppLocalizations.of(context);
    final router = GoRouter.of(context);
    final messenger = ScaffoldMessenger.of(context);
    if (GroupRules.name(_name.text) != null) {
      setState(() => _showErrors = true);
      return;
    }
    setState(() => _saving = true);
    final actions = ref.read(groupActionsProvider);
    try {
      if (_isEdit) {
        await actions.update(widget.groupId!, name: _name.text, type: _type, currency: currency);
        messenger.showSnackBar(SnackBar(content: Text(l.groupSaved)));
        if (mounted) router.pop();
      } else {
        final profile = ref.read(profileProvider).value;
        await ref
            .read(groupActionsProvider)
            .create(
              id: _seed,
              name: _name.text,
              type: _type,
              currency: currency,
              ownerName: profile?.displayName ?? '',
            );
        if (mounted) unawaited(router.pushReplacement('/groups/$_seed'));
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final c = context.colors;
    final group = _isEdit ? ref.watch(groupProvider(widget.groupId!)).value : null;
    if (!_filled && group != null) {
      _filled = true;
      _name.text = group.name;
      _type = GroupRules.type(group.type);
      _currency = group.mainCurrency;
    }
    final currency =
        _currency ?? ref.watch(profileProvider).value?.defaultCurrency ?? Currencies.inr.code;
    final cur = Currencies.of(currency);
    final name = _name.text.trim();
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
          AppSpacing.s10,
        ),
        children: [
          PageTitle(title: _isEdit ? l.editGroup : l.newGroup, subtitle: l.groupFormSubtitle),
          const SizedBox(height: AppSpacing.s6),
          CoverBanner(
            seed: _seed,
            type: _type,
            name: name.isEmpty ? l.newGroup : name,
            caption: groupTypeLabel(l, _type),
          ),
          const SizedBox(height: AppSpacing.s2),
          Text(
            l.coverHint,
            textAlign: TextAlign.center,
            style: context.text.bodySmall.copyWith(color: c.textSecondary),
          ),
          const SizedBox(height: AppSpacing.s6),
          UnderlineField(
            key: const Key('group-name'),
            label: l.groupNameLabel,
            hint: l.groupNameHint,
            required: true,
            controller: _name,
            textInputAction: TextInputAction.done,
            errorText: _nameError(l),
            onChanged: (_) => setState(() {}),
          ),
          const SizedBox(height: AppSpacing.s8),
          SectionLabel(l.groupTypeLabel),
          const SizedBox(height: AppSpacing.s3),
          _TypePicker(selected: _type, onChanged: (t) => setState(() => _type = t)),
          const SizedBox(height: AppSpacing.s8),
          DashedListRow(
            key: const Key('group-currency'),
            icon: AppIcons.coins,
            label: l.mainCurrency,
            value: '${cur.code} · ${cur.symbol}',
            valueColor: c.textSecondary,
            showDivider: false,
            onTap: () => unawaited(_pickCurrency(currency)),
          ),
          Padding(
            padding: const EdgeInsetsDirectional.only(start: AppSpacing.s10 + AppSpacing.s2),
            child: Text(
              l.mainCurrencyHint,
              style: context.text.bodySmall.copyWith(color: c.textSecondary),
            ),
          ),
          const SizedBox(height: AppSpacing.s10),
          PillButton(
            key: const Key('group-save'),
            label: _isEdit ? l.saveLabel : l.createGroupButton,
            loading: _saving,
            onPressed: () => unawaited(_save(currency)),
          ),
        ],
      ),
    );
  }

  Future<void> _pickCurrency(String current) async {
    final code = await showCurrencyPicker(context, selected: current);
    if (code != null && mounted) setState(() => _currency = code);
  }
}

class _TypePicker extends StatelessWidget {
  const _TypePicker({required this.selected, required this.onChanged});

  final String selected;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final c = context.colors;
    Widget tile(String type) => Expanded(
      child: OptionTile(
        key: Key('group-type-$type'),
        label: groupTypeLabel(l, type),
        selected: selected == type,
        leading: Icon(GroupCoverCard.iconFor(coverFamilyFor(type)), size: 18, color: c.primary),
        onTap: () => onChanged(type),
      ),
    );
    return Column(
      children: [
        Row(
          children: [
            tile('trip'),
            const SizedBox(width: AppSpacing.s3),
            tile('home'),
          ],
        ),
        const SizedBox(height: AppSpacing.s3),
        Row(
          children: [
            tile('couple'),
            const SizedBox(width: AppSpacing.s3),
            tile('other'),
          ],
        ),
      ],
    );
  }
}
