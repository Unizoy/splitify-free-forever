# Phase 17 — Charts and CSV export (#33, #22)

- Depends on: 14 · Owner setup: 00 · Branch: `phase/17-charts-export`
- Read first: `08-feature-specs.md` #33 #22, `06-design-system.md` (DotMatrixCard, chart colours = category colours).

## Tasks

- [ ] T1 Aggregations (pure Dart, tested): spending by category and by month for a group or "Me" (my shares), main
      currency via saved conversions, unconverted excluded with count; IOUs and payments excluded.
- [ ] T2 Insights screen: SegmentedPill Group/Me, group picker, donut + month bars (`fl_chart`), legend chips,
      empty/insufficient-data states; DotMatrixCard on Account and group Totals tab link here.
- [ ] T3 CSV export (spec in #22): writer with BOM, escaping, payments rows, per-currency totals rows, deleted flag;
      save via share sheet; golden test of a fixture CSV text.

## Tests

TC-33-01…02, TC-22-01.
