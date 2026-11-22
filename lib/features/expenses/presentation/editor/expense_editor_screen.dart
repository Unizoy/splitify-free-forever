import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:splitify/core/money/money_formatter.dart';
import 'package:splitify/data/data_providers.dart';
import 'package:splitify/features/currency/presentation/currency_picker_sheet.dart'
    show pickGroupCurrency;
import 'package:splitify/features/expenses/application/expense_draft.dart';
import 'package:splitify/features/expenses/application/expense_editor_controller.dart';
import 'package:splitify/features/expenses/application/split_draft.dart';
import 'package:splitify/features/expenses/presentation/editor/amount_step.dart';
import 'package:splitify/features/expenses/presentation/editor/details_step.dart';
import 'package:splitify/features/expenses/presentation/editor/paid_split_steps.dart';
import 'package:splitify/features/expenses/presentation/editor/review_step.dart';
import 'package:splitify/features/expenses/presentation/expense_copy.dart';
import 'package:splitify/features/expenses/presentation/split_editor.dart';
import 'package:splitify/l10n/app_localizations.dart';
import 'package:splitify/ui/components/components.dart';
import 'package:splitify/ui/theme/theme.dart';
import 'package:splitify/features/groups/application/groups_providers.dart'
    show syncOfflineProvider;

/// The stepper's steps (07 §2 Add expense).
enum EditorStep { amount, paidBy, split, details, review }

/// Add / edit expense (`/expense/new?group=`, `/expense/:id/edit`): StepHeader with Amount · Paid by
/// · Split · Details · Review. "Save" is offered from step 1 once amount and description are set
/// (defaults: you paid, the group's default split), so most expenses take one screen.
class ExpenseEditorScreen extends ConsumerStatefulWidget {
  const ExpenseEditorScreen({this.groupId, this.expenseId, this.initialStep, super.key});

  final String? groupId;
  final String? expenseId;

  /// Opens on this step (tests, deep links); default amount.
  final EditorStep? initialStep;

  @override
  ConsumerState<ExpenseEditorScreen> createState() => _ExpenseEditorScreenState();
}

class _ExpenseEditorScreenState extends ConsumerState<ExpenseEditorScreen> {
  late EditorStep _step = widget.initialStep ?? EditorStep.amount;
  TextEditingController? _description;
  TextEditingController? _notes;
  bool _showErrors = false;
  bool _saving = false;
  bool _saved = false;

  ExpenseEditorArgs get _args => (groupId: widget.groupId, expenseId: widget.expenseId);

  @override
  void dispose() {
    _description?.dispose();
    _notes?.dispose();
    super.dispose();
  }

  void _edit(ExpenseDraft Function(ExpenseDraft d) change) =>
      ref.read(expenseEditorProvider(_args).notifier).edit(change);

  Future<void> _pickCurrency(ExpenseDraft d) async {
    final code = await pickGroupCurrency(context, ref, groupId: d.groupId, selected: d.currency);
    if (code != null && code != d.currency) _edit((x) => x.withCurrency(code));
  }

  void _go(EditorStep step) {
    if (step == _step) return;
    HapticFeedback.selectionClick();
    FocusManager.instance.primaryFocus?.unfocus();
    setState(() => _step = step);
  }

  void _back() {
    if (_step.index > 0) {
      _go(EditorStep.values[_step.index - 1]);
    } else {
      unawaited(_close());
    }
  }

  /// Leaves the editor (after Save or Back on step 1). `pop` ignores the step-back PopScope.
  Future<void> _close() async {
    final navigator = Navigator.of(context);
    if (navigator.canPop()) {
      navigator.pop();
    } else {
      context.go('/groups');
    }
  }

  void _next(ExpenseDraft d) {
    if (_step == EditorStep.amount && !d.fastPathReady) {
      setState(() => _showErrors = true);
      return;
    }
    _go(EditorStep.values[_step.index + 1]);
  }

  /// First step that still has a problem.
  EditorStep? _problemStep(ExpenseDraft d) {
    if (!d.fastPathReady) return EditorStep.amount;
    if (!d.payersOk) return EditorStep.paidBy;
    if (d.splitCheck is! SplitReady) return EditorStep.split;
    if (d.notes.trim().length > maxNotes) return EditorStep.details;
    return null;
  }

