# Story 010: Step 4 first-drop framing coach-mark(post-ceremony #21)

> **Epic**: Onboarding Flow(#27)
> **Status**: Complete
> **Layer**: Polish / Presentation
> **Type**: Integration
> **Estimate**: M
> **Manifest Version**: 2026-05-29
> **Last Updated**: 2026-06-12

## Context

**GDD**: `design/gdd/onboarding-flow.md`(Rule 3.4 / Rule 6 / AC-09 / AC-17 / EC-10 / EC-17 — **Pillar 1 + Pillar 3**)
**Requirement**: TR-onboarding-??? (direct GDD trace)

**ADR Governing Implementation**: ADR-0009: Signal Payload Schema(primary)
**ADR Decision Summary**: observe `#21 modal_dismissed` payload minimal+intrinsic。

**Engine**: Godot 4.6 | **Risk**: LOW
**Engine Notes**: `#21 modal_dismissed(drop_id: String, terminal: bool)`（loot_reveal_coordinator.gd:27 verified）。首爆裝 = 真實 `workout_completed` → #15 server-authoritative daily drop（loot-drop-system.md Rule 1-3,`POST /api/game/loot/claim-daily`);onboarding **永不** call #15 / claim daily / client-trigger。

**Control Manifest Rules(this layer)**:
- Required: framing 喺 ceremony **dismiss 之後**（唔疊 #21 sacred surface,Pillar 3）
- Forbidden: 生成/fabricate 首件裝備;call #15 drop-gen / daily-claim / client-trigger（Rule 6,Pillar 1）
- Guardrail: 無 reveal → 待下次,onboarding 唔 nag 唔 fabricate

---

## Acceptance Criteria

- [ ] **AC-09** — GIVEN `COACHING` 且 `step_first_drop==false`,WHEN 首個 `#21 modal_dismissed(terminal=true)` fire,THEN ceremony dismiss **之後** 顯示 first-drop coach-mark、latch `step_first_drop`（唔疊喺 modal 之上）。
- [ ] **AC-17**（must-not-regress）— GIVEN onboarding active,WHEN 任何 step,THEN onboarding **永不** call GSM transition request、**永不** call #15 client-trigger（observe-only,Rule 8 — spy/grep 驗）。
- [ ] **EC-10** — 首件 loot 係 mini-boss drop（非 daily）→ Step 4 照喺首個 `modal_dismissed(terminal=true)` fire（教學係關於爆裝 ceremony,非 drop type）。
- [ ] **EC-17** — 首 workout 但 daily token 已被早一個 workout claim → 無 reveal → `step_first_drop` 唔由此 latch、等下次;**永不** fabricate（Pillar 1）。
- [ ] coach-mark copy「頭先爆嗰件係你真實做嘢換返嚟 — 以後日日做日日有」。

---

## Implementation Notes

*Derived from ADR-0009 / GDD Rule 6:*

- `_on_modal_dismissed(drop_id, terminal)`:首個 `terminal==true` + step_first_drop 未 set → ceremony dismiss **之後** 顯示 first-drop coach-mark、latch。
- **唔疊 sacred surface**（Pillar 3）:fire 喺 `modal_dismissed` 之後（ceremony 已收）— 唔喺 LOOT_DROP state（may_show defer 守）。
- **AC-17 observe-only 命脈**:零 #15 call、零 GSM transition;首件裝備係真 #15 daily drop（onboarding 零干預）。
- **EC-10**:mini-boss 定 daily 一致觸發（教學關於爆裝 moment）。**EC-17**:無 reveal → 唔 latch、等下次、唔 fabricate。

---

## Out of Scope

- Story 011: defer/queue（呢個 story Step 4 trigger;EC-13 two-trigger queue 喺 011）。
- Story 012: G-OB-2 lint 驗 observe-only（呢度 impl;lint 驗 喺 012）。

---

## QA Test Cases

**AC-09(first-drop framing post-ceremony)**:
- Given: FSM=COACHING, step_first_drop=false
- When: `modal_dismissed(drop_id, terminal=true)` 首 fire
- Then: ceremony dismiss 之後顯示 first-drop coach-mark;step_first_drop latched;唔疊 modal
- Edge cases: `terminal=false` 唔 latch;非首個 dismiss 唔重顯（AC-03）

**AC-17(observe-only)**:
- Given: onboarding active 全程
- When: 任何 step
- Then: 零 GSM transition request;零 #15 client-trigger（spy）
- Edge cases: spy #15 claim-daily/drop-gen 未被 call

**EC-10/EC-17(teaching-trigger 邊界)**:
- Given: 首件係 mini-boss drop（EC-10)→ 照 latch;daily token 已 claim（EC-17)→ 無 reveal
- When: observe
- Then: EC-10 latch;EC-17 唔 latch、等下次、唔 fabricate
- Edge cases: 永不為 latch 而 fabricate drop

---

## Test Evidence

**Story Type**: Integration
**Required evidence**: `tests/integration/onboarding_flow/test_step4_first_drop.gd`（AC-09/17 + EC-10/17,Fake#21 modal_dismissed + spy #15）
**Status**: [ ] Not yet created

---

## Dependencies

- Depends on: Story 009（Step 3）
- Unlocks: Story 011（defer/queue + COMPLETE 收口）
