# Story 012: Milestone emit + workout-defer (CR-15) + pending buffer never-drop

> **Epic**: Avatar Renderer (#26)
> **Status**: Ready
> **Layer**: Presentation
> **Type**: Integration
> **Estimate**: M
> **Manifest Version**: 2026-05-29
> **Last Updated**: —

## Context

**GDD**: `design/gdd/avatar-renderer.md` CR-5 / CR-15 / EC-MILE-2/3/4/5 / EC-SUS-4 / FC-2
**Requirement**: AC-14 / AC-17 / AC-21(GDD 直接 trace)
**ADR Governing Implementation**: ADR-0010 Mirror Moment Ownership(primary — #29 ceremony trigger contract)· ADR-0009(payload schema)
**ADR Decision Summary**: #26 emit `avatar_evolution_milestone(tier, source_metrics)` 做 #29 ceremony trigger;#26 render zero ceremony;單向 #29→#26。

**Engine**: Godot 4.6 | **Risk**: LOW
**Engine Notes**: emit 經 ADR-0009 payload(minimal+intrinsic + transition_id);`source_metrics={stat_total, ability_count, max_class_depth, achieved_at_unix}`(FC-2 frozen)。

**Control Manifest Rules (Presentation layer)**:
- Required: workout-window defer(CR-15);pending buffer NEVER silently drop(P5 ritual integrity)
- Forbidden: emit mid-workout(defer);#26 render ceremony(只 emit trigger)
- Guardrail: pending_emit_queue max 3 FIFO;retry `MIRROR_MOMENT_PENDING_BUFFER_FRAMES`(60)

---

## Acceptance Criteria

- [ ] **AC-14**: CR-5 two-gate(promotion+cadence+non-workout)全 pass → `avatar_evolution_milestone` emit exactly once + persisted
- [ ] **AC-17**: workout window active + two-gate satisfied mid-set → emission deferred via persisted `_pending_milestone`,fire on workout-window exit
- [ ] **AC-21**: milestone emit while #29 not registered → buffered in `pending_emit_queue`(max 3),retried,then persisted;NEVER silently dropped
- [ ] CR-15 deferral window:emit deferred while GSM ∈ {WORKOUT_ACTIVE, REST_PERIOD};set `_pending_milestone` + persist;GSM exit → flush(FIFO if multiple)
- [ ] EC-MILE-2:both gate pass but workout active → defer + persist,flush on exit
- [ ] EC-MILE-3(CRITICAL):pending at boot(crash mid-workout)→ re-validate gate_a+cadence;valid → emit on next workout-exit OR after `WORKOUT_END_GRACE_SECONDS`(30)if no workout;invalid → drop + log `stale_pending_milestone_dropped`
- [ ] EC-MILE-4:bootstrap finds prior-session pending → replay-safe,emission keyed `(tier, emit_attempt_id)` UUID;#29 dedupes
- [ ] EC-MILE-5(CRITICAL):#29 not registered → buffer pending_emit_queue(max 3 FIFO);retry to buffer frames;still none → persist;surface next boot — **Never silently drop**
- [ ] EC-SUS-4:suspend after emit before persistence flush → resume trust in-memory `last_emitted_tier`,re-flush;#29 UUID-dedupes

---

## Implementation Notes

*Derived from CR-5 + CR-15(#26 emits trigger, #29 owns the rest):*

- emit `avatar_evolution_milestone(tier, source_metrics)` per FC-2 frozen payload;**#26 render zero ceremony**(CR-17 — story 017 AC-30 grep 守)。
- defer:gate_c false(story 011)→ `_pending_milestone` persist;workout-exit flush FIFO。
- pending buffer:#29 唔 registered → `pending_emit_queue`(max 3)retry `MIRROR_MOMENT_PENDING_BUFFER_FRAMES`(60);still none → persist surface next boot。**Never drop**(P5)。
- UUID `(tier, emit_attempt_id)` 令 replay/split-brain #29-dedupe(EC-MILE-4/EC-SUS-4)。

---

## Out of Scope

- #29 ceremony composition(consumes the signal — separate epic)
- Story 011:should_emit gate(本 story 接受 gate result,負責 emit/defer/buffer)
- Story 013:micro-evolution emit(separate signal)

---

## QA Test Cases

- **AC-14**: emit once
  - Given: two-gate all pass
  - When: derive
  - Then: `avatar_evolution_milestone` emit ×1 + persist
  - Edge cases: idempotent(唔重 emit same tier)
- **AC-17**: workout defer
  - Given: gate satisfied mid-workout
  - When: GSM workout-window
  - Then: defer `_pending_milestone`;flush on workout-exit
- **AC-21**: never drop
  - Given: milestone emit,#29 not registered
  - When: emit
  - Then: buffer max 3,retry,persist;never silently drop
  - Edge cases: EC-MILE-3 stale boot pending;EC-SUS-4 split-brain re-flush UUID-dedupe

---

## Test Evidence

**Story Type**: Integration
**Required evidence**: `tests/integration/avatar_renderer/milestone_emit_defer_test.gd` — MockPersistenceLayer + mock #29-listener seam;defer/buffer/never-drop case;injected clock
**Status**: [ ] Not yet created

---

## Dependencies

- Depends on: Story 011(should_emit gate)/ Story 009(persistence)/ Story 010(EC-SUS-4)
- Unlocks: Story 014(snapshot seam co-consumer #29)
