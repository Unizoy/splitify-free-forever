import 'dart:async';

import 'package:flutter/material.dart';
import 'package:splitify/core/money/currencies.dart';
import 'package:splitify/domain/entities/profile.dart';
import 'package:splitify/domain/rules/profile_rules.dart';
import 'package:splitify/features/account/presentation/upi_scan_screen.dart';
import 'package:splitify/features/currency/presentation/currency_picker_sheet.dart';
import 'package:splitify/features/expenses/presentation/editor/editor_fields.dart' show ToolChip;
import 'package:splitify/l10n/app_localizations.dart';
import 'package:splitify/ui/components/components.dart';
import 'package:splitify/ui/theme/theme.dart';

/// Editable copy of the profile fields with validation (TC-B2-03).
class ProfileDraft {
  ProfileDraft(Profile? p)
    : name = TextEditingController(text: p?.displayName ?? ''),
      upi = TextEditingController(text: p?.upiId ?? ''),
      currency = p?.defaultCurrency ?? 'INR';

  final TextEditingController name;
  final TextEditingController upi;
  String currency;

  bool showErrors = false;

  /// The UPI field lost focus once: its format is checked from then on (inline, D-033).
  bool upiTouched = false;

  /// True once the fields hold a loaded profile.
  bool filled = false;

  /// Fills the fields once, when the profile arrives after the first frame.
  void fillOnce(Profile? p) {
    if (filled || p == null) return;
    filled = true;
    name.text = p.displayName;
    upi.text = p.upiId ?? '';
    currency = p.defaultCurrency;
  }

  String? nameError(AppLocalizations l) =>
      showErrors && !ProfileRules.isValidName(name.text) ? l.nameInvalid : null;

  String? upiError(AppLocalizations l) {
    final v = upi.text.trim();
    return (showErrors || upiTouched) && v.isNotEmpty && !ProfileRules.isValidUpiId(v)
        ? l.upiInvalid
        : null;
  }

  /// True when the fields can be saved; turns on error display.
  bool validate() {
    showErrors = true;
    final v = upi.text.trim();
    return ProfileRules.isValidName(name.text) && (v.isEmpty || ProfileRules.isValidUpiId(v));
  }

  /// Applies the fields to [base].
  Profile apply(Profile base) {
    final v = upi.text.trim();
    return base.copyWith(
      displayName: name.text.trim(),
      upiId: v.isEmpty ? null : v,
      clearUpi: v.isEmpty,
      defaultCurrency: currency,
    );
  }

  void dispose() {
    name.dispose();
    upi.dispose();
  }
}

/// Name, UPI ID (scan icon in the field) and optionally the default currency (D-033). The UPI format is
/// checked when the field loses focus, never clearing what was typed. [collapseUpi] (first-run confirm)
/// hides the UPI field behind "Add a UPI ID (optional)" until tapped or already filled.
class ProfileFields extends StatefulWidget {
  const ProfileFields({
    required this.draft,
    this.showCurrency = true,
    this.collapseUpi = false,
    this.onSubmitted,
    super.key,
  });

  final ProfileDraft draft;
  final bool showCurrency;
  final bool collapseUpi;

  /// Keyboard "done" on the last field.
  final VoidCallback? onSubmitted;

  @override
  State<ProfileFields> createState() => _ProfileFieldsState();
}

class _ProfileFieldsState extends State<ProfileFields> {
  ProfileDraft get d => widget.draft;
  final _upiFocus = FocusNode(debugLabel: 'upi id');
  late bool _upiOpen = !widget.collapseUpi || d.upi.text.trim().isNotEmpty;

  @override
  void initState() {
    super.initState();
    _upiFocus.addListener(() {
      if (!_upiFocus.hasFocus && d.upi.text.trim().isNotEmpty && !d.upiTouched) {
        setState(() => d.upiTouched = true);
      }
    });
  }

  @override
  void dispose() {
    _upiFocus.dispose();
    super.dispose();
  }

  Future<void> _scan() async {
    final l = AppLocalizations.of(context);
    final messenger = ScaffoldMessenger.of(context);
    final raw = await Navigator.of(context)
        .push<String>(MaterialPageRoute(builder: (_) => const QrScanScreen()));
    if (raw == null) return;
    final id = ProfileRules.upiIdFromQr(raw);
    if (id == null) {
      messenger.showSnackBar(SnackBar(content: Text(l.upiQrInvalid)));
      return;
    }
    setState(() {
      d.upi.text = id;
      _upiOpen = true;
    });
  }

  Future<void> _pickCurrency() async {
    final code = await showCurrencyPicker(
      context,
      selected: d.currency,
      title: AppLocalizations.of(context).chooseCurrency,
    );
    if (code != null) setState(() => d.currency = code);
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final c = context.colors;
    final cur = Currencies.of(d.currency);
    // A filled-in field (fillOnce after the first frame) opens the collapsed UPI row.
    if (!_upiOpen && d.upi.text.trim().isNotEmpty) _upiOpen = true;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        UnderlineField(
          key: const Key('profile-name'),
          label: l.nameLabel,
          required: true,
          controller: d.name,
          textCapitalization: TextCapitalization.words,
          textInputAction: _upiOpen ? TextInputAction.next : TextInputAction.done,
          errorText: d.nameError(l),
          onChanged: (_) => setState(() {}),
          onSubmitted: (_) => _upiOpen ? _upiFocus.requestFocus() : widget.onSubmitted?.call(),
        ),
        const SizedBox(height: AppSpacing.s5),
        if (_upiOpen)
          UnderlineField(
            key: const Key('profile-upi'),
            label: l.upiLabel,
            hint: l.upiHint,
            controller: d.upi,
            focusNode: _upiFocus,
            keyboardType: TextInputType.emailAddress,
            textInputAction: TextInputAction.done,
            errorText: d.upiError(l),
            onChanged: (_) => setState(() {}),
            onSubmitted: (_) {
              setState(() => d.upiTouched = d.upi.text.trim().isNotEmpty);
              widget.onSubmitted?.call();
            },
            suffix: AppIconButton(
              key: const Key('profile-scan-upi'),
              tooltip: l.scanUpiQr,
              icon: Icon(AppIcons.qr, color: c.primary),
              onPressed: () => unawaited(_scan()),
            ),
          )
        else
          Align(
            alignment: AlignmentDirectional.centerStart,
            child: ToolChip(
              key: const Key('profile-add-upi'),
              icon: AppIcons.plus,
              label: l.profileAddUpi,
              semanticLabel: l.profileAddUpi,
              onTap: () {
                setState(() => _upiOpen = true);
                WidgetsBinding.instance.addPostFrameCallback((_) => _upiFocus.requestFocus());
              },
            ),
          ),
        if (widget.showCurrency) ...[
          const SizedBox(height: AppSpacing.s6),
          DashedListRow(
            key: const Key('profile-currency'),
            icon: AppIcons.coins,
            label: l.defaultCurrency,
            value: '${cur.code} · ${cur.symbol}',
            valueColor: c.textSecondary,
            showDivider: false,
            onTap: () => unawaited(_pickCurrency()),
          ),
          Padding(
            padding: const EdgeInsetsDirectional.only(start: AppSpacing.s10 + AppSpacing.s2),
            child: Text(
              l.defaultCurrencyHint,
              style: context.text.bodySmall.copyWith(color: c.textSecondary),
            ),
          ),
        ],
      ],
    );
  }
}
