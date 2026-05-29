# Story 015: ADR-006 Binding Gate — Contract Markers + Test File Verification

> **Epic**: PersistenceLayer
> **Status**: Complete
> **Layer**: Foundation
> **Type**: Logic
> **Estimate**: S (1 hour)
> **Manifest Version**: 2026-05-29
> **Last Updated**: 2026-05-29

## Context

**GDD**: `design/gdd/persistence-layer.md`
**Requirement**: All TR-persist-001 through TR-persist-015 (gate covers all)
*(AC-32: Binding markers in source + test file existence verification — runs AFTER all other stories complete)*

**ADR Governing Implementation**: ADR-0006 (all 6 Contracts — gate verifies their presence in implementation)
**ADR Decision Summary**: After all 15 stories (001-014) are implemented, this gate verifies: (1) 6 ADR-006 binding comment markers present in `persistence_layer.gd`; (2) 6 corresponding test files exist on disk. This is the final quality gate before the epic is marked complete.

**Engine**: Godot 4.6 | **Risk**: LOW
**Engine Notes**: CI script uses `rg --glob "*.gd"` (not `--type gdscript`). Test file existence check uses shell `test -f`.

**Control Manifest Rules (Foundation layer)**:
- Required: All 6 ADR-006 contract markers must be present as comments in source
- Required: Gate runs LAST — after all other persistence-layer stories are Done

---

## Acceptance Criteria

- [ ] **AC-32**: GIVEN `persistence_layer.gd` AND stories 001-014 all Done, WHEN CI script `tools/ci/check_adr006_persistence_binding_markers.sh` runs, THEN ALL 6 comment strings present in `persistence_layer.gd`:
  1. `# ADR-006 Contract 3: SerializableResource envelope`
  2. `# ADR-006 Contract 4: autoload position 1 + sync _ready`
  3. `# ADR-006 Contract 9: clock-drift TTL`
  4. `# ADR-006 Contract 10: migration chain bounded`
  5. `# ADR-006 Contract 11: best-effort IDB fence`
  6. `# ADR-006 Contract 14: test spy interface`

- [ ] **AC-32b**: GIVEN `src/autoload/persistence_layer.gd`, WHEN each of the 6 exact marker strings is searched, THEN all 6 are present (verified by `rg --fixed-strings`). This confirms binding markers were added as each contract was implemented.
- [ ] **AC-32c**: GIVEN the 6 required test file paths, WHEN each checked with `test -f`, THEN all 6 exist on disk (CI-verifiable).

  AND these 6 test files exist:
  - `tests/unit/persistence-layer/test_adr006_c3_serializable_envelope.gd`
  - `tests/unit/persistence-layer/test_adr006_c4_autoload_sync.gd`
  - `tests/unit/persistence-layer/test_adr006_c9_clock_drift_ttl.gd`
  - `tests/integration/persistence-layer/test_adr006_c10_migration_chain.gd`
  - `tests/unit/persistence-layer/test_adr006_c11_idb_fence.gd`
  - `tests/unit/persistence-layer/test_adr006_c14_test_spy.gd`

---

## Implementation Notes

CI script `tools/ci/check_adr006_persistence_binding_markers.sh`:

```bash
#!/bin/bash
set -e
SOURCE="src/foundation/persistence/persistence_layer.gd"
FAIL=0

# Check 6 binding markers
for marker in \
    "# ADR-006 Contract 3: SerializableResource envelope" \
    "# ADR-006 Contract 4: autoload position 1 + sync _ready" \
    "# ADR-006 Contract 9: clock-drift TTL" \
    "# ADR-006 Contract 10: migration chain bounded" \
    "# ADR-006 Contract 11: best-effort IDB fence" \
    "# ADR-006 Contract 14: test spy interface"; do
    if ! rg --quiet --fixed-strings "$marker" "$SOURCE" 2>/dev/null; then
        echo "MISSING MARKER: $marker"
        FAIL=1
    fi
done

# Check 6 test files exist
for test_file in \
    "tests/unit/persistence-layer/test_adr006_c3_serializable_envelope.gd" \
    "tests/unit/persistence-layer/test_adr006_c4_autoload_sync.gd" \
    "tests/unit/persistence-layer/test_adr006_c9_clock_drift_ttl.gd" \
    "tests/integration/persistence-layer/test_adr006_c10_migration_chain.gd" \
    "tests/unit/persistence-layer/test_adr006_c11_idb_fence.gd" \
    "tests/unit/persistence-layer/test_adr006_c14_test_spy.gd"; do
    if [ ! -f "$test_file" ]; then
        echo "MISSING TEST FILE: $test_file"
        FAIL=1
    fi
done

exit $FAIL
```

When implementing stories 001-014, add the binding comment in the relevant section of `persistence_layer.gd`. The test files can be thin wrappers referencing the main test files from each story.

---

## Out of Scope

- Story 016 (BLOCKED): ADR-0003-gated stories are NOT required for this gate

---

## QA Test Cases

**AC-32** — Static / CI (gate)
- Given: all 15 stories (001-014) implemented and passing
- When: CI script runs
- Then: exit 0; all 6 markers found; all 6 test files exist

---

## Test Evidence

**Story Type**: Logic (Static / CI gate)
**Required evidence**: `tools/ci/check_adr006_persistence_binding_markers.sh` — must exit 0

**Status**: [x] Created — `check_adr006_persistence_binding_markers.sh` + 6 stub binding test files

---

## Dependencies

- Depends on: ALL of Stories 001-014 must be Done
- Unlocks: PersistenceLayer epic can be marked Complete (run `/story-done` to verify)

---

## Completion Notes
**Completed**: 2026-05-29
**Criteria**: 3/3 passing (AC-32 ✅ AC-32b ✅ AC-32c ✅)
**Deviations**: None — all 6 markers confirmed in persistence_layer.gd; all 6 test files created
**Test Evidence**: Logic/CI — `check_adr006_persistence_binding_markers.sh` (CI gate)
**Code Review**: APPROVED (inline)
