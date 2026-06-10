# Story 005: CR-M3 non-workout presentation gate + #33 soft + LOOT_DROP exclude

> **Epic**: Mirror Moment System (#29)
> **Status**: Ready
> **Layer**: Polish
> **Type**: Integration
> **Estimate**: S
> **Manifest Version**: 2026-05-29
> **Last Updated**: —

## Context

**GDD**: `design/gdd/mirror-moment.md` CR-M3 / FT-M3 / EC-MM-2/16 / States ARMED→PRESENTING
**Requirement**: AC-03 / AC-04(GDD 直接 trace)
**ADR Governing Implementation**: ADR-0006 State Machine Contract(primary — GSM state read)
**ADR Decision Summary**: GSM membership via `get_current_state()`;#29 read-only consumer。

**Engine**: Godot 4.6 | **Risk**: LOW
**Engine Notes**: `GSM.get_current_state() -> GameState`(`game_state_machine.gd:241`)。safe context = `{IDLE}` only。`#33.is_input_permitted()`(Soft — 唔在席則只 GSM gate)。

**Control Manifest Rules (Polish layer)**:
- Required: 呈現只喺 GSM == IDLE;#33 soft 額外 gate;defense-in-depth
- Forbidden: 喺 {WORKOUT_ACTIVE, REST_PERIOD}(Pillar 2)/ {COMBAT, BOSS}/ {LOOT_DROP}/ {BOOTING, DISCONNECTED, SUSPENDED} 呈現
- Guardrail: gate 唔過 → hold ARMED,下次 IDLE 再試(latch 保住)

---

## Acceptance Criteria

- [ ] **AC-03**(FT-M3): cadence window 開 + has_change → GSM ∈ {WORKOUT_ACTIVE, REST_PERIOD, COMBAT_ACTIVE, BOSS_ENCOUNTER, LOOT_DROP, SUSPENDED} → 慶典**唔呈現**,留 ARMED;GSM 轉 IDLE → 先呈現
- [ ] **AC-04**(#33 soft): #33 在席且 `is_input_permitted()==false` → GSM==IDLE 仍 hold(額外 gate);#33 不在席 → 只用 GSM gate 即呈現
- [ ] CR-M3 safe context = `{IDLE}` only;明確排除 workout/combat/loot/not-ready 各 set
- [ ] EC-MM-2:tier-up 喺 set 中(#26 已 defer emit)→ 即使收到 latch only,present gate 仍擋,出 set 入 IDLE 先彈
- [ ] EC-MM-16:LOOT_DROP modal(#21)佔畫面時 window 開 → gate 排除 LOOT_DROP → 留 ARMED,等 #21 收 + IDLE 先彈(唔疊兩 modal)

---

## Implementation Notes

*Derived from CR-M3(Pillar 2 defense-in-depth):*

- ARMED → PRESENTING 轉換要過 CR-M3 gate:`get_current_state() == IDLE` ∧ (#33 不在席 ∨ `is_input_permitted()`)。
- #33 Soft:null-check — 不在席只用 GSM gate(degrade gracefully)。
- gate 唔過 → hold ARMED(latch CR-M4 保住,story 006),下次 GSM state_changed 重評估。
- #26 CR-15 已 defer milestone emit(set 中唔收 trigger)→ 本 gate 係 defense-in-depth(present 端獨立 gate)。

---

## Out of Scope

- Story 003:Formula 1 arm(本 story 係 arm 後 present gate)
- Story 015:transient-IDLE delay(EC-MM-14,stable-IDLE 確認)

---

## QA Test Cases

- **AC-03**: non-workout gate
  - Given: cadence open + has_change
  - When: GSM ∈ {各排除 state}
  - Then: 唔呈現,留 ARMED;GSM==IDLE → 呈現
  - Edge cases: EC-MM-16 LOOT_DROP exclude;EC-MM-2 set-中 latch-only
- **AC-04**: #33 soft gate
  - Given: #33 在席,is_input_permitted false
  - When: GSM==IDLE
  - Then: hold;#33 不在席 → 即呈現
  - Edge cases: #33 null-safe degrade

---

## Test Evidence

**Story Type**: Integration
**Required evidence**: `tests/integration/mirror_moment/present_gate_test.gd` — mock GSM state + mock #33 seam;各排除 state case + #33 null-safe
**Status**: [ ] Not yet created

---

## Dependencies

- Depends on: Story 003(arm → present gate)/ Story 002(FSM)
- Unlocks: Story 007(present → reveal)/ Story 011(present → burst)
