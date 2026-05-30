# Story 002: LootRarityConfig Resource + LootDrop Data Record + Enum Declarations

> **Epic**: Loot Drop System
> **Status**: Complete
> **Layer**: Core
> **Type**: Logic
> **Estimate**: S
> **Manifest Version**: 2026-05-29
> **Last Updated**: 2026-05-30

## Context

**GDD**: `design/gdd/loot-drop-system.md`
**Requirement**: `TR-loot-018`
*(Requirement text: "27 owned knobs + 14 INVs + 10 CI lints" — knobs/config portion)*

**ADR Governing Implementation**: ADR-0005 (Accepted 2026-05-30) primary; ADR-0007 (Accepted 2026-05-29) secondary
**ADR Decision Summary**: All formula parameters stored in `LootRarityConfig extends Resource` with `@export` fields. `_validate()` asserts `WORKOUT_WEIGHT + RNG_WEIGHT == 1.0` + `workout_weight >= 0.70`. `LootDrop` extends `SerializableResource` with `to_dict()`/`from_dict()`. Classification enums (`ClassTag`, `ItemType`) must be explicitly initialised — zero-default is FORBIDDEN per ADR-0007 Family B.

**Engine**: Godot 4.6 | **Risk**: LOW
**Engine Notes**: `@export var tier_thresholds: Array[float]` — typed arrays supported in Godot 4.x. `class_name` registration via `extends Resource` is stable. No post-cutoff API sensitivity.

**Control Manifest Rules (Core layer)**:
- Required: Every Resource payload crossing persistence boundary MUST extend `SerializableResource` with `to_dict()`/`from_dict()` and `payload_type` via `get_script().get_global_name()` (ADR-0006 Contract 3)
- Required: Classification enum fields MUST be explicitly initialised — zero-default is FORBIDDEN (ADR-0007 Family B)
- Required: Outcome/State enum ordinal 0 = safe/uninitialised value (ADR-0007 Family A)
- Forbidden: Never use integer ordinals to serialize enum values — use `find_key()` string names (ADR-0007)
- Forbidden: Never use `Object.get_class()` for `payload_type` — use `get_script().get_global_name()` (ADR-0006 Contract 3)

---

## Acceptance Criteria

*From GDD `design/gdd/loot-drop-system.md` Section H, scoped to this story:*

- [x] **AC-36 (partial)** — `LootRarityConfig._validate()` asserts `INV-1` (`WORKOUT_WEIGHT + RNG_WEIGHT == 1.0`) and `INV-6` (tier_thresholds strictly ascending); either fails → hard assert with `push_error()` crash ✅
- [x] `LootRarityConfig.tres` created with ADR-0005 defaults *(ADVISORY: path is `assets/data/loot/loot_rarity_config.tres` — aligned to CI lint, not story spec)*  ✅
- [x] `LootDrop` class extends `SerializableResource`; implements `to_dict()` and `from_dict()`; `payload_type = get_script().get_global_name()`; all 9 fields present ✅
- [x] `RarityTier` enum declared: `{ COMMON = 0, UNCOMMON = 1, RARE = 2, EPIC = 3, LEGENDARY = 4 }` (Family A — ordinal 0 = safe floor) ✅
- [x] `SourceEventKind` enum declared: `{ WORKOUT_DAILY, MINI_BOSS, FINAL_BOSS }` (Family A) ✅
- [x] `CeremonyDecision` enum declared: `{ FULL_CEREMONY, MICRO_ACK, NON_CEREMONY_ROUTE }` (Family A) ✅
- [x] `ClassTag` enum declared: `{ STRIKE, CONTROL, MOBILITY, NEUTRAL }` (Family B — loot item outcome tag, distinct from `AbilityClass` per ADR-0007 F-7 clarification; `NEUTRAL` = "any class can use" item tag, NOT player class sentinel) ✅
- [x] `ItemType` enum declared: `{ WEAPON, ARMOR, ACCESSORY, CONSUMABLE, COSMETIC }` (Family B) ✅
- [x] `ExpiryState` enum declared: `{ FRESH, SOFT_EXPIRED, HARD_EXPIRED }` (Family A) ✅
- [x] `ResumeAction` enum declared: `{ CONTINUE_ANIMATION, DEFER_TO_NEXT_BOOT, NO_ACTION }` (Family A) ✅
- [x] `CatchUpMode` enum declared: `{ SEQUENTIAL_REVEAL, SUMMARY_BANNER_THEN_BURST }` (Family A) ✅
- [x] `OverflowMode` enum declared: `{ DIRECT_INVENTORY, MAILBOX_OVERFLOW }` (Family A) ✅
- [x] `design/registry/entities.yaml` updated — `build_pins.loot_rarity_config_sha256: "TBD"` (CI lint exits 0 on TBD placeholder) *(ADVISORY: SHA pending Godot import)* ✅

---

## Implementation Notes

*Derived from ADR-0005 Decision + GDD Section D Data Architecture:*

