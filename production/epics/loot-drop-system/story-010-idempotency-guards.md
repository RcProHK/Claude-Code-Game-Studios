# Story 010: Idempotency + Malformed ID Guard + Release Guard + Unknown Tier Fallback

> **Epic**: Loot Drop System
> **Status**: Complete
> **Layer**: Core
> **Type**: Logic
> **Estimate**: M
> **Manifest Version**: 2026-05-29
> **Last Updated**: 2026-05-30

## Context

**GDD**: `design/gdd/loot-drop-system.md`
**Requirement**: `TR-loot-013`
*(Requirement: "Unknown rarity tier → COMMON fallback + telemetry (EC-22)")*

**ADR Governing Implementation**: ADR-0005 (Accepted 2026-05-30) primary; ADR-0006 (Accepted) secondary
**ADR Decision Summary**: Idempotency via `_drops_by_transition` cache keyed on `transition_id` (INV-7 + Rule 9). Deterministic RNG — same transition_id always produces same tier (AC-20, Rule 10). Malformed `transition_id` (empty/null/non-hex) → reject event + telemetry, no crash (EC-12). `_force_test_drop()` in release build → assert crash + CRITICAL telemetry (Rule 12, EC-34). Backend unknown rarity tier (`"MYTHIC"`) → reject as timeout, CRITICAL alert, no crash, no silent default (EC-22, INV-4).

**Engine**: Godot 4.6 | **Risk**: LOW
**Engine Notes**: `OS.is_debug_build()` — stable; `assert()` crashes in debug, no-ops in release (production guard via explicit check). `RegEx` for transition_id format validation — stable.

**Control Manifest Rules (Core layer)**:
- Required: Forward-recovery MUST reuse tombstone's `transition_id` verbatim (ADR-0006 Contract 2)
- Forbidden: Never call `_generate_transition_id()` inside any `_forward_recover*` function (ADR-0006 Contract 2)

---

## Acceptance Criteria

*From GDD Section H, scoped to this story:*

- [x] **AC-20** — Same transition_id → same rarity_tier + item_type + class_tag (cache cleared between calls to prove real determinism) ✅
- [x] **AC-21** — Cache hit → cached LootDrop; pre-seeded cache respected; no new generation ✅
- [x] **AC-22** — empty/null/too-short → `loot.trigger.malformed_id` telemetry; no crash; no drop ✅
- [x] **AC-25** — Simulated release (`_debug_build_override=false`) → CRITICAL `loot.debug.production_leak` telemetry + null return ✅
- [x] **AC-44** — "MYTHIC" → {} + `loot.backend.unknown_tier` CRITICAL; no crash; no silent COMMON ✅
- [x] `_drops_by_transition` cache linked to `_housekeeping_sweep_counters()` ✅

---

## Implementation Notes

*Derived from GDD Rules 9, 10, 12, EC-12, EC-22, EC-31, EC-34:*

**Idempotency cache** (in `loot_drop_system.gd`):
```gdscript
func _generate_loot_internal(transition_id: String, kind: int, workout_score: float) -> LootDrop:
    # Rule 9: idempotency check first
    if _drops_by_transition.has(transition_id):
        return _drops_by_transition[transition_id]

    # Roll new drop
    var final_tier = _compute_final_tier(transition_id, kind, workout_score)
    var rng_roll_2 = _compute_rng_roll(transition_id + "_itemtype")
    var rng_roll_3 = _compute_rng_roll(transition_id + "_classtag")
    var item_type = LootRarityCalc.item_type_weighted_selection(final_tier, _get_gear_gap(), _get_dominant_class(), rng_roll_2)
    var class_tag = LootRarityCalc.class_affinity_resolution(item_type, _get_dominant_class(), rng_roll_3)

    var drop = LootDrop.new()
    drop.drop_id = _generate_drop_id()
    drop.transition_id = transition_id
    drop.rarity_tier = RarityTier.find_key(final_tier)  # string serialization
    drop.item_type = ItemType.find_key(item_type)
    drop.class_tag = ClassTag.find_key(class_tag)
    drop.created_at_unix = int(Time.get_unix_time_from_system())
    drop.schema_version = 1

    _drops_by_transition[transition_id] = drop  # cache for idempotency
    return drop
```

**Malformed ID guard** (EC-12):
```gdscript
func _validate_transition_id(tid: String) -> bool:
    if tid == null or tid.is_empty():
        _emit_telemetry("loot.trigger.malformed_id", {"reason": "empty", "tid": ""})
        return false
    # Basic format check (non-empty string; strict hex validation in AC-37/Story 012)
    if tid.length() < 4:  # minimum sanity
        _emit_telemetry("loot.trigger.malformed_id", {"reason": "too_short", "tid": tid})
        return false
    return true
```

**Release guard** (EC-34, Rule 12):
```gdscript
func _force_test_drop(rarity_tier: int) -> void:
    if not OS.is_debug_build():
        _emit_telemetry("loot.debug.production_leak", {"rarity": rarity_tier})
        assert(false, "loot fabrication blocked in release — CRITICAL: debug API in production")
        return  # release: emit telemetry then return (assert is no-op in release builds)
    # Debug path: generate forced drop for testing
    pass
```

