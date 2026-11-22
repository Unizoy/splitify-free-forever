import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:splitify/core/money/currencies.dart';
import 'package:splitify/core/money/money_formatter.dart';
import 'package:splitify/data/data_providers.dart';
import 'package:splitify/features/expenses/application/expense_draft.dart';
import 'package:splitify/features/expenses/application/keypad_input.dart';
import 'package:splitify/features/expenses/application/loan_draft.dart';
import 'package:splitify/features/expenses/application/loan_editor_controller.dart';
import 'package:splitify/features/expenses/presentation/editor/amount_step.dart';
import 'package:splitify/features/expenses/presentation/editor/details_step.dart';
import 'package:splitify/features/expenses/presentation/editor/step_body.dart';
import 'package:splitify/features/expenses/presentation/expense_copy.dart';
import 'package:splitify/features/groups/presentation/invite_sheet.dart';
import 'package:splitify/l10n/app_localizations.dart';
import 'package:splitify/ui/components/components.dart';
import 'package:splitify/ui/theme/theme.dart';

/// "Record a loan" (`/loan/new?group=&with=`, `/loan/:id/edit`, #11): I lent / I borrowed, the other
/// person, amount (keypad), what for and date; one screen, saved offline as an IOU.
class LoanScreen extends ConsumerStatefulWidget {
  const LoanScreen({this.groupId, this.expenseId, this.withMember, super.key});

  final String? groupId;
  final String? expenseId;
  final String? withMember;

  @override
  ConsumerState<LoanScreen> createState() => _LoanScreenState();
}

class _LoanScreenState extends ConsumerState<LoanScreen> {
  TextEditingController? _note;

  /// Keypad shown (starts open when there is no amount yet). Tapping the amount opens it; picking a
  /// person or "Done" closes it so the rest of the form has room (large text especially).
  bool? _keypad;
  bool _showErrors = false;
  bool _saving = false;

  LoanEditorArgs get _args =>
      (groupId: widget.groupId, expenseId: widget.expenseId, withMember: widget.withMember);

  @override
  void dispose() {
    _note?.dispose();
    super.dispose();
  }

  void _edit(LoanDraft Function(LoanDraft d) change) =>
      ref.read(loanEditorProvider(_args).notifier).edit(change);

  void _close() {
    final navigator = Navigator.of(context);
    if (navigator.canPop()) {
      navigator.pop();
    } else {
      context.go('/groups');
    }
  }

