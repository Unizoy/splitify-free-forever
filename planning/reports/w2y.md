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

## Storage budget (free plan: 1 GB for the whole project)

See "Numbers" below (measured on the emulator with a 4032 × 3024 camera-size picture).

## Tests

TC-W2Y-01..07 in `planning/10-test-catalog.md`.

## Owner actions

- Apply **0029** and **0030** to production with this release and deploy `send-push` (S-439).
- Release builds with Firebase now apply the Crashlytics Gradle plugin; pass `-PsplitifyCrashlyticsUpload=true`
  on the owner's release build to upload R8 mapping files (optional).
- Storage: watch the Supabase storage meter; at ~1 MB per photo the free 1 GB holds roughly 1,000 photos.
