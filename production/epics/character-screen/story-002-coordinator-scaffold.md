# Story 002: CharacterScreenCoordinator scaffold + CanvasLayer 60 + autoload 登記

> **Epic**: Character Screen (#22)
> **Status**: ✅ Complete(2026-06-07)— coordinator scaffold(layer 60 PAUSABLE pre-warm hidden + Rule 1 double guard + clean-slate reset + injected clock seam + DI seams)+ project.godot tail 登記;7/7 scaffold tests;combined gate 324scr/2108/2107/0 fail。Lesson:enum 名 `Panel` 撞 Godot native class → `PanelKind`
> **Layer**: Presentation
> **Type**: Integration
> **Estimate**: M
> **Manifest Version**: 2026-05-29
> **Last Updated**: —

## Context

**GDD**: `design/gdd/character-screen.md` — Rule 34(runtime form)+ Rule 8(CLOSED 零-subscription invariant)
**Requirement**: direct GDD trace

**ADR Governing Implementation**: ADR-0008(primary)+ ADR-0001
**ADR Decision Summary**: autoload tail append(story 001 revision 授權);CanvasLayer 60 PAUSABLE。

**Engine**: Godot 4.6 | **Risk**: LOW
**Engine Notes**: CanvasLayer `layer` property + `process_mode = PROCESS_MODE_PAUSABLE`;pre-warm 跟 #21 `loot_reveal_coordinator.gd` pattern(`_ready` instantiate,`visible = false`)

**Control Manifest Rules (Presentation)**:
- Forbidden: 零 Camera2D / GPUParticles2D 直接操作(#22 particle = 0 pinned)
- Guardrail: 60fps / draw calls ≤200

---

## Acceptance Criteria

- [ ] `src/autoload/character_screen_coordinator.gd` 存在:thin Node,`_ready()` instantiate CanvasLayer(layer=60,PROCESS_MODE_PAUSABLE),pre-warm `visible = false`
- [ ] `project.godot` [autoload] 登記:tail append 喺 LootRevealCoordinator 後(boot-order CI 過)
- [ ] Boot 後 invariant:零 active subscription(CLOSED state — Rule 8;upstream signals 零 connect)
- [ ] Public surface:`can_open() -> bool` + `open()` + `close()` stubs(Rule 1 contract — shell 接線點)
- [ ] DI seams:GSM / #17 / #26 / #3 refs untyped var injectable(GDScript DI seam 慣例)+ injected clock `advance(delta_ms)` seam scaffold(GDD AC header binding)

## Implementation Notes

- 跟 `loot_reveal_coordinator.gd` 結構(grep 佢做 reference);#22 layer **冇** ALWAYS 需求(PAUSABLE — IDLE 唔 pause)
- 禁用 engine Tween / SceneTreeTimer 做 state-bearing timing(成個 #22 — injected clock 行 `_process(delta)` → `advance()` 同一 code path)
- cfis handler 必須 plain method(`.bind()` 禁令 — CI lint `check_connect_for_initial_state_bind.gd` 已存在)

## Out of Scope

- Story 007:FSM 實體 states;Story 008:subscriptions;UI scene 內容(後續 stories)

## QA Test Cases

- **Scaffold**: Given boot(headless),When introspect autoload,Then coordinator 存在 + layer node layer==60 + process_mode==PAUSABLE + visible==false + 零 connections
- **Boot order**: Given project.godot,When CI boot-order check,Then #22 喺 LootRevealCoordinator 之後、(future #28)之前

## Test Evidence

**Story Type**: Integration
**Required evidence**: `tests/integration/character_screen/test_charscreen_lifecycle.gd`(scaffold cases)— combined CI gate
**Status**: [ ] Not yet created

## Dependencies

- Depends on: Story 001
- Unlocks: 004/005/006/007(全部 #22-side code)