  Future<void> _save(LoanDraft d) async {
    if (!d.canSave) {
      setState(() => _showErrors = true);
      return;
    }
    final l = AppLocalizations.of(context);
    final messenger = ScaffoldMessenger.of(context);
    setState(() => _saving = true);
    final id = await ref
        .read(loanEditorProvider(_args).notifier)
        .save(defaultDescription: l.loanDefaultDescription);
    if (!mounted) return;
    setState(() => _saving = false);
    if (id == null) return;
    unawaited(HapticFeedback.mediumImpact());
    messenger
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(l.loanSaved), duration: const Duration(seconds: 2)));
    _close();
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final state = ref.watch(loanEditorProvider(_args));
    final d = state.value;
    final title = widget.expenseId == null ? l.loanTitle : l.loanEditTitle;
    if (d == null) {
      return Scaffold(
        appBar: _bar(l),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(AppSpacing.screen),
            child: state.hasError
                ? EmptyState(
                    icon: AppIcons.loan,
                    title: state.error is LoanNotPossible ? title : l.expNotFoundTitle,
                    message: state.error is LoanNotPossible ? l.loanNoOthers : l.expNotFoundBody,
                  )
                : DotsPulse(color: context.colors.primary, semanticLabel: l.loading),
          ),
        ),
      );
    }
    final note = _note ??= TextEditingController(text: d.note);
    final keyboardOpen = MediaQuery.viewInsetsOf(context).bottom > 0;
    final keypad = (_keypad ??= d.amountText.isEmpty) && !keyboardOpen && d.others.isNotEmpty;
    final now = ref.read(clockProvider).now();
    return Scaffold(
      appBar: _bar(l),
      body: Column(
        children: [
          Expanded(
            child: d.others.isEmpty
                ? Center(
                    child: Padding(
                      padding: const EdgeInsets.all(AppSpacing.screen),
                      child: EmptyState(
                        icon: AppIcons.loan,
                        title: title,
                        message: l.loanNoOthers,
                        actions: [
                          PillButton(
                            key: const Key('loan-invite'),
                            label: l.invitePeople,
                            icon: AppIcons.userPlus,
                            variant: PillVariant.outline,
                            expand: false,
                            onPressed: () => unawaited(showInviteSheet(context, d.groupId)),
                          ),
                        ],
                      ),
                    ),
                  )
                : _Form(
                    draft: d,
                    title: title,
                    note: note,
                    showErrors: _showErrors,
                    today: DateTime(now.year, now.month, now.day),
                    keypadOpen: keypad,
                    onEdit: _edit,
                    onAmountTap: () {
                      FocusManager.instance.primaryFocus?.unfocus();
                      setState(() => _keypad = true);
                    },
                    onPicked: () => setState(() => _keypad = false),
                  ),
          ),
          if (keypad) ...[
            _KeypadBar(onDone: () => setState(() => _keypad = false)),
            AmountKeypad(
              onKey: (k) {
                FocusManager.instance.primaryFocus?.unfocus();
                _edit(
                  (x) => x.copyWith(
                    amountText: KeypadInput.apply(
                      x.amountText,
                      k,
                      Currencies.exponentOf(x.currency),
                    ),
                  ),
                );
              },
              onClear: () => _edit((x) => x.copyWith(amountText: '')),
              allowDot: Currencies.exponentOf(d.currency) > 0,
            ),
          ],
        ],
      ),
      bottomNavigationBar: d.others.isEmpty
          ? null
          : StickyActionBar(
              summary: _Result(draft: d),
              primary: PillButton(
                key: const Key('loan-save'),
                label: l.loanSave,
                variant: PillVariant.money,
                loading: _saving,
                onPressed: () => unawaited(_save(d)),
              ),
            ),
    );
  }

  PreferredSizeWidget _bar(AppLocalizations l) => AppBar(
    leading: IconButton(tooltip: l.back, icon: const Icon(AppIcons.back), onPressed: _close),
  );
}

class _Form extends StatelessWidget {
  const _Form({
    required this.draft,
    required this.title,
    required this.note,
    required this.showErrors,
    required this.today,
    required this.keypadOpen,
    required this.onEdit,
    required this.onAmountTap,
    required this.onPicked,
  });

