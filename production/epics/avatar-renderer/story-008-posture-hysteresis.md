# Story 008: Formula 4 — posture hysteresis + workout-window lock

> **Epic**: Avatar Renderer (#26)
> **Status**: Ready
> **Layer**: Presentation
> **Type**: Logic
> **Estimate**: S
> **Manifest Version**: 2026-05-29
> **Last Updated**: —

## Context

**GDD**: `design/gdd/avatar-renderer.md` Formula 4 / CR-9 / EC-HYST-1/2/3
**Requirement**: AC-09 / AC-10(GDD 直接 trace)
**ADR Governing Implementation**: N/A — pure formula(hysteresis timing logic);secondary ADR-0006(GSM state read)
**ADR Decision Summary**: N/A(pure deterministic formula);GSM membership via `get_current_state()`。

**Engine**: Godot 4.6 | **Risk**: LOW
**Engine Notes**: cooldown 用 `Time.get_ticks_msec()` **monotonic**(NOT wallclock — EC-HYST-3 DST/NTP immune)。GSM workout window = `{WORKOUT_ACTIVE, REST_PERIOD}`(shipped enum;REST_PERIOD,非 v1 stale REST_BETWEEN_SETS)。

**Control Manifest Rules (Presentation layer)**:
- Required: workout-window lock = `{WORKOUT_ACTIVE, REST_PERIOD}` BOTH states(對齊 CR-15)
- Forbidden: wallclock for cooldown;mid-workout/mid-rest posture swap
- Guardrail: `POSTURE_HYSTERESIS_SECONDS`=300 monotonic cooldown

---

## Acceptance Criteria

- [ ] **AC-09**: GSM==REST_PERIOD + dominant_class jitter → NO sprite swap(workout-window lock cover BOTH WORKOUT_ACTIVE + REST_PERIOD — **Pass-4 F4 drift fix**)
- [ ] **AC-10**: dominant_class jitter within `POSTURE_HYSTERESIS_SECONDS` cooldown(monotonic clock)→ no swap;wallclock backward jump 不影響 cooldown
- [ ] Formula 4:`can_swap = (not workout_window_lock) and (new_class != last_class) and cooldown_elapsed`;`workout_window_lock = gsm_state in {WORKOUT_ACTIVE, REST_PERIOD}`;`cooldown_elapsed = (now_monotonic_ms - last_switch_ms) >= 300*1000`
- [ ] EC-HYST-1:flicker within cooldown → suppress;「would-have-switched」唔 reset cooldown(只 actual swap 先 reset)
- [ ] EC-HYST-2:workout-end while jittering → settle on workout-end snapshot's dominant class;commit;start fresh cooldown
- [ ] EC-HYST-3:wallclock backward(DST/NTP)→ monotonic cooldown 不受影響

---

## Implementation Notes

*Derived from Formula 4(Pass-4 drift fix — 三處對齊 BOTH workout states):*

- **F4 drift fix 命脈**:v1 Formula 4 body 只測 WORKOUT_ACTIVE,但 CR-9/CR-15 排除 BOTH。v2 三處(F4 / CR-9 / CR-15)全部對齊 `{WORKOUT_ACTIVE, REST_PERIOD}`。AC-09 REST_PERIOD case = regression guard。
- cooldown 用 `Time.get_ticks_msec()` monotonic;per-session(boot first-swap exempt — CR-12 無 persisted posture timestamp,該 field v2.1 刪除)。
- 「would-have-switched」唔 reset cooldown(EC-HYST-1)。

---

## Out of Scope

- Story 003:dominant_class 計算(本 story 只 swap timing gate)
- Story 015:實際 sprite resource 切換(本 story 決定「可唔可以 swap」)

---

## QA Test Cases

- **AC-09**: REST_PERIOD lock(drift fix)
  - Given: GSM==REST_PERIOD,dominant_class jitters
  - When: Formula 4
  - Then: no swap(workout-window lock)
  - Edge cases: WORKOUT_ACTIVE 同樣 lock;golden table(400s/IDLE→true;120s/IDLE→false;400s/WORKOUT_ACTIVE→false;400s/REST_PERIOD→false **(v1 bug row)**;same-class→false)
- **AC-10**: monotonic cooldown
  - Given: swap 120s ago,jitter
  - When: Formula 4(monotonic)
  - Then: no swap;wallclock backward jump 唔影響
  - Edge cases: EC-HYST-1 flicker 唔 reset cooldown

---

## Test Evidence

**Story Type**: Logic
**Required evidence**: `tests/unit/avatar_renderer/formula4_hysteresis_test.gd` — must pass;injected monotonic clock;golden table 含 REST_PERIOD lock(F4 drift regression)
**Status**: [ ] Not yet created

---

## Dependencies

- Depends on: Story 003(dominant_class)/ Story 002(GSM state seam)
- Unlocks: Story 015(swap gate feeds sprite resolution)
