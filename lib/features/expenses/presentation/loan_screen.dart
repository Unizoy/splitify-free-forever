import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:splitify/core/money/money_formatter.dart';
import 'package:splitify/core/time/clock.dart';
import 'package:splitify/data/data_providers.dart';
import 'package:splitify/features/currency/presentation/currency_picker_sheet.dart'
    show CurrencyChip, pickGroupCurrency;
import 'package:splitify/features/expenses/application/expense_draft.dart';
import 'package:splitify/features/expenses/application/loan_draft.dart';
import 'package:splitify/features/expenses/application/loan_editor_controller.dart';
import 'package:splitify/features/expenses/presentation/editor/editor_fields.dart'
    show AmountField, ToolChip;
import 'package:splitify/features/expenses/presentation/expense_copy.dart';
import 'package:splitify/features/groups/application/groups_providers.dart'
    show syncOfflineProvider;
import 'package:splitify/features/groups/presentation/group_visuals.dart' show confirmAction;
import 'package:splitify/features/groups/presentation/invite_sheet.dart';
import 'package:splitify/features/payments/presentation/money_form.dart';
import 'package:splitify/l10n/app_localizations.dart';
import 'package:splitify/ui/components/components.dart';
import 'package:splitify/ui/theme/theme.dart';

/// "Record a loan" (`/loan/new?group=&with=`, `/loan/:id/edit`, #11) on one screen like add expense
/// (D-033): "In [group]", what for (optional), the amount on the phone's number keyboard with its currency
/// chip, a "You lent Asha" pill that opens who lent whom, and a toolbar (date, notes) with Save above the
/// keyboard. Saved offline as an IOU.
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
  TextEditingController? _amount;
  TextEditingController? _notes;
  final _amountFocus = FocusNode(debugLabel: 'loan amount');
  final _noteFocus = FocusNode(debugLabel: 'loan what for');
  bool _showErrors = false;
  bool _saving = false;
  bool _saved = false;

  /// The person changed something: leaving asks first.
  bool _dirty = false;

  LoanEditorArgs get _args =>
      (groupId: widget.groupId, expenseId: widget.expenseId, withMember: widget.withMember);

  LoanDraft? get _draft => ref.read(loanEditorProvider(_args)).value;

  @override
  void dispose() {
    _note?.dispose();
    _amount?.dispose();
    _notes?.dispose();
    _amountFocus.dispose();
    _noteFocus.dispose();
    super.dispose();
  }

  void _edit(LoanDraft Function(LoanDraft d) change) {
    _dirty = true;
    ref.read(loanEditorProvider(_args).notifier).edit(change);
  }

  void _close() {
    final navigator = Navigator.of(context);
    if (navigator.canPop()) {
      navigator.pop();
    } else {
      context.go('/groups');
    }
  }

  /// Leaving with changes asks first (an app sheet, never a system alert).
  Future<void> _back() async {
    final d = _draft;
    if (_dirty && !_saved && d != null) {
      final l = AppLocalizations.of(context);
      FocusManager.instance.primaryFocus?.unfocus();
      final discard = await confirmAction(
        context,
        title: d.isEdit ? l.expDiscardEditTitle : l.loanDiscardTitle,
        body: d.isEdit ? l.loanDiscardEditBody : l.loanDiscardBody,
        confirm: l.discardLabel,
        icon: AppIcons.trash,
      );
      if (!discard || !mounted) return;
    }
    _close();
  }

  Future<void> _pickCurrency(LoanDraft d) async {
    final code = await pickGroupCurrency(context, ref, groupId: d.groupId, selected: d.currency);
    if (code != null && code != d.currency) _edit((x) => x.copyWith(currency: code));
  }

  Future<void> _pickDate(LoanDraft d) async {
    final picked = await pickDay(context, value: d.date, today: ref.read(clockProvider).today());
    if (picked != null && !DateUtils.isSameDay(picked, d.date)) {
      _edit((x) => x.copyWith(date: picked));
    }
  }

  Future<void> _openNotes() async {
    final notes = _notes;
    if (notes == null) return;
    final l = AppLocalizations.of(context);
    await showTextSheet(
      context,
      title: l.expNotesLabel,
      fieldKey: const Key('loan-notes'),
      label: l.expNotesLabel,
      hint: l.expNotesHint,
      controller: notes,
      max: maxNotes,
      tooLong: l.expNotesTooLong,
      onChanged: (t) => _edit((x) => x.copyWith(notes: t)),
    );
  }

  /// Who lent whom: I lent / I borrowed and the other person, straight into the draft; Done closes.
  Future<void> _openWho() async {
    final l = AppLocalizations.of(context);
    final container = ProviderScope.containerOf(context, listen: false);
    FocusManager.instance.primaryFocus?.unfocus();
    await showAppSheet<void>(
      context,
      title: l.loanWhoTitle,
      builder: (sheet) => UncontrolledProviderScope(
        container: container,
        child: Consumer(
          builder: (context, ref, _) {
            final d = ref.watch(loanEditorProvider(_args)).value;
            if (d == null) return const SizedBox.shrink();
            return LoanWhoPanel(
              draft: d,
              showErrors: _showErrors,
              onDirection: (v) => _edit((x) => x.copyWith(direction: v)),
              onPerson: (id) {
                _edit((x) => x.copyWith(personId: id));
                Navigator.of(sheet).pop();
              },
              onDone: () => Navigator.of(sheet).pop(),
            );
          },
        ),
      ),
    );
  }

  /// Points at what stops Save: the amount field, the who sheet, the what-for field or the notes.
  void _point(LoanDraft d) {
    if (d.total == null) {
      _amountFocus.requestFocus();
    } else if (d.personId == null) {
      unawaited(_openWho());
    } else if (d.noteTooLong) {
      _noteFocus.requestFocus();
    } else if (d.notesTooLong) {
      unawaited(_openNotes());
    }
  }

  Future<void> _save() async {
    if (_saving || _saved) return;
    final d = _draft;
    if (d == null) return;
    if (!d.canSave) {
      setState(() => _showErrors = true);
      unawaited(HapticFeedback.lightImpact());
      _point(d);
      return;
    }
    final l = AppLocalizations.of(context);
    final messenger = ScaffoldMessenger.of(context);
    FocusManager.instance.primaryFocus?.unfocus();
    setState(() => _saving = true);
    final id = await ref
        .read(loanEditorProvider(_args).notifier)
        .save(defaultDescription: l.loanDefaultDescription);
    if (!mounted) return;
    if (id == null) {
      setState(() => _saving = false);
      return;
    }
    unawaited(HapticFeedback.mediumImpact());
    setState(() {
      _saving = false;
      _saved = true;
    });
    messenger
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(l.loanSaved), duration: const Duration(seconds: 2)));
    _close();
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final state = ref.watch(loanEditorProvider(_args));
    final offline = ref.watch(syncOfflineProvider).value ?? false;
    final d = state.value;
    final title = widget.expenseId == null ? l.loanTitle : l.loanEditTitle;
    if (d == null) {
      return Scaffold(
        appBar: _bar(l, title, () => Navigator.of(context).maybePop()),
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
    if (d.others.isEmpty) {
      return Scaffold(
        appBar: _bar(l, title, _close),
        body: Center(
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
        ),
      );
    }
    if (_amount == null && !d.isEdit && d.amountText.isEmpty) {
      // A new loan opens with the amount focused (number keyboard up), fewest taps.
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _amountFocus.requestFocus();
      });
    }
    final note = _note ??= TextEditingController(text: d.note);
    final amount = _amount ??= TextEditingController(text: d.amountText);
    _notes ??= TextEditingController(text: d.notes);
    final c = context.colors;
    final amountError =
        l.amountError(d.amount, d.currency) ??
        (_showErrors && d.total == null ? l.expAmountMissing : null);
    final today = ref.read(clockProvider).today();
    return PopScope(
      canPop: _saved || !_dirty,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) unawaited(_back());
      },
      child: Scaffold(
        appBar: _bar(l, title, () => unawaited(_back())),
        body: Column(
          children: [
            Expanded(
              child: ListView(
                key: const Key('loan-form'),
                keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
                padding: const EdgeInsets.fromLTRB(
                  AppSpacing.screen,
                  AppSpacing.s3,
                  AppSpacing.screen,
                  AppSpacing.s6,
                ),
                children: [
                  GroupLine(name: d.groupName, type: d.groupType, offline: offline),
                  const SizedBox(height: AppSpacing.s6),
                  Table(
                    columnWidths: const {0: IntrinsicColumnWidth(), 1: FlexColumnWidth()},
                    children: [
                      TableRow(
                        children: [
                          Padding(
                            padding: const EdgeInsetsDirectional.only(end: AppSpacing.s3),
                            child: Center(
                              child: ExcludeSemantics(
                                child: TintedIcon(icon: AppIcons.loan, color: c.primary, size: 56),
                              ),
                            ),
                          ),
                          UnderlineField(
                            key: const Key('loan-note'),
                            label: l.loanWhatFor,
                            hint: l.loanWhatForHint,
                            controller: note,
                            focusNode: _noteFocus,
                            textInputAction: TextInputAction.next,
                            textCapitalization: TextCapitalization.sentences,
                            errorText: d.noteTooLong ? l.expDescriptionTooLong : null,
                            inputFormatters: [
                              LengthLimitingTextInputFormatter(maxDescription + 20),
                            ],
                            onChanged: (t) => _edit((x) => x.copyWith(note: t)),
                            onSubmitted: (_) => _amountFocus.requestFocus(),
                          ),
                        ],
                      ),
                      TableRow(
                        children: [
                          Padding(
                            padding: const EdgeInsetsDirectional.only(
                              top: AppSpacing.s5 + AppSpacing.s4,
                              end: AppSpacing.s3,
                            ),
                            child: Center(
                              child: CurrencyChip(
                                key: const Key('loan-currency'),
                                code: d.currency,
                                onTap: () => unawaited(_pickCurrency(d)),
                              ),
                            ),
                          ),
                          Padding(
                            padding: const EdgeInsets.only(top: AppSpacing.s5),
                            child: AmountField(
                              key: const Key('loan-amount'),
                              controller: amount,
                              focusNode: _amountFocus,
                              currency: d.currency,
                              errorText: amountError,
                              onChanged: (t) => _edit((x) => x.copyWith(amountText: t)),
                              onSubmitted: (_) => _amountFocus.unfocus(),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                  const SizedBox(height: AppSpacing.s6),
                  _WhoPill(draft: d, showErrors: _showErrors, onTap: () => unawaited(_openWho())),
                  const SizedBox(height: AppSpacing.s4),
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
              ),
            ),
            // In the body (not bottomNavigationBar): the Scaffold lifts it above the keyboard.
            if (!_saved)
              StickyActionBar(
                summary: SingleChildScrollView(
                  key: const Key('loan-toolbar'),
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: [
                      ToolChip(
                        key: const Key('loan-date'),
                        icon: AppIcons.calendar,
                        label: dayLabel(context, d.date, today),
                        semanticLabel: l.expToolDate(shortDate(context, d.date)),
                        active: !DateUtils.isSameDay(d.date, today),
                        onTap: () => unawaited(_pickDate(d)),
                      ),
                      const SizedBox(width: AppSpacing.s2),
                      ToolChip(
                        key: const Key('loan-notes-chip'),
                        icon: AppIcons.notes,
                        label: l.expNotesLabel,
                        semanticLabel: d.notes.trim().isNotEmpty
                            ? l.expToolNotesAdded
                            : l.expNotesLabel,
                        active: d.notes.trim().isNotEmpty,
                        onTap: () => unawaited(_openNotes()),
                      ),
                    ],
                  ),
                ),
                primary: PillButton(
                  key: const Key('loan-save'),
                  label: l.loanSave,
                  variant: PillVariant.money,
                  loading: _saving,
                  onPressed: () => unawaited(_save()),
                ),
              ),
          ],
        ),
      ),
    );
  }

  PreferredSizeWidget _bar(AppLocalizations l, String title, VoidCallback onBack) => AppBar(
    leading: AppIconButton(tooltip: l.back, icon: const Icon(AppIcons.back), onPressed: onBack),
    title: Text(title),
  );
}

/// "You lent Asha" over "Asha will owe you ₹500" (TC-11-02); red "Choose a person" after a Save attempt
/// without one. Tapping opens who lent whom.
class _WhoPill extends StatelessWidget {
  const _WhoPill({required this.draft, required this.showErrors, required this.onTap});

  final LoanDraft draft;
  final bool showErrors;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final d = draft;
    final person = d.member(d.personId);
    final self = d.member(d.selfId)?.name ?? '';
    final lent = d.direction == LoanDirection.lent;
    final total = d.total;
    final amount = total == null ? null : MoneyFormatter.list.format(total, d.currency);
    final String title;
    final String? sub;
    if (person == null) {
      title = d.selfIsMe
          ? (lent ? l.loanILent : l.loanIBorrowed)
          : (lent ? l.loanNameLent(self) : l.loanNameBorrowed(self));
      sub = l.loanPickPerson;
    } else if (d.selfIsMe) {
      title = lent ? l.loanPillLent(person.name) : l.loanPillBorrowed(person.name);
      sub = amount == null
          ? l.loanPillNoAmount
          : (lent
                ? l.loanResultLent(person.name, amount)
                : l.loanResultBorrowed(person.name, amount));
    } else {
      title = lent ? l.loanPillOthers(self, person.name) : l.loanPillOthers(person.name, self);
      sub = amount == null
          ? l.loanPillNoAmount
          : (lent
                ? l.loanResultOthers(person.name, self, amount)
                : l.loanResultOthers(self, person.name, amount));
    }
    return FormPill(
      key: const Key('loan-who'),
      icon: lent ? AppIcons.loan : AppIcons.wallet,
      title: title,
      subtitle: sub,
      error: showErrors && person == null,
      hint: l.loanWhoHint,
      onTap: onTap,
    );
  }
}

/// The who-lent-whom sheet: I lent / I borrowed, then the other person (picking one closes the sheet).
class LoanWhoPanel extends StatelessWidget {
  const LoanWhoPanel({
    required this.draft,
    required this.showErrors,
    required this.onDirection,
    required this.onPerson,
    required this.onDone,
    super.key,
  });

  final LoanDraft draft;
  final bool showErrors;
  final ValueChanged<LoanDirection> onDirection;
  final ValueChanged<String> onPerson;
  final VoidCallback onDone;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final c = context.colors;
    final d = draft;
    final selfName = d.member(d.selfId)?.name ?? '';
    final lent = d.direction == LoanDirection.lent;
    final large = MediaQuery.textScalerOf(context).scale(1) > 1.4;
    return Column(
      key: const Key('loan-who-sheet'),
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Two short labels: clamped so they never break inside a word at large text sizes.
        MediaQuery.withClampedTextScaling(
          maxScaleFactor: 1.3,
          child: SegmentedPill<LoanDirection>(
            key: const Key('loan-direction'),
            value: d.direction,
            onChanged: onDirection,
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
        Text(
          lent ? l.loanToWhom : l.loanFromWhom,
          style: context.text.body.w(600).copyWith(color: c.textSecondary),
        ),
        const SizedBox(height: AppSpacing.s3),
        for (final m in d.others) ...[
          OptionTile(
            key: Key('loan-person-${m.id}'),
            label: m.name,
            selected: d.personId == m.id,
            leading: Avatar(name: m.name, seed: m.id, size: AvatarSize.s32),
            onTap: () => onPerson(m.id),
          ),
          const SizedBox(height: AppSpacing.s3),
        ],
        if (showErrors && d.personId == null) ...[
          Text(
            l.loanPickPerson,
            key: const Key('loan-person-error'),
            style: context.text.bodySmall.w(600).copyWith(color: c.oweText),
          ),
          const SizedBox(height: AppSpacing.s3),
        ],
        const SizedBox(height: AppSpacing.s3),
        PillButton(key: const Key('loan-who-done'), label: l.loanAmountDone, onPressed: onDone),
      ],
    );
  }
}
