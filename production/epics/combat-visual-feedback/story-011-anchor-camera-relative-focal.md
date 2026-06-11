# Story 011: F5 anchor — camera-relative fixed focal point + jitter (#26 non-dep)

> **Epic**: Combat Visual Feedback(#25)
> **Status**: Complete
> **Layer**: Presentation
> **Type**: Integration
> **Estimate**: S
> **Manifest Version**: 2026-05-29
> **Last Updated**: 2026-06-11

## Context

**GDD**: `design/gdd/combat-visual-feedback.md`(R-17 + Formula 5 + EC-10/19 + AC-18)
**Requirement**: `TR-cvf-011`

**ADR Governing Implementation**: ADR-0001: Web Export Budget Caps(primary)
**ADR Decision Summary**: spawn position = camera-relative fixed focal point(MVP primary);#26 anchor **grep 證實唔存在**(render-only per ADR-0010,零 position/facing API)→ v0.2-only,**非 MVP dep**。

**Engine**: Godot 4.6 | **Risk**: LOW
**Engine Notes**: 經 active Camera2D 將 screen 中下方 → world;jitter RNG(cosmetic,排除 deterministic 斷言;test 用 `ANCHOR_JITTER_PX=0`)。

**Control Manifest Rules (Presentation)**:
- Required: camera-relative focal point = MVP primary path
- Forbidden: 依賴 #26 position/facing API(唔存在)
- Guardrail: jitter cosmetic（唔入 deterministic assertion）

---

## Acceptance Criteria

*From GDD R-17 + Formula 5 + EC-10/19:*

- [x] **AC-18**:route hit(無 #26 anchor + 無 camera)→ particle spawn at finite focal + 無 crash/NaN(test_route_hit_spawns_at_finite_focal_no_crash)
- [x] **Formula 5**:`anchor_base((400,300),+1)==(440,284)`(J=0 deterministic);facing=-1 mirror;vertical upward;knobs 40/-16/24(test_cvf_anchor 4/4)
- [x] **EC-10**:`_avatar` = bare RefCounted 無 `get_render_anchor` → routing 照行(test_avatar_anchor_never_queried,grep-proof #26 render-only)
- [x] **EC-19**:無 active camera → `vp.get_visible_rect().size*0.5` screen-center default,finite Vector2,fail-soft(test_focal_without_camera_is_finite_no_crash)
- [x] 多 enemy jitter:`_rng.randf_range(-J,J)` cosmetic（boot-time RNG,非 per-hit alloc;排除 deterministic assertion per coding-standards)

---

## Implementation Notes

*Derived from ADR-0001 / R-17:*

- `_compute_spawn_pos()`:`focal_base = _camera_relative_focal()`(active Camera2D → world;camera 未 ready → screen-center world default,EC-19)。`facing=+1`(無 #26 facing source)。
- jitter:`Vector2(rng.randf_range(-J,J), rng.randf_range(-J,J))`,純 cosmetic;test 注入 seeded RNG 或 `J=0` 驗 base position(deterministic note)。
- **唔 query #26**(grep 證實 avatar_renderer 無 `get_render_anchor()`);v0.2 若 #26 加 API 先切換(Q-CV4)。

---

## Out of Scope

- Story 009: number pool（消費此 position）
- v0.2: #26 anchor 精確定位 / #14 `get_enemy_render_position`

---

## QA Test Cases

- **AC-18**: camera-relative focal
  - Given: MVP(無 #26 API)+ active Camera2D
  - When: route
  - Then: spawn at camera-relative focal point + 無 crash
  - Edge cases: EC-19 camera 未 ready → screen-center default + fail-soft
- **Formula 5**: base position(deterministic)
  - Given: `focal_base=(400,300), facing=+1, FORWARD=40, VERTICAL=-16, J=0`
  - Then: spawn==(440,284)（無 jitter）
  - Edge cases: J>0 → jitter cosmetic(seeded RNG 驗範圍,唔驗精確值)

---

## Test Evidence

**Story Type**: Integration
**Required evidence**: `tests/unit/combat_visual_feedback/test_cvf_anchor.gd`(Formula 5 base, J=0)+ `tests/integration/combat_visual_feedback/test_cvf_anchor_camera.gd`(AC-18 + EC-10/19)
**Status**: [x] Created + green 2026-06-11 — `test_cvf_anchor.gd` 4/4 + `test_cvf_anchor_camera.gd` 3/3。F5 `anchor_base` + 3 knobs @ formulas;`_focal_point`/`_camera_relative_focal`/`_rng` @ coordinator。cvf suite 62 pass / 1 pending(AC-24)/ 0 fail

---

## Dependencies

- Depends on: Story 009(number pool)
- Unlocks: None
