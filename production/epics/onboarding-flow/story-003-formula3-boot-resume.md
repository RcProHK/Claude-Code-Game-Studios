# Story 003: Formula 3 boot-resume state selection

> **Epic**: Onboarding Flow(#27)
> **Status**: Complete
> **Layer**: Polish / Presentation
> **Type**: Logic
> **Estimate**: S
> **Manifest Version**: 2026-05-29
> **Last Updated**: 2026-06-12

## Context

**GDD**: `design/gdd/onboarding-flow.md`(Formula 3 / Rule 7 / States §boot resume / AC-02 / AC-05 / EC-08 / EC-09)
**Requirement**: TR-onboarding-??? (direct GDD trace)

**ADR Governing Implementation**: ADR: N/A — pure decision function（無架構 pattern;boot-resume 由 4 latch 純推導,無浮點）
**ADR Decision Summary**: —

**Engine**: Godot 4.6 | **Risk**: LOW
**Engine Notes**: pure static func,GSM-agnostic,可單獨 unit test（同 #26 `avatar_formulas.gd` / #29 `mirror_moment_formulas.gd` 先例）。

**Control Manifest Rules(this layer)**:
- Required: gameplay/gating logic 為 pure static func（testable,DI over singleton）
- Forbidden: formula 路徑 read singleton state（傳入 4 latch 作參數）
- Guardrail: 決定性 — 同 input 同 output

---

## Acceptance Criteria

- [ ] **AC-02** — GIVEN `step_connect==true` 而 `step_preview==false`,WHEN boot,THEN resume 入 `PREVIEW`(Formula 3 file-backed resume)。
- [ ] **AC-05** — GIVEN `onboarding.completed==true`,WHEN boot,THEN 直入 `DORMANT`(即使某 step latch 因 corruption 為 false — completed-first,EC-08)。
- [ ] **EC-09** — 四 step latch 齊但 `completed` 未寫 → `COMPLETE` → 即補寫 `completed=true` → `DORMANT`(self-heal)。
- [ ] Formula 3 decision tree:DORMANT(completed)→ WELCOME(¬step_connect)→ PREVIEW(¬step_preview)→ COACHING(¬step_class ∨ ¬step_first_drop)→ COMPLETE(else)。

---

## Implementation Notes

*Formula 3(GDD):*
```
resume_state =
    DORMANT   if onboarding.completed
    WELCOME   elif NOT step_connect
    PREVIEW   elif NOT step_preview
    COACHING  elif (NOT step_class) OR (NOT step_first_drop)
    COMPLETE  else   # 四步齊但 completed 未寫 → 補寫 → DORMANT
```
- `src/core/onboarding_formulas.gd` static `resume_state(completed, step_connect, step_preview, step_class, step_first_drop) -> int`(回 FSM enum int)。
- **completed-first 次序 load-bearing**(EC-08 corruption:completed==true 但某 step false → 仍 DORMANT,唔重 onboard)。
- COMPLETE branch 喺 coordinator 接住即補寫 completed(self-heal,story 004 persist)。

---

## Out of Scope

- Story 004: persist 寫入 / read（呢個 story 純 decision func,coordinator wire latch 喺 002/004）。
- Story 005/006: may_show / auto-dismiss formula（唔同 formula）。

---

## QA Test Cases

**AC-02(resume PREVIEW)**:
- Given: completed=false, step_connect=true, step_preview=false
- When: `resume_state(...)`
- Then: == PREVIEW
- Edge cases: step_connect=true/step_preview=true → COACHING(若 class/first_drop 未);全 false → WELCOME

**AC-05 / EC-08(completed-first)**:
- Given: completed=true, step_class=false(corruption)
- When: `resume_state(...)`
- Then: == DORMANT(completed 贏)
- Edge cases: 四 step true + completed=false → COMPLETE(self-heal trigger)

**Determinism**:
- Given: 固定 5-bool input
- When: 多次 call
- Then: 同 output(無時間/隨機)

---

## Test Evidence

**Story Type**: Logic
**Required evidence**: `tests/unit/onboarding_flow/test_onboarding_formula_resume.gd`(全 5 branch + corruption + self-heal)
**Status**: [ ] Not yet created

---

## Dependencies

- Depends on: Story 002（scaffold — FSM enum）
- Unlocks: Story 004（coordinator boot 用 F3 揀 resume state）
