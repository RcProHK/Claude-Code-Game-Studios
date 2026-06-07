# Story 016: Salvage 兩步 friction + ITEM_INSPECT + modal routing

> **Epic**: Character Screen (#22)
> **Status**: ✅ Complete(2026-06-07)
> **Layer**: Presentation
> **Type**: Integration
> **Estimate**: L
> **Manifest Version**: 2026-05-29
> **Last Updated**: —

## Context

**GDD**: `design/gdd/character-screen.md` — Rules 19/20/22(entry map + modal affordances:cancel button / scrim tap / default focus)+ EC-01/07/13(backfill 兩 outcome)/14/15/18/22;UX spec Z5 modals
**Requirement**: direct GDD trace

**ADR Governing Implementation**: ADR-0007(RarityTier)secondary;主體 N/A — UI flow
**Engine**: Godot 4.6 | **Risk**: LOW
**Engine Notes**: salvage equipped = #17 synchronous batch transaction(unequip+SALVAGED+shard+**backfill** — equipment-inventory.md L258)⇒ 同 frame re-read 見 final state

---

## Acceptance Criteria(GDD AC-19/28/29/30/32/34/51)

- [ ] **AC-28**:salvage tap(inspect 內)→ modal:yield preview + provenance + badge;equipped 加「會自動卸下(如有後備會自動補上)」;LEGENDARY signature_text;**無單 tap 毀件 code path**
- [ ] **AC-29**:locked item → inspect 內 salvage 入口 disabled +「上鎖中」hint
- [ ] **AC-30**:兩 scenario —(a)有 candidate → backfill item render +「自動補上」note + 淨變化 tween;(b)無 → empty-state + ↓ tween;+ shards snap
- [ ] **AC-32**:confirm 時 item 已死 → not_found → modal close + toast + 全 panel re-read;#22 零 shards 計算
- [ ] **AC-34**:inspect(經 card 主體 tap)render provenance 全 tier + LEGENDARY signature + salvage 入口;timezone = device local
- [ ] **AC-51**:scrim tap / ESC 第一下 = dismiss = cancel;keyboard default focus = **cancel**;明確 cancel button 存在
- [ ] **AC-19**:ESC modal open → 第一下只 dismiss modal,第二下先 close screen

## Implementation Notes

- Modal 軸:SALVAGE_CONFIRM / ITEM_INSPECT(+ SLOT_PICKER story 017);force-close cancel 行為已喺 story 007(EC-01)— 本 story 接 modal 內容
- EC-14:CJK wrap 優先、死限 ellipsis + inspect 全文;12px floor(AC-43b manual)
- Salvage CTA `#D94B3E` 1px border(唯一紅);無 elastic

## Out of Scope

- Story 017:SLOT_PICKER;Story 020:manual evidence(CJK 截圖)

## QA Test Cases

GDD AC 各條 GWT embed(真 #17);EC-18 yield preview 唯一 stale class = 件唔存在;EC-13 兩 outcome fixture(有/無 candidate)

## Test Evidence

**Story Type**: Integration
**Required evidence**: `tests/integration/character_screen/test_charscreen_commands.gd`(salvage/inspect cases)
**Status**: [ ] Not yet created

## Dependencies

- Depends on: Story 015
- Unlocks: None(leaf)
