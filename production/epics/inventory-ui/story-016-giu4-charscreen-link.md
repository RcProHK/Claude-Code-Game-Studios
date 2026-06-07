# Story 016: G-IU-4 #22「查看全部 →」link + sequential glue + AC-09

> **Epic**: Inventory UI (#23)
> **Status**: Ready
> **Layer**: Presentation
> **Type**: Integration
> **Estimate**: S
> **Manifest Version**: 2026-05-29
> **Last Updated**: —

## Context

**GDD**: `design/gdd/inventory-ui.md` — Rules 1-2(glue locus + 互斥收窄 + 雙 cue 政策)+ EC-11 + G-IU-4 row
**Requirement**: direct GDD trace(AC-09 — G-IU-4 gated)

**ADR Governing Implementation**: ADR-0006(secondary — call_deferred 紀律)
**ADR Decision Summary**: —

**Engine**: Godot 4.6 | **Risk**: LOW
**Engine Notes**: glue = #22 link handler `close()` 後同 gesture `call_deferred` `/root/InventoryUICoordinator.open()`(untyped seam + `has_method` guard)— 「唔互相依賴」收窄為「唔 subscribe 唔讀 state」

**Control Manifest Rules (Presentation)**: #22-side 改動最小化(link row + handler 一段)

---

## Acceptance Criteria

- [ ] #22 LOADOUT panel header「查看全部 →」link(≥48px)+ handler(close → deferred open)
- [ ] **AC-09**:link tap → #22 normal close → #23 open sequential;GSM race → #23 double guard 拒 → 兩邊 CLOSED 無 limbo;雙 cue 各一響(政策 verify)
- [ ] #22 GDD「查看全部 →」row + #22 ux spec Entry/Exit 表加 exit row(doc 同步)
- [ ] **#22 suite 零變紅**(parity — 掂已 merged #22)

## Implementation Notes

- 唔好等 #22 CLOSED 先 open(EC-11 已暗示 same-gesture 即 call — CLOSING×OPENING crossfade 接受,61>60 冚住)
- #24 落地後 glue 遷移(G-IU-4 注記)— 唔使留 TODO 喺 code,doc 有

## Out of Scope

- Shell 入口本體(Q-IU1 — #24)

## QA Test Cases

(= AC-09 GWT;邊界:link tap 時 #23 已 OPEN[double guard no-op]/ rapid double-tap link)

## Test Evidence

**Story Type**: Integration
**Required evidence**: `tests/integration/inventory_ui/test_invui_lifecycle.gd`(link cases)+ #22 suite 重跑
**Status**: [ ] Not yet created

## Dependencies

- Depends on: Story 007(lifecycle suite 通)
- Unlocks: —
