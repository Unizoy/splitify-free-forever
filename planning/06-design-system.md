# 06 — Design system (Atlys-inspired)

Owner decisions D-010, D-011, D-013: Atlys look, closely matched; Splitify's own content, assets and features.
Reference screenshots (never copy into the repo): `C:\Users\mohit\OneDrive\Desktop\theCode\splitify-design-reference\atlys\`
— cited below by their time stamp (e.g. **438** = `Screenshot_20261121-144438_Atlys.png`).
Colours were sampled from the screenshots with PIL (2026-11-21).

## 1. Character

Premium, calm, high-contrast. Big elegant **serif** headlines over **photographic/gradient heroes**; everything
interactive is a **pill** or a **large-radius card**; **frosted glass** status cards on imagery; a **floating
capsule nav**; **dashed lines** as a recurring motif (underlined inputs, dividers, "add" buttons, circle CTA);
occasional **skeuomorphic showpieces** (wallet with a metal card, brushed-metal card, dot-matrix navy card, arc
gauge) and **playful motion** (stacked cards shuffling while working, celebration on settle-up). Generous white
space, centred hero typography, black/white base, indigo accents, amber for money actions.

## 2. Colour tokens

Implement as `AppColors` in a `ThemeExtension` (light + dark), plus a Material 3 `ColorScheme` built from them.
Dynamic colour (Material You) is **off**.

| Token | Light | Dark | Use / sampled from |
| --- | --- | --- | --- |
| `bg` | `#FFFFFF` | `#050507` | screens |
| `bgSubtle` | `#F8FAFC` | `#0E0E13` | headers, stepper band (532) |
| `surface` | `#FFFFFF` | `#141419` | cards, sheets |
| `surfaceMuted` | `#F1F5F9` | `#1C1C24` | gauge card, segmented track (646, 534) |
| `chip` | `#EEF2F6` | `#24242D` | inactive tabs/chips (712) |
| `border` | `#E3E8EF` | `#2C2C36` | card outlines (614) |
| `divider` | `#CDD5DF` | `#33333E` | dashed dividers (534, 646) |
| `textPrimary` | `#121926` | `#F5F5F7` | body/titles (712, 532 `#212121`) |
| `textSecondary` | `#697586` | `#A1A1AA` | dates, subtitles (646) — 4.7:1 on white |
| `textTertiary` | `#9AA4B2` | `#71717A` | disabled/placeholder only (532) |
| `primary` | `#5057EA` | `#7C83FF` | indigo badge, banner, outline buttons (532, 712) — 5.4:1 on white |
| `primaryPressed` | `#3F45D6` | `#6A71F5` | |
| `primaryDisabled` | `#A7ABF4` | `#3B3F7A` | disabled CTA (534) |
| `primaryContainer` | `#E8E8F8` | `#23244A` | avatar tint (542), selected rows |
| `onPrimaryContainer` | `#3A3FC4` | `#C9CBFF` | |
| `money` (amber) | `#FDB022` | `#FDB022` | main money CTA: Save expense, Settle up, Mark as paid (712) |
| `onMoney` | `#121926` | `#121926` | 9.7:1 on amber |
| `ink` | `#000000` | `#FFFFFF` | black pills (nav active, primary black buttons) (438) |
| `onInk` | `#FFFFFF` | `#000000` | |
| `owedText` | `#15803D` | `#4ADE80` | "you are owed" amounts (5.0:1) |
| `owedAccent` | `#84CC16` | `#A3E635` | lime highlight words, success checks (455) |
| `oweText` | `#D92D2D` | `#F87171` | "you owe" amounts (4.8:1) |
| `oweAccent` | `#EA5050` | `#EF6B6B` | icons/large numbers only (646) |
| `settled` | `#697586` | `#A1A1AA` | settled/zero |
| `info` | `#3B82F6` | `#60A5FA` | info icons (614) |
| `unsynced` | `#B45309` | `#FBBF24` | "not synced yet" marker |
| `heroTop` / `heroBottom` | `#6E70B0` → `#9293CB` | `#000000` → `#1A1A2E` | lavender hero (438) / black hero (442) |
| `navyTop` / `navyBottom` | `#030518` → `#022945` | same | stats card (542) |
| `metal` | `#BFC3C9` (+ highlights `#E9ECEF`, `#8E949C`) | same | brushed card (542) |
| `chipDarkGreen` / `onChipDarkGreen` | `#375010` / `#A3E635` | same | date chips on photos (455) |
| `blobLavender`, `blobPink` | `#EFEFFA`, `#F9ECF1` | `#1B1B2E`, `#2A1820` | soft backgrounds (636) |
| `scrim` | `#000000` 40 % | `#000000` 60 % | behind sheets (614) |

