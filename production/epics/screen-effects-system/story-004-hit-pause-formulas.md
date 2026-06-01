# Story 004: Hit Pause Formulas — max-remaining + ceiling

> **Epic**: Screen Effects System
> **Status**: Complete
> **Layer**: Foundation
> **Type**: Logic
> **Estimate**: S
> **Manifest Version**: 2026-05-29
> **Last Updated**: 2026-06-01

## Context

**GDD**: `design/gdd/screen-effects-system.md`
**Requirement**: `TR-screen-004`
*(Requirement text lives in `docs/architecture/tr-registry.yaml` — read fresh at review time)*

**ADR Governing Implementation**: ADR-0001 (Web Export Budget Caps, **Accepted-structural 2026-05-30**)
**ADR Decision Summary**: Hit pause combiner = max-remaining（no extend, no stack, no queue）：`pause_remaining_new = min(MAX_PAUSE_SEC, max(pause_remaining_old, requested))`。`MAX_PAUSE_SEC=0.12`（DNF 上限 = 2 frame @60Hz；125ms human-detectable threshold 留 5ms margin）。over-ceiling → clamp + push_warning（valid-but-clamped，唔 reject）。

**Engine**: Godot 4.6 | **Risk**: LOW
**Engine Notes**: hit_pause **唔受 motion_intensity 影響**（time perturbation ≠ vestibular）。max-remaining 確保強者 wins、cascade-free。

**Control Manifest Rules (this layer — Foundation)**:
- Required: hit pause max-remaining combiner（bounded by MAX_PAUSE_SEC）
- Forbidden: pause queue / extend / stack（Pillar 2 cascade ban）
- Guardrail: pause ≤ 0.12s（user-detectable freeze threshold）

---

## Acceptance Criteria

*From GDD Section H, scoped to this story:*

- [ ] **AC-10** — `_pause_remaining=0.06` + `hit_pause(0.04)` → `max(0.06, 0.04)=0.06`（no extend；shorter 唔縮短亦唔延長）。
- [ ] **AC-11** — `hit_pause(0.5)` → clamp `MAX_PAUSE_SEC=0.12` + push_warning（AC-D3）。

---

## Implementation Notes

*Derived from ADR-0001 + GDD Rule 8 / Formula 3:*

- `hit_pause(d)`：validate（≤0 / NaN / INF reject — Story 001）；clamp `d_clamped = min(d, MAX_PAUSE_SEC)`，若 `d > MAX_PAUSE_SEC` → push_warning（**唔** increment `_rejected_calls` — valid-but-clamped）；`_pause_remaining_sec = min(MAX_PAUSE_SEC, max(_pause_remaining_sec, d_clamped))`。
- over-ceiling warning 同 reject 唔同：reject（≤0/NaN）係 EC-03 path（Story 001）；clamp（>0.12）係 valid call。
- 注意：entering HitPaused state（`get_tree().paused`）+ `hit_pause_started` signal 係 Story 005（呢個 story 只計 `_pause_remaining_sec` formula）。

---

## Out of Scope

*Handled by neighbouring stories:*

- Story 001: hit_pause input validation（≤0/NaN reject）
- Story 005: HitPaused state entry（`get_tree().paused=true`）+ `hit_pause_started` signal + lifecycle
- Story 003: motion_intensity（hit_pause 唔受影響 — AC-08 喺 Story 003 驗）

---

## QA Test Cases

> **Precondition seams**: `_pause_remaining_sec`/`_rejected_calls` test-readable；`SE.MAX_PAUSE_SEC` constant。push_warning 唔可直接 assert — clamp **value** 係 observable。

- **AC-10**: max-remaining no extend
  - Given: SUT ACTIVE；`_pause_remaining_sec=0.06`
  - When: `hit_pause(0.04)`
  - Then: `assert_almost_eq(_pause_remaining_sec, 0.06, 0.0001)`（shorter 唔縮短亦唔延長；max() wins）
  - Edge: `hit_pause(0.10)` while 0.06 → `max(0.06,0.10)=0.10`（longer DOES win，仍 ≤ MAX）。測兩個方向。

- **AC-11**: ceiling clamp + warning
  - Given: SUT ACTIVE；`_pause_remaining_sec=0`
  - When: `hit_pause(0.5)`
  - Then: `assert_almost_eq(_pause_remaining_sec, 0.12, 0.0001)`（clamp MAX_PAUSE_SEC）
  - Edge: `hit_pause(0.12)` exact → accepted no warning（inclusive max）；`hit_pause(0.1201)` → clamp 0.12 + warning。**over-max 唔 increment `_rejected_calls`**（valid-but-clamped）— assert `_rejected_calls` unchanged。

---

## Test Evidence

**Story Type**: Logic
**Required evidence**:
- `tests/unit/screen_effects/test_screen_effects_hit_pause.gd` — must exist and pass（AC-10, AC-11）

**Status**: [ ] Not yet created

---

## Dependencies

- Depends on: Story 001（hit_pause validation + API）
- Unlocks: Story 005（HitPaused state uses `_pause_remaining_sec`）
