# Story 007: Re-entry Guard + Suspended State + bfcache Hardening

> **Epic**: Screen Effects System
> **Status**: Complete
> **Layer**: Foundation
> **Type**: Integration
> **Estimate**: M
> **Manifest Version**: 2026-05-29
> **Last Updated**: 2026-06-01

## Context

**GDD**: `design/gdd/screen-effects-system.md`
**Requirement**: `TR-screen-007`, `TR-screen-008`
*(Requirement text lives in `docs/architecture/tr-registry.yaml` — read fresh at review time)*

**ADR Governing Implementation**: ADR-0001 (Web Export Budget Caps, **Accepted-structural 2026-05-30**) primary; ADR-0006 Contract 6 secondary
**ADR Decision Summary**: Re-entry guard `_emit_depth` counter，`MAX_EMIT_DEPTH=0`（strict — 第一個 nested call 已 drop）。GSM `state_changed → Suspended` 強制 cancel-all（trauma=0, pause=0, uniform ZERO, paused=false）+ reject 後續。bfcache resume（`NOTIFICATION_APPLICATION_RESUMED`）force reset；`_process` delta clamp `MAX_FRAME_DELTA=0.1`。Booting state silent reject（唔 increment counter）。

**Engine**: Godot 4.6 | **Risk**: MEDIUM
**Engine Notes**: re-entry 經 injectable `_shader_sink` callable 觸發（唔 override native method）。Suspended 覆蓋一切（per locked Player Fantasy）。bfcache delta clamp 需 observable `_last_clamped_delta`（test 驗證 clamp 真係用咗 0.1 唔係大 delta）。`_gsm` untyped DI seam。

**Control Manifest Rules (this layer — Foundation)**:
- Required: Suspended force-reset；bfcache delta clamp；re-entry depth guard
- Forbidden: lifecycle-state reject increment `_rejected_calls`（distinct from input reject）
- Guardrail: bfcache resume 無殘留 shake（Falsifiable Test #5）

---

## Acceptance Criteria

*From GDD Section H, scoped to this story:*