Avatar tint pairs (initials circles, 542): lavender `#E8E8F8`/`#6D35D9`, peach `#FAF6EE`/`#B86A1F`,
mint `#F4FCF4`/`#3F8F3F`, sky `#EAF3FF`/`#1D5FC9`, rose `#FDF0F3`/`#B4335A`; colour picked by
`hash(member.id) % 5`. Category icon colours: Food `#F97316`, Groceries `#22C55E`, Travel `#3B82F6`, Rent `#8B5CF6`,
Utilities `#EAB308`, Shopping `#EC4899`, Entertainment `#14B8A6`, Other `#64748B` (icon on 12 % tint circle).

Every text/background pair used must pass WCAG AA (4.5:1, or 3:1 for ≥ 18 sp / bold ≥ 14 sp); the widget-test
helper `expectContrast()` checks the token pairs above.

## 3. Typography

Fonts are bundled assets (offline-first, no runtime download), both SIL OFL 1.1 — include their licence files in
`assets/fonts/LICENSES/` and the in-app licences page:

- **Instrument Serif** (Regular, Italic) — display/hero, sheet titles, card titles (matches Atlys' condensed
  high-contrast serif, 438/455/614).
- **Inter** (variable, weights 400–700; `FontFeature.tabularFigures()` for amounts) — all UI text.

| Style | Font | Size/line (sp) | Weight | Letter spacing | Use |
| --- | --- | --- | --- | --- | --- |
| `heroDisplay` | Instrument Serif | 34/38 | 400 | −0.5 | hero headlines, lowercase sentence ("split it. settle it.") |
| `sheetTitle` | Instrument Serif | 28/32 | 400 | −0.3 | bottom-sheet & screen titles ("Account settings") |
| `cardTitle` | Instrument Serif | 19/23 | 400 | −0.1, UPPERCASE | group card names (438 "THAILAND") |
| `headline` | Inter | 20/26 | 700 | −0.3 | step questions ("Who paid?") (532) |
| `title` | Inter | 16/22 | 600 | −0.1 | list titles, app bar |
| `body` | Inter | 15/21 | 400 | −0.1 | default |
| `bodySmall` | Inter | 13/18 | 400 | 0 | secondary lines |
| `caption` | Inter | 11.5/15 | 500 | 0.2 | dates, meta |
| `labelCaps` | Inter | 11/14 | 700 | 1.4, UPPERCASE | "YOU ARE OWED", "PAID BY", field labels (602, 542) |
| `amountHero` | Inter | 34/38 | 700 | −0.8, tabular | big balance in glass/wallet card |
| `amount` | Inter | 15/20 | 600 | −0.1, tabular | list amounts |
| `button` | Inter | 16/20 | 600 | −0.1 | buttons |

Text scaling: everything must work at 200 %; serif hero clamps to 1.6× to avoid absurd sizes.
Scale one step down since S-268 (owner D-027, Atlys 438/602). Amounts — hero ones included — are always Inter
`amountHero`/`amount` (tabular); serif is for words only (S-269).

## 4. Layout, spacing, radii, elevation

- 4 dp grid: `s1 4, s2 8, s3 12, s4 16, s5 20, s6 24, s8 32, s10 40, s12 48`. Screen side margin **20 dp**;
  grid gutters 12 dp; sections separated by 24–32 dp.
