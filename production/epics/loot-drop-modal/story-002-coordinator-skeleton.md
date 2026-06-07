# Story 002: Coordinator autoload 骨架 + layers + 登記 + GSM trigger

> **Epic**: Loot Drop Modal (#21)
> **Status**: ✅ Complete(2026-06-07 — 5/5 ACs;GUT 9/9 + lint PASS;combined gate 1939/1938/0 fail;commit db8beb4)
> **Layer**: Presentation
> **Type**: Logic
> **Estimate**: M
> **Manifest Version**: 2026-05-29
> **Last Updated**: —

## Context

**GDD**: `design/gdd/loot-drop-modal.md`(Rule 1 / Rule 2 / Rule 13 入口半邊)
**ADR**: ADR-0006 C4/C6(primary)+ ADR-0008(G-LM-5 config 半)+ ADR-0001(layer 數值,story 001 已 pin)
**Engine**: Godot 4.6 | **Risk**: MEDIUM(autoload boot order)

**Control Manifest Rules**:
- Required:`connect_for_initial_state` helper(C6);initial-state sentinel `source_event == "initial_state"`;per-autoload sequential boot(C4)
- Forbidden:`state_changed.connect()` 直連喺 `_ready()`;`.bind()` callable 入 `connect_for_initial_state`(CI error);`GameStateMachine._ready()` emit 假設

## Acceptance Criteria

- [ ] **AC-4**:coordinator `_ready` 後持有 ModalLayer(120)+ CelebrationVFXLayer(110)且係唯一 instantiator;layer 數值 == ADR-0001 pinned(story 001)
- [ ] **AC-5**:fake GSM `state_changed`→LOOT_DROP 且 queue 非空 → modal 開;其他 state / 單獨 `loot_dropped` → 唔開
- [ ] **AC-6**:boot 時 GSM 已喺 LOOT_DROP(force-reveal)→ `connect_for_initial_state` 收 sentinel 並開 modal
- [ ] **AC-7**:modal active 時新 `loot_dropped` → 零 modal 動作(doorbell no-op,無第二 modal / FSM 重入)
- [ ] **AC-79**:`project.godot` — coordinator 位於 predecessor set 全部之後、ZoneSystem 後 tail(#28 keep last)— Static/CI

## Implementation Notes

- `src/autoload/loot_reveal_coordinator.gd`(thin Node);兩個 CanvasLayer `_ready` instantiate + `visible=false` pre-warm(HIDDEN state)。
- `loot_dropped` 訂閱 = doorbell 語意(Rule 2):modal 唔 active 且 GSM==LOOT_DROP → drain head;否則 no-op。**唔自建 wait queue** — deferral 係 GSM Rule 13 own。
- DI seam:GSM/#15 注入用 untyped var(typed Node 會 compile-time member check fail — codebase 慣例)。
- AC-79 CI:boot-order assert 跟 #18 story-002 / ADR-0008 lint 先例(grep `project.godot` autoload section 順序)。

## Out of Scope

- FSM transition table(003);reveal pipeline(006);banner/toast surfaces(013/016)。

## QA Test Cases

GDD AC-4/5/6/7/79 GWT 原文(3-pass verified,qa-plan-import-equivalent)。AC-6 用 C6 sentinel fake(`from==to`,`source_event=="initial_state"`)。

## Test Evidence

**Required**: `tests/unit/loot_reveal/test_coordinator_boot.gd` + AC-79 CI assert。
**Status**: [ ] Not yet created

## Dependencies

- Depends on: 001
- Unlocks: 003–016、022、023、025
