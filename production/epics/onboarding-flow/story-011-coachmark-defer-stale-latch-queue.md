# Story 011: Coach-mark defer loop + stale-latch(max_defer)+ queue order

> **Epic**: Onboarding Flow(#27)
> **Status**: Complete
> **Layer**: Polish / Presentation
> **Type**: Integration
> **Estimate**: M
> **Manifest Version**: 2026-05-29
> **Last Updated**: 2026-06-12

## Context

**GDD**: `design/gdd/onboarding-flow.md`(Rule 4 / AC-13 / EC-12 / EC-13;States §transition discipline)
**Requirement**: TR-onboarding-??? (direct GDD trace)

**ADR Governing Implementation**: ADR-0006: State Machine Contract(primary)
**ADR Decision Summary**: GSM state read 作 gating;4-state shell FSM orthogonal to GSM。

**Engine**: Godot 4.6 | **Risk**: LOW
**Engine Notes**: defer loop 用 injected clock（`coach_max_defer_sec` → int ms;同 Formula 2 clock seam）;single-slot queue（Formula 1 `no_other_coachmark_visible`）。

**Control Manifest Rules(this layer)**:
- Required: workout-critical defer 保持 pending;single coach-mark slot
- Forbidden: 過時教學強推（Pillar 2 — 過時 hand-holding 比唔教仲差）
- Guardrail: max_defer 超時 → silent latch（唔顯示過時）

---

## Acceptance Criteria

- [ ] **AC-13** — GIVEN coach-mark defer 超過 `COACH_MAX_DEFER_MS`,WHEN 仍無非-critical window,THEN **silent latch 該 step**（唔顯示過時教學）(EC-12)。
- [ ] **EC-13** — 兩個 coach-mark trigger 同 frame fire(`dominant_class_changed` + `modal_dismissed`)→ single slot → 按 step order 排隊(class 先於 first-drop),逐個喺非-critical window 顯示。
- [ ] defer loop:pending coach-mark 喺 workout-critical 保持 pending,state 清返先 fade-in 補顯（Formula 1 `may_show` 每 frame 重判）。
- [ ] COACHING → COMPLETE:四 latch 全 set 後收口（AC-04 機制由 story 004,呢度確保 defer/queue 唔阻 latch）。

---

## Implementation Notes

*Derived from ADR-0006 / GDD Rule 4 / EC-13:*

- coordinator `_process`/tick:pending coach-mark queue（step order:connect/class/first-drop）;每 frame `may_show` 判 → 顯示首個 eligible。
- **AC-13 stale-latch**:某 pending 嘅 `shown_eligible_wait_ms` 超 `COACH_MAX_DEFER_MS`（`coach_max_defer_sec`*1000,預設 120000）仍無 non-critical window → **silent latch 該 step**（唔顯示過時）。
- **EC-13 queue order**:同 frame 兩 trigger → single slot,class（step order 前）先顯,first-drop 後;逐個非-critical window。
- injected clock `advance(delta_ms)` 驅 defer timeout（test 可控）。

---

## Out of Scope

- Story 005: may_show formula（呢度用 it 做 defer loop）。
- Story 004: latch persist 機制（呢度 silent-latch 經 004 persist）。

---

## QA Test Cases

**AC-13(stale silent-latch)**:
- Given: pending coach-mark,GSM 長期 workout-critical（defer）
- When: advance clock > COACH_MAX_DEFER_MS 仍無 non-critical window
- Then: 該 step silent latch（唔顯示）;step 完成靠 latch
- Edge cases: boundary（剛好 == max_defer）;defer 期間 clear → 補顯（唔 silent）

**EC-13(queue order)**:
- Given: `dominant_class_changed` + `modal_dismissed` 同 frame fire,GSM=IDLE
- When: tick
- Then: class coach-mark 先顯（step order）;first-drop 後（single slot）
- Edge cases: 第一個 dismiss 後第二個先 show（no_other_coachmark_visible gate）

---

## Test Evidence

**Story Type**: Integration
**Required evidence**: `tests/integration/onboarding_flow/test_defer_queue.gd`（AC-13 + EC-13,FakeGSM critical-toggle + FakeClock）
**Status**: [ ] Not yet created

---

## Dependencies

- Depends on: Story 005（may_show）+ Story 009/010（class/first-drop trigger）
- Unlocks: Story 016（playtest 驗 mid-set 零 coach-mark）
