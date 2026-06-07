# Story 008: Subscription wiring — cfis(#11+GSM)+ plain connect(#26)

> **Epic**: Character Screen (#22)
> **Status**: ✅ Complete(2026-06-07)
> **Layer**: Presentation
> **Type**: Integration
> **Estimate**: S
> **Manifest Version**: 2026-05-29
> **Last Updated**: —

## Context

**GDD**: `design/gdd/character-screen.md` — Rule 8(Pass 1 cfis phantom fix:**#26 plain connect**)+ EC-02(per-owner sentinel timing 表)
**Requirement**: direct GDD trace

**ADR Governing Implementation**: ADR-0006 C6
**ADR Decision Summary**: cfis 兩個 shipped owner(stat_system.gd L445 sync burst ×7 / game_state_machine.gd L271 deferred next-frame callv);#26 從未 expose cfis — initial avatar state 由 Rule 7 open-time 5-getter sync read cover。

**Engine**: Godot 4.6 | **Risk**: LOW
**Engine Notes**: `.bind()` 禁令(StatSystem L450-457 unconditional reject + CI lint)

---

## Acceptance Criteria(GDD AC-18)

- [ ] open 時:#11 + GSM 經 cfis(mock `cfis_call_count` ==1 each + raw `connect()` ==0);#26 plain `connect`
- [ ] open sync read + 同 frame 真 signal 雙到 → render idempotent(同 state 二次 render 無變化)
- [ ] close 時全部 disconnect(AC-15 喺 story 007 — 本 story 提供 wiring)

## Implementation Notes

- Per-owner sentinel timing(EC-02):#11 = connect 嗰下 synchronous burst ×7;GSM = deferred next-frame callv;#26 = sync read + plain connect — test 分開寫
- Handler 全部 plain method(no bind);handler 內 no-op guard 用 story 007 嘅 state check

## Out of Scope

- Story 009:handler 內容(render 邏輯)

## QA Test Cases

GDD AC-18 GWT embed:cfis count introspect / raw connect 零 / idempotent double-delivery;rapid open→close→open 雙 pending lambda case

## Test Evidence

**Story Type**: Integration
**Required evidence**: `tests/integration/character_screen/test_charscreen_lifecycle.gd`(subscription cases)
**Status**: [ ] Not yet created

## Dependencies

- Depends on: Story 007
- Unlocks: Story 009
