---
name: ui-review
description: Visual QA for Splitify screens against the Atlys-inspired design system — captures emulator screenshots in light, dark and large text, compares them with planning/06-design-system.md, planning/07-screens-and-flows.md and the Atlys reference images, and fixes deviations. Use whenever a screen or component is built or changed, for gate G5, or when asked "does it look right", "polish the UI", "match the design".
---

# UI review

The owner asked for the Atlys look (D-011) — closely, but with Splitify's own content and assets.
Reference images (UI inspiration only, contain personal data, never copy into the repo):
`C:\Users\mohit\OneDrive\Desktop\theCode\splitify-design-reference\atlys\Screenshot_20261121-*.png`.

## 1. Capture

For every screen the phase touched, using `emulator-e2e` §6, capture into
`C:\Users\mohit\OneDrive\Desktop\theCode\splitify-artifacts\phase-NN\`:
`<screen>-light.png`, `<screen>-dark.png`, `<screen>-text200.png`, plus empty, loading, error and offline states
where the screen has them (use test data / airplane mode to reach them).

## 2. Look at them

Open each PNG with the Read tool. Open the matching Atlys reference named in `07-screens-and-flows.md` for that
screen. Compare side by side.

## 3. Checklist (every screen)

- [ ] Tokens only: colours, radii, spacing, type styles come from the theme / ThemeExtension — no ad-hoc values.
- [ ] Hierarchy matches the spec: serif display for hero/sheet titles, sans for UI, letter-spaced UPPERCASE labels.
- [ ] Signature elements present where the spec asks: gradient/photo hero, frosted glass card, sheet overlapping the
      hero with large top radius, floating capsule nav (active = black pill with label), dashed dividers/underlines.
- [ ] Money: amounts via the money formatter (₹ with Indian grouping), owed = green, owe = red, settled = neutral,
      "not synced yet" marker visible on unsynced rows.
- [ ] Dark mode: no pure-white surfaces left, contrast OK, gradients adapted.
- [ ] Text scale 2.0: nothing clipped or overlapping; buttons grow; no fixed-height text containers.
- [ ] Touch targets ≥ 48 dp; TalkBack labels on icons and amount rows (check semantics in widget tests).
- [ ] Spacing on a 4 dp grid; side margins per spec; nothing touching screen edges; safe areas respected.
- [ ] Motion (if any): uses the spec's durations/curves; respects "remove animations" (reduced motion).
- [ ] No Atlys branding, names, photos or copy — only our generated covers and our own text.

## 3b. Score (D-018 — must be ≥ 8/10 on every line, per screen, light AND dark)

| Criterion | 10 = |
| --- | --- |
| Atlys feel | Side by side with the matching reference, it reads as the same design family |
| Typography | Serif/sans pairing, sizes, weights, caps labels exactly per tokens; no orphan styles |
| Layout & spacing | 20 dp margins, 4 dp rhythm, generous white space, aligned edges, no crowding |
| Colour & contrast | Only tokens; AA contrast; money colours correct; dark mode equally polished |
| Signature elements | Hero/glass/overlap sheet/capsule nav/dashed motif/showpiece cards present where specified |
| Polish | Radii, shadows, icon weights consistent; no jank, clipping, overflow stripes, misaligned baselines |
| States | Empty/loading/error/offline/unsynced designed (not default Material) |

Write the scores in the phase report. Anything < 8 → fix and re-capture; never ship below 8.

## 4. Fix and record

Fix deviations, re-capture, and re-check. Update or add golden tests so the approved look is locked. List the
screens reviewed and any accepted deviations (with reason) in the phase report.
