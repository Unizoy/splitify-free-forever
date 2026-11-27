import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:splitify/core/time/clock.dart';
import 'package:splitify/data/data_providers.dart' show clockProvider;
import 'package:splitify/domain/rules/expense_categories.dart';
import 'package:splitify/features/currency/presentation/currency_picker_sheet.dart'
    show CurrencyChip, pickGroupCurrency;
import 'package:splitify/features/expenses/application/category_providers.dart';
import 'package:splitify/features/expenses/application/expense_draft.dart';
import 'package:splitify/features/expenses/application/expense_editor_controller.dart';
import 'package:splitify/features/expenses/presentation/editor/editor_fields.dart';
import 'package:splitify/features/expenses/presentation/editor/paid_split_sheet.dart';
import 'package:splitify/features/expenses/presentation/editor/pickers.dart';
import 'package:splitify/features/expenses/presentation/editor/receipt_field.dart';
import 'package:splitify/features/expenses/presentation/expense_copy.dart';
import 'package:splitify/features/groups/application/groups_providers.dart'
    show syncOfflineProvider;
import 'package:splitify/features/groups/presentation/group_visuals.dart' show confirmAction;
import 'package:splitify/features/recurring/application/recurring_providers.dart'
    show intervalLabel;
import 'package:splitify/features/recurring/presentation/repeat_picker.dart';
import 'package:splitify/l10n/app_localizations.dart';
import 'package:splitify/ui/components/components.dart';
import 'package:splitify/ui/theme/theme.dart';

/// How long typing must pause before the category follows the description (D-028).
const suggestDelay = Duration(milliseconds: 250);

/// Add / edit expense (`/expense/new?group=`, `/expense/:id/edit`, `/recurring/:id/edit`) on one screen
/// like Splitwise (D-032): "With you and" + the group, category + description, currency + amount on the
/// phone's own keyboards, one "Paid by · split" pill that opens a sheet, and a bottom toolbar (date, notes,
/// receipt, repeat) with Save that stays above the keyboard. Defaults: you paid, the group's default split.
class ExpenseEditorScreen extends ConsumerStatefulWidget {
  const ExpenseEditorScreen({this.groupId, this.expenseId, this.templateId, super.key});

  final String? groupId;
  final String? expenseId;

  /// "Edit future copies" of this repeating-expense template (#12) instead of one expense.
  final String? templateId;

  @override
  ConsumerState<ExpenseEditorScreen> createState() => _ExpenseEditorScreenState();
}

class _ExpenseEditorScreenState extends ConsumerState<ExpenseEditorScreen> {
  TextEditingController? _description;
  TextEditingController? _amount;
  TextEditingController? _notes;
  final _descriptionFocus = FocusNode(debugLabel: 'expense description');
  final _amountFocus = FocusNode(debugLabel: 'expense amount');
  Timer? _suggest;

  /// Show "required" problems (after a Save attempt).
  bool _showErrors = false;
  bool _saving = false;
  bool _saved = false;

  /// The user changed something: leaving asks first.
  bool _dirty = false;

  ExpenseEditorArgs get _args => (groupId: widget.groupId, expenseId: widget.expenseId);

  AsyncNotifierProvider<ExpenseEditorController, ExpenseDraft> get _provider =>
      widget.templateId != null
      ? templateEditorProvider(widget.templateId!)
      : expenseEditorProvider(_args);

  ExpenseDraft? get _draft => ref.read(_provider).value;

  @override
  void dispose() {
    _suggest?.cancel();
    _description?.dispose();
    _amount?.dispose();
    _notes?.dispose();
    _descriptionFocus.dispose();
    _amountFocus.dispose();
    super.dispose();
  }

  /// A change the user made (marks the editor as changed).
  void _edit(ExpenseDraft Function(ExpenseDraft d) change) {
    _dirty = true;
    ref.read(_provider.notifier).edit(change);
  }

  /// Auto-category (D-028): the category follows the description ~250 ms after typing stops.
  void _described(String text) {
    _edit((d) => d.copyWith(description: text));
    _suggest?.cancel();
    _suggest = Timer(suggestDelay, _flushSuggestion);
  }

  /// Applies a pending suggestion now (opening the category picker, saving).
  void _flushSuggestion() {
    _suggest?.cancel();
    _suggest = null;
    if (mounted) ref.read(_provider.notifier).suggestCategory();
  }

  /// The sheets read and change the same draft as the screen (also when a test scopes the editor).
  Widget _scoped(Widget child) =>
      UncontrolledProviderScope(container: ProviderScope.containerOf(context), child: child);

