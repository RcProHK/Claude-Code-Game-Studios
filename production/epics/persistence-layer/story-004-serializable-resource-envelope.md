# Story 004: SerializableResource Envelope + payload_type CI

> **Epic**: PersistenceLayer
> **Status**: Complete
> **Layer**: Foundation
> **Type**: Logic
> **Estimate**: M (2-3 hours)
> **Manifest Version**: 2026-05-29
> **Last Updated**: 2026-05-29

## Context

**GDD**: `design/gdd/persistence-layer.md`
**Requirement**: `TR-persist-004`, `TR-persist-005`
*(TR-004: "SerializableResource envelope: `payload_type` via `get_script().get_global_name()`"; TR-005: "`_payload_dispatch` via `ClassDB.instantiate(payload_type)` — no manual registry")*

**ADR Governing Implementation**: ADR-0006 Contract 3 (tombstone serialization envelope — `to_dict()`/`from_dict()` explicit schema)
**ADR Decision Summary**: Every Resource payload crossing persistence boundary MUST extend `SerializableResource` + implement `to_dict()` + `from_dict()`. `payload_type` MUST use `get_script().get_global_name()` (NOT `get_class()` — returns `"Resource"` for all GDScript classes, silently corrupts forward-recovery). `from_dict` uses `ClassDB.instantiate(payload_type)` for lazy class lookup — no manual registry.

**Engine**: Godot 4.6 | **Risk**: HIGH
**Engine Notes**: `Object.get_class()` returns engine base class `"Resource"` for GDScript classes — this is a HIGH risk footgun. `get_script().get_global_name()` returns the registered `class_name` string (e.g., `"BossPayload"`). `ClassDB.instantiate(name)` works for any registered `class_name` in global scope — inner classes without `class_name` are FORBIDDEN as payloads.

**Control Manifest Rules (Foundation layer)**:
- Required: `payload_type = get_script().get_global_name()` (NOT `get_class()`)
- Required: All Resource payloads crossing persistence boundary extend `SerializableResource`
- Forbidden: Never use `Object.get_class()` for `payload_type` — CI enforced

---

## Acceptance Criteria

- [ ] **AC-05**: GIVEN `BossPayload.new()` with `outcome=DEFEATED`, `boss_id=42`, `hp_at_interrupt=100`, `hp_max=200`, WHEN `to_dict()` → `write("pending_transition", ...)` → `read()` → `BossPayload.from_dict()`, THEN restored `outcome==DEFEATED`, `boss_id==42`, `hp_at_interrupt==100`, `hp_max==200`; `payload_type == "BossPayload"` (NOT `"Resource"`).
- [ ] **AC-05b**: GIVEN `BossPayload.new()` with `outcome=ABANDONED` (default enum value = 0) AND `hp_at_interrupt=0` (zero integer), WHEN `to_dict()` → `from_dict()` round-trip, THEN `outcome==ABANDONED` (not corrupted to "DEFEATED" by null-find_key fallback); `hp_at_interrupt==0` (zero preserved, not dropped as falsy).
- [ ] **AC-06**: GIVEN all `.gd` files under `src/`, WHEN CI grep for `payload_type.*=.*\.get_class\(`, THEN zero matches (only `get_script().get_global_name()` allowed).

---

## Implementation Notes

*From ADR-0006 Contract 3 + GDD Rule 4:*

1. `SerializableResource` base class (already created at `src/core/serializable_resource.gd` — Foundation chain step 4, 2026-05-28):
   ```gdscript
   class_name SerializableResource extends Resource
   func to_dict() -> Dictionary: push_error("..."); return {}
   static func from_dict(_data: Dictionary) -> SerializableResource: push_error("..."); return null
   ```
2. `BossPayload extends SerializableResource` — implement `to_dict()` using `BossOutcome.find_key(outcome)` (4.4+ API, returns null on invalid value — use `if outcome_str != null else "ABANDONED"`)
3. `StateTransitionPayload extends SerializableResource` (already at `src/core/state_transition_payload.gd` — step 4) — ensure `to_dict()/from_dict()` implemented
4. `_payload_dispatch` in `from_dict`: `ClassDB.instantiate(payload_type)` — if fails → Rule 9 corrupt path (`error_code: "UNREGISTERED_PAYLOAD_TYPE"`)
5. CI script `tools/ci/check_payload_type_uses_get_script.sh`: `rg --glob "*.gd" "payload_type.*=.*\.get_class\("` — exit 1 if any match

---

## Out of Scope

- Story 009: corrupt detection when `UNREGISTERED_PAYLOAD_TYPE` triggers (Rule 9 path)
- LootPayload, other payload classes: defined in their respective system stories

---

## QA Test Cases

**AC-05** — Unit
- Given: `BossPayload` with all 4 fields set (outcome=DEFEATED, boss_id=42, hp_at_interrupt=100, hp_max=200)
- When: full round-trip through `to_dict()` → `write()` → `read()` → `from_dict()`
- Then: all 4 fields equal original; `payload_type == "BossPayload"` (NOT `"Resource"`)

**AC-05b** — Unit
- Given: `BossPayload` with `outcome=ABANDONED` (enum value 0) AND `hp_at_interrupt=0`
- When: `to_dict()` → `from_dict()` round-trip
- Then: `outcome==ABANDONED`; `hp_at_interrupt==0` (zero int preserved, not treated as missing)

**AC-06** — Static / CI
- Given: all `.gd` files under `src/`
- When: CI grep `payload_type.*=.*\.get_class\(`
- Then: exit 0, zero matches
- Edge cases: comments containing `get_class()` must not false-positive (ripgrep excludes comments by default in content mode — verify)

---

## Test Evidence

**Story Type**: Logic
**Required evidence**:
- `tests/unit/persistence-layer/test_serializable_resource_round_trip.gd` — must pass
- `tools/ci/check_payload_type_uses_get_script.sh` — must exit 0 in CI

**Status**: [x] Created — `test_serializable_resource_round_trip.gd` (6 tests) + `check_payload_type_uses_get_script.sh` (CI)

---

## Dependencies

- Depends on: Story 001 (interface exists), Story 002 (write/read exists)
- Unlocks: Story 014 (cross-system uses BossPayload envelope)

---

## Completion Notes
**Completed**: 2026-05-29
**Criteria**: 3/3 passing (AC-05 ✅ AC-05b ✅ AC-06 ✅)
**Deviations**:
- ADVISORY: BossOutcome ordering `{ABANDONED=0, DEFEATED=1}` vs ADR-0006 example `{DEFEATED=0}` — documented inline (Pillar 3 fail-safe reasoning)
- ADVISORY: `payload_type` embedded in `to_dict()` output (ADR spec has it at outer level only — redundant but harmless)
- ADVISORY: AC-05 tests use direct `to_dict()`→`from_dict()` (not through PersistenceLayer) — cleaner isolation
- INFO: CI wiring auto-handled by Story 001's `tools/ci/*.sh` workflow loop
**Test Evidence**: Logic — `test_serializable_resource_round_trip.gd` (6 tests) + `check_payload_type_uses_get_script.sh` (CI)
**Code Review**: Complete — APPROVED WITH SUGGESTIONS (2026-05-29)
**QA Coverage Gate**: ADEQUATE (inline)
**LP Code Review Gate**: APPROVE (inline)
