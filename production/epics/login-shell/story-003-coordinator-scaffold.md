# Story 003: Coordinator scaffold + 2 CanvasLayer + project.godot tail + file split + cfis connect

> **Epic**: Login / GymSys Connection UI(Shell)
> **Status**: Ready
> **Layer**: Presentation
> **Type**: Integration
> **Estimate**: M
> **Manifest Version**: 2026-05-29
> **Last Updated**: 2026-06-08

## Context

**GDD**: `design/gdd/login-gymsys-connection-ui.md`(Rule 1 + Rule 14 + AC-01/02/27)
**Requirement**: G-LS-1/2 落地 + Rule 1 single-coordinator

**ADR Governing**: ADR-0008(primary — autoload 位置)+ ADR-0001(layer)+ ADR-0006 C6(cfis)
**ADR Decision Summary**: ADR-0008 = project.godot sole ground-truth tail-append;ADR-0001 = LoginShellLayer 62 + ErrorBannerLayer 111;ADR-0006 C6 = GSM subscriber 必用 `connect_for_initial_state`。
**Engine**: Godot 4.6 | **Risk**: LOW
**Engine Notes**: pre-warm `visible=false`(#21/#22/#23 先例);idle 零 draw-call 貢獻。

**Control Manifest Rules**:
- Required: GSM subscriber 用 `connect_for_initial_state(callable)`;autoload boot per-instance sequential(C4)
- Required: file-split pattern = 一個 autoload coordinator + 多個 `src/ui/[system]/` helper file(#22 character_screen_coordinator + src/ui/character_screen/* 先例)
- Forbidden: 第二個 autoload(Rule 1 真約束 — coordinator-owned sub-controller)

---

## Acceptance Criteria

*GDD AC-01 / AC-02 / AC-27:*

- [ ] **AC-01**: `LoginShellCoordinator._ready()` 完成 → 持有 `LoginShellLayer`(layer 62 PAUSABLE)+ `ErrorBannerLayer`(layer 111 ALWAYS),兩個初始 `visible=false`;零第二 autoload;**`src/ui/login_shell/banner_stack.gd` + `shell_transitions.gd` 拆獨立 file 存在**(AC-35a grep target 前提)
- [ ] **AC-02**: 完整 claim success + logout cycle(MockPersistenceLayer 注入於 add_child 前)→ mock `write_calls == 0`(#24 零 persist write)
- [ ] **AC-27**: `_ready()` 用 `connect_for_initial_state` 模式 connect GSM(唔係 plain connect)— boot 即收 current state
- [ ] `project.godot` 登記 `LoginShellCoordinator` tail(InventoryUICoordinator 後;#28 keep last)
- [ ] 內部拆 4 sub-controller(LoginPanel / ConnectionStatus / BannerStack / ShellEntry)— 唔開第二 autoload

---

## Implementation Notes

- `src/autoload/login_shell_coordinator.gd` thin Node;`_ready()` 建兩 CanvasLayer + pre-warm `visible=false`;cfis connect GSM `state_changed`。
- **file split binding**:`src/ui/login_shell/banner_stack.gd` + `shell_transitions.gd` 必須獨立 file(AC-35a grep scope 明確,唔誤殺合法 state-transition cross-fade tween);**AC-35a CI step 必須 assert target file 存在,no-file ≠ no-match**(否則 grep 不存在檔案 = phantom pass)。
- DI seam:autoload 注入 seam 必須**untyped**(typed Node 會 fail compile-time member check — reference_gdscript_di_seam)。
- persistence-consumer test 喺 `add_child` **前**注入 MockPersistenceLayer(真 autoload cache 跨 file 污染 — reference_test_persistence_isolation)。

---

## Out of Scope

- Story 004:shell FSM 5-state 分流邏輯(本 story 只建殼 + connect)
- Story 010:banner stack 內部 severity 機制(本 story 只建 banner_stack.gd 殼)

---

## QA Test Cases

- **AC-01**: coordinator shape
  - Given: `LoginShellCoordinator._ready()` 完成
  - When: 驗 coordinator 持有節點 + file 存在
  - Then: LoginShellLayer(62 PAUSABLE)+ ErrorBannerLayer(111 ALWAYS)兩個 visible=false;`src/ui/login_shell/banner_stack.gd`+`shell_transitions.gd` 存在
  - Edge cases: file 不存在 → fail(no-file ≠ pass)
- **AC-02**: 零 persist write
  - Given: MockPersistenceLayer 注入(add_child 前)
  - When: claim success + logout cycle
  - Then: mock `write_calls == 0`(token write 只來自 MockGymSysClient)
  - Edge cases: 確認 #24 path 零 `PersistenceLayer.write` call
- **AC-27**: cfis GSM connect
  - Given: `_ready()` 執行,spy GSM connection
  - When: 檢查 connect 模式
  - Then: 用 `connect_for_initial_state`(非 plain connect)— boot 即收 current state
  - Edge cases: payload `source_event == "initial_state"` sentinel 識別

---

## Test Evidence

**Story Type**: Integration
**Required evidence**: `tests/unit/login_shell/test_login_shell_coordinator.gd`
**Status**: [ ] Not yet created

---

## Dependencies

- Depends on: Story 002(ADR amendment — layer/位置 授權)
- Unlocks: Stories 004/005/006/007/010/013(全部依賴 coordinator 殼 + 2 layer + cfis)
