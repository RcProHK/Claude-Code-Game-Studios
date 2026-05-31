# Epic: Enemy Director

> **Layer**: Core
> **GDD**: design/gdd/enemy-director.md
> **Architecture Module**: EnemyDirector (autoload pos 10 — LAST among current autoloads, `src/autoload/enemy_director.gd`)
> **Status**: Ready
> **Stories**: 24 stories (20 Ready, 4 Blocked)

## Overview

EnemyDirector 係「無形軍師」— Pillar 2（Frictionless Companion）PRIMARY protector 同 Pillar 3（Drop Euphoria）PRIMARY substrate。佢擁有 wave spawn lifecycle、boss anchor、同 AI state machines，orchestrating 玩家看到嘅所有敵人動態。Wave archetype selection（STRIKE/CONTROL/MOBILITY × 3 difficulty tiers）由 WorkoutStateTracker.dominant_class 驅動（anti-fabrication chain 延伸）。Boss pre-spawn trigger at `set_progress ≥ pre_spawn_threshold`，boss anchor commit 後 `enemy_killed` signal 攜帶 `transition_id` 作為 loot chain seed（ADR-0005 FR-2）。自動處理 catchup backlog（5s polling cadence bound）。`pos 10 = LAST` 確保所有 upstream autoloads（特別係 Particles/ScreenEffects/Camera）ready 先可以 spawn。12-layer CI lint suite 係 Foundation+Core 最全面嘅架構防衛。

## Governing ADRs

| ADR | Decision Summary | Status | Engine Risk |
|-----|-----------------|--------|-------------|
| ADR-0001 (Accepted-structural 2026-05-30) | Web Export Budget Caps — structural: Camera/Particle/ScreenEffects autoload chokepoints, forbidden direct GPUParticles2D; CPU budget numbers Provisional pending VS-tier mobile profiling | MEDIUM risk: structural Accepted; AC-24 (CPU benchmark) ADR-RATIFICATION-GATED | HIGH |
| ADR-0002 (Accepted-data-contract 2026-05-31) | GymSys Integration Protocol — ability_cast events driven by 5s±0.5s polling cadence; catch-up backlog bound | LOW (data contract only; transport VS-gated) | MEDIUM |
| ADR-0005 (Accepted 2026-05-30) | Loot Rarity Formula — `enemy_killed.transition_id` → #15 LootDrop RNG seed chain binding (FR-2) | Accepted — no blocking | LOW |
| ADR-0006 Contracts 2+4+6 (Accepted 2026-05-25) | transition_id atomicity, boot order pos 10 LAST, connect_for_initial_state | Accepted — no blocking | MEDIUM |
| ADR-0007 (Accepted 2026-05-29) | Class & Domain Enum Convention — wave archetype Faction/EnemyAIState/BossAnchorState enum naming convention Locked | Accepted — no blocking | LOW |

> ✅ All governing ADRs confirmed present + status current as of 2026-05-31.

## GDD Requirements

