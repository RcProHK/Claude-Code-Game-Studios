# Story 001: shake/hit_pause/set_motion_intensity API + Input Validation

> **Epic**: Screen Effects System
> **Status**: Complete
> **Layer**: Foundation
> **Type**: Logic
> **Estimate**: M
> **Manifest Version**: 2026-05-29
> **Last Updated**: 2026-06-01

## Context

**GDD**: `design/gdd/screen-effects-system.md`
**Requirement**: `TR-screen-001`
*(Requirement text lives in `docs/architecture/tr-registry.yaml` — read fresh at review time)*

**ADR Governing Implementation**: ADR-0001 (Web Export Budget Caps, **Accepted-structural 2026-05-30**) primary; ADR-0006 Contract 6 secondary
**ADR Decision Summary**: ScreenEffects 係 closed-primitive autoload — `shake(intensity, duration)` + `hit_pause(duration)` + `set_motion_intensity(scale)` 三個 entry，caller 不可繞過去自己改 `Camera2D.offset` / `Engine.time_scale`。Foundation 唔 throw（Pillar 2 frictionless）— invalid input reject + push_warning，唔 crash。

**Engine**: Godot 4.6 | **Risk**: LOW
**Engine Notes**: NaN/INF check 用 `is_finite()`（NOT `== ` 比較）。`shake` intensity clamp [0,1]、duration clamp [0, 0.5s]；`hit_pause` duration [0, 0.12s]；`set_motion_intensity` [0,1]。

**Control Manifest Rules (this layer — Foundation)**:
- Required: 所有 screen-feel effect 過 ScreenEffects API；single mutation funnel `_apply_shake`
- Forbidden: 直接 `Camera2D.offset` / `Engine.time_scale` 改動（CI: `check_screen_effects_callers.gd`）
- Guardrail: Foundation 唔 throw — invalid input fail-loud（push_warning）+ early return

---

## Acceptance Criteria

*From GDD Section H, scoped to this story:*

- [ ] **AC-01** — `shake(0.6, 0.08)` 喺 Active state → 經 `_apply_shake` funnel（Rule 11 single point of truth），`_trauma += 0.6 × _motion_intensity`。
- [ ] **AC-02** — `hit_pause(0.0)` 或 `hit_pause(-0.5)` → reject + push_warning，`_pause_remaining_sec` 不變（EC-03）。
- [ ] **AC-03** — `set_motion_intensity(1.5)` → silent clamp 1.0（NO log，EC-05）；`set_motion_intensity(NaN)` → reject + warning，保留先前 value（EC-04）。
- [ ] **AC-04** — `shake(NaN,d)` / `shake(i,NaN)` / `shake(±INF,...)` → reject + warning + `_rejected_calls += 1`（EC-01 + EC-02）。

---

## Implementation Notes

*Derived from ADR-0001 + GDD Rules 1/2/3/11:*

- 三個 public method funnel：`shake()` → validate → `_apply_shake(intensity, duration)`（single mutation path，Rule 11）。`hit_pause()` / `set_motion_intensity()` 各自 validate。
- Rule 1 validation 次序：`is_finite()` check **先**於 clamp（INF silent-clamp 會 mask caller bug — fail-loud）。
- `hit_pause`：non-positive（≤0）+ NaN/INF → reject（EC-03）。注意：over-ceiling（>0.12）係 valid-but-clamped（Story 004），**唔** increment `_rejected_calls`。
- `set_motion_intensity`：out-of-range [0,1] → silent clamp（EC-05，settings slider 邊界，NO log）；NaN → reject + warning + retain（EC-04）。
- Counter：`_rejected_calls`（malformed input）。注意 lifecycle-state reject（Booting/Suspended，Story 007）係另一條 path，**唔** increment `_rejected_calls`。
- **DI seam（untyped）**：`_shader_sink: Callable`（default = real `RenderingServer.global_shader_parameter_set` wrapper；唔可 override native method — GUT phantom-pass guard）、`_gsm`、`_settings`。Constants：`MAX_OFFSET_PX=4.0`、`MAX_PAUSE_SEC=0.12`、`TRAUMA_EPSILON=0.01`、`MAX_EMIT_DEPTH=0`、`MAX_FRAME_DELTA=0.1`。

---

## Out of Scope

*Handled by neighbouring stories — do not implement here:*

- Story 002: Trauma² decay math（呢個 story 只接收 shake input + accrue trauma）
- Story 003: motion_intensity composition into Formula 2 + clamp combiner（呢度只 store + 基本 funnel）
- Story 004: hit_pause max-remaining + ceiling clamp formula
- Story 007: lifecycle-state reject（Booting/Suspended）+ re-entry guard

---

## QA Test Cases

*Written by qa-lead at story creation. Implement against these — do not invent new cases.*

> **Precondition seams（programmer 必讀）**: `_shader_sink` injectable Callable（spy records last (name,value)；唔可 override native RenderingServer）；counters `_rejected_calls`/`_trauma`/`_pause_remaining_sec`/`_motion_intensity`/`_emit_depth` 為 test-readable member。SUT load：`const SE := preload("res://src/autoload/screen_effects.gd")`（autoload 無 class_name）；`before_each` new SUT + 注入 stub + force `_lifecycle_state = ACTIVE`。push_warning 唔可直接 assert — 用 counter proxy。

- **AC-01**: shake funnels + motion scaling
  - Given: SUT ACTIVE；`_motion_intensity=1.0`；`_trauma=0`；spy `_shader_sink`
  - When: `shake(0.6, 0.08)`
  - Then: `assert_almost_eq(_trauma, 0.6, 0.0001)`；`_rejected_calls==0`；`_emit_depth==0`（funnel entered+exited once）
  - Edge: motion=0.5 baseline 屬 Story 003；呢度只驗 1.0 funnel。Headless: assert `_trauma` member（無 GPU）。

- **AC-02**: non-positive hit_pause rejected
  - Given: SUT ACTIVE；`_pause_remaining_sec=0`
  - When: `hit_pause(0.0)` 然後 `hit_pause(-0.5)`
  - Then: `_pause_remaining_sec==0`；`_rejected_calls==2`
  - Edge: 0.0 係 boundary（rejected）；最小正值（0.001）accepted。push_warning 用 counter proxy。

- **AC-03**: motion_intensity clamp vs reject
  - When: `set_motion_intensity(1.5)` → `_motion_intensity==1.0` AND `_rejected_calls==0`（silent clamp，唔係 reject）
  - When2: `set_motion_intensity(NAN)` → `_motion_intensity==1.0`（保留）AND `_rejected_calls==1`
  - Edge: `(-0.3)` → clamp 0.0 silent；`(0.0)` 係 valid（Reduce Motion full off）非 reject。

- **AC-04**: malformed shake rejected
  - Given: SUT ACTIVE；`_trauma=0`
  - When: `shake(NAN,0.08)`、`shake(0.6,NAN)`、`shake(INF,0.08)`、`shake(-INF,0.08)`
  - Then: `_trauma==0`；`_rejected_calls==4`（每個 malformed call +1）
  - Edge: 兩個 arg position NaN + 兩個 INF sign 全覆蓋；validation 用 `is_finite()` 唔用 `==`。

---

## Test Evidence

**Story Type**: Logic
**Required evidence**:
- `tests/unit/screen_effects/test_screen_effects_api_validation.gd` — must exist and pass（AC-01..04）

**Status**: [ ] Not yet created

---

## Dependencies

- Depends on: None（foundational — 第一個 screen-effects story）
- Unlocks: Story 002（decay）、Story 003（combiner）、Story 004（hit pause）
