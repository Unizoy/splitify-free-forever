# Phase 10 — Multiple payers, IOU, receipt photos (#10, #11, #29)

- Depends on: 09 · Owner setup: 00 · Branch: `phase/10-payers-iou-receipts`
- Read first: `08-feature-specs.md` #10 #11 #29, `04-sync-engine.md` §6.

## Tasks

- [ ] T1 "Paid by" sheet → "Multiple people" with per-payer amounts and live remaining; payers needn't be
      participants; review sentence "Paid by you and Asha".
- [ ] T2 IOU quick action ("Record a loan": I lent / I borrowed) from group and friend pages; Loan chip in lists;
      excluded from totals (verify TC-21-01 still green).
- [ ] T3 Receipt: camera or Android photo picker (no storage permission), compression (JPEG q80, ≤1600 px,
      ≤500 KB), `pending_uploads` queue, uploader after mutation applied, local thumbnail, full-screen viewer with
      zoom, replace/remove, signed URL caching.
- [ ] T4 Storage policy tests for receipts (member-only read/write by folder) — extend `023_storage.test.sql`.

## Tests

TC-10-02, TC-11-02, TC-29-01…03.

## E2E scenario

Airplane mode → add expense with receipt photo → back online → photo uploads → harness B can fetch it via signed URL.
