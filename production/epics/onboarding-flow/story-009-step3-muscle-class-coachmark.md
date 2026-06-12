# Story 009: Step 3 muscle=class coach-mark + #10 lookup + UNKNOWN defer

> **Epic**: Onboarding Flow(#27)
> **Status**: Complete
> **Layer**: Polish / Presentation
> **Type**: Integration
> **Estimate**: M
> **Manifest Version**: 2026-05-29
> **Last Updated**: 2026-06-12

## Context

**GDD**: `design/gdd/onboarding-flow.md`(Rule 3.3 / AC-08 / AC-20 / EC-11)
**Requirement**: TR-onboarding-??? (direct GDD trace)

**ADR Governing Implementation**: ADR-0009: Signal Payload Schema(primary)
**ADR Decision Summary**: observe payload minimal+intrinsic;cross-cutting context late-bind null-safe。

**Engine**: Godot 4.6 | **Risk**: LOW
**Engine Notes**: `#9 dominant_class_changed(new_class: int)` carry AbilityClass int（可係 UNKNOWN=3 — grep workout_state_tracker.gd:102/200/259 verified）;`#10 get_class_for_exercise(exercise_id: StringName) -> int`（exercise_class_mapping.gd:119）。CF-1 teaching 背景 = #12 ability-system.md L444（`DEFAULT_BASE_STAT=10 ≥ TIER_1_THRESHOLD=10` → 3×TIER_1 auto-unlock;**onboarding 唔計呢個值,純引用**）。

**Control Manifest Rules(this layer)**:
- Required: #10 read-only lookup;class copy data-driven localized
- Forbidden: naming UNKNOWN（無意義）;mutate #10（static config）
- Guardrail: UNKNOWN → 等 known class 或 generic copy,永不「UNKNOWN 着燈」

---

## Acceptance Criteria

- [ ] **AC-08** — GIVEN `COACHING` 且 `step_class==false`,WHEN 首個 `#9 dominant_class_changed(known_class)` fire(非 workout-critical window),THEN 顯示 muscle=class coach-mark(copy 含 #10 `get_class_for_exercise` 對應 class)、latch `step_class`。
- [ ] **AC-20** — GIVEN `dominant_class_changed(UNKNOWN)`,WHEN Step 3 trigger,THEN **唔顯示「UNKNOWN 着燈」**、等 known class（STRIKE/CONTROL/MOBILITY）或 generic copy「你嘅訓練決定你嘅 class」（EC-11）。
- [ ] coach-mark copy「你今日做緊推 → STRIKE 着燈」（class 着色,借 P-06 rarity-color-tier 慣例;class 名明寫 — color-independent）。
- [ ] 早 fire（WELCOME/PREVIEW 期間)→ latch 照 set,coach-mark 喺非-critical window 補顯 或 silent latch（過時則唔推,Pillar 2）。

---

## Implementation Notes

*Derived from ADR-0009:*

- `_on_dominant_class_changed(new_class: int)`:首個 known class（≠ UNKNOWN=3）+ step_class 未 set + may_show → 顯示 class coach-mark（#10 lookup taxonomy → copy）、latch step_class。
- **AC-20 UNKNOWN defer**:`new_class == AbilityClass.UNKNOWN`（3）→ 唔顯示具體 copy,等下個 known class;若全程 UNKNOWN → generic copy 或 silent defer。**永不** naming UNKNOWN。
- class copy data-driven localized（廣東話口語）;class 名明寫（a11y color-independent,顏色 enhancement）。
- CF-1 純作 teaching 背景引用（#12 owns auto-unlock 行為）。

---

## Out of Scope

- Story 010: Step 4 first-drop（呢個 story Step 3）。
- Story 013/014: coach-mark 視覺 / a11y（呢度 trigger + copy 邏輯）。

---

## QA Test Cases

**AC-08(class coach-mark)**:
- Given: FSM=COACHING, step_class=false, GSM=IDLE
- When: `dominant_class_changed(STRIKE)` 首 fire
- Then: 顯示 coach-mark copy 含「STRIKE」（#10 lookup）;step_class latched
- Edge cases: 早 fire（PREVIEW 期間)→ latch + 補顯/silent;非首個 emit 唔重顯（AC-03）

**AC-20(UNKNOWN defer)**:
- Given: FSM=COACHING, step_class=false
- When: `dominant_class_changed(UNKNOWN=3)`
- Then: 唔顯示「UNKNOWN 着燈」;等 known class
- Edge cases: 之後 `dominant_class_changed(CONTROL)` → 顯示 CONTROL copy;全程 UNKNOWN → generic copy 或 silent latch

---

## Test Evidence

**Story Type**: Integration
**Required evidence**: `tests/integration/onboarding_flow/test_step3_class.gd`（AC-08/20,FakeGSM + Fake#9 dominant_class_changed + #10 real/fake lookup）
**Status**: [ ] Not yet created

---

## Dependencies

- Depends on: Story 008（PREVIEW → COACHING）
- Unlocks: Story 010（Step 4）
