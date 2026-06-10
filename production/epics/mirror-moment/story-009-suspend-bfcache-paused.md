# Story 009: CR-M12 suspend/bfcache during ceremony (PAUSED state)

> **Epic**: Mirror Moment System (#29)
> **Status**: Ready
> **Layer**: Polish
> **Type**: Integration
> **Estimate**: S
> **Manifest Version**: 2026-05-29
> **Last Updated**: —

## Context

**GDD**: `design/gdd/mirror-moment.md` CR-M12 / EC-MM-15 / States PAUSED
**Requirement**: AC-18(GDD 直接 trace)
**ADR Governing Implementation**: ADR-0006 State Machine Contract(primary — SUSPENDED)· ADR-0001(bfcache parity)
**ADR Decision Summary**: GSM SUSPENDED handling;bfcache 30s parity 與 #26。

**Engine**: Godot 4.6 | **Risk**: LOW
**Engine Notes**: `BFCACHE_CONTINUE_THRESHOLD_MS`=30000 **== #26 同名 const**(parity)。monotonic delta(negative → safe collapse)。

**Control Manifest Rules (Polish layer)**:
- Required: PAUSED 凍 overlay + 暫停粒子;唔清 window marker(慶典未 dismiss)
- Forbidden: >30s/negative resume 後重彈舊慶典(spam)
- Guardrail: `BFCACHE_CONTINUE_THRESHOLD_MS` parity #26

---

## Acceptance Criteria

- [ ] **AC-18**(CR-M12 / EC-MM-15): 慶典呈現中 GSM SUSPENDED → resume Δ≤30000ms → **續演**;resume Δ>30000ms / negative → **收 overlay + 保 window marker**(唔重彈)
- [ ] CR-M12 PAUSED:PRESENTING + SUSPENDED → pause overlay(凍粒子 + 凍 share-card),唔清 window marker
- [ ] resume ≤30s → PRESENTING(續演);>30s/negative → 收 overlay + 標「呈現過」(保 window marker,防 resume spam)→ DORMANT
- [ ] pending latch 若未呈現過 → 跨 suspend 保住

---

## Implementation Notes

*Derived from CR-M12:*

- PAUSED state(PRESENTING + GSM SUSPENDED):凍 overlay + 暫停 #5 粒子;**唔清 window marker**(未 dismiss)。
- resume delta(monotonic,parity #26 `BFCACHE_CONTINUE_THRESHOLD_MS`=30000):≤30s 續;>30s/negative → 收 overlay + 標呈現過(防 resume spam,EC-MM-15)。
- pending latch 未呈現過 → 跨 suspend 保(同 #26 bfcache parity)。

---

## Out of Scope

- Story 012:正常 dismiss window marker(本 story 係 suspend 特例)
- Story 010:share-card render(本 story 凍/收 overlay)

---

## QA Test Cases

- **AC-18**: suspend resume
  - Given: 呈現中 SUSPENDED
  - When: resume Δ=5000 / 30000 / 30001 / −5000
  - Then: 續演 / 續演 / 收+保marker / 收+保marker
  - Edge cases: pending 未呈現過跨 suspend 保住

---

## Test Evidence

**Story Type**: Integration
**Required evidence**: `tests/integration/mirror_moment/suspend_paused_test.gd` — injected monotonic clock + mock GSM SUSPENDED;boundary Δ table
**Status**: [ ] Not yet created

---

## Dependencies

- Depends on: Story 002(FSM PAUSED)/ Story 010(overlay 凍/收)
- Unlocks: None
