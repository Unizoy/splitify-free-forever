# Phase 17 — Charts and CSV export (#33, #22)

- Depends on: 14 · Owner setup: 00 · Branch: `phase/17-charts-export`
- Read first: `08-feature-specs.md` #33 #22, `06-design-system.md` (DotMatrixCard, chart colours = category colours).

## Tasks

- [x] T1 Aggregations (pure Dart, tested): spending by category and by month for a group or "Me" (my shares), main
      currency via saved conversions, unconverted excluded with count; IOUs and payments excluded.
- [x] T2 Insights screen: SegmentedPill Group/Me, group picker, donut + month bars (`fl_chart`), legend chips,
      empty/insufficient-data states; DotMatrixCard on Account and group Totals tab link here.
- [x] T3 CSV export (spec in #22): writer with BOM, escaping, payments rows, per-currency totals rows, deleted flag;
      save via share sheet; golden test of a fixture CSV text.

## Tests

TC-33-01…02, TC-22-01.

Pre-built (branch prep/insights-export): T1 logic in `lib/features/insights/domain/aggregations.dart`
(`spendingPerCurrency`, `spendingInMainCurrency` with unconverted count, `SpendingSummary.lastMonths` for the
12 bars; Group/Me scopes) and T3 writer in `lib/features/export/domain/csv_export.dart` (`buildGroupCsv` /
`buildGroupCsvBytes`: BOM, RFC 4180 escaping, CSV-injection guard, payment rows, per-currency totals, deleted
flag, `MoneyFormatter.plain`). Tests TC-33-01 and TC-22-01 (fixture CSV text) in `test/features/insights/domain`
and `test/features/export/domain`, 100 % line coverage of both files. Decisions S-090…S-092. Still open: mapping
Drift rows to the inputs, T2 UI, share sheet, TC-33-02; TC-22-02 round trip needs the X1 importer to accept this
format (it expects Splitwise's `Date,Description,Category,Cost,Currency`).