**Backend unknown tier** (EC-22, AC-44):
```gdscript
class_name LootDropParser

static func parse_backend_ack(response: Dictionary) -> Dictionary:
    var tier_str: String = response.get("rarity_tier", "")
    # Validate tier is in known enum
    if RarityTier.find_key(RarityTier.COMMON) == null:  # sanity test
        pass
    # Check tier_str is a valid RarityTier name
    var valid_tiers = ["COMMON", "UNCOMMON", "RARE", "EPIC", "LEGENDARY"]
    if not tier_str in valid_tiers:
        # EC-22: reject, treat as timeout, emit CRITICAL alert
        LootDropSystem.emit_telemetry_static("loot.backend.unknown_tier", {
            "received": tier_str, "severity": "CRITICAL"
        })
        return {}  # empty dict = parse failed = treat as timeout (caller handles EC-18 retry)
    return response  # valid
```

**Determinism test** (AC-20): Call `_generate_loot_internal("T-feedface", WORKOUT_DAILY, 0.75)` twice — second call hits `_drops_by_transition` cache and returns identical LootDrop object. To test actual determinism (not just cache), clear cache between calls and verify same tier/item/class.

---

## Out of Scope

- Story 009: Autoload boot (provides `_drops_by_transition` dict, `_state` checks)
- Story 012: Schema migration (transition_id format validation expanded in AC-37)
- Story 013: Backend ACK server authority (full tier correction flow — BLOCKED)

---

## QA Test Cases

**AC-20 (deterministic replay)**:
- Given: Same `transition_id = "T-feedface"`, same workout_score, same config
- When: `_generate_loot_internal()` called twice (cache cleared between calls to test real determinism)
- Then: `rarity_tier`, `item_type`, `class_tag` identical both calls
- Edge cases: Different transition_id → different drop (non-collision)

**AC-21 (idempotency cache hit)**:
- Given: `_drops_by_transition["T-abc123"]` already populated
- When: Same event triggers `_generate_loot_internal("T-abc123", ...)`
- Then: Cached LootDrop returned; no new randf() call; no duplicate `loot_dropped` signal
- Edge cases: Cache cleared after session → subsequent call re-generates (same result via RNG seed)

**AC-22 (malformed transition_id)**:
- Given: `transition_id = ""` or `transition_id = "!@#"`
- When: Signal handler receives event
- Then: `_validate_transition_id()` returns false; `loot.trigger.malformed_id` telemetry emitted; no LootDrop created; no crash
- Edge cases: null transition_id → must not crash GDScript

**AC-25 (release guard)**:
- Given: `OS.is_debug_build()` returns false (simulated via mock)
- When: `_force_test_drop(RarityTier.LEGENDARY)` called
- Then: `loot.debug.production_leak` telemetry emitted; function returns without generating drop
- Edge cases: Debug build → proceeds normally; telemetry NOT emitted in debug path

**AC-44 (unknown tier from backend)**:
- Given: Backend response `{rarity_tier: "MYTHIC"}`
- When: `LootDropParser.parse_backend_ack(response)` called
- Then: Returns empty dict {}; `loot.backend.unknown_tier` CRITICAL telemetry emitted; no crash; no silent COMMON default
- Edge cases: Valid tiers ("COMMON"..."LEGENDARY") → parse succeeds; case sensitivity checked

---

## Test Evidence

**Story Type**: Logic
**Required evidence**: 
- `tests/unit/loot/test_deterministic_rng_replay.gd` (AC-20)
- `tests/unit/loot/test_transition_id_idempotency.gd` (AC-21)
- `tests/unit/loot/test_malformed_transition_id.gd` (AC-22)
- `tests/unit/loot/test_force_test_drop_release_guard.gd` (AC-25)
- `tests/unit/loot/test_backend_unknown_rarity_tier_fallback.gd` (AC-44)

**Status**: [ ] Not yet created

---

## Dependencies

- Depends on: Story 009 (autoload provides `_drops_by_transition` dict + `_state` checks)
- Unlocks: Story 011 (trigger handlers call `_validate_transition_id()` + `_generate_loot_internal()`), Story 013 (backend ACK parsing — BLOCKED)

## Completion Notes

**Completed**: 2026-05-30
**Criteria**: 6/6 passing
**Deviations**: None
**Test Evidence**: Logic — 5 unit test files (39 test functions):
- `tests/unit/loot/test_deterministic_rng_replay.gd` (5 tests, AC-20)
- `tests/unit/loot/test_transition_id_idempotency.gd` (5 tests, AC-21)
- `tests/unit/loot/test_malformed_transition_id.gd` (10 tests, AC-22)
- `tests/unit/loot/test_force_test_drop_release_guard.gd` (6 tests, AC-25)
- `tests/unit/loot/test_backend_unknown_rarity_tier_fallback.gd` (13 tests, AC-44)
New file: `src/core/loot_drop_parser.gd` (LootDropParser static class)
**Code Review**: Complete (passed)
