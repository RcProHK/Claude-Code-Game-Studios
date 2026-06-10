# Story 013: Micro-evolution weekly delta (shader-only)

> **Epic**: Avatar Renderer (#26)
> **Status**: Ready
> **Layer**: Presentation
> **Type**: Integration
> **Estimate**: S
> **Manifest Version**: 2026-05-29
> **Last Updated**: —

## Context

**GDD**: `design/gdd/avatar-renderer.md` CR-5b / Formula 3b / Visual C(micro shader)/ FC schema
**Requirement**: AC-15(GDD 直接 trace)
**ADR Governing Implementation**: ADR-0009 Signal Payload Schema(primary — `avatar_micro_evolution(delta_kind, source_metrics)`)
**ADR Decision Summary**: signal payload minimal+intrinsic;cross-cutting context late-bound。

**Engine**: Godot 4.6 | **Risk**: LOW
**Engine Notes**: shader uniform tween(hue/outline/breathing)— shader-only,**NO sprite asset,NO silhouette change,NO tier change**。reduced-motion(`motion_reduction`,#6 owns)→ tween disabled。

**Control Manifest Rules (Presentation layer)**:
- Required: micro = shader-only delta;rolling 7-day stat delta gate;non-workout gate
- Forbidden: micro 改 silhouette / 加 sprite asset / 改 tier
- Guardrail: cadence `MICRO_EVOLUTION_CADENCE_SECONDS`=604800 rolling(anchored account_created_unix)

---

## Acceptance Criteria

- [ ] **AC-15**: rolling 7-day stat delta > 0 + >7 days since last micro → `avatar_micro_evolution` emit;shader uniform tween applied;**ZERO sprite asset / tier change**
- [ ] Formula 3b:`should_micro = (now−last_micro_emit)≥MICRO_EVOLUTION_CADENCE_SECONDS ∧ (rolling_7day_stat_delta>0) ∧ gsm_state ∉ {WORKOUT_ACTIVE, REST_PERIOD}`
- [ ] CR-5b:emit `avatar_micro_evolution(delta_kind, source_metrics)`;visual = shader-only(hue shift / outline brightness / breathing amplitude);NOT gated by tier promotion
- [ ] reduced-motion:`motion_reduction` on → micro shader tween disabled(无 information loss — micro 係 texture 非 tier)

---

## Implementation Notes

*Derived from CR-5b + Formula 3b:*

- micro emit 獨立於 milestone(唔 gate by tier promotion);rolling 7-day stat delta>0 = 「真有訓練先 micro」(honest)。
- shader uniform tween 經 `shader_avatar_outline.gdshader`(hue/outline)+ breathing amplitude;**零 sprite swap**。
- `micro_palette_shift` / `micro_outline_intensity`(AvatarVisualState field)driven。
- reduced-motion gate disable tween(accessibility — information never motion-carried)。

---

## Out of Scope

- Story 012:milestone(tier)emit — 唔同 signal
- Story 015:sprite asset swap(micro 唔 touch sprite)
- shader file 創作(art/shader pipeline — G-AR-5 / asset-spec)

---

## QA Test Cases

- **AC-15**: micro shader-only
  - Given: rolling 7-day delta>0,>7 days since last micro,non-workout
  - When: Formula 3b
  - Then: `avatar_micro_evolution` emit;shader uniform tween;zero sprite/tier change
  - Edge cases: delta==0 → no micro;workout-window → no micro;tier 不變
- **reduced-motion**: tween off
  - Given: motion_reduction on
  - When: micro
  - Then: shader tween disabled;tier/class 仍 readable

---

## Test Evidence

**Story Type**: Integration
**Required evidence**: `tests/integration/avatar_renderer/micro_evolution_test.gd` — injected clock + mock stat delta;assert zero sprite-asset/tier change on micro
**Status**: [ ] Not yet created

---

## Dependencies

- Depends on: Story 002(pipeline)/ Story 009(last_micro_emit persisted)
- Unlocks: None(downstream #29 consumes signal — separate epic)
