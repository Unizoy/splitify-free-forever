# Phase 02 — Design system and app shell (B3)

- Depends on: 01 · Owner setup: none · Branch: `phase/02-design-system` · Features: B3 + all UI foundations
- Goal: the Atlys-inspired look as reusable code: tokens, fonts, themes (light/dark/system switch), every component
  from `06-design-system.md` §6, generated covers, app icon/splash, the 4-tab shell with the floating capsule nav —
  all locked by golden tests.
- Read first: `06-design-system.md`, `07-screens-and-flows.md` §1–2, `ui-review` skill. Look at every Atlys
  reference image once (`…\splitify-design-reference\atlys\`).

## Tasks

- [ ] T1 Fonts: download **Instrument Serif** (Regular, Italic) and **Inter** (variable) TTFs from the official
      Google Fonts GitHub repo (`github.com/google/fonts`, `ofl/…`) with `curl -L`; save to `assets/fonts/` with
      `OFL.txt` files in `assets/fonts/LICENSES/`; register in pubspec; add to `LicenseRegistry`.
- [ ] T2 Theme: `lib/ui/theme/` → `app_colors.dart` (ThemeExtension, light+dark tokens), `app_text.dart`,
      `app_spacing.dart`, `app_radii.dart`, `app_motion.dart`, `app_theme.dart` (ThemeData/ColorScheme from tokens),
      `context_ext.dart` (`context.colors`, `context.text`).
- [ ] T3 B3: `ThemeModeController` (Riverpod) persisted with shared_preferences, read before `runApp`.
- [ ] T4 Components (`lib/ui/components/`), each in its own file with doc comment + semantics:
      CapsuleNavBar, HeroHeader, GlassCard, OverlapSheet, GroupCoverCard, PillButton, OptionTile, SegmentedPill,
      StepHeader, StatusPill, IconChip, UnderlineField, Avatar (+ AvatarStack, AvatarCarousel), AccordionCard,
      DashedListRow, AppSheet, ArcGauge, AmountRow, FolderTabs, OverlapBanner, QuantityStepper, StickyActionBar,
      EmptyState, BlobBackground, StackedCardsLoader, WalletCard, MetalCard, DotMatrixCard, DashedCircleButton,
      Celebration, SyncMarker, plus painters (dashed border/line, noise, dot matrix).
- [ ] T5 `CoverPainter` + `CoverCache` (§7 of the design doc) with deterministic seeds; golden for each family.
- [ ] T6 Brand: `assets/brand/icon.svg` (split-circle mark), `flutter_launcher_icons` + `flutter_native_splash`
      configs (dev deps), generate Android icons (adaptive + monochrome) and splash.
- [ ] T7 Shell: `StatefulShellRoute` with Groups / Friends / Activity / Account placeholder screens using
      HeroHeader + OverlapSheet layouts; amber add button (no action yet); welcome screen visual (`/welcome`).
- [ ] T8 Debug gallery `/debug/gallery` (only `kDebugMode`) showing every component variant.
- [ ] T9 Goldens (`alchemist`): every component × light/dark × text 1.0/2.0; shell tabs; welcome. Contrast helper
      `expectContrast()` over the token pairs; a11y guideline matchers on gallery sections.
- [ ] T10 `ui-review`: screenshots of gallery + shell (light/dark/200 %) vs Atlys refs; fix; document deviations.

## Tests

TC-B3-01, TC-B3-02, TC-B3-03, TC-1-05 (card goldens with fake data).

## Done when

All goldens committed and passing; gallery and shell reviewed with the `ui-review` checklist; no literal colours or
text styles outside `lib/ui/theme/` (guard).
