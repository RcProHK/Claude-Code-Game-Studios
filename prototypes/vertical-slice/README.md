# Vertical Slice — Mirror Hero (Production Sprint 1)

## Hypothesis being tested
**Is the full core loop achievable end-to-end?** — a mock workout, fed only at the GymSys
seam, should drive the real autoload graph all the way to a loot drop + avatar evolution +
Mirror Moment ceremony, with watchable timing. (The *experiential* "is it fun" half is a
separate human gate — Milestone 1.)

## What's here
| File | What it is |
|------|-----------|
| `vertical_slice_harness.gd` | **Headless** SceneTree harness — boots autoloads, mock-feeds a workout, asserts the loop signal chain fires. Run for a quick wiring proof. |
| `playable_slice.gd` + `PlayableSlice.tscn` | **Playable** scene — drawn placeholder avatar + real Gym-Mode HUD (#20) + live on-screen loop trace + loot-gem pop. A human can WATCH the loop with real timing. Set as `run/main_scene`. |
| `REPORT.md` | The vertical-slice gate report (verdict + traceability + findings). |

## How to run
- **Playable (watch it)**: open the project in Godot 4.6.3 → **F5** (main scene is set), or **F6** on `PlayableSlice.tscn`.
  A mock "push day" workout auto-loops every ~12s: workout → class derives (avatar recolors) →
  workout completes → boss kill → **loot gem pops**. The amber panel (top-left) traces every loop event.
- **Headless self-check**: `godot --headless --path . res://prototypes/vertical-slice/PlayableSlice.tscn`
  (runs one pass, prints the trace, quit 0). Same for `vertical_slice_harness.gd`.

## Status
**Concluded (technical)** — 2026-06-12. Loop wiring PROVEN. Experiential validation pending (Milestone 1, human-gated).

## Findings
- ✅ The full loop is wired: a mock workout produces `dominant_class_changed → STRIKE`,
  `workout_completed_forwarded`, `loot_dropped` (fires NATURALLY via the GSM WORKOUT_ACTIVE→LOOT_DROP
  transition), and `ceremony_presented` (#29). Verified godot 4.6.3 headless EXIT 0.
- 🔴→✅ **Discovered + fixed** a real production gap: `assets/data/exercise_registry.tres` was MISSING
  (phantom-green — ECM unit tests inject a mock registry, so the missing shipped asset never tripped CI;
  the real build degraded every exercise to UNKNOWN, breaking Pillar 4). Authored 30 exercises; verified
  `bench_press=STRIKE / deadlift=CONTROL / squat=MOBILITY`. Full gate after fix: 2969 tests / 0 fail.
- ⚠️ **It is placeholder art on purpose.** The avatar is drawn from primitive shapes, the stage is colored
  rects. It reads as a *prototype skeleton*, not a finished game. The single thing between this and
  "looks like a game" = **real sprites** (`design/assets/entity-inventory.md` → start with avatar T1 STRIKE).
- Render architecture learned (informs production): **view/coordinator split** — `AvatarRenderer` is
  render-only and needs a view to `register_sprite()`; `GymModeHud` is a Control scene that self-wires in
  `_ready()` under CanvasLayer 50; `LootRevealCoordinator` owns its own modal CanvasLayer. There was no
  `main_scene` because no one had assembled the view layer yet — this prototype is that first assembly.

## Note
This is throwaway prototype code (per `.claude/rules/prototype-code.md`). When the real game scene is
built to production standards, this is NOT migrated directly — its findings inform the production scene.
