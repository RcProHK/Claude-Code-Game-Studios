# Story 007: BossSystem autoload + spawn_boss + idempotency

> **Epic**: Boss System
> **Status**: Complete (autoload registration deferred — see notes)
> **Layer**: Feature
> **Type**: Integration
> **Estimate**: L
> **Manifest Version**: 2026-05-29
> **Last Updated**: 2026-06-05

**Completion Notes (2026-06-05)**: `src/gameplay/boss_system.gd` (`class_name BossSystem extends Node`) + `tests/integration/boss_system/test_spawn_boss_lifecycle.gd` (5 tests; combined 265scr/1740/1739pass/0fail/1pending). spawn_boss (A1.3 4-param) + idempotency + ordering (set fields → add_child → re-set pos → asserts → boss_committed sync) + `_instantiate_boss` (PackedScene) + telemetry noop + AC-41(e) bootstrap telemetry caller-side + eviction-on-free (Pass 11 512MB rec via `boss.tree_exited`). AC-25 (dup→null), AC-26/EC-02 (empty txn→null), AC-43 (null snapshot→null), AC-37 (position + commit signal).
- **empty-txn refinement**: GDD used `assert(transition_id != "")` → refined to graceful **return-null + push_error + telemetry** (EC-02「reject + #14 rollback」semantics + GUT-testable; assert crashes in debug).
- snapshot param type = `BossSpawnContext` (Story 002 resolution, not CombatResolver.StatSnapshot).
- **⚠️ AUTOLOAD REGISTRATION DEFERRED**: BossSystem is NOT yet registered in project.godot. Rationale: nothing calls it at boot yet (#14 EnemyDirector boss-anchor wiring — which invokes `BossSystem.spawn_boss` — is in #14's epic, not done), and the boot-position tests assert specific autoload indices (main-CI-red risk). spawn logic is fully tested via `.new()` + in-tree. **Register (append at end of autoload block per ADR-0008) WHEN #14 wires boss-spawn** — a clean cross-epic integration point. Test builds a packable BossInstance scene (owner-set children) for `_instantiate_boss`.

## Context

**GDD**: `design/gdd/boss-system.md` — BossSystem autoload contract (GP-F4) + Rule 7 spawn ordering + Rule 8
**Requirement**: `TR-boss-002` (deterministic spawn), `TR-boss-006` (transition_id chain integrity), `TR-boss-014` (reveal dispatch hook)

**ADR Governing Implementation**: ADR-0006 (transition_id provenance — Contract 2 idempotency) — primary; ADR-0009 (boss_committed payload) secondary
**ADR Decision Summary**: tombstone-style idempotency; transition_id opaque + intrinsic to payload; `connect_for_initial_state` (Contract 6) for subscribers.

**Engine**: Godot 4.6 | **Risk**: LOW
**Engine Notes**: `class_name BossSystem extends Node` autoload (ADR-0008 position map — append after existing autoloads; verify boot order). Identity transform (Pass 4 A2.3 parent-identity contract). `spawn_boss(template, transition_id: String, spawn_pos: Vector2, player_snapshot: CombatResolver.StatSnapshot) -> BossInstance`. `_emit_telemetry` graceful local noop (#28 Not Started). Telemetry callsites (`boss.first_session_bootstrap`/`boss.scaling_clamp`/`boss.null_snapshot`) live HERE, not in BossFormulas.

**Control Manifest Rules (Feature layer)**:
- Required: `boss_committed` payload carries `transition_id`; enum fields serialize via `find_key` (if any payload persists).
- Forbidden: never parse transition_id; never generate own transition_id (NEVER #3).

---

## Acceptance Criteria

*From GDD Section H, scoped to this story:*

- [ ] **AC-25** (EC-01): spawn_boss called twice same transition_id → exactly 1 BossInstance + 2nd logs `BOSS_DUP_SPAWN_001`; `_spawned_transition_ids` dedupe (evict on free — Pass 11 512MB note).
- [ ] **AC-26** (EC-02/EC-23): empty transition_id OR total_planned_sets==0 → no spawn + error + #14 rollback signal.
- [ ] **AC-43** (A1.2): `player_snapshot==null` → returns null, no add_child, `BOSS_NULL_SNAPSHOT_001` push_error + `boss.null_snapshot` telemetry.
- [ ] **AC-37** (GP3): spawn ordering — set immutable fields BEFORE add_child; `global_position=spawn_pos` re-set AFTER add_child; `assert(boss.global_position.is_equal_approx(spawn_pos))`; `boss_committed` emitted sync before return with `spawn_pos` cached in payload.
- [ ] `_instantiate_boss(template)` instantiates `template.boss_scene` (asserts non-null + root is BossInstance), NOT a bare `.new()`. `boss.first_session_bootstrap` telemetry emitted post-add_child when `snapshot.attack_power==0` (AC-41(e) — caller scope).

---

## Implementation Notes

*From GDD BossSystem contract + Rule 7 + Rule 8:*

- Entry guards: main-thread assert; transition_id != ""; null-snapshot path. EC-01 idempotency dict. `boss_committed.emit(template, boss, snapshot, spawn_pos, transition_id)` synchronous before return.
- Subscribers (#5/#6/#7/Audio/#28) connect at their own `_ready` via `connect_for_initial_state` — NOT auto-connected by BossSystem.
- Register autoload in `project.godot` per ADR-0008 (append; verify boot test size).

---

## Out of Scope

- **Story 008**: the spawn SELECTION (which template) + effort gate. **Story 010**: subscriber-side reveal handlers. **Story 009**: snapshot caching enforcement (CF-3 lint).

---

## QA Test Cases

- **AC-25**: twice same tid → 1 instance + dup log; assert `_spawned_transition_ids` evicts on boss free.
- **AC-26**: tid="" → null + rollback. total_planned_sets==0 → reject + `boss.empty_workout`.
- **AC-43**: null snapshot → null return, no `add_child`, push_error + telemetry.
- **AC-37**: spawn_pos=Vector2(800,300); assert global_position is_equal_approx post-add_child + payload spawn_pos exact + boss_committed emitted once sync.
- Use mock #14 caller + mock scene (BossInstance stub with the 4 children).

---

## Test Evidence

**Story Type**: Integration
**Required evidence**: `tests/integration/feature/boss_system/test_spawn_boss_lifecycle.gd` + `test_ec01_dup_spawn_idempotency.gd` + `test_ac43_null_snapshot_rejection.gd` + `test_ac37_spawn_position_persistence.gd` — must pass
**Status**: [ ] Not yet created

---

## Dependencies

- Depends on: Story 002 (BossInstance), Story 003 (compute_max_hp called via _ready)
- Unlocks: Story 008, Story 009, Story 010, Story 011
