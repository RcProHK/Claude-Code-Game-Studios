# Story 013: 入口 affordance(三態)+ 互斥 arbiter + G-LS-5 #22 遷移

> **Epic**: Login / GymSys Connection UI(Shell)
> **Status**: Ready
> **Layer**: Presentation
> **Type**: Integration
> **Estimate**: M
> **Manifest Version**: 2026-05-29
> **Last Updated**: —

## Context

**GDD**: `design/gdd/login-gymsys-connection-ui.md`(Rule 10/11 + AC-39/40;EC-E4)
**UX Spec**: `design/ux/login-gymsys-connection-ui.md`(LZ-Entry + 入口卡三態 + Component Inventory)
**Requirement**: enabled/hidden/interactive-dimmed 三態 + 中央 request_open arbiter + G-LS-5

**ADR Governing**: ADR-0006(primary — observe-not-subscribe glue)+ N/A(arbiter pattern)
**ADR Decision Summary**: shell 唔 subscribe #22/#23 state（主動 call + `has_method` guard — #22 G-IU-4 glue 紀律）;GSM force-close 唔經 shell。
**Engine**: Godot 4.6 | **Risk**: LOW
**Engine Notes**: `request_open` last-wins pending-target latch（`call_deferred` 內再 call 只覆寫最後目標,唔排隊雙開）;本 project `check_inventory_reentrancy.gd` 證明 reentrancy 已知風險區。

**Control Manifest Rules**:
- Required: `request_open` 主動 call + `has_method` guard（唔 subscribe 對方 state）
- Forbidden: greyed disabled 入口（Rule 10 enabled/hidden 二態;grey 全功能 surface = 細講大話）

---

## Acceptance Criteria

*GDD AC-39 / AC-40:*

- [ ] **AC-39**: DISCONNECTED_SHELL steady-state,render 入口 → #22/#23 卡 `visible==true` + `modulate.a==1.0`（enabled,非 greyed — 對齊 #22 EC-30）。**Race-branch**:`can_open()` 返 false（罕見）→ 卡 `modulate.a==0.55`（interactive-dimmed)但仍 tappable → tap 出 inline reason（唔 force open — EC-E4）。permitted state 零 hidden 入口
- [ ] **AC-40**: #22 open,`request_open(&"inventory")` → #22 close（deferred)→ #23 open;`can_open()` 被查詢（double guard 唔 bypass);false → 唔 force open + log warning（EC-E4）
- [ ] **G-LS-5**: #22 `loadout_view_all_tap` 由直 call #23 → `request_open(&"inventory")`;grep 晒 `_inventory_ui`/`loadout_view_all_tap` 全部 mention（orphan-cleanup）

---

## Implementation Notes

- shell 暴露 `request_open(screen_id: StringName)`:close 現 open screen → `call_deferred` open 目標（last-wins pending-target latch — rapid-tap / 並發 race 防護）。
- 各 screen `can_open()` double guard 保留（defense-in-depth);shell 唔 subscribe #22/#23 state（主動 call + `has_method` guard);GSM force-close 唔經 shell（各 screen 自己 `_on_gsm_state_changed`）。
- 入口卡三態:enabled(a=1.0)/ interactive-dimmed(a=0.55,仍 tappable→inline reason)/ hidden(workout 系,唔 render)。**無 greyed disabled**。alpha ≠ desaturate（desaturate 係 §4.E MoodController 工具）。
- **G-LS-5**：grep `_inventory_ui` / `loadout_view_all_tap` 全 mention,遷移做 `request_open(&"inventory")`（Q-IU1 已承諾,orphan-cleanup 紀律 — fresh-grep 每 mention）。

---

## Out of Scope

- Story 012:DISCONNECTED status/reconnect（本 story 只入口 + arbiter）
- Story 019:AC-UX entry 三態 region 量度（補 UX 層）

---

## QA Test Cases

- **AC-39**: 入口三態
  - Given: DISCONNECTED_SHELL steady-state;When: render;Then: 卡 visible + modulate.a==1.0
  - Edge cases: `can_open()` false race → a==0.55 仍 tappable → inline reason;workout state → 唔 render
- **AC-40**: arbiter 互斥
  - Given: #22 open;When: `request_open(&"inventory")`;Then: #22 close(deferred)→ #23 open;`can_open()` 查詢;false → 唔 force open + log
  - Edge cases: rapid `request_open` → last-wins latch 唔排隊雙開
- **G-LS-5**: 遷移完整
  - Given: grep `loadout_view_all_tap`;Then: 全部 → `request_open(&"inventory")`,零 orphan 直 call #23

---

## Test Evidence

**Story Type**: Integration
**Required evidence**: `tests/unit/login_shell/test_entry_affordance.gd` + `test_shell_arbiter.gd`
**Status**: [ ] Not yet created

---

## Dependencies

- Depends on: Story 004(FSM — SHELL_IDLE/DISCONNECTED_SHELL state);G-LS-5 觸 #22 churn
- Unlocks: None
