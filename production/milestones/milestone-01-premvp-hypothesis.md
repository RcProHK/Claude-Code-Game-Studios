# Milestone 1 — Pre-MVP Hypothesis Test

> **Created**: 2026-06-12 (Production Sprint 1 — PR-PHASE-GATE condition C2)
> **Type**: Go / No-Go hypothesis gate (NOT a feature milestone — all features are already implemented)
> **Target date**: TBD (frank sets — depends on Line A backend deploy + Line F playtest availability)
> **Status**: 🟡 PARTIAL — **desk-pass PROCEED** 2026-06-13 (VS-1 placeholder build, mock workout;
> see `production/playtests/vs1-fun-check-2026-06-13.md`). Full GO still requires the real
> mid-workout Pillar-2 test (needs GymSys backend → real workout data, not mock).

## Why this milestone exists

All MVP-tier systems are implemented + CI-green, but the project's **core bet has never been tested on a
human**. `game-concept.md` L305 states the Pre-MVP hypothesis in two halves. This milestone exists to answer
them before committing further Production effort — and to give the "fun was never validated" CONCERN
(CD-PHASE-GATE) an explicit Go/No-Go with a PIVOT escape hatch, rather than letting it silently ride into Alpha.

## The hypothesis (two halves)

1. **Watchability**: a mid-set glance of ≤1 second is enough for the player to read what just happened
   (loot tier / hit / avatar state) WITHOUT pulling attention off the workout. *(game-concept.md L275 — #1 design risk.)*
2. **Return value**: the 爆裝 (loot reveal) moment feels worth coming back for a second workout day.

## What measures it

- **Quantitative**: #28 Telemetry. `test_premvp_data_completeness` already proves both hypothesis halves have
  end-to-end metric coverage with 0 PII (`production/qa/evidence/telemetry-premvp-data-completeness.md`).
  Once a real session runs, telemetry emits the switch-latency / foreground-attention / loot-euphoria signals
  that quantify both halves.
- **Qualitative**: at least one **human playtest mid-workout** (Line F of the external-gate register). Telemetry
  numbers say *what* happened; only a human says whether it *felt* watchable and worth returning for.

## Entry criteria (what must be true to start the test)

- [ ] Vertical slice runs end-to-end (mock GymSys data acceptable) — workout → loot → avatar → mirror moment
- [ ] First real Web Export build smokes on a real browser (Line B)
- [ ] Telemetry collecting (already implemented; needs a live transport or local spool)

## Go / No-Go criteria

| Outcome | Condition | Action |
|---------|-----------|--------|
| **GO** | Both hypothesis halves confirmed (telemetry signals present + ≥1 human says glance is watchable AND loot is worth returning for) | Advance to full-MVP Production scope; close this milestone |
| **CONCERNS** | One half confirmed, one ambiguous | Targeted iteration on the weak half (tuning, not redesign); re-test |
| **NO-GO / PIVOT** | Either half fails — glance NOT watchable mid-workout, OR loot not worth returning | **PIVOT the core loop** (per game-concept.md L342 failure criteria). This is a design-level change, not a code fix. Do NOT push more features on top of an unvalidated loop. |

## Dependencies

- **Line A** (GymSys deploy) — for a *real* (non-mock) end-to-end run. A mock-fed slice can start sooner.
- **Line F** (human playtest) — the qualitative half.
- Vertical slice build — the first Production deliverable (does not yet exist).

## Notes

- This milestone deliberately front-loads the riskiest unanswered question. Per GDC postmortem lesson embedded
  in `/gate-check`: validating fun late is the #1 source of wasted production effort. We built everything first
  (unusual order), so this milestone is the catch-up validation.
