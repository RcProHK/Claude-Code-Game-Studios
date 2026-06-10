# Story 014: get_evolution_snapshot() + read-only API closure (#29 seam)

> **Epic**: Avatar Renderer (#26)
> **Status**: Ready
> **Layer**: Presentation
> **Type**: Integration
> **Estimate**: M
> **Manifest Version**: 2026-05-29
> **Last Updated**: —

## Context

**GDD**: `design/gdd/avatar-renderer.md` CR-11 / AvatarEvolutionSnapshot schema / FC-1/2/3/4 / Ownership Seam table
**Requirement**: AC-13(GDD 直接 trace)
**ADR Governing Implementation**: ADR-0010 Mirror Moment Ownership(primary — the #29 ceremony seam)
**ADR Decision Summary**: #26 owns visible-state/tier/sprite/snapshot/signal(render-only);#29 owns ceremony composition;#26 expose seam **只** `get_evolution_snapshot()` + 2 emit signal;單向 #29→#26。

**Engine**: Godot 4.6 | **Risk**: LOW
**Engine Notes**: `get_visual_state()` 返 `.duplicate()`(no external mutation by ref)。snapshot read-only Resource。

**Control Manifest Rules (Presentation layer)**:
- Required: read-only public API closure(6 getters);snapshot 自足 + read-only
- Forbidden: `set_*/mutate_*/force_*/inject_*` public prefix(CI-3);#26 render ceremony from snapshot
- Guardrail: downstream(#22/#25/#29)read-only;schema frozen(FC-1/2/3/4)

---

## Acceptance Criteria

- [ ] **AC-13**: `get_evolution_snapshot()` → valid `AvatarEvolutionSnapshot {tier, class_posture, sprite_frames path, hero_pose_frame, prior_tier, prior path, source_metrics}` for #29 — 且 **#26 renders NO ceremony from it**
- [ ] CR-11 read-only API closure exactly:`get_visual_state()->AvatarVisualState`(`.duplicate()`)、`get_class_posture()->StringName`、`get_evolution_tier()->int`、`get_animation_state()->StringName`、`is_ready_for_milestone_check()->bool`、`get_evolution_snapshot()->AvatarEvolutionSnapshot`
- [ ] NO `set_*/mutate_*/force_*/inject_*` public surface(CI-3 lint 喺 story 017)
- [ ] `AvatarEvolutionSnapshot` schema(8 field)frozen(FC-3);`source_metrics={stat_total, ability_count, max_class_depth, achieved_at_unix}`(FC-2)
- [ ] #22 Character Screen(shipped)integration seam:verify #22 stub 對 CR-11 API names(`get_visual_state`/`get_class_posture`/`get_evolution_tier` + `avatar_visual_updated` subscribe)

---

## Implementation Notes

*Derived from CR-11 + ADR-0010 ownership seam:*

- `get_evolution_snapshot()` 砌 `AvatarEvolutionSnapshot`(read-only Resource)— expose `hero_pose_frame` index + sprite paths;**唔 render 任何嘢**。#29 decide 9:16 canvas / gradient / ghost offset / divider / badge / share。
- `get_visual_state()` 返 `.duplicate()` 防 external mutation。
- **#22 integration seam**:#22 shipped before #26 — verify #22 read calls 對 CR-11 names(若 #22 用 stub/phantom name → errata,同 G-AR-4 cluster)。
- snapshot 是 #29 唯一 render-state source(coupled pair seam — #29 epic G-MM 接住)。

---

## Out of Scope

- #29 ceremony composition(consumes snapshot — separate epic)
- Story 017:CI-3 no-setter lint + AC-30 zero-ceremony grep
- Story 015:sprite resolution(snapshot 引用 path,resolution 喺 015)

---

## QA Test Cases

- **AC-13**: snapshot valid + zero ceremony
  - Given: avatar at T2 STRIKE
  - When: `get_evolution_snapshot()`
  - Then: valid snapshot 8 field;#26 render no ceremony(grep + behaviour)
  - Edge cases: prior_tier/prior path for ghost;first-ever(prior_sprite=="")
- **CR-11**: API closure
  - Given: public surface
  - When: enumerate
  - Then: exactly 6 getters;`get_visual_state` 返 duplicate;zero setter prefix
  - Edge cases: #22 stub name parity

---

## Test Evidence

**Story Type**: Integration
**Required evidence**: `tests/integration/avatar_renderer/snapshot_api_test.gd` — snapshot field completeness;duplicate-by-value;#22 seam name check
**Status**: [ ] Not yet created

---

## Dependencies

- Depends on: Story 004(tier)/ Story 012(milestone state)/ Story 015(sprite path)
- Unlocks: #29 Mirror Moment epic(coupled pair — consumes this seam)