- [ ] **AC-16** — `_emit_depth=0`，`_apply_shake` callback 內再 invoke `_apply_shake` → reject + warning + `_dropped_by_depth_guard += 1`（MAX_EMIT_DEPTH=0 strict）。
- [ ] **AC-17** [Falsifiable #5] — GSM `state_changed → Suspended` during active shake（trauma=0.5, pause=0.03）→ trauma=0, pause=0, uniform `Vector2.ZERO`, `get_tree().paused=false`, state=SUSPENDED。
- [ ] **AC-18** [Falsifiable #5] — bfcache resume `NOTIFICATION_APPLICATION_RESUMED` → 無殘留 shake offset；無 pending hit_pause；delta clamp `MAX_FRAME_DELTA=0.1`（EC-12）。
- [ ] **AC-19** — Booting state（before `_ready` 完成）→ `shake()` / `hit_pause()` / `set_motion_intensity()` → silent reject；`_rejected_calls` **唔** increment（EC-07）。

---

## Implementation Notes

*Derived from ADR-0001 + GDD Rules 12/13 / EC-07/08/10/11/12/19:*

- Re-entry：`_apply_shake` entry `_emit_depth += 1`、exit `-= 1`；entry 若 `_emit_depth > MAX_EMIT_DEPTH(0)` → `_dropped_by_depth_guard += 1` + push_warning + return（outer call 仍成功，只 drop nested）。
- Suspended：`_on_gsm_state_changed`（`connect_for_initial_state`，Story 008）→ to==SUSPENDED → `_trauma=0; _decay_rate=0; _pause_remaining_sec=0; _emit_depth=0; if get_tree().paused: get_tree().paused=false; _shader_sink.call("u_shake_offset", Vector2.ZERO); _state=SUSPENDED`。非-Suspended（from Suspended）→ `_state=Active`。
- bfcache：`_notification(NOTIFICATION_APPLICATION_RESUMED)` + `NOTIFICATION_WM_WINDOW_FOCUS_IN` → force reset（同 Suspended-exit reset）。`_process` 入口 `var clamped := min(delta, MAX_FRAME_DELTA); _last_clamped_delta = clamped`（observable for test）。
- Booting：`_state == Booting`（before `_ready` done）→ API silent reject（`_rejected_calls` 唔動 — EC-07，distinct from input-reject Story 001）；`set_motion_intensity` 保留 default。

---

## Out of Scope

*Handled by neighbouring stories:*

- Story 008: `connect_for_initial_state` boot wiring（呢度用 handler，subscription 喺 008）
- Story 002: per-frame decay（呢度用 delta clamp 餵 decay）
- Story 005: HitPaused（Suspended 覆蓋 HitPaused — 呢度驗 reset）

---

## QA Test Cases

> **Precondition seams**: `_shader_sink` spy（re-entry via 注入 sink callable 觸發，唔 override native）；`_gsm` untyped stub；`_clock` 供大 delta；`_last_clamped_delta` observable（AC-18 必須）；counters `_dropped_by_depth_guard`/`_rejected_calls`/`_emit_depth`/`_trauma`/`_pause_remaining_sec`/`_lifecycle_state`。after_each restore `get_tree().paused=false`。

- **AC-16**: re-entry depth guard
  - Given: SUT ACTIVE；`_emit_depth=0`；MAX_EMIT_DEPTH=0；spy `_shader_sink` 嘅 callable 內 re-enter `_sut.shake()` 一次
  - When: `_sut.shake(0.5, 0.08)`（outer 入 funnel，sink callback 嘗試 re-enter）
  - Then: `_dropped_by_depth_guard==1`（nested rejected）；`_emit_depth==0`（unwound）
  - Edge: outer call 本身成功（trauma accrues）；只 nested drop。re-entry 經 injectable sink，唔 override native。

- **AC-17**: Suspended cancel-all
  - Given: SUT ACTIVE；`_trauma=0.5`；`_pause_remaining_sec=0.03`；`get_tree().paused=true`；`_gsm` stub；spy
  - When: 觸發 SUT 嘅 GSM handler → Suspended（`_sut._on_gsm_state_changed(GameState.SUSPENDED)` — match real handler name）
  - Then: `_trauma==0`；`_pause_remaining_sec==0`；`spy.last_value==Vector2.ZERO`；`get_tree().paused==false`；`_lifecycle_state==SE.LifecycleState.SUSPENDED`
  - Edge: 5 個 outcome 全驗（hard cancel）。after_each restore paused。

- **AC-18**: bfcache resume + delta clamp
  - Given: SUT resumed；`_clock` 報大 delta（8.0s）；`_trauma=0.5` pre-resume
  - When: `_sut._notification(NOTIFICATION_APPLICATION_RESUMED)` 然後 `_sut._process(8.0)`
  - Then: `_trauma==0`；`_pause_remaining_sec==0`；`assert_almost_eq(_last_clamped_delta, 0.1, 0.0001)`（clamp 用 0.1 唔係 8.0）
  - Edge: EC-12 — 無 clamp 8s delta 會 jump physics。**需 observable `_last_clamped_delta`**（flag programmer expose；否則只能間接驗）。`_notification` 可 headless 直接 send。

- **AC-19**: Booting silent reject
  - Given: SUT `_lifecycle_state = BOOTING`（呢個 test 唔 force ACTIVE）
  - When: `shake(0.6,0.08)`；`hit_pause(0.06)`；`set_motion_intensity(0.5)`
  - Then: `_trauma==0`；`_pause_remaining_sec==0`；`_rejected_calls==0`（EC-07 silent，distinct from AC-04 input-reject）
  - Edge: 關鍵分別 — input-reject（AC-02/04）increment counter；lifecycle-state reject 唔 increment。`set_motion_intensity` 喺 Booting → 保留 default（1.0）。

---

## Test Evidence

**Story Type**: Integration
**Required evidence**:
- `tests/integration/screen_effects/test_screen_effects_reentry_suspend.gd` — must exist and pass（AC-16, 17, 18, 19）

**Status**: [ ] Not yet created

---

## Dependencies

- Depends on: Story 001（API + funnel）、Story 002（decay 用 clamped delta）、Story 005（Suspended 覆蓋 HitPaused）
- Unlocks: Story 008（GSM subscription wiring）
