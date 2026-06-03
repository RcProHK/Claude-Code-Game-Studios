# Story 001: HUD scaffold + 3-state view + GSM boot wiring

> **Epic**: Gym-Mode HUD (#20)
> **Status**: Ready
> **Layer**: Presentation
> **Type**: Integration
> **Estimate**: M (3-4h)
> **Manifest Version**: 2026-05-29
> **Last Updated**: (set by /dev-story)

## Context

**GDD**: `design/gdd/gym-mode-hud.md` · **UX**: `design/ux/gym-mode-hud.md`
**Requirement**: GDD CR-3 / CR-5 + UX AC-UX-1 / AC-UX-2 (no TR-ID — presentation display, cite GDD/UX AC-IDs)

**ADR Governing Implementation**: ADR-0006 State Machine Contract (primary)
**ADR Decision Summary**: `connect_for_initial_state` sentinel 令 boot 即收 current value(唔空白/stale);#20 唔起第二 state machine,薄 view 3-state(Booting/Active/BannerGate/Suspended)derive GSM,作為 external GSM reader 須同步 generation。

**Engine**: Godot 4.6 (Web Export, Compatibility) | **Risk**: MEDIUM
**Engine Notes**: #20 **唔係 autoload**,喺 main scene instantiate(所有 autoload `_ready()` 已完);CanvasLayer 50(< ScreenEffects 100);`get_current_state()` 係 **method 唔係 `.current_state`**(GDD grep-verified)。

**Control Manifest Rules (Presentation layer)**:
- Required: signal-driven update + pull-on-init;`connect_for_initial_state` for initial-state signals(`stat_changed` CI lint `check_stat_changed_connect.gd` 強制 / `state_changed` / `ability_unlocked`)
- Forbidden: `_process` 每幀 poll state;HUD drive GSM transition(絕不)
- Guardrail: ADR-0001 draw-call budget(常駐 overlay)

---

## Acceptance Criteria

*From GDD + UX spec, scoped to this story:*

- [ ] **AC-CR-3**:`stat_changed(EXP)` push 到 → 只 EXP sub-widget redraw、非 HUD stat_id O(1) early-return、全程無 `_process` 每幀 poll state(data push/pull only)。
- [ ] **AC-UX-1**:HUD ambient 由 GSM 離 BOOTING 到首 frame render ≤ 200ms(含 pull-then-subscribe initial state)。
- [ ] **AC-UX-2**:注入 GSM 9 state,每 state HUD layout 對應 States 矩陣(emphasis/dim/defer/freeze 正確 dispatch)。
- [ ] **AC-CR-5(visibility 部分)**:GSM LOOT_DROP → HP/EXP ○dim、PROG ▽defer、不渲染 loot 文字(input-gate 部分 → Story 006/#33)。
- [ ] 薄 3-state view:Booting 離開時 branch `is_audio_unlocked() ? Active : BannerGate`(SM-D);唔起第二 state machine。

---

## Implementation Notes

*Derived from ADR-0006:*
- HUD root = Control under CanvasLayer 50。`_ready()` **pull-then-subscribe**:先 pull 填 initial UI(GSM `get_current_state()` / #11 `get_stat()` / #9 phase)再 `connect` 收後續 delta。
- 有 initial-state 概念嘅 signal 用 `connect_for_initial_state`(`stat_changed`/`ability_unlocked`/`state_changed`);瞬時 event(`audio_unlocked`/`set_logged`/`phase_changed`)用 plain `.connect` + query pull 補 initial。
- State dispatch:data-driven matrix(GameState → per-element emphasis enum),唔 hardcode if-ladder。emphasis apply 邏輯抽成 `_apply_state_matrix(state)` 純 method 俾 test 注入。
- `_exit_tree()` kill tween + 清 `_pending`(避 dangling)。
- 矩陣真相 = GDD「HUD Element × GSM GameState 顯示矩陣」9 state(BOOTING/DISCONNECTED/IDLE/WORKOUT_ACTIVE/REST_PERIOD/COMBAT_ACTIVE/BOSS_ENCOUNTER/LOOT_DROP/SUSPENDED)。

---

## Out of Scope

- Story 002/003:bar/tween 實作(本 story 只 dispatch visibility)。
- Story 006:banner render + audio gate(本 story 只 branch 到 BannerGate state)。
- Story 008:dim alpha 數值 + DIM_PRODUCT_FLOOR(本 story 只 dispatch ○dim/▽ enum)。
- Story 010:bfcache/resume reconcile + generational guard(本 story 只立 boot branch)。

---

## QA Test Cases

*Inline-authored (full-mode qa-lead spawn skipped per session directive; author has deep GDD context).*

- **AC-CR-3**:
  - Given: `_ready()` 完成、`_process` poll 已禁
  - When: emit `stat_changed(stat_id=EXP)` 一次,再 emit `stat_changed(stat_id=非HUD)` 一次
  - Then: EXP sub-widget redraw count == 1;非HUD stat_id handler O(1) early-return(無 redraw);全 frame 無 `_process` state-poll
  - Edge: 同幀多 stat_id → 各 filter 各 redraw,唔 batch full redraw
- **AC-UX-2**:
  - Given: SUT 注入 stub GSM
  - When: 依次 set 9 個 GameState 並 `_apply_state_matrix(state)`
  - Then: 每 state 嘅 per-element emphasis enum == GDD 矩陣對應值(逐 cell assert)
  - Edge: BOSS_ENCOUNTER → Boss element 出現;非 BOSS → Boss hidden
- **AC-CR-5(visibility)**:
  - Given: GSM LOOT_DROP
  - When: `_apply_state_matrix`
  - Then: HP/EXP emphasis==○dim、PROG==▽、loot 文字 node 不存在/不可見
- **AC-UX-1**:
  - Given: boot harness 計時由 state≠BOOTING 起
  - When: 首 frame render
  - Then: elapsed ≤ 200ms(headless 量 frame budget;真機 ADVISORY)

---

## Test Evidence

**Story Type**: Integration
**Required evidence**: `tests/integration/gym_mode_hud/test_hud_scaffold_state_machine.gd` — must exist and pass (GUT `test_` prefix)
**Status**: [ ] Not yet created

---

## Dependencies

- Depends on: #1 GSM (Ready, autoload) · #11 Stat (merged) · #9 WST (merged) — 全 available
- Unlocks: Story 002-010(全部疊喺 scaffold + matrix dispatch 上)