- Radii: `r8, r12, r16` (inputs, option buttons), `r24` (small cards), `r28` (cards, accordions, photo cards),
  `r32` (glass card, sheets), `r36` (overlap sheet top), `pill 999`.
- Elevation: flat by default. `shadowFloat` = 0 8 24 rgba(16,24,40,0.12) (capsule nav, floating CTA),
  `shadowCard` = 0 2 8 rgba(16,24,40,0.06). Dark mode: no shadows; use `border` instead.
- Hit targets ≥ 48 dp. Primary buttons 56 dp tall, secondary 44 dp.
- Edge-to-edge (Android 15+ enforced): content draws behind status/nav bars; heroes extend under the status bar;
  bottom content respects `MediaQuery.viewPadding`.

## 5. Motion

| Token | Value | Use |
| --- | --- | --- |
| `press` / `release` | 90 ms easeOut / 160 ms spring | every tap (`Pressable`, scale 0.97; rows 0.985; icon buttons 0.9) |
| `fast` | 150 ms, `easeOut` | toggles, sheet close, folder-tab fill |
| `base` | 240 ms, `Cubic(0.2,0,0,1)` | most transitions, accordions |
| `slow` | 300 ms, emphasized `Cubic(0.05,0.7,0.1,1)` | sheets (≤ 320 ms) |
| `route` / `routeBack` | 280 / 240 ms | shared-axis push / pop (`SharedAxisPageTransitionsBuilder`) |
| `tab` | 220 ms | fade-through between nav tabs, in-page tab fade-in |
| `count` | 350 ms, easeOutCubic | balance totals counting to a new value (`AnimatedAmount`) |
| `entrance` + `stagger` | 220 ms + 30 ms/row, rows 0–7 | first-load list entrance (`EntranceScope`/`Entrance`) |
| `showcase` | 300 ms, spring (stiffness 300, damping 26) | nav pill morph |
| `shimmer` | 1.2 s sweep, 8 sweeps max | skeleton loaders |

Amendment (S-260..S-267, owner D-027): durations stay 90–300 ms (sheets ≤ 320), nothing blocks input, the
phone runs at its highest refresh rate; Hero flights for group card → group page and expense row → expense
page; the glass blur is pre-rendered from the static hero background (no live blur while scrolling).

Respect `MediaQuery.disableAnimations` (all durations → 0, loaders become static progress). Haptics (`AppHaptics`):
`selection` on toggles/steps/chips/tabs/nav, `light` on primary pills and the + button, `success` (medium) on Save
and Mark as paid, `heavyImpact` never.

## 6. Components (`lib/ui/components/`, each with a golden test in light + dark + 2.0× text)

