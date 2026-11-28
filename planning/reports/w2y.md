# D-034 wave 2, package W2-Y — attachments, summaries and reliability

- Date: 2026-11-28 · Branch: `feat/w2-attachments-reliability` · Base: `origin/feat/simple-add-expense` @ e3ad96b
- Decisions S-430..S-439 · Migrations **0029_expense_attachments**, **0030_summary_batch_push** (DEV only)
- Plan: `planning/research/11-splitwise-gap-plan.md` (Wave 2: P-7, F14, batch-settle push) + crash reporting

## Summary

- **Several photos and PDFs per expense (P-7):** the receipt sheet in the editor is a grid (photos and PDFs,
  × to take one out, "Add" up to 10 files); Camera, Photos (several at once, Android photo picker) or a PDF (system
  file picker), no permissions. The expense page shows one photo wide as before, several files as a grid with
  "Receipts and files". A tap opens the photo at full resolution (the thumbnail shows first, the big file is
  downloaded once) or the PDF page by page (Android's PdfRenderer, "Open in another app"). Removing a file has
  Undo; files follow the expense's delete / restore. Offline first: rows, outbox and the upload queue in one
  transaction; files go up after their row (thumbnail first). Private bucket `expense-files`: members of the group
  read, only registered paths can be written, nobody deletes. In the backup export too.
- **Monthly summary (F14):** a card at the top of Activity in the first 7 days of a month ("Your November · You
  spent ₹x across n groups · You're owed ₹y", per currency, tap → Insights, × hides it until next month), and an
  opt-in monthly push (Notifications → Monthly summary, default off) sent by pg_cron on the 1st at 09:00 IST.
- **One push per batch settle-up:** the friend still gets a bell row per group, but one push for the batch
  ("Asha settled up with you in 3 groups · ₹800 + $20"); settings, mutes and "never the actor" unchanged.
- **Crash reports:** Firebase Crashlytics (free) with only the error type and stack (no names, amounts, emails,
  messages), switch in Account → Settings (on in release, off in debug, not present without Firebase / in `.qa`
  builds), docs/PRIVACY.md "Crash reports".

## Numbers

- **Storage (free plan: 1 GB for the whole project):** a 4032 × 3024 camera-size picture (JPEG q95, 1,579,830 B)
  was stored by the device's real encoder at 3072 × 2304 q85 = **707,321 B** plus a **39,060 B** thumbnail
  (first ladder step; cap 1.5 MB, then q78 / 2560 px … 1280 px). So ≈ 0.75 MB per photo → roughly 1,300–1,400
  photos per GB; PDFs as picked (≤ 5 MB); ≤ 10 files and 25 MB per expense (server-enforced). Uploads only to
  paths a row registered, so the bucket can't be abused. DEV storage before this package: 2.5 MB in 10 objects.
- **APK:** release arm64-v8a split with Firebase (Crashlytics plugin applied, mapping upload off):
  **25,025,222 B** vs 24,814,802 B before (final QA) = **+210,420 B (+0.85 %)** — Crashlytics SDK + PdfBridge;
  no PDF library is bundled (S-433).

## Tests

TC-W2Y-01..07 in `planning/10-test-catalog.md`.

- pgTAP on DEV: `280_expense_attachments` 47/47, `290_summary_batch_push` 32/32 (after apply), `001_schema`
  32/32 (seq triggers 10 → 11).
- Deno: fmt (LF copy) / lint clean, 56 tests passed (3 new in `send-push/push_test.ts`); `send-push` v4 deployed
  on DEV (verify_jwt false).
- Device (`integration_test/w2y_test.dart`, `.qa`, `--no-uninstall`, packages unchanged before/after, owner app
  untouched): photo + PDF attached offline → 3 rows/outbox/3 uploads queued, nothing on the server → online:
  rows + 3 objects in `expense-files` visible to the other member; full-size photo downloaded on tap; PDF pages
  rendered by PdfRenderer; remove + Undo, delete + restore (server rows); monthly card "Your November" → Insights;
  batch settle over 2 groups → friend's rows `batched` + one released push ("… settled up with you in 2 groups ·
  ₹250"). Screenshots `splitify-artifacts\screenshots\w2y-*-{light,dark}.png` (9 screens).

## Owner actions

- Apply **0029** and **0030** to production with this release and deploy `send-push` (S-439).
- Release builds with Firebase now apply the Crashlytics Gradle plugin; pass `-PsplitifyCrashlyticsUpload=true`
  on the owner's release build to upload R8 mapping files (optional).
- Storage: watch the Supabase storage meter; at ~1 MB per photo the free 1 GB holds roughly 1,000 photos.
