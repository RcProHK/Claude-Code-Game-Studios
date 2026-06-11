# Story 009: Formula 1 damage number rise+fade + R-19 Label pool

> **Epic**: Combat Visual Feedback(#25)
> **Status**: Complete
> **Layer**: Presentation
> **Type**: Integration
> **Estimate**: M
> **Manifest Version**: 2026-05-29
> **Last Updated**: 2026-06-11

## Context

**GDD**: `design/gdd/combat-visual-feedback.md`(R-19 + Formula 1 + UI Requirements + AC-29)
**Requirement**: `TR-cvf-009`

**ADR Governing Implementation**: ADR-0001: Web Export Budget Caps(primary)
**ADR Decision Summary**: number host = #25-owned `CombatNumberLayer`(follow-viewport,sort 10-50);Label object pool 自管 `_process` rise+fade(**無 per-label Tween / 無 runtime alloc** — 避 orphan + WASM GC hitch)。

**Engine**: Godot 4.6 | **Risk**: HIGH(ADR-0001 — draw call / fillrate / WASM)
**Engine Notes**: pre-生 `Label` pool size `MAX_CONCURRENT_DAMAGE_NUMBERS=12`,acquire/release;`_process(delta)` 自管 y_offset/alpha;share font atlas(≤16 draw call 峰值);無 `Tween`/`Timer.new()`/`Label.new()` at runtime。

**Control Manifest Rules (Presentation)**:
- Required: Label pool acquire/release + `_process` 自管;follow-viewport layer host
- Forbidden: per-label `Tween` / runtime `Label.new()` / `Timer.new()`(AC-29 grep)
- Guardrail: ≤16 draw call 峰值;ratio clamp[0,1]

---

## Acceptance Criteria

*From GDD R-19 + Formula 1 + AC-29:*

- [x] **AC-19**:13 hit into 12 pool → `_active_numbers`==12(oldest recycle latest-wins)+ newest visible/text="13"(test_pool_oldest_recycle_when_full)
- [x] **AC-20(Formula 1)**:`number_y_offset(0.4)≈-30` + `number_alpha(0.4)==1.0`;`(0.8)→-40,0.0`;robustness clamp(t=2.0→-40/0)+ monotone(test_cvf_number_formula 8/8)
- [x] **AC-29(static)**:`tools/ci/check_cvf_no_runtime_alloc.gd` PASS(0 `GPUParticles2D.new(`/`create_tween(`/`Tween.new(`/`Timer.new(`)+ `test_cvf_ci_lint.gd` test_real_source_has_zero_runtime_alloc
- [x] number host = `CombatNumberLayer`(layer 15,follow_viewport,pre-instantiate 12 Label @ boot,test_pool_pre_instantiated_at_boot);style 由 is_crit flag → NUMBER_COLOR_CRIT/PLAIN
- [x] `_process` 經 F1 clampf ratio(ease_out/smoothstep robustness);_process MAX_FRAME_DELTA clamp;Suspended release-all(test_suspended_releases_all_numbers)

---

## Implementation Notes

*Derived from ADR-0001:*

- pool:`Array[Label]` pre-instantiate 12 個,`_acquire()` 攞 free(或 oldest-recycle)、`_release()` hide。每 frame `_process` 行 active list:`y_offset(t)` + `alpha(t)`(Formula 1),`t≥LIFETIME → release`。
- Formula 1:`y_offset = -RISE_PX × ease_out(clampf(t/LIFETIME,0,1))`,`alpha = 1 - smoothstep(FADE_START, 1, clampf(t/LIFETIME,0,1))`,`ease_out(x)=1-(1-x)²`。
- crit style(story 007 flag):暖橙 + bounce overshoot settle;plain:白 + 1px ink shadow。
- **無 Tween**:rise/fade 全 `_process` 算;AC-29 lint grep #25 source。

---

## Out of Scope

- Story 011: spawn position(F5 anchor)— 本 story 用 fixed test position
- Story 010: overlay(唔同 component)

---

## QA Test Cases

- **AC-20**: Formula 1(deterministic)
  - Given: `RISE_PX=40, LIFETIME=0.8, FADE_START=0.5`
  - When: 算 t=0.4 / t=0.8
  - Then: t=0.4 → y_offset≈-30, alpha==1.0;t=0.8 → y_offset==-40, alpha==0
  - Edge cases: t>LIFETIME → ratio clamp[0,1](唔反彈負)
- **AC-19**: pool recycle
  - Given: 12-full pool
  - When: 第 13 hit
  - Then: oldest recycle + 新 number visible
- **AC-29**: no-alloc grep
  - Given: #25 source
  - Then: 0 `GPUParticles2D.new()` / per-label Tween / `Timer.new()`

---

## Test Evidence

**Story Type**: Integration
**Required evidence**: `tests/unit/combat_visual_feedback/test_cvf_number_formula.gd`(AC-20 pure)+ `tests/integration/combat_visual_feedback/test_cvf_number_pool.gd`(AC-19)+ static lint `tools/ci/check_cvf_no_runtime_alloc.gd`(AC-29)
**Status**: [x] Created + green 2026-06-11 — `test_cvf_number_formula.gd` 8/8 + `test_cvf_number_pool.gd` 4/4(pre-instantiate/recycle/F1-tick-release/suspend-release)+ `check_cvf_no_runtime_alloc.gd` PASS + `test_cvf_ci_lint.gd` AC-29 assert。F1 funcs `number_y_offset`/`number_alpha` + 4 number knobs @ formulas;pool render @ coordinator。cvf suite 45/45。lesson:`_process` MAX_FRAME_DELTA=0.1 clamp → test 要分多 frame tick(唔可一次 0.4)+ fp boundary 留 margin

---

## Dependencies

- Depends on: Story 002(CombatNumberLayer)、Story 007(number style flag)
- Unlocks: Story 011(anchor spawn position)