| Component | Spec (Atlys source) |
| --- | --- |
| `CapsuleNavBar` | Floating white capsule (dark: `surface` + border), height 64, radius pill, margin 16 sides + 12 bottom, `shadowFloat`. 4 destinations: Groups, Friends, Activity, Account (avatar). Active item = black `ink` pill with icon + label, inactive = icon only; width morphs with `showcase` spring (438, 542). An amber 56 dp round **+** button sits right of the capsule (main "Add expense" action) on Groups/Friends/Activity. |
| `HeroHeader` | Full-bleed gradient (`heroTop→heroBottom`) or generated cover, extends under status bar, optional top action icons in 40 dp translucent circles, centred `heroDisplay` text (white), optional segmented icon tabs like 438's Explore/Events. Bottom fades into the overlap sheet. |
| `GlassCard` | Radius 32, fill black 28 % (light) / white 8 % (dark), `BackdropFilter` blur σ 18 over the hero only (one per screen; fall back to plain 45 % black when `disableAnimations` or low-end), 1 dp border white 22 %, padding 20. Holds flag-like circle icon + title + status pill + white pill button (438). |
| `OverlapSheet` | White `surface` sheet with top radius 36 that overlaps the hero by 32 dp and scrolls over it (438). |
| `GroupCoverCard` | 2-column grid, aspect 0.62, radius 28, generated cover (§7) or photo with bottom dark gradient; centred 28 dp type icon circle; `cardTitle` white; thin divider; footer row `labelCaps` "YOU ARE OWED"/"YOU OWE"/"SETTLED" + amount (438 "VALID 90 DAYS"). |
| `PillButton` | Variants: `ink` (black, white text — default primary), `inverse` (white on dark/hero), `money` (amber, `onMoney`), `outline` (1.5 dp primary border + primary text, radius 16 for option lists, 532), `ghost`. Heights 56/44; loading state shows a 3-dot pulse; disabled = `primaryDisabled`/40 % opacity (534). |
| `OptionTile` | Outlined indigo rounded-rect choice (532 "Before Dec 24"), radius 16, 56 dp, centred primary text; selected = filled `primaryContainer`. |
| `SegmentedPill` | Track `surfaceMuted`, selected white pill with `shadowCard` (534 Fixed/Flexible). |
| `StepHeader` | Top band `bgSubtle`: back arrow, centre status pill (indigo, white text, leading icon), trailing home circle; below, 5 icon steps joined by 2 dp lines; active = primary, done = check, todo = `textTertiary` (532). Used by Add expense. |
| `StatusPill` | Pill, primary fill or dark-green chip (455) or translucent on photos; icon + text. |
| `IconChip` | Pill chip with leading 24 dp coloured circle icon (442 Music/Sports); outlined when unselected, filled `ink` when selected; dark variant outlined white (555). |
| `UnderlineField` | `labelCaps` label + red asterisk if required, borderless input, **dashed** 1 dp underline (`divider`), focus = primary solid line, error text below in `oweText` (602). Two-column layout allowed. |
| `Avatar` | Initials (1–2 letters) on tint pair, or photo; sizes 32/40/56/96; stack-overlap variant "+2" (438). `AvatarCarousel`: PageView viewportFraction 0.4 with scale 1.0→0.7, inside a 200 dp light ring, dots below (602, 542). |
| `AccordionCard` | Radius 28, 1 dp `border`, leading coloured icon, title + subtitle, chevron rotates; expands to rows with value + chevron (614, 623). |
| `DashedListRow` | Icon + label + trailing value/chevron, dashed `divider` separators (614). |
| `AppSheet` | Bottom sheet radius 32, handle 36×4 `#A9A9A9`, `sheetTitle` centred, scrim (614). |
| `ArcGauge` | 240° arc, track white/`surfaceMuted`, progress primary, black round knob at progress end, centre `amountHero` + caption (646). Used for "settled so far" on settle-up. |
| `AmountRow` | Title + caption date left; signed amount right (`owedText` with "+", `oweText` with "−"), divider (646). Unsynced rows show the `SyncMarker`. |
| `FolderTabs` | Tabs shaped like file-folder tabs: active white with icon, inactive `chip` grey slanted edge (712). Group detail: Expenses · Balances · Totals. |
| `OverlapBanner` | Primary-filled banner card that overhangs its parent card by 8 dp each side, shield/check icon in outline + two lines (712). Used for group summary ("You are owed ₹2,400 here"). |
| `QuantityStepper` | Outlined − / + circles 36 dp with value between (712). Used for shares. |
| `StickyActionBar` | White bar with top divider: summary text left/top + amber CTA (712). |
| `EmptyState` | 64 dp light-blue icon bubble, `title`, `bodySmall` secondary (636). |
| `BlobBackground` | 2–3 blurred colour blobs (`blobLavender`, `blobPink`) behind content (636). Comments & activity empty states. |
| `StackedCardsLoader` | 4–5 tilted white cards with generated covers + captions (group names / "Syncing…") that shuffle (505/528). For create-group, import, first sync. |
| `WalletCard` | Showpiece on Account and Groups top: dark leather-texture sleeve (gradient + subtle noise painter, stitched dashed edge) holding a metal/gold card that peeks out; card shows overall balance per currency; tap = balances breakdown (542 "INFINITY" wallet). |
| `MetalCard` | Brushed silver gradient with sheen sweep animation; "Your stats" (expenses this month, groups) (542 vault card). |
| `DotMatrixCard` | Navy gradient with a dotted globe/rupee pattern painted from dots; stats grid of big numbers + labels; entry to charts (542 trips card). |
| `DashedCircleButton` | 120 dp dashed circle, slow rotation, two-line label ("Get / started") (455). Onboarding. |
| `Celebration` | Settle-up success: cards fan out, big check draws, lime highlight word in serif ("all *settled*"), haptic. |
| `SyncMarker` | Small cloud-off icon + "Not synced yet" caption in `unsynced`; tooltip/semantics explain. |