  /// A sheet that shows the live draft.
  Widget _live(Widget Function(BuildContext context, ExpenseDraft d) build) => _scoped(
    Consumer(
      builder: (context, ref, _) {
        final d = ref.watch(_provider).value;
        return d == null ? const SizedBox.shrink() : build(context, d);
      },
    ),
  );

  Future<void> _pickCurrency(ExpenseDraft d) async {
    final code = await pickGroupCurrency(context, ref, groupId: d.groupId, selected: d.currency);
    if (code != null && code != d.currency) _edit((x) => x.withCurrency(code));
  }

  Future<void> _pickCategory() async {
    if (_suggest != null) _flushSuggestion();
    final l = AppLocalizations.of(context);
    await showAppSheet<void>(
      context,
      title: l.expCategoryLabel,
      builder: (sheet) => _live(
        (context, d) => Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            CategoryPicker(
              value: d.category,
              onChanged: (key) {
                final sub =
                    ExpenseCategories.parentOf(key) == ExpenseCategories.parentOf(d.category);
                _edit((x) => x.pickCategory(key));
                // A sub category finishes the choice; a new parent first shows its subs.
                if (sub) Navigator.of(sheet).pop();
              },
            ),
            const SizedBox(height: AppSpacing.s6),
            PillButton(
              key: const Key('category-done'),
              label: l.loanAmountDone,
              onPressed: () => Navigator.of(sheet).pop(),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _openPaidSplit() async {
    final l = AppLocalizations.of(context);
    await showAppSheet<void>(
      context,
      title: l.expPaidSplitTitle,
      builder: (sheet) => _live(
        (context, d) => Padding(
          padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
          child: PaidSplitPanel(
            draft: d,
            onPayer: (id) => _edit((x) => x.withSinglePayer(id)),
            onMultiple: () => _edit((x) => x.withMultiplePayers()),
            onPayerText: (id, t) => _edit((x) => x.withPayerText(id, t)),
            onSplit: (s) => _edit((x) => x.copyWith(split: s)),
            onDone: () => Navigator.of(sheet).pop(),
          ),
        ),
      ),
    );
  }

  Future<void> _pickDate(ExpenseDraft d) async {
    final l = AppLocalizations.of(context);
    final today = ref.read(clockProvider).today();
    final yesterday = DateTime(today.year, today.month, today.day - 1);
    final picked = await showAppSheet<DateTime>(
      context,
      title: l.expPickDate,
      builder: (sheet) => Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Wrap(
            spacing: AppSpacing.s2,
            runSpacing: AppSpacing.s2,
            children: [
              IconChip(
                key: const Key('date-today'),
                label: l.expToday,
                selected: DateUtils.isSameDay(d.date, today),
                onTap: () => Navigator.of(sheet).pop(today),
              ),
              IconChip(
                key: const Key('date-yesterday'),
                label: l.expYesterday,
                selected: DateUtils.isSameDay(d.date, yesterday),
                onTap: () => Navigator.of(sheet).pop(yesterday),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.s5),
          MonthCalendar(
            initial: d.date,
            today: today,
            onPicked: (day) => Navigator.of(sheet).pop(day),
          ),
        ],
      ),
    );
    if (picked != null && !DateUtils.isSameDay(picked, d.date)) {
      _edit((x) => x.copyWith(date: picked));
    }
  }

  Future<void> _openNotes() async {
    final l = AppLocalizations.of(context);
    final notes = _notes;
    if (notes == null) return;
    await showAppSheet<void>(
      context,
      title: l.expNotesLabel,
      builder: (sheet) => Padding(
        padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(sheet).bottom),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            ValueListenableBuilder<TextEditingValue>(
              valueListenable: notes,
              builder: (context, value, _) => UnderlineField(
                key: const Key('expense-notes'),
                label: l.expNotesLabel,
                hint: l.expNotesHint,
                controller: notes,
                autofocus: true,
                maxLines: null,
                keyboardType: TextInputType.multiline,
                errorText: value.text.trim().length > maxNotes ? l.expNotesTooLong : null,
                inputFormatters: [LengthLimitingTextInputFormatter(maxNotes + 50)],
                onChanged: (t) => _edit((d) => d.copyWith(notes: t)),
              ),
            ),
            const SizedBox(height: AppSpacing.s6),
            PillButton(
              key: const Key('notes-done'),
              label: l.loanAmountDone,
              onPressed: () => Navigator.of(sheet).pop(),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _openReceipt() async {
    final l = AppLocalizations.of(context);
    await showAppSheet<void>(
      context,
      title: l.receiptLabel,
      builder: (sheet) => _live(
        (context, d) => Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            ReceiptField(
              receipt: d.receipt,
              onChanged: (r) => _edit((x) => x.copyWith(receipt: r)),
            ),
            const SizedBox(height: AppSpacing.s6),
            PillButton(
              key: const Key('receipt-done'),
              label: l.loanAmountDone,
              onPressed: () => Navigator.of(sheet).pop(),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _openRepeat() async {
    final l = AppLocalizations.of(context);
    final today = ref.read(clockProvider).today();
    await showAppSheet<void>(
      context,
      title: l.repeatLabel,
      builder: (sheet) => _live(
        (context, d) => Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            RepeatPicker(
              value: d.repeat,
              start: d.date,
              today: today,
              allowNever: !d.isTemplate,
              onChanged: (r) => _edit((x) => x.withRepeat(r)),
            ),
            const SizedBox(height: AppSpacing.s6),
            PillButton(
              key: const Key('repeat-done'),
              label: l.loanAmountDone,
              onPressed: () => Navigator.of(sheet).pop(),
            ),
          ],
        ),
      ),
    );
  }

  /// Leaving with changes asks first (an app sheet, never a system alert).
  Future<void> _back() async {
    final d = _draft;
    if (_dirty && !_saved && d != null) {
      final l = AppLocalizations.of(context);
      final changing = d.isEdit || d.isTemplate;
      FocusManager.instance.primaryFocus?.unfocus();
      final discard = await confirmAction(
        context,
        title: changing ? l.expDiscardEditTitle : l.expDiscardTitle,
        body: changing ? l.expDiscardEditBody : l.expDiscardBody,
        confirm: l.discardLabel,
        icon: AppIcons.trash,
      );
      if (!discard || !mounted) return;
    }
    _close();
  }

  /// Leaves the editor. `pop` ignores the PopScope that asks before discarding.
  void _close() {
    final navigator = Navigator.of(context);
    if (navigator.canPop()) {
      navigator.pop();
    } else {
      context.go('/groups');
    }
  }

  /// Points at what stops Save: focuses the field, or opens the sheet that fixes it.
  void _point(EditorProblem problem) {
    switch (problem) {
      case EditorProblem.description:
        _descriptionFocus.requestFocus();
      case EditorProblem.amount:
        _amountFocus.requestFocus();
      case EditorProblem.paidSplit:
        unawaited(_openPaidSplit());
      case EditorProblem.notes:
        unawaited(_openNotes());
      case EditorProblem.repeat:
        unawaited(_openRepeat());
    }
  }

  Future<void> _save() async {
    if (_saving || _saved) return;
    if (_suggest != null) _flushSuggestion();
    final d = _draft;
    if (d == null) return;
    final problem = d.firstProblem;
    if (problem != null) {
      setState(() => _showErrors = true);
      unawaited(HapticFeedback.lightImpact());
      _point(problem);
      return;
    }
    FocusManager.instance.primaryFocus?.unfocus();
    final messenger = ScaffoldMessenger.of(context);
    final l = AppLocalizations.of(context);
    final pause = context.motion.reduced ? Duration.zero : const Duration(milliseconds: 700);
    setState(() => _saving = true);
    final id = await ref.read(_provider.notifier).save();
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
      ..showSnackBar(
        SnackBar(
          content: Text(d.isTemplate ? l.recurringSaved : l.expSaved),
          duration: const Duration(seconds: 2),
        ),
      );
    _close();
  }

  String _title(AppLocalizations l) {
    if (widget.templateId != null) return l.recurringEditFuture;
    return widget.expenseId != null ? l.expEdit : l.expAddTitle;
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final state = ref.watch(_provider);
    // Load the keyword list while the editor opens, so the first typed word can use it.
    ref.watch(categorySuggesterProvider);
    final offline = ref.watch(syncOfflineProvider).value ?? false;
    final draft = state.value;

    if (draft == null) {
      return Scaffold(
        appBar: AppBar(
          leading: AppIconButton(
            tooltip: l.back,
            icon: const Icon(AppIcons.back),
            onPressed: () => Navigator.of(context).maybePop(),
          ),
          title: Text(_title(l)),
        ),
        body: Center(
          child: state.hasError
              ? Padding(
                  padding: const EdgeInsets.all(AppSpacing.screen),
                  child: EmptyState(
                    icon: AppIcons.receipt,
                    title: widget.templateId == null
                        ? l.expNotFoundTitle
                        : l.recurringNotFoundTitle,
                    message: widget.templateId == null
                        ? l.expNotFoundBody
                        : l.recurringNotFoundBody,
                  ),
                )
              : DotsPulse(color: context.colors.primary, semanticLabel: l.loading),
        ),
      );
    }

    final description = _description ??= TextEditingController(text: draft.description);
    final amount = _amount ??= TextEditingController(text: draft.amountText);
    _notes ??= TextEditingController(text: draft.notes);
    final c = context.colors;
    final descriptionProblem = draft.descriptionProblem;
    final descriptionError =
        descriptionProblem == DescriptionProblem.tooLong ||
            (_showErrors && descriptionProblem != null)
        ? l.descriptionError(descriptionProblem)
        : null;
    final amountError =
        l.amountError(draft.amount, draft.currency) ??
        (_showErrors && draft.amountMissing ? l.expAmountMissing : null);

    return PopScope(
      canPop: _saved || !_dirty,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) unawaited(_back());
      },
      child: Scaffold(
        appBar: AppBar(
          leading: AppIconButton(
            tooltip: l.back,
            icon: const Icon(AppIcons.back),
            onPressed: () => unawaited(_back()),
          ),
          title: Text(_title(l)),
          actions: [
            Padding(
              padding: const EdgeInsetsDirectional.only(end: AppSpacing.s2),
              child: TextButton(
                key: const Key('expense-save-top'),
                onPressed: draft.canSave && !_saving && !_saved ? () => unawaited(_save()) : null,
                child: Text(
                  l.expSave,
                  // In step with the app bar title at large text sizes.
                  textScaler: MediaQuery.textScalerOf(context).clamp(maxScaleFactor: 1.3),
                  style: context.text.body
                      .w(700)
                      .copyWith(color: draft.canSave ? c.primary : c.textTertiary),
                ),
              ),
            ),
          ],
        ),
        body: Stack(
          children: [
            Column(
              children: [
                Expanded(
                  child: ListView(
                    key: const Key('expense-form'),
                    keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
                    padding: const EdgeInsets.fromLTRB(
                      AppSpacing.screen,
                      AppSpacing.s3,
                      AppSpacing.screen,
                      AppSpacing.s6,
                    ),
                    children: [
                      WithRow(draft: draft, offline: offline),
                      const SizedBox(height: AppSpacing.s6),
                      // Icon column (category, currency) sized to the wider of the two, so both fields
                      // start at the same edge at any text size.
                      Table(
                        columnWidths: const {0: IntrinsicColumnWidth(), 1: FlexColumnWidth()},
                        children: [
                          TableRow(
                            children: [
                              Padding(
                                padding: const EdgeInsetsDirectional.only(end: AppSpacing.s3),
                                child: Center(
                                  child: CategoryButton(
                                    category: draft.category,
                                    auto: draft.categoryIsAuto,
                                    onTap: () => unawaited(_pickCategory()),
                                  ),
                                ),
                              ),
                              UnderlineField(
                                key: const Key('expense-description'),
                                label: l.expDescriptionLabel,
                                hint: l.expDescriptionHint,
                                required: true,
                                controller: description,
                                focusNode: _descriptionFocus,
                                autofocus:
                                    !draft.isEdit && !draft.isTemplate && draft.description.isEmpty,
                                errorText: descriptionError,
                                textInputAction: TextInputAction.next,
                                textCapitalization: TextCapitalization.sentences,
                                inputFormatters: [
                                  LengthLimitingTextInputFormatter(maxDescription + 20),
                                ],
                                onChanged: _described,
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
                                    key: const Key('expense-currency'),
                                    code: draft.currency,
                                    onTap: () => unawaited(_pickCurrency(draft)),
                                  ),
                                ),
                              ),
                              Padding(
                                padding: const EdgeInsets.only(top: AppSpacing.s5),
                                child: AmountField(
                                  key: const Key('expense-amount'),
                                  controller: amount,
                                  focusNode: _amountFocus,
                                  currency: draft.currency,
                                  errorText: amountError,
                                  onChanged: (t) => _edit((d) => d.copyWith(amountText: t)),
                                  onSubmitted: (_) => _amountFocus.unfocus(),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                      const SizedBox(height: AppSpacing.s6),
                      PaidSplitPill(
                        summary: paidSplitSummary(l, draft),
                        footer: splitSheetFooter(l, draft),
                        onTap: () => unawaited(_openPaidSplit()),
                      ),
                      if (draft.isTemplate) ...[
                        const SizedBox(height: AppSpacing.s5),
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Icon(AppIcons.info, size: 18, color: c.textSecondary),
                            const SizedBox(width: AppSpacing.s2),
                            Expanded(
                              child: Text(
                                l.recurringEditNote,
                                key: const Key('template-note'),
                                style: context.text.bodySmall.copyWith(color: c.textSecondary),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ],
                  ),
                ),
                // In the body (not bottomNavigationBar): the Scaffold lifts it above the keyboard.
                if (!_saved)
                  StickyActionBar(
                    summary: _Toolbar(
                      draft: draft,
                      today: ref.read(clockProvider).today(),
                      onDate: () => unawaited(_pickDate(draft)),
                      onNotes: () => unawaited(_openNotes()),
                      onReceipt: () => unawaited(_openReceipt()),
                      onRepeat: () => unawaited(_openRepeat()),
                    ),
                    primary: PillButton(
                      key: const Key('expense-save'),
                      label: draft.isTemplate ? l.expSave : l.expSaveExpense,
                      variant: PillVariant.money,
                      loading: _saving,
                      onPressed: () => unawaited(_save()),
                    ),
                  ),
              ],
            ),
            if (_saved) const Positioned.fill(child: _SavedCheck()),
          ],
        ),
      ),
    );
  }
}

/// The bottom toolbar: date (calendar), notes, receipt photo and repeat as compact chips; a chip is
/// filled once it holds something. Editing future copies shows the first date read-only and no receipt.
class _Toolbar extends StatelessWidget {
  const _Toolbar({
    required this.draft,
    required this.today,
    required this.onDate,
    required this.onNotes,
    required this.onReceipt,
    required this.onRepeat,
  });

  final ExpenseDraft draft;

  /// The phone's local calendar day (India: IST).
  final DateTime today;
  final VoidCallback onDate;
  final VoidCallback onNotes;
  final VoidCallback onReceipt;
  final VoidCallback onRepeat;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final d = draft;
    final yesterday = DateTime(today.year, today.month, today.day - 1);
    final String dateText;
    if (DateUtils.isSameDay(d.date, today)) {
      dateText = l.expToday;
    } else if (DateUtils.isSameDay(d.date, yesterday)) {
      dateText = l.expYesterday;
    } else {
      dateText = d.date.year == today.year ? dayMonth(context, d.date) : shortDate(context, d.date);
    }
    final hasNotes = d.notes.trim().isNotEmpty;
    final repeat = d.repeat.interval;
    final repeatText = repeat == null ? l.repeatLabel : intervalLabel(l, repeat);
    return SingleChildScrollView(
      key: const Key('expense-toolbar'),
      scrollDirection: Axis.horizontal,
      child: Row(
        children: [
          if (d.isTemplate)
            ToolChip(
              key: const Key('template-start'),
              icon: AppIcons.calendar,
              label: l.expToolFirstDate(dateText),
              semanticLabel: l.expToolFirstDate(shortDate(context, d.date)),
            )
          else
            ToolChip(
              key: const Key('expense-date'),
              icon: AppIcons.calendar,
              label: dateText,
              semanticLabel: l.expToolDate(shortDate(context, d.date)),
              active: !DateUtils.isSameDay(d.date, today),
              onTap: onDate,
            ),
          const SizedBox(width: AppSpacing.s2),
          ToolChip(
            key: const Key('expense-notes-chip'),
            icon: AppIcons.notes,
            label: l.expNotesLabel,
            semanticLabel: hasNotes ? l.expToolNotesAdded : l.expNotesLabel,
            active: hasNotes,
            onTap: onNotes,
          ),
          if (!d.isTemplate) ...[
            const SizedBox(width: AppSpacing.s2),
            ToolChip(
              key: const Key('expense-receipt-chip'),
              icon: AppIcons.camera,
              label: l.receiptLabel,
              semanticLabel: d.receipt.hasPhoto ? l.expToolReceiptAdded : l.receiptAdd,
              active: d.receipt.hasPhoto,
              onTap: onReceipt,
            ),
          ],
          if (d.canRepeat || d.isTemplate) ...[
            const SizedBox(width: AppSpacing.s2),
            ToolChip(
              key: const Key('expense-repeat-chip'),
              icon: AppIcons.repeat,
              label: repeatText,
              semanticLabel: repeatText,
              active: repeat != null,
              onTap: onRepeat,
            ),
          ],
        ],
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
