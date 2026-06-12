# Onboarding Flow — Playtest Protocol (#27 Story 016, ADVISORY)

> Type: Visual/Feel. **Protocol authored here; execution is an external human gate** (needs
> a real new player + a connected GymSys session — same posture as #29 FT / #25 playtest).
> Pre-execution status: `pending()` honest — never assert-true a playtest that has not run.

## AC-14 (ADVISORY) — Pillar 2: zero coach-mark mid-set

**Falsifiable claim**: No coach-mark ever appears while the player is mid-set.

- **Setup**: New player (fresh `onboarding.*`), connected, into a real workout. Drive the
  game into `WORKOUT_ACTIVE` (and `REST_PERIOD`, `LOOT_DROP`) with a class-change / loot
  reveal pending in the onboarding queue.
- **Observe**: Screen-record the entire set. Inspect every frame in the workout-critical
  states for any `OnboardingOverlayLayer` coach-mark.
- **Pass condition**: **Zero** coach-mark frames during `WORKOUT_ACTIVE` / `REST_PERIOD` /
  `LOOT_DROP`. The pending coach-mark must appear ONLY after the state returns to a
  non-critical window (or silently latch if deferred past `coach_max_defer_sec`).
- **Automated backstop**: `tests/unit/onboarding_flow/test_onboarding_formula_may_show.gd`
  + `tests/integration/onboarding_flow/test_defer_queue.gd` prove the gate logic; this
  playtest confirms the *rendered* result matches.

## AC-24 (ADVISORY) — Pillar 2 fantasy: "didn't feel like a tutorial"

**Falsifiable claim**: The player learns auto-combat / muscle=class / loot-on-real-reps
without perceiving a tutorial.

- **Setup**: Real new player, full first session: connect → preview「試演」→ first real
  workout → first guaranteed drop ceremony.
- **Observe**: Post-session questionnaire —
  1. 「你覺唔覺得頭先睇咗一個 tutorial?」(expect: no / barely)
  2. 「你可唔可以自己講返:點解你個角色自己打?今日點解係 STRIKE?幾時先爆裝?」
     (expect: player can articulate all three concepts unprompted)
- **Pass condition**: Player reports **not** feeling tutorialed AND can self-describe the
  three concepts (auto-combat / 練乜變乜 / real-reps→real-loot).
- **Sample**: ≥5 new players for a directional signal (not a statistical gate — Polish-phase
  qualitative).

## Execution status

- [ ] AC-14 screen-record + frame inspection — **deferred** (needs real workout session)
- [ ] AC-24 questionnaire ≥5 players — **deferred** (needs real new players + real art)
- Both gated on real art (`/asset-spec system:onboarding-flow`) + a live GymSys-connected
  build. Until then: ADVISORY `pending()`, never false-green.
