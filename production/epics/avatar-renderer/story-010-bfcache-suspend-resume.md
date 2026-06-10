# Story 010: Formula 5 — bfcache suspend/resume (pause() API)

> **Epic**: Avatar Renderer (#26)
> **Status**: Ready
> **Layer**: Presentation
> **Type**: Integration
> **Estimate**: M
> **Manifest Version**: 2026-05-29
> **Last Updated**: —

## Context

**GDD**: `design/gdd/avatar-renderer.md` CR-8 / Formula 5 / INV-5 / EC-SUS-1/2/3/5 / States SUSPENDED row
**Requirement**: AC-11 / AC-18(GDD 直接 trace)
**ADR Governing Implementation**: ADR-0006 State Machine Contract(primary — Contract 6 SUSPENDED)· ADR-0001(bfcache 30s parity)
**ADR Decision Summary**: GSM SUSPENDED via Contract 6;bfcache 30s parity 與 #15.Rule17。

**Engine**: Godot 4.6 | **Risk**: LOW(empirically verified 4.6.3)
**Engine Notes**: **`AnimatedSprite2D.pause()` HOLDS frame**(empirical 4.6.3 — `production/qa/evidence/avatar-renderer/blocker4_api_probe.gd`);**`stop()` RESETS frame→0 = FORBIDDEN here**(CR-8 hallucination fix,Pass-4)。`set_frame_and_progress(frame:int, progress:float)` confirmed。

**Control Manifest Rules (Presentation layer)**:
- Required: suspend 用 `pause()`(NOT `stop()`);`BFCACHE_CONTINUE_THRESHOLD_MS`==#15.Rule17(INV-5/CI-2 parity)
- Forbidden: `stop()` for snapshot(resets frame);wallclock for delta(monotonic only)
- Guardrail: negative-delta → safe re-derive(untrusted clock)

---

## Acceptance Criteria

- [ ] **AC-11**: GSM SUSPENDED → `AnimatedSprite2D.pause()` called(NOT `stop()`);`_suspended_snapshot` 有 `frame_progress:float`;resume ≤30s → `play`+`set_frame_and_progress(frame, frame_progress)` 還原 exact frame
- [ ] **AC-18**: bfcache resume Δ≤30000ms → RESTORE_SNAPSHOT;Δ=−5000(NTP)→ clamp + `avatar_monotonic_anomaly` + RESET_TO_IDLE_REDERIVE;threshold == #15.Rule17
- [ ] Formula 5:`raw_delta_ms<0` → RESET_TO_IDLE_REDERIVE + anomaly telemetry;`delta_ms=max(0,raw)`;`action = RESTORE if delta≤30000 else RESET`
- [ ] CR-8 suspend:cache `_suspended_snapshot={animation_state, current_frame:int, frame_progress:float, state_before_suspend, suspended_at_monotonic_ms}`;emit no `avatar_visual_updated`;reject incoming canonical signal(resume re-derive via CR-13)
- [ ] EC-SUS-1:suspend <30s → restore snapshot,no re-derive
- [ ] EC-SUS-2:suspend ≥30s OR negative → reset IDLE + re-derive
- [ ] EC-SUS-3:suspend mid-cast(hard window)→ resume synthesize `animation_finished`(NOT restore mid-cast frame — atlas may unload);process queued cast normally
- [ ] EC-SUS-5:WebGL context lost during suspend → textures re-upload on restore(4.6 default);force one IDLE frame;log `webgl_context_restored`

---

## Implementation Notes

*Derived from Formula 5 + CR-8(the empirically-verified pause/restore fix):*

- **CR-8 hallucination fix 命脈**:v1「stop() pauses-in-place」= CONFIRMED HALLUCINATION(probe:stop() resets frame→0)。MUST 用 `pause()`。AC-11 = regression guard,test 必 assert `pause()` called 且 `stop()` 唔 called。
- delta 用 monotonic `Time.get_ticks_msec()`;negative-delta(NTP anomaly)→ untrusted → safe re-derive(Formula 5 head)。
- `BFCACHE_CONTINUE_THRESHOLD_MS`=30000 MUST==#15.Rule17(INV-5,CI-2 parity assert — story 017)。
- EC-SUS-4(split-brain milestone)= story 012 範疇(milestone emit timing)。

---

## Out of Scope

- Story 012:EC-SUS-4 milestone split-brain re-flush
- Story 017:CI-2 BFCACHE parity assert lint

---

## QA Test Cases

- **AC-11**: pause not stop
  - Given: GSM SUSPENDED
  - When: suspend
  - Then: `pause()` called,`stop()` NOT called;snapshot 有 frame_progress;resume ≤30s 還原 exact frame
  - Edge cases: `set_frame_and_progress(frame, progress)` 用
- **AC-18**: resume action
  - Given: suspend snapshot
  - When: resume Δ=5000 / 30000 / 30001 / −5000
  - Then: RESTORE / RESTORE(inclusive) / RESET / RESET+anomaly
  - Edge cases: threshold parity #15.Rule17
- **EC-SUS-3**: mid-cast suspend
  - Given: suspend during hard window
  - When: resume
  - Then: synthesize animation_finished,唔 restore mid-cast frame

---

## Test Evidence

**Story Type**: Integration
**Required evidence**: `tests/integration/avatar_renderer/bfcache_resume_test.gd` — injected monotonic clock;`pause()`/`stop()` call assertion(CR-8 regression);boundary Δ table
**Status**: [ ] Not yet created

---

## Dependencies

- Depends on: Story 002(pipeline)/ Story 006(anim state to snapshot)
- Unlocks: Story 012(EC-SUS-4 milestone split-brain)
