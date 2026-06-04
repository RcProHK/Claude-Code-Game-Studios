# #20 Gym-Mode HUD — Epic-Close External Gate Proposals

> **Status**: Advisory proposals for owner/TD review — **NOT committed upstream changes**.
> **Author**: (autonomous #20 implementation pass, 2026-06-04)
> **Purpose**: All self-contained code/logic/scene/doc-reciprocity AC are done CI-green (12 stories,
> 100 tests, full gate 245 scripts / 1525 pass / 0 fail; commits 8df3a8a→3dcfd08, PR #17). The
> remaining gates need a cross-system **owner or TD design decision** — this doc turns each into a
> concrete, reviewable starting point so #20 epic-close is unblocked when an owner picks it up.

---

## Gate A — #8 Streak `streak_chime` contract (Q-OQ1 / Prov-3) — needs #8 owner

**Blocks**: Story 007 AC-CR-11 (real streak chime + stagger). The #20 side is already built:
`WorkoutAudioAdapter.handle_set_complete(has_streak: bool)` plays `set_complete` immediately and,
when `has_streak == true`, schedules `streak_chime` at `SET_STREAK_CHIME_STAGGER_MS` (100ms) via the
injectable `ITimerService` seam. The **only** missing piece is how #20 learns `has_streak` for the
just-logged set.

**#8 today exposes**: `substate_changed(from, to)` · `invalid_transition_attempted(...)` ·
`streak_persistence_failed(...)`. None signals "this set advanced the streak" at set-complete time.

**Two routes (Q-OQ1), with recommendation:**

| Route | Mechanism | Trade-off |
|-------|-----------|-----------|
| **(A) Query-based ⭐ recommended** | #8 exposes `func did_streak_advance_this_set() -> bool` (or `get_pending_chime() -> bool`). #20 calls it inside `_on_set_logged` → passes result to `handle_set_complete(has_streak)`. | Simplest. No cross-signal timing/correlation. Synchronous read at the exact moment #20 needs it. No new signal ordering contract. Matches #20's already-built `has_streak` boolean API 1:1. |
| **(B) Signal + correlation key** | #8 emits `streak_advanced(set_correlation_key)`; #20 buffers `set_complete` keyed by the same key, matches, then staggers. | Needs a shared correlation key contract between #2 `set_logged` and #8, plus same-frame coalescing. Heavier; only worth it if chime must reflect server-confirmed streak state that arrives async. |

**Recommendation**: Route (A). #20's `handle_set_complete(has_streak)` already models exactly this.
#8 owner decides whether streak-advance is known synchronously at set-log time (→ A) or only after a
backend round-trip (→ B). If unknown, ship **AC-EC-S6 fallback** (already done): no #8 → `set_complete`
plays immediately, no stagger, CR-11 logic dormant.

---

## Gate B — SUSPENDED producer (Q-OQ12) — needs technical-director / architecture-review

**Blocks**: Story 010 AC-EC-S9b (real browser `pageshow`/visibilitychange → reconcile wiring). The
#20 side is already built: `GymModeHud.reconcile(pulled_state, dom_visible)` is a pure method with the
SM-C generational defer + SM-B AND guard, fully headless-tested. It just needs a producer to **call it**
(and to drive GSM into/out of SUSPENDED) on real browser lifecycle events.

**Constraint**: `JavaScriptBridge.eval()` is locked to `src/autoload/platform_detect.gd` (ADR-0001 CI:
`check_platform_detect_callers.gd`). So the DOM `visibilitychange`/`pageshow` listener MUST live there.

**Options, with recommendation:**

| Option | Owner | Shape |
|--------|-------|-------|
| **(A) platform_detect emits, GSM consumes ⭐ recommended** | platform_detect.gd + #1 GSM | platform_detect registers the JS `visibilitychange` callback (it already owns JavaScriptBridge) and emits `page_visibility_changed(visible: bool)`. #1 GSM subscribes → transitions to SUSPENDED on hidden / reconciles on visible. #20 already reconciles on resume via its own `state_changed` subscription + `reconcile()`. |
| (B) New web-lifecycle autoload | new system / TD | A dedicated autoload owns browser lifecycle. Heavier; adds an autoload position (ADR-0008) for one concern. |
| (C) #20 self-listens | #20 | Rejected — would require #20 to call JavaScriptBridge (ADR-0001 violation) and would make a Presentation node a lifecycle producer (layer breach). |

**Recommendation**: Option (A). Smallest surface, respects the ADR-0001 JavaScriptBridge lock, keeps
SUSPENDED a GSM-owned state (single source of truth), and #20's `reconcile()` already consumes the
resulting `state_changed`. Needs an ADR addendum or a short foundation story owned by TD.

---

## Pure-external gates (no proposal — human / asset work)

| Gate | Needs |
|------|-------|
| AC-V-1 glance playtest | N=12 human tachistoscope playtest (gym community + OQ-U4 web flash harness). BINDING entry gate per EPIC DoD — or ship deferred-and-tracked per user decision. |
| AC-UX-6/V-5 colorblind · AC-V-2/CR-1/13⑧ shake | Human visual sign-off on rendered-scene screenshots (3 colorblind sims + greyscale + shake figure-ground). Scene now exists (Story 012) — evidence collection can begin. |
| Real art assets | P-04 skill silhouettes + P-11 threat-chevron glyphs (art-director / asset pipeline). Story 012 ships placeholder geometry + correct metadata channels. |
| main-scene CanvasLayer 50 mount | main-scene composition story — instantiate `GymModeHud.tscn` under CanvasLayer 50 (below ScreenEffects 100). |

---

## Summary

- **Resolved this pass**: Q-OQ5 (#2 GDD reciprocity, commit 8ae26f0).
- **Owner-decision gates (proposals above)**: Gate A (#8 owner) · Gate B (TD).
- **Human/asset gates**: playtest · colorblind/shake sign-off · art · main-scene mount.
- #20's code side is **fully built and tested for every gate** — each remaining item is a decision or a
  human action, not missing #20 implementation.
