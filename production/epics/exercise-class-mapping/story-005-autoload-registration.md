# Story 005: Autoload pos 5 registration + CI mutator-ban lint

> **Epic**: Exercise → Class Mapping
> **Status**: Complete
> **Layer**: Core
> **Type**: Integration
> **Estimate**: M (~3h)
> **Manifest Version**: 2026-05-29
> **Last Updated**: 2026-06-02

## Context

**GDD**: `design/gdd/exercise-class-mapping.md`
**Requirement**: `TR-ECM-005` *(provisional — pending /architecture-review Phase 8)*

**ADR Governing Implementation**: ADR-0008: Autoload Position Map (primary)
**Secondary**: ADR-0007 (read-only closed API the lint enforces)
**ADR Decision Summary**: `project.godot` is sole ground-truth for absolute autoload position. #10 insertion rule (added 2026-06-02, TD sign-off): place `ExerciseClassMapping` after `GymSysBackendClient` → pos 5; renumber pos 5-14 (StatSystem…ScreenEffects) +1. Binding constraint 7: `ExerciseClassMapping ≺ StatSystem`.

**Engine**: Godot 4.6 | **Risk**: MEDIUM
**Engine Notes**: autoload `_ready()` runs sequentially in `project.godot` listing order (ADR-0006 Contract 4) — placing #10 at pos 5 guarantees it is READY before StatSystem/AbilitySystem/WST consumers. No GDD holds an absolute number — only `project.godot` does. Manifest Version 2026-05-29 predates ADR-0008 in full; insertion follows the ADR-0008 insertion procedure directly.

**Control Manifest Rules (this layer)**:
- Required: PersistenceLayer pos 1, GameStateMachine pos 2 hard-locked; all others pos 3+. Autoload boot per-instance sequential (not batched).
- Required: closed lookup is read-only — CI lint bans external mutators (owner self-exempt), mirroring `check_camera_callers.gd` / `check_screen_effects_callers.gd` / `check_particle_callers.gd` patterns.
- Forbidden: any GDD/ADR prose asserting an absolute autoload number as authoritative — reference `project.godot`.

---

## Acceptance Criteria

*Infra DoD (no direct GDD AC — autoload + CI infrastructure):*

- [ ] `ExerciseClassMapping` registered at `project.godot` autoload pos 5 (after GymSysBackendClient pos 4); StatSystem…ScreenEffects renumbered +1.
- [ ] Boot smoke: full GUT headless suite green after renumber (no regression, no "autoload not found" / order errors).
- [ ] CI position audit updated for new pos 5-14 layout and passes (no duplicates, no gaps).
- [ ] `tools/ci/check_exercise_mapping_callers.gd` lint present: bans external write/mutator calls to ExerciseClassMapping; owner file `exercise_class_mapping.gd` self-exempt; reports 0 violations.

---

## Implementation Notes

*Derived from ADR-0008 insertion procedure + technical-preferences CI-lint precedent:*

- Edit `project.godot` `[autoload]` block: insert `ExerciseClassMapping="*res://src/autoload/exercise_class_mapping.gd"` at position 5 (immediately after `GymSysBackendClient`). Godot renumbers downstream automatically by listing order — verify pos 6 = StatSystem … pos 15 = ScreenEffects.
- Regenerate CI position audit + (optionally) note for control-manifest regen (`/create-control-manifest` to fold in ADR-0008 — cross-cutting, can be a follow-up).
- `tools/ci/check_exercise_mapping_callers.gd`: grep for write/assignment to ExerciseClassMapping members / banned mutators outside the owner file; full-path EXEMPT for `src/autoload/exercise_class_mapping.gd` (and test factory `_create_test_registry`); follow the established `EXEMPT_FILES` anchor pattern from screen_effects/camera lints to avoid self-false-positive.
- Provide fixtures: one violation file (external mutator) + one clean file, asserting the lint catches/passes correctly (per particle/screen-effects lint test precedent).

---

## Out of Scope

- **Story 001-004**: all lookup logic, schema, validation, alias, edge cases.
- entities.yaml 7-member MovementPattern registration — cross-system gate (systems-designer), not this story.
- #9 WST UNKNOWN-dominant display patch — cross-system epic-close gate (game-designer + #9).

---

## QA Test Cases

- **TC-005-01 Boot smoke — autoload pos 5 registered (Integration)**
  - Given: `project.godot` with ExerciseClassMapping at pos 5, consumers at pos 6+
  - When: GUT headless suite runs
  - Then: full suite green (no renumber regression); no autoload-order errors
  - Edge: pos 4 = GymSysBackendClient intact; pos 6 = StatSystem; no gap
- **TC-005-02 Position audit pass (Integration)**
  - Given: CI position audit updated for pos 5-14 layout
  - When: audit script runs
  - Then: PASS — all autoloads in expected positions, no duplicates/gaps
  - Edge: flag any prior test hardcoding positions by number
- **TC-005-03 CI mutator-ban — external caller blocked**
  - Given: `check_exercise_mapping_callers.gd` in `tools/ci/`
  - When: lint scans for external write/set calls outside owner
  - Then: 0 violations on clean tree; violation fixture is flagged
  - Edge: owner `exercise_class_mapping.gd` + test factory self-exempt
- **TC-005-04 CI mutator-ban — self-exempt**
  - Given: owner file writes `_class_by_id` internally during `_build_lookup`
  - When: lint runs
  - Then: no false-positive for owner; exact full-path match (not partial name)

---

## Test Evidence

**Story Type**: Integration
**Required evidence**: `tests/integration/exercise_class_mapping/test_autoload_boot.gd` + CI lint green (combined GUT gate)
**Status**: [ ] Not yet created

> ⚠️ GUT `test_` PREFIX (not `*_test.gd` suffix). See [[reference-gut-filename-convention]].

---

## Dependencies

- Depends on: Story 001-004 (full API surface must exist before autoload registration + read-only lint are meaningful)
- Unlocks: epic close (subject to 2 cross-system gates: Q5 #9 WST patch + entities.yaml 7-member registration)

---

## Completion Notes
**Completed**: 2026-06-02
**Criteria**: 4/4 passing (autoload pos 5 registered, boot smoke green, position audit updated, CI mutator-ban lint present + 0 violations).
**Deviations**: None.
- Structural: `ExerciseClassMapping` inserted at `project.godot` autoload pos 5 (after GymSysBackendClient, before StatSystem — ADR-0008 #10 insertion rule + binding constraint 7). Downstream shifted: ParticleSystemWrapper 12→13, CameraController 13→14, ScreenEffects 14→15 — the 3 hardcoded position tests updated to match. Boot is safe (no .tres yet → FAILED state, lookups return UNKNOWN, one boot push_error — expected until the registry .tres content gate).
**Test Evidence**: Integration — `tests/integration/exercise_class_mapping/test_autoload_boot.gd` (4 tests incl. runtime `/root` singleton boot proof). CI lint: `tools/ci/check_exercise_mapping_callers.gd` (exit 0, 41 files, 0 violations) + `tests/unit/ci/test_exercise_mapping_caller_ban.gd` (5 tests) + fixtures. Full gate (unit+integration+static): 232 scripts / 1400 tests / 1399 pass / 1 pre-existing pending (AC-37) / 0 fail.
**Code Review**: Complete — QL-STORY-READY + QL-TEST-COVERAGE ADEQUATE + LP-CODE-REVIEW APPROVED (full review mode, 2026-06-02).
**LP advisory (non-blocking, not applied)**: minor comment label in boot test; pre-existing stale Ability/Stat note in project.godot header (unrelated to #10).
