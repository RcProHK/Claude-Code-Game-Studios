# Story 001: CI Lints — Closed API + Namespace + Config Integrity

> **Epic**: Loot Drop System
> **Status**: Complete
> **Layer**: Core
> **Type**: Logic
> **Estimate**: M
> **Manifest Version**: 2026-05-29
> **Last Updated**: 2026-05-30

## Context

**GDD**: `design/gdd/loot-drop-system.md`
**Requirement**: `TR-loot-018`
*(Requirement text: "27 owned knobs + 14 INVs + 10 CI lints")*

**ADR Governing Implementation**: ADR-0005 (Loot Rarity Formula, Accepted 2026-05-30)
**ADR Decision Summary**: Formula constants in `LootRarityConfig.tres` are locked post-build; bare `randf()`/`randi()` inside loot code is forbidden; `_generate_loot_internal()` caller whitelist enforced; signal payload must be minimal (drop_id, rarity_tier, item_type, transition_id only). Config SHA pinned in registry to prevent hot-swap.

**Engine**: Godot 4.6 | **Risk**: LOW
**Engine Notes**: GDScript static analysis scripts use `FileAccess` + `RegEx` — stable APIs across 4.4–4.6. No post-cutoff API sensitivity.

**Control Manifest Rules (Core layer)**:
- Required: Signal payloads MUST be minimal + intrinsic (ADR-0009)
- Forbidden: Never stuff ambient context into signal payloads (ADR-0009)
- Guardrail: State transition CPU < 0.5ms (ADR-0006)

---

## Acceptance Criteria

*From GDD `design/gdd/loot-drop-system.md` Section H, scoped to this story:*

- [x] **AC-26** — `tools/ci/check_loot_rng_seeded.gd` exists; any `randf()` / `randi()` bare call inside `src/autoload/loot_drop_system.gd` causes CI exit code != 0
- [x] **AC-27** — `tools/ci/check_loot_namespace_writers.gd` exists; any `PersistenceLayer.write("loot.*", ...)` call outside `src/autoload/loot_drop_system.gd` causes CI fail
- [x] **AC-28** — `tools/ci/check_loot_generator_callers.gd` exists; any call to `_generate_loot_internal()` outside `src/autoload/loot_drop_system.gd` causes CI fail
- [x] **AC-29** — `tools/ci/check_loot_config_hash_pinned.gd` exists; drift between `LootRarityConfig.tres` SHA and value pinned in `design/registry/entities.yaml` causes CI fail
- [x] **AC-30** — `tools/ci/check_loot_signal_payload_minimal.gd` exists; any `emit_signal("loot_dropped", ...)` payload containing a full `LootDrop` object (not just 4 primitive fields) causes CI fail
- [x] Additional lint scripts created (not directly AC-mapped but GDD Rule enforcement):
  - `check_loot_force_drop_debug_only.gd` — `_force_test_drop` in production path → fail ✅
  - `check_loot_ceremony_cap.gd` — intra-function backward scan: loot_dropped emit must have preceding _ceremony_cap_check ✅
  - `check_loot_workout_id_resolution.gd` — handler body scan: get_active_workout_id() + explicit null branch ✅
  - `check_loot_final_boss_reservation.gd` — FINAL_BOSS context must use _emit_counter_final pool ✅
  - `check_loot_e3_termination_guard.gd` — E3 function body scan: max_iterations + assert() ✅

---

## Implementation Notes

*Derived from ADR-0005 Implementation Guidelines + GDD Section C §18.1/18.2/18.3:*

All scripts live in `tools/ci/`. Follow the established pattern from `tools/ci/check_stat_*.gd` and `tools/ci/check_ability_*.gd`:
- Use `RegEx` for pattern matching; load file via `FileAccess.open()`
- Scan `src/autoload/loot_drop_system.gd` and broader `src/` as appropriate
- Exit `0` = clean, exit `1` = violation found (use `OS.exit(code)` or return code pattern per engine CI runner)

**Lint script logic summary**:

