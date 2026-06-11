# Combat Visual Feedback (#25) — Colorblind / Greyscale Legibility Evidence (UX-05)

> **Story**: 013 — Accessibility | **Type**: Visual/Feel ADVISORY (manual)
> **AC**: UX-05 (tier escalation readable under desaturation)
> **Status**: ⏳ PROTOCOL AUTHORED — awaits human capture (art-director sign-off, external gate)

## Why this is ADVISORY, not automated

Tier escalation is communicated through **non-colour channels by design** — this is the
load-bearing accessibility decision, verified structurally in code but confirmed
perceptually only by a human looking at a desaturated screen:

| Tier / event | Non-colour channel (CI-verified) | Colour (foveal bonus only) |
|---|---|---|
| LIGHT / MEDIUM | small particle (HIT_LIGHT), small number | — |
| HEAVY | bigger particle (HIT_HEAVY) + `hit_pause(0.065)` | — |
| CRITICAL | HIT_HEAVY + `hit_pause(0.080)` + **full-screen flash** | — |
| OVERKILL | flash (0.6 opacity) + `hit_pause(0.080)` | — |
| `is_crit` number | (none — number style is the ONLY colour use) | warm-orange vs white |

The tier signal rides **particle size + hit-pause duration + flash presence** — all of
which survive greyscale. Colour is used in exactly one place (the `is_crit` number tint),
and it is explicitly a *foveal bonus*, never the tier carrier (R-12 dual-axis decoupling,
CI-verified in `test_cvf_dual_axis.gd`).

## Capture protocol

1. Run a combat session (or the playtest harness, story 017) with a macOS/iOS
   **Greyscale** accessibility filter ON (System Settings → Accessibility → Display →
   Colour Filters → Greyscale), OR apply a `saturation: 0` post filter to the recording.
2. Capture, in greyscale, one frame each of: a LIGHT hit, a HEAVY hit, a CRITICAL hit
   (mid-flash), an OVERKILL kill (mid-flash).
3. Save to `production/qa/evidence/cvf-colorblind/<tier>.png`.

## Pass criteria (art-director sign-off)

- [ ] In greyscale, a HEAVY hit is distinguishable from a LIGHT hit (particle mass + the
      perceptible freeze) without reading the number text.
- [ ] In greyscale, a CRITICAL / OVERKILL climax is distinguishable from a HEAVY hit (the
      full-screen flash is present for the climax, absent for HEAVY).
- [ ] No tier relies on hue to be told apart (a deuteranope/protanope/greyscale viewer
      reads the same escalation a trichromat does).
- [ ] The `is_crit` warm number, when desaturated, does not become *unreadable* (contrast
      vs background holds in greyscale — it is a bonus, its loss does not hide information).

## Sign-off

| Reviewer | Role | Verdict | Date |
|---|---|---|---|
| _pending_ | art-director | — | — |
| _pending_ | accessibility (UX) | — | — |

> Gate note: this is an **external human gate** (same class as the #26 silhouette-glance
> playtest). The structural guarantee (tier ≠ colour) is already CI-green; this doc closes
> the perceptual confirmation when real art + a playtest build exist (story 017).
