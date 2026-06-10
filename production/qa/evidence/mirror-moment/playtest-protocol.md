# Mirror Moment (#29) — Playtest Protocol (FT-2 / FT-M1)

> **Story**: mirror-moment story-016 · **Gate level**: ADVISORY (Visual/Feel)
> **Status**: Protocol authored — **execution deferred to human playtest** (needs ≥2 weeks of
> real workout sessions + ≥5 playtesters; same posture as #26 story-019 silhouette-glance).
> Automated BLOCKING coverage (FSM / cadence / latch / content / suspend / persistence /
> screenshot signal flow / no-fabrication trace) ships green in
> `tests/unit/mirror_moment/` + `tests/integration/mirror_moment/`.

## What to measure

### FT-2 — Screenshot share rate (Pillar 3 / 5, falsifiable)
- **Telemetry**: count `mirror.shared` (confirm_shared) vs `mirror.ceremony_presented`.
- **Pass**: weekly self-initiated share rate **≥ 30%** over ≥2 weeks of presented ceremonies.
- **Falsified if < 30%** → re-examine the share affordance (P-13): is the CTA discoverable?
  is the native-screenshot hint clear? is the card clean enough to be share-worthy?

### FT-M1 — Weekly pause noticeability (Pillar 5)
- **Method**: 5 playtesters do ≥2 weeks of training; observe the weekend first-open.
- **Pass**: **≥ 80%** notice the ceremony appeared (unprompted recall).
- **Falsified if < 80%** → the pause is too subtle / collapses too fast; revisit
  `CEREMONY_PRESENT_DELAY_FRAMES`, backdrop dim, and the EVOLUTION burst intensity.

### AC-15 — Mobile burst silhouette (ADVISORY, visual)
- Screenshot an EVOLUTION ceremony on desktop vs mobile. The #5 0.5× mobile density must
  NOT reduce avatar silhouette legibility — the silhouette (#26) carries identity, the burst
  (#29) only celebrates (ADR-0010). Compare side-by-side.

### AC-23 / AC-24 — telemetry + recall (map to FT-2 / FT-M1 above)

## Setup notes
- Requires a live GymSys feed (or a 2-week scripted workout fixture) so real `avatar_evolution_milestone`
  / `avatar_micro_evolution` signals fire across multiple cadence windows.
- Capture: device-native screenshots of EVOLUTION (ghost + badge + burst) and REFLECTION
  (single pose, no burst) ceremonies for the art-director sign-off (Visual/Feel gate).

## Sign-off
- [ ] FT-2 share rate ≥ 30% (telemetry) — _pending live playtest_
- [ ] FT-M1 noticeability ≥ 80% (5 testers) — _pending live playtest_
- [ ] AC-15 mobile silhouette parity (art-director) — _pending art pipeline_
