# Combat Visual Feedback (#25) — Peripheral Legibility & Tone Evidence (AC-26/27, UX-02/03)

> **Story**: 017 — Peripheral legibility + tone | **Type**: Visual/Feel ADVISORY
> **AC**: AC-26 / AC-27 / UX-02 / UX-03 (the CI-testable slice of AC-28 lives in `test_cvf_perf.gd`)
> **Status**: ⏳ PROTOCOL AUTHORED — awaits human capture + art-director sign-off (external gate)

## The claim being tested

The Player-Fantasy load-bearing principle is **「Foveal punch, Peripheral pulse」**: while
the player's fovea is on the GymSys set-rep UI, combat escalation must still register **in
the periphery**. Tier therefore rides **hit-pause duration + full-screen flash** (peripheral
channels), NOT number size/colour (foveal-only, unreadable at the eye's edge). The structural
side is already CI-green (routing keyed on tier/pause/flash, R-12 dual-axis); this doc closes
the **perceptual** confirmation a human must give.

## Capture protocol

**Setup**: combat session (or the playtest harness), fixed viewport, recorded at 60fps.

1. **Peripheral-glance test (AC-26 / UX-02)** — the tester fixes their gaze on a *corner*
   marker (NOT the combat focal point) and watches a ~1s window containing a normal hit and
   a CRITICAL climax. Capture both frames.
2. **Tier-contrast test (AC-27 / UX-03)** — side-by-side: a HEAVY hit (no flash, 65ms pause)
   vs a CRITICAL hit (flash + 80ms pause). Then the **EC-20 degrade** variant (no flash,
   65ms vs 100ms pause) — confirm the climax is still distinguishable on pause alone.
3. **Greyscale variant** — reuse the `cvf-colorblind-evidence.md` desaturated protocol.

Save frames to `production/qa/evidence/cvf-peripheral/`.

## Pass criteria (art-director sign-off)

- [ ] **AC-26 / UX-02**: in a 1s peripheral glance, a tester can tell「a climax happened」from
      「a normal hit happened」**without foveating the number** — the flash + freeze carry it.
      The number is a *foveal bonus*, never the only signal.
- [ ] **AC-27 / UX-03**: a CRITICAL/OVERKILL climax is peripherally distinct from a HEAVY hit
      (flash present vs absent). In degrade mode (no flash), the 65ms-vs-100ms pause delta is
      still perceptible as「heavier」.
- [ ] **Tone**:「乾淨定格 + 骯髒爆發」— the freeze reads *clean* (a crisp stop), the particle
      burst reads *dirty* (messy impact). The two together feel like a DNF heavy hit.
- [ ] **「稀疏即重量」**: across a full combat, climax flashes are *sparse* — most hits are quiet.
      The flash never feels spammy (which would also trip WCAG 2.3.1, already structurally safe).

## Sign-off

| Reviewer | Role | Verdict | Date |
|---|---|---|---|
| _pending_ | art-director | — | — |
| _pending_ | creative-director (tone) | — | — |

> Gate note: ADVISORY external human gate (same class as #26 silhouette-glance / the
> colorblind evidence). The structural guarantees (tier→peripheral, single-instance flash,
> draw-call/blend-pass bounds) are CI-green in `test_cvf_perf.gd`; this doc + a playtest build
> close the perceptual confirmation. The mobile-Safari P95 ≤16.6ms frame budget is a separate
> **VS-tier hardware gate** (`pending()` in `test_cvf_perf.gd`).