  Future<void> _save(ExpenseDraft d) async {
    final problem = _problemStep(d);
    if (problem != null) {
      setState(() => _showErrors = true);
      _go(problem);
      return;
    }
    final messenger = ScaffoldMessenger.of(context);
    final l = AppLocalizations.of(context);
    final pause = context.motion.reduced ? Duration.zero : const Duration(milliseconds: 700);
    setState(() => _saving = true);
    final id = await ref.read(expenseEditorProvider(_args).notifier).save();
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
    await Future<void>.delayed(pause);
    if (!mounted) return;
    messenger
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(l.expSaved), duration: const Duration(seconds: 2)));
    await _close();
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final state = ref.watch(expenseEditorProvider(_args));
    final offline = ref.watch(syncOfflineProvider).value ?? false;
    final draft = state.value;

    if (draft == null) {
      return Scaffold(
        body: Column(
          children: [
            _header(l, groupName: '', offline: offline),
            Expanded(
              child: state.hasError
                  ? Center(
                      child: Padding(
                        padding: const EdgeInsets.all(AppSpacing.screen),
                        child: EmptyState(
                          icon: AppIcons.receipt,
                          title: l.expNotFoundTitle,
                          message: l.expNotFoundBody,
                        ),
                      ),
                    )
                  : Center(
                      child: DotsPulse(color: context.colors.primary, semanticLabel: l.loading),
                    ),
            ),
          ],
        ),
      );
    }

    final description = _description ??= TextEditingController(text: draft.description);
    final notes = _notes ??= TextEditingController(text: draft.notes);
    final now = ref.read(clockProvider).now();
    final today = DateTime(now.year, now.month, now.day);

    final body = switch (_step) {
      EditorStep.amount => AmountStep(
        draft: draft,
        description: description,
        showErrors: _showErrors,
        onAmountText: (t) => _edit((d) => d.copyWith(amountText: t)),
        onDescription: (t) => _edit((d) => d.copyWith(description: t)),
        onPickCurrency: () => unawaited(_pickCurrency(draft)),
      ),
      EditorStep.paidBy => PaidByStep(
        draft: draft,
        onPayer: (id) => _edit((d) => d.withSinglePayer(id)),
        onMultiple: () => _edit((d) => d.withMultiplePayers()),
        onPayerText: (id, t) => _edit((d) => d.withPayerText(id, t)),
      ),
      EditorStep.split => SplitStep(
        draft: draft,
        onSplit: (s) => _edit((d) => d.copyWith(split: s)),
      ),
      EditorStep.details => DetailsStep(
        draft: draft,
        today: today,
        notes: notes,
        onCategory: (k) => _edit((d) => d.copyWith(category: k)),
        onDate: (date) => _edit((d) => d.copyWith(date: date)),
        onNotes: (t) => _edit((d) => d.copyWith(notes: t)),
        onReceipt: (r) => _edit((d) => d.copyWith(receipt: r)),
      ),
      EditorStep.review => ReviewStep(
        draft: draft,
        onEditPayer: () => _go(EditorStep.paidBy),
        onEditSplit: () => _go(EditorStep.split),
      ),
    };

    return PopScope(
      canPop: _saved || _step == EditorStep.amount,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _back();
      },
      child: Scaffold(
        body: Stack(
          children: [
            Column(
              children: [
                _header(l, groupName: draft.groupName, offline: offline, edit: draft.isEdit),
                Expanded(
                  child: AnimatedSwitcher(
                    duration: context.motion.base,
                    switchInCurve: AppMotion.standard,
                    child: KeyedSubtree(key: ValueKey(_step), child: body),
                  ),
                ),
              ],
            ),
            if (_saved) const Positioned.fill(child: _SavedCheck()),
          ],
        ),
        bottomNavigationBar: _saved ? null : _bar(l, draft),
      ),
    );
  }

  Widget _header(
    AppLocalizations l, {
    required String groupName,
    required bool offline,
    bool edit = false,
  }) {
    final status = offline
        ? l.expOfflinePill(groupName)
        : (edit ? l.expEditPill(groupName) : groupName);
    return StepHeader(
      steps: [
        StepItem(label: l.stepAmount, icon: AppIcons.stepAmount),
        StepItem(label: l.stepPaidBy, icon: AppIcons.stepPaidBy),
        StepItem(label: l.stepSplit, icon: AppIcons.stepSplit),
        StepItem(label: l.stepDetails, icon: AppIcons.stepDetails),
        StepItem(label: l.stepReview, icon: AppIcons.stepReview),
      ],
      current: _step.index,
      statusText: status,
      statusIcon: offline ? AppIcons.unsynced : AppIcons.receipt,
      onBack: _back,
      onHome: () => context.go('/groups'),
      onStepTap: (i) => _go(EditorStep.values[i]),
    );
  }

  Widget _bar(AppLocalizations l, ExpenseDraft d) {
    final review = _step == EditorStep.review;
    final total = d.total;
    final Widget? summary = switch (_step) {
      EditorStep.paidBy when d.multiplePayers => SplitFooterLine(
        key: const Key('payers-footer'),
        footer: payersFooter(l, d),
      ),
      EditorStep.split => SplitFooterLine(
        footer: splitFooter(
          l,
          d.split,
          total,
          d.currency,
          nameOf: (id) => d.member(id)?.name ?? '',
        ),
      ),
      EditorStep.review when total != null => Text(
        l.expReviewSummary(
          MoneyFormatter.list.format(total, d.currency),
          d.split.participants.length,
        ),
        textAlign: TextAlign.center,
      ),
      _ => null,
    };
    return StickyActionBar(
      summary: summary,
      primary: PillButton(
        key: const Key('expense-save'),
        label: review ? l.expSaveExpense : l.expSave,
        variant: PillVariant.money,
        loading: _saving,
        onPressed: d.canSave ? () => unawaited(_save(d)) : null,
      ),
      secondary: review
          ? null
          : PillButton(
              key: const Key('expense-next'),
              label: l.expNext,
              variant: PillVariant.ghost,
              onPressed: () => _next(d),
            ),
    );
  }
}

/// Celebration-lite after saving: a lime check that pops in, then the editor closes.
class _SavedCheck extends StatelessWidget {
  const _SavedCheck();

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final l = AppLocalizations.of(context);
    return ColoredBox(
      color: c.bg,
      child: Center(
        child: TweenAnimationBuilder<double>(
          tween: Tween(begin: 0.4, end: 1),
          duration: context.motion.slow,
          curve: context.motion.spring,
          builder: (context, t, child) => Transform.scale(scale: t, child: child),
          child: Semantics(
            liveRegion: true,
            label: l.expSaved,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 96,
                  height: 96,
                  decoration: BoxDecoration(color: c.ink, shape: BoxShape.circle),
                  child: Icon(AppIcons.check, size: 48, color: c.owedAccent),
                ),
                const SizedBox(height: AppSpacing.s4),
                ExcludeSemantics(child: Text(l.expSaved, style: context.text.title)),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
