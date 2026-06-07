# Story 019: ARIA announcements + SFX assertions + 48px automated

> **Epic**: Character Screen (#22)
> **Status**: ✅ Complete(2026-06-07)
> **Layer**: Presentation
> **Type**: Integration
> **Estimate**: M
> **Manifest Version**: 2026-05-29
> **Last Updated**: —

## Context

**GDD**: `design/gdd/character-screen.md` — Rules 12/32(command ARIA — Pass 1 ux B6 fix)+ EC-28/29 + §Audio direction(settle dedupe locus / silent 名單 / CD C1)
**Requirement**: direct GDD trace

**ADR Governing Implementation**: N/A — presentation a11y/audio wiring;seam = `platform_detect.announce_aria`(shipped,#21 story-025)
**Engine**: Godot 4.6 | **Risk**: LOW
**Engine Notes**: `get_aria_announcements()` test seam shipped(platform_detect.gd L43)

---

## Acceptance Criteria(GDD AC-41/42/54 + 45a)

- [ ] **AC-41**:avatar significant change → announce 恰好一次;window 內 coalesce 最後一條;非 significant 零;settings:slider settle「[pct]%」一次;clamp hold coalesce
- [ ] **AC-42**:**positive control 先行**(equip settle 1 響 + open/close cue 各 1)→ negative:**完整 silent 名單**(「明文 silent 名單」section)零 SFX;retarget-merge 共 1 響
- [ ] **AC-54**:command 結果 announce(「已裝備 [name]」/「已分解 — +[n] 碎片」/ toast 文字)+ EQUIPMENT settle coalesced stat announce(只列有變 row)
- [ ] **AC-45a**:全部 interactive Control nodes rect/custom_minimum_size ≥48px(automated introspect)

## Implementation Notes

- `ui_equip_settle` dedupe locus = **#22-side settle-frame coalesce**(#4 stateless gateway — audio R2 pin);同 frame N row settle = 1 響
- Force-close / suspend snap 零 SFX(CD C1 — AC-11 已驗,本 story 係 cue wiring 唔好破壞佢)
- ARIA coalesce 共用 `ARIA_COALESCE_WINDOW_MS`(injected clock)

## Out of Scope

- Story 020:真 SR walkthrough(AC-44 manual);audio assets(/asset-spec)

## QA Test Cases

GDD AC-41/42/54/45a GWT embed;`get_aria_announcements()` sink assert;play_sfx spy(同一 instance positive→negative 順序);48px walk 全 tree

## Test Evidence

**Story Type**: Integration
**Required evidence**: `tests/integration/character_screen/test_charscreen_aria.gd` + 45a 喺 lifecycle file
**Status**: [ ] Not yet created

## Dependencies

- Depends on: Story 009 + 015 + 018 + 012(cue 表)
- Unlocks: None(leaf)