| Script | Grep target | Fail condition |
|--------|-------------|----------------|
| `check_loot_rng_seeded.gd` | `src/autoload/loot_drop_system.gd` | Match `randf\(\)` or `randi\(\)` not preceded by `_rng.` |
| `check_loot_namespace_writers.gd` | `src/` excluding `src/autoload/loot_drop_system.gd` | Match `PersistenceLayer\.write\("loot\.` |
| `check_loot_generator_callers.gd` | `src/` excluding `src/autoload/loot_drop_system.gd` | Match `_generate_loot_internal\(` |
| `check_loot_signal_payload_minimal.gd` | `src/autoload/loot_drop_system.gd` | `emit_signal\("loot_dropped"` passes a non-String object as arg |
| `check_loot_config_hash_pinned.gd` | `design/registry/entities.yaml` | SHA of `LootRarityConfig.tres` ≠ pinned value |
| `check_loot_force_drop_debug_only.gd` | `src/` | `_force_test_drop` outside `if OS.is_debug_build()` guard |
| `check_loot_ceremony_cap.gd` | `src/autoload/loot_drop_system.gd` | `emit_signal\("loot_dropped"` without preceding `_ceremony_cap_check` call |
| `check_loot_workout_id_resolution.gd` | `src/autoload/loot_drop_system.gd` | boss_killed/enemy_killed handlers missing explicit `get_active_workout_id()` null branch |
| `check_loot_final_boss_reservation.gd` | `src/autoload/loot_drop_system.gd` | FINAL_BOSS emit uses `_emit_counter_mini` instead of `_emit_counter_final` |
| `check_loot_e3_termination_guard.gd` | `src/autoload/loot_drop_system.gd` | `expected_weekly_rarity_distribution` function missing `max_iterations` or `assert` monotonic |

**Note**: `loot_drop_system.gd` does not exist yet at story-001 time. Scripts must gracefully handle missing target files (non-fail when file absent — `FileAccess.file_exists()` guard before scan). This matches stat-system lint pattern.

---

## Out of Scope

*Handled by neighbouring stories:*

- Story 002: `LootRarityConfig.tres` file (lints check its SHA, but don't create it)
- Story 003+: Implementation of `_generate_loot_internal()`, `loot_dropped` signal (lints validate these don't violate contracts)
- Story 009+: `loot_drop_system.gd` autoload creation (lints scan it when it exists)

---

## QA Test Cases

**AC-26**: CI lint fires on bare randf()
- Given: A test GDScript file with `randf()` in scope of loot code
- When: `check_loot_rng_seeded.gd` runs
- Then: Exit code != 0; error message contains filename + line number
- Edge cases: `_rng.randf()` must NOT trigger; only bare `randf()`/`randi()`

**AC-27**: CI lint fires on namespace write from outside loot system
- Given: A test .gd file in `src/` (not loot_drop_system.gd) calls `PersistenceLayer.write("loot.foo", ...)`
- When: `check_loot_namespace_writers.gd` runs
- Then: Exit code != 0
- Edge cases: `PersistenceLayer.write("player.foo", ...)` must NOT trigger

**AC-28**: CI lint fires on _generate_loot_internal from outside
- Given: External caller file references `_generate_loot_internal()`
- When: `check_loot_generator_callers.gd` runs
- Then: Exit code != 0
- Edge cases: Call inside `loot_drop_system.gd` must NOT trigger

**AC-29**: Config hash pinned
- Given: `LootRarityConfig.tres` SHA != pinned SHA in `entities.yaml`
- When: `check_loot_config_hash_pinned.gd` runs
- Then: Exit code != 0; matching SHA → exit 0
- Edge cases: File missing → exit 0 (pre-creation stage)

**AC-30**: Payload minimality
- Given: `emit_signal("loot_dropped", drop_id, rarity_tier, item_type, transition_id)` — all Strings
- When: `check_loot_signal_payload_minimal.gd` runs
- Then: Exit 0 (clean)
- Edge cases: Passing a `LootDrop` object → exit != 0

---

## Test Evidence

**Story Type**: Logic (static-analysis)
**Required evidence**: CI lint scripts themselves ARE the tests — each script must exit 0 on clean code, exit != 0 on violation. No GUT test file required for this story. Verify manually by: (a) running each script against a clean target, (b) running against a seeded violation file.

**Status**: [ ] Not yet created

---

## Dependencies

- Depends on: None (creates standalone CI scripts independent of loot_drop_system.gd existence)
- Unlocks: Story 002 (config SHA lint enables pinning), Story 003+ (all subsequent stories must pass these lints)

## Completion Notes

**Completed**: 2026-05-30
**Criteria**: 5/5 BLOCKING AC + 5/5 additional Rule-enforcement scripts — all COMPLETE
**Deviations**: ADVISORY — `check_loot_config_hash_pinned.gd` CONFIG_FILE path `res://assets/data/loot/loot_rarity_config.tres` must align with the path chosen in Story 002 when LootRarityConfig.tres is created. No impact until file exists (lint returns exit 0 on missing target). Logged in tech-debt-register.md.
**Test Evidence**: CI lint scripts ARE the test artifacts (declared in Test Evidence section). No GUT unit test required for this static-analysis story — exception documented. ADVISORY: follows standard Logic-story exception for CI infrastructure.
**Code Review**: Complete (passed)