## 7. Generated group covers (D-013)

`CoverPainter(seed: groupId, type)` → mesh gradient: 3–4 radial blobs at seeded positions over a base linear
gradient, plus 2 % monochrome noise and a bottom-to-top black gradient (0→55 %) for legible text. Families:
trip (coral `#FF7A59`, amber `#FDB022`, violet `#6E56CF`), home (sage `#7FB77E`, teal `#2A9D8F`, sand `#E9C46A`),
couple (rose `#F28CA8`, lavender `#B9A7F2`, peach `#FFC6A5`), other (indigo `#5057EA`, sky `#7CC4FA`,
mint `#9BE3C6`), friend/direct (graphite `#3A3F4B`, slate `#7A8699`, ice `#DCE3EC`). Deterministic per seed,
rendered once to an image and cached by `(seed, size, brightness)`. Hero headers inside a group use the same
cover. Users may upload a photo instead (compressed, stored in Storage).

## 8. Iconography and imagery

- Icons: **Phosphor** (`phosphor_flutter`, MIT) regular/bold weights — closest to Atlys' rounded line icons.
  If the package fails the dependency check, use Material Symbols Rounded (built in).
- No stock photos, no Atlys assets. Illustrations are code-drawn (covers, wallet, metal, dot matrix, loaders).
- App icon: rounded-square indigo→lavender gradient with a white circle split into two offset halves (the
  "split" mark); adaptive icon (foreground/background) + monochrome themed icon; generated with
  `flutter_launcher_icons` from `assets/brand/icon.svg` (written in phase 02).
- Splash: plain `bg` with the mark (Android 12+ splash API via `flutter_native_splash`).

## 9. Implementation rules

- All styling from `Theme.of(context)` + `context.colors` / `context.text` extensions; no literal colours, sizes or
  durations in widgets (guard script flags `Color(0x` and `TextStyle(` outside `lib/ui/theme/`).
- Theme mode: system by default; manual Light/Dark/System in Account → Appearance, persisted locally (B3).
- Blur budget: at most one `BackdropFilter` on screen; heroes are static images (cover cache) so blur is cheap.
- Every component: semantics label, focus/pressed states, RTL-safe paddings (`EdgeInsetsDirectional`).
- Debug-only **Component gallery** route (`/debug/gallery`) shows every component in all variants; golden tests
  render the same gallery sections.

## Amendments (phase 02)

- Amendment (S-005): extra tokens added in `AppColors`: `primaryFill`/`onPrimaryFill` (#5057EA + white in both
  modes, for filled indigo surfaces), `moneyPressed`, `owedOnDark`/`oweOnDark` (money on covers/navy),
  `infoContainer`, `onHero`/`onHeroMuted`, `glassFill`/`glassFallback`/`glassBorder`, `onMetal`, leather
  (`leatherTop`, `leatherBottom`, `stitch`), gold card (`goldLight`, `goldMid`, `goldDark`, `onGold`),
  `chipDarkRed`/`onChipDarkRed`, `sheetHandle`, `shadow`; dark avatar tints. All AA-checked in `contrast_test`.
- Amendment (S-006): secondary buttons are 48 dp tall (touch target rule wins over the 44 dp in §4).
- Amendment (S-008): Phosphor icons are vendored fonts (`AppIcons`), MIT licence in `assets/fonts/LICENSES/`.
- Amendment (S-009): covers' 2 % grain is drawn from a cached 128 px tile (image shader); the Celebration sits on
  a navy panel so the lime highlight keeps 3:1+.
- Amendment (S-015): capsule-nav labels scale at most 1.15× (they must fit the active pill); everything else
  scales to 2.0×.