| TR-ID | Requirement | ADR Coverage |
|-------|-------------|--------------|
| TR-enemy-001 | 8 state containers owned in EnemyDirector class body (Rule 1 caller-side state locality, CI enforced) | ADR-0006 ✅ |
| TR-enemy-002 | Damage chokepoint — all damage paths via `CombatResolver.resolve_hit()`; inline arithmetic rejected (CI) | ADR-0006 ✅ |
| TR-enemy-003 | Autoload position LAST among combat-relevant autoloads (after #1/#3/#5/#6/#7/#11/#12/#15/#28) | ADR-0006 Contract 4 ✅ |
| TR-enemy-004 | No direct `Camera2D.position/zoom/offset` mutation, no `GPUParticles2D.emitting = true` outside wrappers (ADR-001 CI enforced) | ADR-0001 structural ✅ |
| TR-enemy-005 | Subscribe via `connect_for_initial_state` to #1 GSM + #12 AbilitySystem (Contract 6) | ADR-0006 Contract 6 ✅ |
| TR-enemy-006 | Emit exactly 3 signals (hit_resolved / enemy_killed / combat_metric_anomaly) — no internal/debug leak | ADR-0006 ✅ |
| TR-enemy-007 | Anomaly rate limit: 10/sec per reason via Formula 4 rate_limit_check; window expiry emits aggregate | ADR-0006 ✅ |
| TR-enemy-008 | No `signal.disconnect/connect` in hot path (`_physics_process`, `_on_ability_cast`) | ADR-0006 ✅ |
| TR-enemy-009 | Catch-up queue defers new AOE casts (Rule 7) | ADR-0006 ✅ |
| TR-enemy-010 | `_rng_factory.create(transition_id)` + `create_sub(transition_id, label)` — sub-RNG independence + deterministic | ADR-0005 + ADR-0006 C2 ✅ |
| TR-enemy-011 | RNG ban: no `randf/randi/randf_range/Time.get_ticks_msec/RandomNumberGenerator.new()` outside `_rng_factory` (CI) | ADR-0005 ✅ |
| TR-enemy-012 | EnemyRegistry.tres schema validation: 3 archetypes × mandatory fields (Rule 12) | ADR-0007 ✅ |
| TR-enemy-013 | Wave archetype readability — 60%+ test recognition (ADVISORY playtest) | ADR-0007 ✅ |
| TR-enemy-014 | Boss kill same-frame `enemy_killed` emit (Rule 5 order) | ADR-0005 ✅ |
| TR-enemy-015 | Boss anchor pre-spawn at `set_progress >= 0.8`; rollback on undo set | ADR-0006 ✅ |
| TR-enemy-016 | Light-workout boss scaling (`LIGHT_WORKOUT_THRESHOLD_SETS = 2` → mini-boss + reduced ritual intensity) | ADR-0006 ✅ |
| TR-enemy-017 | Particle throttle auto-degrade (Formula 3) — 3-frame >33ms window triggers `caller_mult` 1.5→1.0; 60-frame recovery hysteresis | ADR-0001 structural ✅ |
| TR-enemy-018 | Per-enemy AI state machine (SPAWNING / IDLE / PURSUING / ATTACKING / STAGGERED / DYING) | ADR-0006 + ADR-0007 ✅ |
| TR-enemy-019 | CPU orchestration ≤ 0.5ms p95 (ADR-001 FR-4) — ADR-RATIFICATION-GATED | ADR-0001 Provisional ⚠️ |
| TR-enemy-020 | MOBILITY mob lateral dodge (Formula 2 mobility_dodge_offset) | ADR-0006 ✅ |
| TR-enemy-021 | `enemy_killed.transition_id` propagates verbatim from `ctx.transition_id` (#15 RNG seed binding) | ADR-0005 ✅ |

> Full requirements: `docs/architecture/tr-registry.yaml` — 21 TR-enemy-* entries.

## Definition of Done

This epic is complete when:
- All Ready stories are implemented, reviewed, and closed via `/story-done`
- All acceptance criteria from `design/gdd/enemy-director.md` (38 ACs: 31 BLOCKING + 5 ADVISORY + 2 ADR-RATIFICATION-GATED) verified
- Logic stories: unit tests in `tests/unit/enemy_director/` pass
- Integration stories: integration tests in `tests/integration/enemy_director/` + `tests/integration/combat/` pass
- `enemy_killed.transition_id` chain test: payload carries valid non-null transition_id from GSM
- CI lint suite (12 scripts): all pass on source tree
- 4 BLOCKED stories unblock when their gates open (ADR-0001 CPU / hardware / #9 WST / art assets)

## Stories

| # | Story | Type | Status | ADR |
|---|-------|------|--------|-----|
| 001 | [Core Class + 8 State Containers](story-001-core-class-state-containers.md) | Logic | Complete ✅ | ADR-0006 C4 |
| 002 | [CI Lint Suite A — RNG / Chokepoint / Stat](story-002-ci-lint-suite-a.md) | Logic | Complete ✅ | N/A (tooling) |
| 003 | [CI Lint Suite B — Boot Order / Signal Lifecycle / State Locality](story-003-ci-lint-suite-b.md) | Logic | Ready | ADR-0006 |
| 004 | [CI Lint Suite C — Forbidden Patterns / Move Cap / Dodge Invariant](story-004-ci-lint-suite-c.md) | Logic | Ready | ADR-0001 structural |
| 005 | [Signal Surface + Contract 6 Subscription + Payload Schemas](story-005-signal-surface-contract6.md) | Integration | Ready | ADR-0006 C6 |
| 006 | [RNG Factory + Sub-RNG Determinism](story-006-rng-factory-determinism.md) | Logic | Ready | ADR-0005 + ADR-0006 C2 |
| 007 | [Anomaly Rate-Limiter (Formula 4)](story-007-anomaly-rate-limiter.md) | Logic | Ready | ADR-0006 |
| 008 | [_on_ability_cast Pipeline: GSM Gate + StatSnapshot](story-008-ability-cast-gsm-gate-statsnapshot.md) | Logic | Ready | ADR-0006 C2 |
| 009 | [Catch-up Queue + AOE Serialization Mutex](story-009-catch-up-queue-aoe-mutex.md) | Integration | Ready | ADR-0006 |
| 010 | [EnemyRegistry.tres Data File](story-010-enemy-registry-data-file.md) | Config/Data | Ready | ADR-0007 |
| 011 | [Wave Archetype Scheduler (Rule 12 + Formula 1)](story-011-wave-archetype-scheduler.md) | Logic | Ready | ADR-0006 + ADR-0007 |
| 012 | [Enemy Spawn + Lifecycle Pool Cleanup](story-012-enemy-spawn-lifecycle.md) | Logic | Ready | ADR-0006 |
| 013 | [Per-enemy AI State Machine 6 States](story-013-per-enemy-ai-state-machine.md) | Logic | Ready | ADR-0006 + ADR-0007 |
| 014 | [Enemy Locomotion + 4Hz Batch Perception](story-014-enemy-locomotion-perception.md) | Logic | Ready | ADR-0001 structural + ADR-0006 |
| 015 | [Particle Concurrency Cap + Auto-degrade](story-015-particle-concurrency-auto-degrade.md) | Logic | Ready | ADR-0001 structural |
| 016 | [Boss Anchor Pre-spawn + Rollback](story-016-boss-anchor-pre-spawn.md) | Logic | Ready | ADR-0006 |
| 017 | [Boss Anchor Commit + Entry Cascade](story-017-boss-anchor-commit-cascade.md) | Integration | Ready | ADR-0006 + ADR-0001 structural |
| 018 | [Full AOE Handler Pipeline](story-018-aoe-handler-pipeline.md) | Integration | Ready | ADR-0006 + ADR-0005 |
| 019 | [enemy_killed Signal Chain + Idempotency](story-019-enemy-killed-signal-chain.md) | Integration | Ready | ADR-0005 + ADR-0006 |
| 020 | [Test Infrastructure Helpers](story-020-test-infrastructure-helpers.md) | Config/Data | Ready | N/A |
| 021 | [BLOCKED: Wave Archetype Readability Playtest](story-021-blocked-wave-readability-playtest.md) | Visual/Feel | Blocked | ADR-0007 ⚠️ (art assets required) |
| 022 | [BLOCKED: Mobile Particle Floor Benchmark](story-022-blocked-mobile-particle-benchmark.md) | Logic | Blocked | ADR-0001 ⚠️ (hardware required) |
| 023 | [BLOCKED: Boss Anchor Latency Gate](story-023-blocked-boss-anchor-latency.md) | Integration | Blocked | ADR-0002 ⚠️ (#9 WST required) |
| 024 | [BLOCKED: CPU Budget Benchmark](story-024-blocked-cpu-budget-benchmark.md) | Logic | Blocked | ADR-0001 ⚠️ (CPU Provisional) |

## Next Step

Run `/story-readiness production/epics/enemy-director/story-001-core-class-state-containers.md` then `/dev-story` to begin implementation.

> ⚠️ EnemyDirector requires #5 Particles + #6 ScreenEffects + #7 Camera + #9 WorkoutStateTracker + #13 CombatResolver all ready before full integration stories can run. Logic + Config/Data stories 001-020 can be implemented now.
