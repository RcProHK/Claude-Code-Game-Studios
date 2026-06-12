# Story 006: Formula 2 auto-dismiss + tap-dismiss(injected clock)

> **Epic**: Onboarding Flow(#27)
> **Status**: Complete
> **Layer**: Polish / Presentation
> **Type**: Logic
> **Estimate**: S
> **Manifest Version**: 2026-05-29
> **Last Updated**: 2026-06-12

## Context

**GDD**: `design/gdd/onboarding-flow.md`(Formula 2 / Rule 4 / AC-11 / AC-12)
**Requirement**: TR-onboarding-??? (direct GDD trace)

**ADR Governing Implementation**: ADR: N/A — pure timer function
**ADR Decision Summary**: —

**Engine**: Godot 4.6 | **Risk**: LOW
**Engine Notes**: monotonic clock（`Time.get_ticks_msec()`,wall-clock tamper 免疫）;test seam = **injected clock** `advance(delta_ms)`（#22/#23/#24/#29 先例）。**Integer-ms 紀律**:knob float sec → `int(sec*1000)`,formula 內全 int 比較（去 float boundary-flaky）；formula 路徑唔可直 call `Time.get_ticks_msec()`,必讀注入 clock。

**Control Manifest Rules(this layer)**:
- Required: timing 用 injected clock(testable);integer-ms 比較
- Forbidden: formula 直 call `Time.get_ticks_msec()`(test 不可控)
- Guardrail: tap 即時 dismiss（玩家主導,先於 auto-timer）

---

## Acceptance Criteria

- [ ] **AC-11** — GIVEN coach-mark 顯示中,WHEN `now_ms - shown_at_ms >= COACH_AUTO_DISMISS_MS`(注入 clock advance),THEN coach-mark dismiss（Formula 2）。
- [ ] **AC-12** — GIVEN coach-mark 顯示中,WHEN 玩家 tap-anywhere,THEN 即時 dismiss(先於 auto timer)。
- [ ] Formula 2:`dismissed(t) = tapped OR (now_ms - shown_at_ms >= COACH_AUTO_DISMISS_MS)`;`visible(t) = shown AND NOT dismissed(t)`。
- [ ] `COACH_AUTO_DISMISS_MS = int(coach_auto_dismiss_sec * 1000)`(knob 預設 6.0 → 6000)。

---

## Implementation Notes

*Formula 2(GDD):*
- `src/core/onboarding_formulas.gd` static `is_dismissed(tapped, now_ms, shown_at_ms, auto_dismiss_ms) -> bool` + `is_visible(shown, dismissed) -> bool`。
- knob load:`coach_auto_dismiss_sec` float → `int(*1000)` 一次,formula 全 int。
- coordinator 用 injected clock（`_clock` seam,FakeClock `advance(delta_ms)`）— formula 路徑零直 `Time.get_ticks_msec()`。
- **tap 優先**:`tapped==true` → dismissed true 即使 timer 未到（玩家主導,Pillar 2）。

---

## Out of Scope

- Story 005: may_show gate（顯示閘 — 唔同 formula）。
- Story 013: coach-mark fade transition（`coach_fade_sec` 視覺 — 呢度只 dismiss 邏輯）。

---

## QA Test Cases

**AC-11(auto-dismiss)**:
- Given: shown_at_ms=10000, auto_dismiss_ms=6000, tapped=false
- When: now_ms=16001（advance 6001ms）
- Then: `is_dismissed == true`
- Edge cases: now_ms=15999 → false（未到）;boundary 16000 → true（>= ）

**AC-12(tap 優先)**:
- Given: shown_at_ms=10000, now_ms=12000（未到 timer）, tapped=true
- When: `is_dismissed(...)`
- Then: == true（tap 即走,先於 auto）
- Edge cases: tapped=false same time → false

**Integer-ms determinism**:
- Given: 固定 int ms input
- When: 多次 call
- Then: 同 output;無 float boundary flake

---

## Test Evidence

**Story Type**: Logic
**Required evidence**: `tests/unit/onboarding_flow/test_onboarding_formula_dismiss.gd`（AC-11/12 + boundary + integer-ms,FakeClock）
**Status**: [ ] Not yet created

---

## Dependencies

- Depends on: Story 002（scaffold）
- Unlocks: Story 007-010（coach-mark show/dismiss 用 F2）
