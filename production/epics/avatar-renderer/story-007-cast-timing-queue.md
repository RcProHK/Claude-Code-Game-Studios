# Story 007: Cast timing + 1-deep queue

> **Epic**: Avatar Renderer (#26)
> **Status**: Ready
> **Layer**: Presentation
> **Type**: Logic
> **Estimate**: M
> **Manifest Version**: 2026-05-29
> **Last Updated**: —

## Context

**GDD**: `design/gdd/avatar-renderer.md` CR-10 / Visual B / EC-ANIM-1/2/5 / EC-SIG-2 / INV-2
**Requirement**: AC-07(GDD 直接 trace)
**ADR Governing Implementation**: ADR-0009 Signal Payload Schema(secondary — `avatar_cast_dropped` telemetry)· N/A primary(pure timing logic)
**ADR Decision Summary**: signal payload minimal+intrinsic;`avatar_cast_dropped(ability_id)` telemetry。

**Engine**: Godot 4.6 | **Risk**: LOW
**Engine Notes**: timing 用 injected clock seam(test determinism);`#12.ability_cast(ability_id, caster, target)`。

**Control Manifest Rules (Presentation layer)**:
- Required: `CAST_QUEUE_DEPTH`=1;hard window uninterruptible;timing constants from knobs
- Forbidden: queue depth >1(thrash);interrupt during hard window
- Guardrail: onset ≤100ms;INV-2 `CAST_HARD_WINDOW_MS(300) < CAST_TOTAL_MS(500)`;`POSTURE_HYSTERESIS_SECONDS*1000 ≥ CAST_TOTAL_MS`

---

## Acceptance Criteria

- [ ] **AC-07**: 2nd cast within 300ms hard window → queued(depth 1);3rd → drop oldest + emit `avatar_cast_dropped(ability_id)`
- [ ] CR-10:(a) onset ≤100ms(`play("cast")` sync);(b) `CAST_HARD_WINDOW_MS`=300 uninterruptible;(c) wind-down to `CAST_TOTAL_MS`=500 interruptible by queue release;(d) `CAST_QUEUE_DEPTH`=1
- [ ] EC-ANIM-1:cast twice within 50ms → 2nd 入 1-deep queue;full → drop newest + `cast_queue_overflow`
- [ ] EC-ANIM-2:new cast during hard window → buffer 1-deep,play on `animation_finished`;3rd → drop oldest(most-recent intent wins)
- [ ] EC-ANIM-5:sprite swap requested during active cast → defer to `animation_finished`(atomicity);overwrite queued swap intent
- [ ] EC-SIG-2:`ability_cast(caster==player)` while Booting → drop + telemetry `cast_dropped_pre_ready`
- [ ] INV-2 timing assert(N-2 pin):`CAST_HARD_WINDOW_MS < CAST_TOTAL_MS` 且 `POSTURE_HYSTERESIS_SECONDS*1000 ≥ CAST_TOTAL_MS` load-time assert

---

## Implementation Notes

*Derived from CR-10:*

- cast onset 同步 `play("cast")` ≤100ms;hard window(300ms)期間拒絕 interrupt + 拒絕 sprite swap。
- queue depth 1:hard window 內第 2 cast 入 queue;第 3 → drop oldest(EC-ANIM-2 most-recent-intent)或 newest(EC-ANIM-1 queue-full)— 按 GDD 兩 EC 語意實現(50ms 內 = overflow drop-newest;hard-window buffer = drop-oldest)。
- wind-down 到 `CAST_TOTAL_MS`(500)= 300 hard + 200 interruptible;queue release 喺 wind-down 觸發。
- **timing test 用 injected clock** `advance(delta_ms)`(determinism;reference_dev_environment)。
- **N-2**:INV-2 timing monotonic 補 load-time assert + AC pin(GDD advisory carry)。

---

## Out of Scope

- Story 006:CAST state entry/exit FSM wiring(本 story 接續 timing/queue 內部)
- Story 016:`AVATAR_CAST_BURST` particle(release frame)

---

## QA Test Cases

- **AC-07**: cast queue
  - Given: cast in 300ms hard window
  - When: 2nd cast arrives
  - Then: queued(depth 1);3rd → drop oldest + `avatar_cast_dropped`
  - Edge cases: 50ms 雙 cast(EC-ANIM-1 overflow);Booting cast drop(EC-SIG-2)
- **INV-2**: timing monotonic
  - Given: knob load
  - When: `_validate_knobs()`
  - Then: assert 300<500 且 300000≥500;違反 → fail
  - Edge cases: boundary 值

---

## Test Evidence

**Story Type**: Logic
**Required evidence**: `tests/unit/avatar_renderer/cast_timing_queue_test.gd` — must pass;injected-clock seam(`advance(delta_ms)`),deterministic;queue overflow + atomicity case
**Status**: [ ] Not yet created

---

## Dependencies

- Depends on: Story 006(CAST FSM state)
- Unlocks: Story 016(cast burst particle hook)
