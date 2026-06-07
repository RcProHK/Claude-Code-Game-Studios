# Story 002: InventoryUICoordinator scaffold + FSM fork + CanvasLayer 61 + autoload 登記

> **Epic**: Inventory UI (#23)
> **Status**: Complete
> **Layer**: Presentation
> **Type**: Integration
> **Estimate**: M
> **Manifest Version**: 2026-05-29
> **Last Updated**: 2026-06-07

## Context

**GDD**: `design/gdd/inventory-ui.md` — Rules 1-4(lifecycle)+ States(FSM fork 裁決 + orthogonal 軸 + return-target 表)
**Requirement**: direct GDD trace

**ADR Governing Implementation**: ADR-0008(primary)+ ADR-0001 + ADR-0006
**ADR Decision Summary**: tail append(story 001 授權);CanvasLayer 61 PAUSABLE;C6 cfis + ghost-callv guard 語意跟 #22。

**Engine**: Godot 4.6 | **Risk**: LOW
**Engine Notes**: pre-warm 跟 `character_screen_coordinator.gd` pattern;**FSM = fork #22**(~150-200 行:ScreenState enum + advance() + open/close/_enter_closed + _on_gsm_state_changed)— **header comment cross-ref #22 + divergence 同步註記**(CD binding);剝走 #22-specific(_flush_pending_persist[#23 零 persist]/ _advance_tweens / _advance_settings)

**Control Manifest Rules (Presentation)**:
- Forbidden: 零 Camera2D / GPUParticles2D 直接操作(particle = 0 pinned)
- Guardrail: 60fps / draw calls ≤200

---

## Acceptance Criteria

- [x] `src/autoload/inventory_ui_coordinator.gd` 存在:thin Node,CanvasLayer(layer=61,PAUSABLE),pre-warm `visible=false`
- [x] FSM fork:五態 + timing knobs reuse `char_screen_timing_config.gd`(preload — 唔搬家唔 rename)+ injected clock `advance(delta_ms)` seam + ghost-callv guard(CLOSED no-op)
- [x] Orthogonal 軸 scaffold:`active_section` / `slot_filter` / `modal` / `make_room_pending` + clean-slate reset(open 時全 reset 含 pending — Rule 3)
- [x] `project.godot` 登記:tail append CharacterScreenCoordinator 後(boot-order CI 過)
- [x] Boot invariant:零 active subscription;public surface `can_open()` / `open()` / `close()`;DI seams(GSM / #17 untyped var injectable)

## Implementation Notes

- Fork 唔係 extract(CD 裁決 — extraction ADR 留 #24);兩邊 divergence 要同步嘅位喺 header comment 列明
- 禁 engine Tween / SceneTreeTimer 做 state-bearing timing;cfis handler plain method(`.bind()` 禁令 CI lint 已存在)
- Rule 5 data reads **唔喺本 story**(story 006 — G-IU-1 後)

## Out of Scope

- Story 003:G-IU-1 getters;Story 006:binding;Story 007:lifecycle AC suite

## QA Test Cases

- **Scaffold**: Given boot(headless),When introspect,Then coordinator 存在 + layer==61 + PAUSABLE + visible==false + 零 connections
- **Boot order**: Given project.godot,When CI boot-order check,Then #23 喺 CharacterScreenCoordinator 之後
- **Clean-slate**: Given 軸亂晒 + pending set,When close→open,Then 全 reset(INVENTORY/ALL/NONE/&"")

## Test Evidence

**Story Type**: Integration
**Required evidence**: `tests/integration/inventory_ui/test_invui_lifecycle.gd`(scaffold cases)— combined CI gate
**Status**: [x] Created — 13 tests 全 pass;combined gate GREEN 2260/2259 pass/0 fail(+13 精確對數,2026-06-07)

## Dependencies

- Depends on: Story 001
- Unlocks: 004/005/007(#23-side code);006 另需 003

## Completion Notes

**Completed**: 2026-06-07
**Criteria**: 5/5 passing
**Deviations**: None — FSM fork 照 #22 spec,剝走部分(persist/tweens/settings)+ divergence list 喺 FORK NOTICE header(CD binding 兌現);timing config 真實路徑 = `src/ui/character_screen/char_screen_timing_config.gd`(story 引用嘅 filename 無 path — 已確認唔搬家)
**Test Evidence**: `tests/integration/inventory_ui/test_invui_lifecycle.gd` — 13 tests(boot shape ×2 / boot order / whitelist ×2 / clean-slate / FSM ×2 / force-close / SUSPENDED / banner / ghost / OPENING abort)
**Code Review**: Complete — LP-CODE-REVIEW degraded inline APPROVED;QL-TEST-COVERAGE degraded inline ADEQUATE(spawn 1M-credit block 持續)
