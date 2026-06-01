# Visual Evidence — Screen Effects AC-20 (HUD_SHAKES_WITH_WORLD toggle)

**Story**: screen-effects-system / Story 010 (HUD Toggle + CanvasLayer Topology)
**AC**: AC-20 (Visual/Feel — ADVISORY gate)
**Date**: 2026-06-01
**Status**: ⏳ PENDING — deferred to master-scene + art availability

## What AC-20 verifies

`HUD_SHAKES_WITH_WORLD` (default `true`) controls HUDLayer position relative to
ScreenEffectsLayer (GDD Rule 14 topology):

- **true** → `HUDLayer.layer < ScreenEffectsLayer.layer` → HUD pixels shake WITH the world
  (DNF unified feel).
- **false** → `HUDLayer.layer > ScreenEffectsLayer.layer` → HUD pixels stay pixel-sharp
  (readability priority).

## Why pending

ScreenEffects (autoload) owns only the knob constant (`HUD_SHAKES_WITH_WORLD`, single source of
truth) + the shader-uniform shake offset. It does **NOT** own the CanvasLayer topology — the
master scene (GameLayer 0 / ParticleLayer 10 / HUDLayer 50 / ScreenEffectsLayer 100) is
ADR-0001 input scope and not yet scaffolded. The BackBufferCopy + ColorRect post-process shake
pipeline is likewise pending the master scene. Visual co-movement therefore cannot be captured
until those exist.

## Verification protocol (to run when master scene + art land)

1. Boot a scene with HUD (HP bar / timer) + ≥1 world sprite (e.g. combat test scene).
2. Confirm `ScreenEffects.HUD_SHAKES_WITH_WORLD == true`.
3. Trigger a strong shake (debug: `ScreenEffects.shake(1.0, 0.5)`).
4. **true case** — screenshot the shake-peak frame: HUD elements offset together with the world;
   assert `HUDLayer.layer < ScreenEffectsLayer.layer`.
5. Toggle `HUD_SHAKES_WITH_WORLD = false`, repeat: HUD rock-steady, world shakes;
   assert `HUDLayer.layer > ScreenEffectsLayer.layer`.
6. Save the two side-by-side comparison images here + obtain lead sign-off below.

## Sign-off

| Role | Name | Verdict | Date |
|------|------|---------|------|
| Art Director | — | [ ] Approved | — |
| QA Lead | — | [ ] Approved | — |

## Optional headless structural micro-test (not the evidence gate)

When the topology scene exists, a `tests/unit/screen_effects/test_screen_effects_hud_layer_ordering.gd`
can instantiate it and assert the two CanvasLayer `.layer` numeric ordering flips with the knob —
this proves numeric ordering, but visual co-movement still needs the screenshots above.
