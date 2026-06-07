# Story 014: Loadout panel render + lock nudge + AntiSnowball badge

> **Epic**: Character Screen (#22)
> **Status**: ✅ Complete(2026-06-07)
> **Layer**: Presentation
> **Type**: Integration
> **Estimate**: L
> **Manifest Version**: 2026-05-29
> **Last Updated**: —

## Context

**GDD**: `design/gdd/character-screen.md` — Rules 13/18/22(entry map:card 3 zones)+ EC-12 + F4 consumer;UX spec Z4 LOADOUT(component inventory + messaging priority 表)
**Requirement**: direct GDD trace

**ADR Governing Implementation**: ADR-0007(RarityTier badge)secondary;主體 N/A — UI render
**Engine**: Godot 4.6 | **Risk**: LOW
**Engine Notes**: `get_item()` 回 live ref — **read-only-by-discipline**(Rule 14)

---

## Acceptance Criteria(GDD AC-20 full + 27)

- [ ] **AC-20**:open 第一 frame sync read 齊(7 stat + loadout + aggregate + shards + 5 avatar getters,無 loading);4 slot card 三件套(name + P-06 badge + provenance)/ empty-state;aggregate「+0」照 render;F4 badge;LOADOUT 切走切返 re-read
- [ ] **AC-27**:manual equip 成功 + 未 lock → unconditional nudge(advance(LOCK_NUDGE_DURATION_MS) 後消失);**[鎖定] inline tap → set_lock(true) + 變「已鎖定」**;已 lock → 無 nudge
- [ ] Card 3-zone 結構:主體(→inspect,story 016)/「更換」button(→picker,story 017)/ lock toggle — 每 zone ≥48px
- [ ] Nudge = overlay strip 唔推 layout;per-slot 各自一條(stacking pin);backfill note 同款 strip

## Implementation Notes

- AntiSnowball badge:effective amber / raw `ui_amber_dim #A87526`;F4 predicate 用 story 005 API
- 每次 loadout mutation 後 re-read(`get_loadout` — story 010);empty slot:1px dotted outline + silhouette + dim label(L0)
- Forge shards row verbatim int(禁 K/M)

## Out of Scope

- Story 015:command issue/error;Story 016:inspect + salvage;Story 017:picker 內容

## QA Test Cases

GDD AC-20/27 GWT embed(真 #17 + G-CS-1 getters);nudge:injected clock 消失 / inline tap set_lock call assert / lock 後無 nudge;EC-12 {0,0} →「+0」+ badge hidden

## Test Evidence

**Story Type**: Integration
**Required evidence**: `tests/integration/character_screen/test_charscreen_binding.gd`(loadout cases)
**Status**: [ ] Not yet created

## Dependencies

- Depends on: Story 009 + **Story 010(G-CS-1 — AC-20 解封)**
- Unlocks: Story 015 / 016 / 017