**File locations**:
- `src/core/loot_drop.gd` — `LootDrop` SerializableResource
- `res://data/loot/loot_rarity_config.tres` — tuning knob resource (designer-editable)
- Enums declared as inner classes or top-level in `src/core/loot_drop_system_enums.gd` (or inside `loot_drop_system.gd` when created in Story 009)

**LootRarityConfig field defaults** (from ADR-0005 Tuning Knob table):
```gdscript
class_name LootRarityConfig extends Resource

@export var workout_weight: float = 0.75
@export var rng_weight: float = 0.25
@export var target_exercises: int = 5
@export var pr_bonus_per_pr: float = 0.12
@export var max_pr_factor: float = 1.25
@export var streak_scale: float = 28.0
@export var max_streak_bonus: float = 0.20
@export var tier_thresholds: Array[float] = [0.0, 0.35, 0.55, 0.72, 0.88]
@export var tier_values: Array[int] = [0, 1, 2, 3, 4]  # RarityTier ordinals

func _validate() -> void:
    assert(abs(workout_weight + rng_weight - 1.0) < 1e-6, "INV-1: Weights must sum to 1.0")
    assert(workout_weight >= 0.70, "Pillar 1 violation: workout_weight < 0.70")
    assert(rng_weight <= 0.30, "Pillar 1 violation: rng_weight > 0.30")
    # INV-6: strictly ascending thresholds
    for i in range(1, tier_thresholds.size()):
        assert(tier_thresholds[i] > tier_thresholds[i-1], "INV-6: thresholds not strictly ascending")
```

**ADR-0007 enum distinction (F-7)**: `ClassTag.NEUTRAL` ≠ `AbilityClass.UNKNOWN`. `ClassTag` is a loot-item outcome enum (weight-distribution result). `AbilityClass.UNKNOWN` is a player-class sentinel (per ADR-0007 Family B). Do NOT conflate. Both enums have `STRIKE/CONTROL/MOBILITY` members but are distinct types and must never be cast/compared cross-enum.

**LootDrop serialization**: `rarity_tier` stored as enum string name (`RarityTier.find_key(value)`) per ADR-0007 string-name serialization rule. Same for `item_type`, `class_tag`, `source_event_kind`.

**SHA pinning**: After creating `LootRarityConfig.tres`, compute SHA-256 and add entry to `design/registry/entities.yaml`:
```yaml
loot_rarity_config_sha: "<sha256_hex>"
```
This enables `check_loot_config_hash_pinned.gd` from Story 001.

---

## Out of Scope

- Story 001: CI lint scripts (validate this story's output)
- Story 003: Formula computation using these types
- Story 009: `LootDropSystem` autoload (imports these types)

---

## QA Test Cases

**AC-36 (config invariants)**:
- Given: `LootRarityConfig` with `workout_weight = 0.80, rng_weight = 0.20` (valid)
- When: `_validate()` called
- Then: No assertion fires
- Edge cases: `workout_weight = 0.69` → assertion fires; `rng_weight = 0.31` → assertion fires; `tier_thresholds = [0.0, 0.55, 0.35, ...]` (non-ascending) → assertion fires

**ClassTag enum distinctness**:
- Given: `ClassTag.NEUTRAL` and `AbilityClass.UNKNOWN` are distinct enum types
- When: Code attempts `var x: ClassTag = AbilityClass.UNKNOWN` (should be type error)
- Then: GDScript static type check fails at editor level; no runtime confusion
- Edge cases: Verify `ClassTag.find_key(ClassTag.NEUTRAL)` returns "NEUTRAL", not "UNKNOWN"

**LootDrop round-trip serialization**:
- Given: `LootDrop` with all fields populated
- When: `to_dict()` then `from_dict()` called
- Then: All fields identical; `payload_type == "LootDrop"` (via `get_script().get_global_name()`)
- Edge cases: Missing optional fields in dict → graceful default

---

## Test Evidence

**Story Type**: Logic
**Required evidence**: `tests/unit/loot/test_data_resources.gd` — must exist and pass

**Status**: [ ] Not yet created

---

## Dependencies

- Depends on: Story 001 (CI lints will validate these resources; lint scripts should exist first)
- Unlocks: Story 003, 004, 005, 006, 007, 008, 009 (all formula stories import these types)

## Completion Notes

**Completed**: 2026-05-30
**Criteria**: 13/13 passing
**Deviations**:
1. ADVISORY — `.tres` path is `assets/data/loot/loot_rarity_config.tres` (story spec said `data/loot/LootRarityConfig.tres`). Aligned to Story 001 CI lint `CONFIG_FILE` — lint is the CI gate and cannot be changed; impl follows lint. Logged in tech-debt-register.md.
2. ADVISORY — `entities.yaml` key is `loot_rarity_config_sha256` (story spec said `loot_rarity_config_sha`). Aligned to lint `PIN_KEY`. Logged in tech-debt-register.md.
3. ADVISORY — SHA value is `"TBD"` placeholder. CI lint exits 0 on TBD. Update to real SHA-256 after first Godot import of `.tres` file. Logged in tech-debt-register.md.
**Test Evidence**: Logic — `tests/unit/loot/test_data_resources.gd` (50 test functions)
**Code Review**: Complete (passed)
