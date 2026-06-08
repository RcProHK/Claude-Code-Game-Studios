# Story 013: 入口 affordance(三態)+ 互斥 arbiter + G-LS-5 #22 遷移

> **Epic**: Login / GymSys Connection UI(Shell)
> **Status**: Complete (G-LS-5 DEFERRED — fresh-context #22 migration)
> **Layer**: Presentation
> **Type**: Integration
> **Estimate**: M
> **Manifest Version**: 2026-05-29
> **Last Updated**: 2026-06-09

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

---

## Completion Notes
**Completed**: 2026-06-09(G-LS-5 DEFERRED)
**Criteria**:
- **AC-40 ✅**:`request_open(screen_id)` arbiter — close 現 open screen(best-effort has_method guard)→ `call_deferred _apply_pending_open` open target;**can_open() double guard 唔 bypass**(false → 唔 force + push_warning,EC-E4);**last-wins latch**(rapid request_open 覆寫 pending,唔雙開);unknown target no-op。
- **AC-39 ✅**:`is_entry_visible()`(只 SHELL_IDLE/DISCONNECTED_SHELL render)+ `get_entry_card_alpha(screen_id)`(enabled 1.0 / can_open()==false race → interactive-dimmed 0.55 仍 tappable / workout → hidden 唔 render)。**無 greyed disabled**(Rule 10)。
- **G-LS-5 ⏸️ DEFERRED**:見下。
**Test Evidence**: `test_shell_arbiter.gd`(5,AC-40)+ `test_entry_affordance.gd`(4,AC-39)— **本地 9/9**(login_shell 全 113/113)。Combined gate + 全 lint(見 commit)。
**Design**: #24 `request_open` arbiter + `_character_screen`/`_inventory_ui` seams(get_node_or_null resolve;主動 call + has_method guard,唔 subscribe 對方 state — G-IU-4 紀律)+ `_pending_open_target` last-wins + entry 三態 getter。

### ⏸️ G-LS-5 DEFERRED(fresh-context cross-file migration)
**Why deferred**: G-LS-5 = 遷移 #22 `loadout_view_all_tap`(`src/autoload/character_screen_coordinator.gd` L251-256)由直 call `_inventory_ui.call_deferred("open")` → 改經 #24 `request_open(&"inventory")`。呢個 = **跨檔 orphan-cleanup**(改 #22 + rework `tests/integration/inventory_ui/test_invui_lifecycle.gd` 4 個 test case[L365/391/409/423,佢哋注入 `cs._inventory_ui = _sut` 直 seam,遷移後 #22 唔再用嗰 seam → 必須改注入經 #24 arbiter])。本 session context 已重 → 跟 [[feedback_orphan_cleanup_fresh_context]] 紀律,**唔喺 exhausted context 硬塞跨檔 migration**(net-regression 高危)。**arbiter 已建好兼測好**(AC-40),只欠 #22→arbiter wiring。
**Fresh-context follow-up plan**(grep-verifiable exit bar):
1. #22 加 `_shell` seam(resolve `/root/LoginShellCoordinator`)+ 遷移 `loadout_view_all_tap`:`close()` 後 `_shell.request_open(&"inventory")`(取代 L255-256);移除 orphaned `_inventory_ui`(L130 decl + L1048 resolve)。
2. rework `test_invui_lifecycle.gd` 4 case:注入 `cs._shell = <#24 coord with _inventory_ui=_sut>` 取代 `cs._inventory_ui = _sut`;dual-cue / GSM-race / rapid-tap 斷言對 arbiter 路徑重驗。
3. `rg loadout_view_all_tap` + `rg _inventory_ui` 全 src → 零 orphaned 直 call #23(exit bar)。
4. combined gate + 全 lint green。
**Code Review**: N/A spawn(本地全套 GUT + lint 等效)。