  final LoanDraft draft;
  final String title;
  final TextEditingController note;
  final bool showErrors;
  final DateTime today;
  final bool keypadOpen;
  final void Function(LoanDraft Function(LoanDraft d) change) onEdit;
  final VoidCallback onAmountTap;
  final VoidCallback onPicked;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final c = context.colors;
    final d = draft;
    final self = d.member(d.selfId);
    final selfName = self?.name ?? '';
    final text = d.amountText;
    final error = l.amountError(d.amount, d.currency);
    final symbol = Currencies.of(d.currency).symbol;
    final lent = d.direction == LoanDirection.lent;
    final large = MediaQuery.textScalerOf(context).scale(1) > 1.4;
    return ListView(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.screen,
        AppSpacing.s2,
        AppSpacing.screen,
        AppSpacing.s6,
      ),
      children: [
        Semantics(
          header: true,
          child: MediaQuery.withClampedTextScaling(
            maxScaleFactor: AppText.maxSerifScale,
            child: Text(title, textAlign: TextAlign.center, style: context.text.sheetTitle),
          ),
        ),
        // With the keypad up at large text sizes the amount needs the room.
        if (!(large && keypadOpen)) ...[
          const SizedBox(height: AppSpacing.s2),
          Text(
            l.loanSubtitle,
            textAlign: TextAlign.center,
            style: context.text.bodySmall.copyWith(color: c.textSecondary),
          ),
        ],
        const SizedBox(height: AppSpacing.s5),
        // Two short labels: clamped so they never break inside a word at large text sizes.
        MediaQuery.withClampedTextScaling(
          maxScaleFactor: 1.3,
          child: SegmentedPill<LoanDirection>(
            key: const Key('loan-direction'),
            value: d.direction,
            onChanged: (v) => onEdit((x) => x.copyWith(direction: v)),
            items: [
              SegmentedPillItem(
                value: LoanDirection.lent,
                label: d.selfIsMe ? l.loanILent : l.loanNameLent(selfName),
                icon: large ? null : AppIcons.loan,
              ),
              SegmentedPillItem(
                value: LoanDirection.borrowed,
                label: d.selfIsMe ? l.loanIBorrowed : l.loanNameBorrowed(selfName),
                icon: large ? null : AppIcons.wallet,
              ),
            ],
          ),
        ),
        const SizedBox(height: AppSpacing.s5),
        Semantics(
          button: !keypadOpen,
          label: l.loanAmountLabel,
          value: d.total == null ? text : MoneyFormatter.detail.format(d.total!, d.currency),
          liveRegion: true,
          excludeSemantics: true,
          onTap: keypadOpen ? null : onAmountTap,
          child: InkWell(
            key: const Key('loan-amount-tap'),
            onTap: keypadOpen ? null : onAmountTap,
            borderRadius: AppRadii.all16,
            child: ConstrainedBox(
              constraints: const BoxConstraints(minHeight: AppSpacing.minTouch),
              child: Column(
                children: [
                  FittedBox(
                    fit: BoxFit.scaleDown,
                    child: Text(
                      '$symbol${text.isEmpty ? '0' : KeypadInput.display(text)}',
                      key: const Key('loan-amount'),
                      maxLines: 1,
                      textAlign: TextAlign.center,
                      style: context.text.amountHero.copyWith(
                        color: text.isEmpty ? c.textTertiary : c.textPrimary,
                      ),
                    ),
                  ),
                  AnimatedContainer(
                    duration: context.motion.fast,
                    width: keypadOpen ? 56 : 32,
                    height: 3,
                    decoration: BoxDecoration(
                      color: keypadOpen ? c.primary : c.divider,
                      borderRadius: AppRadii.allPill,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
        SizedBox(
          height: MediaQuery.textScalerOf(context).scale(22),
          child: Center(
            child: error != null || (showErrors && d.total == null)
                ? Text(
                    error ?? l.expErrNeedAmount,
                    key: const Key('loan-amount-error'),
                    style: context.text.bodySmall.w(600).copyWith(color: c.oweText),
                  )
                : null,
          ),
        ),
        const SizedBox(height: AppSpacing.s4),
        SectionLabel(lent ? l.loanToWhom : l.loanFromWhom),
        _People(
          draft: d,
          onPick: (id) {
            onEdit((x) => x.copyWith(personId: id));
            onPicked();
          },
        ),
        if (showErrors && d.personId == null) ...[
          const SizedBox(height: AppSpacing.s2),
          Text(
            l.loanPickPerson,
            key: const Key('loan-person-error'),
            style: context.text.bodySmall.w(600).copyWith(color: c.oweText),
          ),
        ],
        const SizedBox(height: AppSpacing.s6),
        UnderlineField(
          key: const Key('loan-note'),
          label: l.loanWhatFor,
          hint: l.loanWhatForHint,
          controller: note,
          textInputAction: TextInputAction.done,
          errorText: d.noteTooLong ? l.expDescriptionTooLong : null,
          inputFormatters: [LengthLimitingTextInputFormatter(maxDescription + 20)],
          onChanged: (t) => onEdit((x) => x.copyWith(note: t)),
        ),
        const SizedBox(height: AppSpacing.s6),
        SectionLabel(l.expDateLabel),
        DateChips(
          value: d.date,
          today: today,
          onChanged: (v) => onEdit((x) => x.copyWith(date: v)),
        ),
        const SizedBox(height: AppSpacing.s5),
        Row(
          children: [
            Icon(AppIcons.info, size: 16, color: c.textTertiary),
            const SizedBox(width: AppSpacing.s2),
            Expanded(
              child: Text(
                l.loanNotSpending,
                style: context.text.caption.copyWith(color: c.textSecondary),
              ),
            ),
          ],
        ),
      ],
    );
  }
}

/// The other side: avatar choices that wrap (selected = indigo ring + filled container).
class _People extends StatelessWidget {
  const _People({required this.draft, required this.onPick});

  final LoanDraft draft;
  final ValueChanged<String> onPick;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        for (final m in draft.others) ...[
          OptionTile(
            key: Key('loan-person-${m.id}'),
            label: m.name,
            selected: draft.personId == m.id,
            leading: Avatar(name: m.name, seed: m.id, size: AvatarSize.s32),
            onTap: () => onPick(m.id),
          ),
          const SizedBox(height: AppSpacing.s3),
        ],
      ],
    );
  }
}

/// "You lent Asha ₹500" over "Asha will owe you ₹500" (TC-11-02), or a hint while incomplete.
class _Result extends StatelessWidget {
  const _Result({required this.draft});

  final LoanDraft draft;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final c = context.colors;
    final d = draft;
    final person = d.member(d.personId);
    final total = d.total;
    if (person == null || total == null) {
      return Text(
        person == null ? l.loanPickPerson : l.expErrNeedAmount,
        key: const Key('loan-sentence'),
        textAlign: TextAlign.center,
      );
    }
    final amount = MoneyFormatter.list.format(total, d.currency);
    final self = d.member(d.selfId)?.name ?? '';
    final lent = d.direction == LoanDirection.lent;
    final String sentence;
    final String result;
    if (d.selfIsMe) {
      sentence = lent
          ? l.loanSentenceLent(person.name, amount)
          : l.loanSentenceBorrowed(person.name, amount);
      result = lent
          ? l.loanResultLent(person.name, amount)
          : l.loanResultBorrowed(person.name, amount);
    } else {
      sentence = lent
          ? l.loanCaption(self, person.name, amount)
          : l.loanCaption(person.name, self, amount);
      result = '';
    }
    return Semantics(
      liveRegion: true,
      child: Column(
        children: [
          Text(
            sentence,
            key: const Key('loan-sentence'),
            textAlign: TextAlign.center,
            style: context.text.body.w(700).copyWith(color: c.textPrimary),
          ),
          if (result.isNotEmpty)
            Text(
              result,
              key: const Key('loan-result'),
              textAlign: TextAlign.center,
              style: context.text.bodySmall.w(600).copyWith(color: lent ? c.owedText : c.oweText),
            ),
        ],
      ),
    );
  }
}

/// Slim bar over the keypad with "Done" (hides it so the person list and details have room).
class _KeypadBar extends StatelessWidget {
  const _KeypadBar({required this.onDone});

  final VoidCallback onDone;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final c = context.colors;
    return ColoredBox(
      color: c.bgSubtle,
      child: Align(
        alignment: AlignmentDirectional.centerEnd,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(AppSpacing.s3, AppSpacing.s1, AppSpacing.s3, 0),
          child: TextButton(
            key: const Key('loan-keypad-done'),
            onPressed: onDone,
            child: Text(
              l.loanAmountDone,
              // The keypad itself is clamped to 1.4; keep its bar in proportion.
              textScaler: MediaQuery.textScalerOf(context).clamp(maxScaleFactor: 1.4),
              style: context.text.body.w(700).copyWith(color: c.primary),
            ),
          ),
        ),
      ),
    );
  }
}
