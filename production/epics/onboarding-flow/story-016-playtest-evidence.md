# Story 016: Playtest evidence(AC-14 mid-set + AC-24 fantasy)

> **Epic**: Onboarding Flow(#27)
> **Status**: Complete
> **Layer**: Polish / Presentation
> **Type**: Visual/Feel
> **Estimate**: S（protocol authoring;playtest execution = external human gate）
> **Manifest Version**: 2026-05-29
> **Last Updated**: 2026-06-12

## Context

**GDD**: `design/gdd/onboarding-flow.md`(AC-14 / AC-24 — ADVISORY playtest)
**Requirement**: TR-onboarding-??? (direct GDD trace)

**ADR Governing Implementation**: ADR: N/A — ADVISORY playtest（Testing Standards:Visual/Feel = screenshot + sign-off,ADVISORY gate）
**ADR Decision Summary**: —

**Engine**: Godot 4.6 | **Risk**: LOW
**Engine Notes**: ADVISORY — protocol authored this story,playtest execution = external human gate（真新玩家首 session;同 #29 story 016 / #25 playtest 先例）。

**Control Manifest Rules(this layer)**:
- Required: Visual/Feel evidence = screenshot + lead sign-off（ADVISORY）
- Forbidden: 假綠 — playtest 未做就 `pending()` honest,唔 assert-true
- Guardrail: protocol 可執行（falsifiable pass condition）

---

## Acceptance Criteria

- [ ] **AC-14**（ADVISORY playtest）— GIVEN 真實 mid-set,WHEN 觀察成個 set 期間,THEN **零 coach-mark 出現**（Pillar 2 falsifiable — 人手 / 截圖驗）。
- [ ] **AC-24**（ADVISORY playtest）— GIVEN 真新玩家首 session,WHEN 完成連接→preview→首 workout→首爆裝,THEN 事後問卷顯示玩家**唔覺有過 tutorial**、能自述 auto-combat / muscle=class / 爆裝三個概念（Pillar 2 fantasy 驗）。
- [ ] playtest protocol authored（setup / 觀察點 / falsifiable pass condition）;execution deferred（external human gate）。

---

## Implementation Notes

*ADVISORY playtest protocol(同 #29 FT / #25 先例):*

- `production/qa/evidence/onboarding-playtest-protocol.md`:
  - **AC-14**:setup = 真新玩家做一整個 real set（GSM WORKOUT_ACTIVE）;觀察 = 成個 set 期間截圖;pass = 零 coach-mark frame。
  - **AC-24**:setup = 真新玩家首 session 全程;觀察 = 事後問卷（「有冇覺得睇咗 tutorial?」+ 「能唔能自己講 auto-combat / 練乜變乜 / 幾時爆裝?」）;pass = 唔覺 tutorial + 三概念能自述。
- execution = external human gate（protocol-authored,playtest deferred — `pending()` honest,唔假綠）。

---

## Out of Scope

- Story 011: defer 機制（AC-14 靠 011 defer 邏輯;呢度人手驗結果）。
- 全部 BLOCKING AC（已喺 001-015 自動 test gate）。

---

## QA Test Cases

**AC-14(mid-set 零 coach-mark)**:
- Setup: 真新玩家做一整個 real set（GSM=WORKOUT_ACTIVE）
- Verify: 成個 set 期間截圖
- Pass condition: 零 coach-mark frame（Pillar 2 falsifiable）

**AC-24(fantasy — 唔覺 tutorial)**:
- Setup: 真新玩家首 session 全程（connect→preview→workout→爆裝）
- Verify: 事後問卷
- Pass condition: 玩家唔覺有過 tutorial + 能自述 auto-combat / muscle=class / 爆裝三概念

---

## Test Evidence

**Story Type**: Visual/Feel
**Required evidence**: `production/qa/evidence/onboarding-playtest-protocol.md`（protocol authored）+ playtest sign-off（external human gate,deferred）
**Status**: [ ] Not yet created（protocol authored;execution deferred — ADVISORY）

---

## Dependencies

- Depends on: Story 011（defer 邏輯 — AC-14 驗結果）+ 全 step stories（AC-24 全流程）
- Unlocks: None（epic 收口 ADVISORY）
