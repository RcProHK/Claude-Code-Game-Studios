# Smoke Check — Particle System Wrapper (#5) Preset Library

**Date**: 2026-06-01
**Story**: particle-system-wrapper / Story 008 (Preset Library + Visual Spec .tres — Config/Data)
**Engine**: Godot 4.6.3

## Scope

Verify the 9 preset `ParticleProcessMaterial` `.tres` assets load and that `PRESET_TABLE`
is schema-complete, per GDD Visual Spec Table (Rule 13).

## Assets generated

`assets/vfx/presets/` (via `tools/asset-pipeline/generate_particle_presets.gd`, built from the GDD
Visual Spec Table):

| File | Preset | base_count | lifetime_s | z_index | emission_shape |
|------|--------|-----------|-----------|---------|----------------|
| hit_light.tres | HIT_LIGHT | 8 | 0.25 | 5 | POINT |
| hit_heavy.tres | HIT_HEAVY | 18 | 0.40 | 5 | SPHERE |
| parry.tres | PARRY | 14 | 0.35 | 5 | RING |
| death.tres | DEATH | 28 | 0.65 | 5 | SPHERE |
| status_burn.tres | STATUS_BURN | 4 | 0.30 | 4 | BOX |
| status_freeze.tres | STATUS_FREEZE | 5 | 0.45 | 4 | SPHERE |
| status_stun.tres | STATUS_STUN | 6 | 0.50 | 4 | RING |
| loot_burst.tres | LOOT_BURST | 24 | 0.90 | 7 | SPHERE |
| loot_rare_burst.tres | LOOT_RARE_BURST | 48 | 1.60 | 7 | RING |

Each material carries the GDD `color_ramp` (GradientTexture1D), `emission_shape` + shape
param, `spread`, `direction`, `initial_velocity_min/max`, `gravity`, and `damping` (drag).

## Result: PASS

Verified by automated smoke/schema test `tests/unit/particle/test_preset_library.gd`
(6 tests, all passing — combined gate 1220/1221, 0 fail):

- ✅ AC-S1 — all 9 `.tres` load as `ParticleProcessMaterial`; `PRESET_TABLE` has the 9 PresetId keys (set equality).
- ✅ AC-S2 — every entry schema-complete: `base_count`(int), `lifetime`(float), `z_index`(int), `material_path`(String).
- ✅ AC-S3 — spot checks: HIT_LIGHT 8 / 0.25 / z5; z_index discipline combat 5 / status 4 / loot 7; base_count range [4, 48].

## Known deferrals (not blocking)

- **Particle texture**: a GPUParticles2D node property + unproduced art dependency (e.g.
  `spark_sharp.png`). Left null until art lands; materials are texture-agnostic.
- **scale_curve (CurveTexture)**: the GDD per-preset scale-over-lifetime curve is approximated
  via material defaults; full curves land with art polish (follow-up).
- **FR-2 peripheral distinguishability** (LOOT_BURST vs LOOT_RARE_BURST 1-second glance):
  visual playtest — Story 009 (BLOCKED, ADR-0001 hardware ratification).
