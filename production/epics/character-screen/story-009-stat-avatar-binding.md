# Story 009: Stat panel + avatar panel binding + breathing freeze

> **Epic**: Character Screen (#22)
> **Status**: ✅ Complete(2026-06-07)
> **Layer**: Presentation
> **Type**: Integration
> **Estimate**: L
> **Manifest Version**: 2026-05-29
> **Last Updated**: —

## Context

**GDD**: `design/gdd/character-screen.md` — Rules 7/10/11/12(部分)/23 + EC-08..11/16 + F1 wiring;UX spec `design/ux/character-screen.md`(Z2/Z4 STATS layout + watermark 行)
**Requirement**: direct GDD trace

**ADR Governing Implementation**: ADR-0006(signal handling)+ ADR-0009(payload minimal)
**ADR Decision Summary**: `stat_changed` 5-arg payload;source==EQUIPMENT 先 tween。

**Engine**: Godot 4.6 | **Risk**: LOW
**Engine Notes**: `stat_changed(EQUIPMENT)` 喺 command return **之前** synchronous fire(Rule 14 sequencing note)— handler 喺 #22 自己 call stack 內跑

---

## Acceptance Criteria(GDD AC-21..24 + 53)

- [ ] **AC-21**:EQUIPMENT source → row tween + arrow;非 EQUIPMENT → snap 無 arrow;**EQUIPMENT tween 中收非 EQUIPMENT → kill + snap + 清 arrow**(interleave)
- [ ] **AC-22**:aggregate push 4 derived → 4 row 並行獨立 tween,constant duration 同時落定
- [ ] **AC-23**:avatar panel 5 getters 齊(visual/posture「Class:」label/tier/animation/milestone hint);hint 只喺 open + `avatar_visual_updated` evaluate
- [ ] **AC-24**:STATS tween 中 tab 切走切返 → re-read + snap true 值、舊 tween kill 唔 resume
- [ ] **AC-53**:`reduce_camera_motion==true` → breathing freeze 第一 frame + posture instant cut;toggle flip 同 frame 生效;OFF → 恢復

## Implementation Notes

- 「Class: [name]」label — **禁「今日」字眼**(posture 係 stat-derived,#26 L170 Formula 1)
- Watermark dim 行整合(story 006 API);7 stat rows columnar m6x11 右對齊(5-digit width)
- Rule 23 visibility re-read:tab 切返 = re-read 對應 source
- ARIA avatar announcement 屬 story 019;本 story render only

## Out of Scope

- Story 014:loadout panel;Story 019:ARIA/SFX;Story 018:settings panel

## QA Test Cases

GDD AC-21..24/53 GWT embed;mock #11(5-arg emit)+ mock #26(getters + signal);EC-16 mid-session flip 唔追 real-time case

## Test Evidence

**Story Type**: Integration
**Required evidence**: `tests/integration/character_screen/test_charscreen_binding.gd`
**Status**: [ ] Not yet created

## Dependencies

- Depends on: Story 004 + 006 + 008
- Unlocks: Story 014 / 019
