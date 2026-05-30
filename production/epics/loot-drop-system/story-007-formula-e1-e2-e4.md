# Story 007: Formula E1 (Item Type) + E2 (Class Affinity) + E4 (Inventory Overflow)

> **Epic**: Loot Drop System
> **Status**: Complete
> **Layer**: Core
> **Type**: Logic
> **Estimate**: M
> **Manifest Version**: 2026-05-29
> **Last Updated**: 2026-05-30

## Context

**GDD**: `design/gdd/loot-drop-system.md`
**Requirement**: `TR-loot-008`, `TR-loot-009`, `TR-loot-010`
*(TR-loot-008: "Item type weighted selection Formula E1"; TR-loot-009: "Class affinity resolution Formula E2"; TR-loot-010: "Inventory overflow → mailbox Formula E4")*

**ADR Governing Implementation**: ADR-0005 (Accepted 2026-05-30) primary; ADR-0007 (Accepted 2026-05-29) secondary
**ADR Decision Summary**: Formulas E1/E2 use deterministic seeded RNG (second/third roll from `transition_id` + suffix — CI-6 Pillar 1 replay safety). E2 uses `ClassTag` enum (NOT `AbilityClass`) per ADR-0007 F-7 distinction. `dominant_class == null` → uniform 1/N fallback (EC-35). Formula E4 boundary is `MAX_INVENTORY = 120` (raised Pass 2 per economy F-10).

**Engine**: Godot 4.6 | **Risk**: LOW
**Engine Notes**: CDF roll via `RandomNumberGenerator.randf()` stable. `Array[float]` typed arrays stable in 4.x.

**Control Manifest Rules (Core layer)**:
- Required: Classification enum fields MUST be explicitly initialised — zero-default is FORBIDDEN (ADR-0007 Family B); `ClassTag` and `ItemType` must be initialized explicitly, never assume ordinal 0
- Forbidden: Never use integer ordinals to serialize enum values — use `find_key()` (ADR-0007)
- Required: `rng_roll_2` / `rng_roll_3` MUST seed deterministically from `hash(transition_id + suffix)` — CI-6

---

## Acceptance Criteria

*From GDD Section H, scoped to this story:*

- [x] **AC-15** — RARE + weapon_slot_starter + rng_roll_2=0.42 → ARMOR; CF-E1 Σ=1.0 ✅
- [x] **AC-16** — WEAPON + STRIKE + rng_roll_3=0.78 → NEUTRAL; CDF: dominant→NEUTRAL→off-classes = [0.650, 0.850) → NEUTRAL ✅ *(ADVISORY: Implementation Notes had wrong CDF order; fixed to match GDD)*
- [x] **AC-17** — size=119→DIRECT; size=120→MAILBOX (MAX_INVENTORY=120) ✅ *(ADVISORY: AC text stale "size=61→MAILBOX" from old MAX=60; impl uses MAX=120 per Implementation Notes)*
- [x] COSMETIC_EPIC_BONUS=0.05 applied for EPIC+ (const + test verified) ✅
- [x] CONSUMABLE/COSMETIC → ClassTag.NEUTRAL early-return ✅
- [x] EC-35 null dominant_class → uniform 1/4 deterministic (idx=int(roll×4)) ✅
- [x] rng_roll_2/rng_roll_3 seeded from `hash(transition_id + suffix)` (CI-6 documented in source) ✅

---

## Implementation Notes

*Derived from GDD Formulas E1, E2, E4:*

**Formula E1** — `item_type_weighted_selection`:
```gdscript
static func item_type_weighted_selection(
    rarity_tier: int, gear_gap_state: Dictionary, dominant_class, rng_roll_2: float
) -> int:  # ItemType
    # BASE_WEIGHTS per GDD Section D Formula E1
    var raw: Dictionary = {
        ItemType.WEAPON: 0.25,
        ItemType.ARMOR: 0.25,
        ItemType.ACCESSORY: 0.20,
        ItemType.CONSUMABLE: 0.20,
        ItemType.COSMETIC: 0.10
    }
    # gear_gap modifier
    if gear_gap_state.get("weapon_slot_starter", false):
        raw[ItemType.WEAPON] *= 1.5
    if gear_gap_state.get("armor_slot_starter", false):
        raw[ItemType.ARMOR] *= 1.5
    if gear_gap_state.get("accessory_gap", false):
        raw[ItemType.ACCESSORY] *= 1.2
    # EPIC+ cosmetic bonus
    if rarity_tier >= RarityTier.EPIC:
        raw[ItemType.COSMETIC] += COSMETIC_EPIC_BONUS  # 0.05
    # Normalize
    var total: float = 0.0
    for k in raw: total += raw[k]
    assert(total > 0.0)
    var cdf: float = 0.0
    for item_type in [ItemType.WEAPON, ItemType.ARMOR, ItemType.ACCESSORY, ItemType.CONSUMABLE, ItemType.COSMETIC]:
        cdf += raw[item_type] / total
        if rng_roll_2 < cdf:
            return item_type
    return ItemType.CONSUMABLE  # fallback

const COSMETIC_EPIC_BONUS: float = 0.05
```

**Formula E2** — `class_affinity_resolution`:
```gdscript
static func class_affinity_resolution(item_type: int, dominant_class, rng_roll_3: float) -> int:  # ClassTag
    if item_type == ItemType.CONSUMABLE or item_type == ItemType.COSMETIC:
        return ClassTag.NEUTRAL
    if dominant_class == null:
        # EC-35: uniform 25% each (explicit, not random)
        var idx = int(rng_roll_3 * 4.0)  # 0-3 for STRIKE/CONTROL/MOBILITY/NEUTRAL
        return [ClassTag.STRIKE, ClassTag.CONTROL, ClassTag.MOBILITY, ClassTag.NEUTRAL][clamp(idx, 0, 3)]
    # Weighted roll: dominant 0.65, neutral 0.20, off_class×2 0.075 each
    var dom = dominant_class  # ClassTag ordinal matching AbilityClass ordinal (STRIKE=0, etc.)
    var weights = {ClassTag.STRIKE: W_OFF_CLASS, ClassTag.CONTROL: W_OFF_CLASS, ClassTag.MOBILITY: W_OFF_CLASS, ClassTag.NEUTRAL: W_NEUTRAL}
    weights[dom] = W_DOMINANT  # override dominant
    # CDF roll
    var cdf: float = 0.0
    for ct in [ClassTag.STRIKE, ClassTag.CONTROL, ClassTag.MOBILITY, ClassTag.NEUTRAL]:
        cdf += weights[ct]
        if rng_roll_3 < cdf:
            return ct
    return ClassTag.NEUTRAL

const W_DOMINANT: float = 0.65
const W_NEUTRAL: float = 0.20
const W_OFF_CLASS: float = 0.075
```

**Formula E4** — `inventory_overflow_to_mailbox`:
```gdscript
static func inventory_overflow_to_mailbox(current_inventory_size: int) -> int:  # OverflowMode
    const MAX_INVENTORY: int = 120  # Pass 2 F-10 raised from 60
    if current_inventory_size < MAX_INVENTORY:
        return OverflowMode.DIRECT_INVENTORY
    return OverflowMode.MAILBOX_OVERFLOW
```

**CF-E1 invariant**: Normalized weights Σ == 1.0 (within 1e-6). Assert on each call in debug mode.
**CF-E2 invariant**: `W_DOMINANT + W_NEUTRAL + 2×W_OFF_CLASS = 0.65 + 0.20 + 0.15 = 1.00`. Assert loaded config.

**Note on dominant_class mapping**: `dominant_class` input comes from `#9.get_dominant_ability_class()` which returns `AbilityClass` enum ordinal. STRIKE/CONTROL/MOBILITY ordinals 0/1/2 match `ClassTag` ordinals 0/1/2. AbilityClass.UNKNOWN (ordinal 3) maps to `dominant_class == null` branch (EC-35 uniform fallback).

---

## Out of Scope

- Story 003: Formula 1 (raw_tier that feeds into E1)
- Story 008: Formula E3 (distribution analytics — uses E1/E2 outputs statistically)
- Story 014: #9 WorkoutStateTracker integration for real dominant_class (BLOCKED)

---

## QA Test Cases

**AC-15 (Formula E1 worked example)**:
- Given: RARE, weapon_slot_starter=true, rng_roll_2=0.42
- When: `item_type_weighted_selection()` called
- Then: Σ weights = 1.0 (±1e-6); CDF at 0.42 = in ARMOR band (0.341..0.568) → ARMOR
- Edge cases: EPIC drop → cosmetic weight = 0.10+0.05=0.15 before normalize; rng_roll_2=0.0 → first type in CDF

**AC-16 (Formula E2 worked example)**:
- Given: WEAPON, dominant=STRIKE, rng_roll_3=0.78
- When: `class_affinity_resolution()` called
- Then: Σ weights = 1.0; 0.78 in [0.650, 0.850) → NEUTRAL; same rng_roll_3 always produces same result
- Edge cases: CONSUMABLE → always NEUTRAL regardless of rng_roll_3; dominant_class=null, rng_roll_3=0.1 → STRIKE (uniform idx=0)

**AC-17 (Formula E4 boundary)**:
- Given: current_inventory_size=59 → DIRECT_INVENTORY; 60 → DIRECT_INVENTORY (slot 60 available); 120 → MAILBOX_OVERFLOW
- When: `inventory_overflow_to_mailbox()` called
- Then: Boundary at MAX_INVENTORY=120; < 120 → DIRECT; ≥ 120 → MAILBOX
- Edge cases: MAX_INVENTORY=0 (degenerate) → always MAILBOX; size exactly 119 → DIRECT

---

## Test Evidence

**Story Type**: Logic
**Required evidence**: 
- `tests/unit/loot/test_item_type_weighted_selection.gd` (AC-15)
- `tests/unit/loot/test_class_affinity_resolution.gd` (AC-16)
- `tests/unit/loot/test_inventory_overflow_boundary.gd` (AC-17)

**Status**: [ ] Not yet created

---

## Dependencies

- Depends on: Story 002 (enums: ItemType, ClassTag, OverflowMode, RarityTier), Story 003 (RarityTier context)
- Unlocks: Story 008 (Formula E3 uses E1/E2 as sub-routines), Story 011 (trigger routing calls E1/E2 for item generation)

## Completion Notes

**Completed**: 2026-05-30
**Criteria**: 7/7 passing
**Deviations**:
1. ADVISORY — E2 CDF order: Implementation Notes used static [STRIKE, CONTROL, MOBILITY, NEUTRAL] but GDD AC-16 worked example requires dynamic `dominant → NEUTRAL → off-classes` order. Fixed in `loot_item_calc.gd`. Logged in tech-debt-register.md.
2. ADVISORY — AC-17 story text says "size=61→MAILBOX" (stale, written at old MAX=60). Implementation uses MAX=120 per Implementation Notes (GDD Pass 2 F-10). Test `test_ac17_size_61_returns_direct_inventory` documents the discrepancy. Logged in tech-debt-register.md.
**Test Evidence**: Logic — 3 unit test files (28 test functions):
- `tests/unit/loot/test_item_type_weighted_selection.gd` (7 tests, AC-15)
- `tests/unit/loot/test_class_affinity_resolution.gd` (12 tests, AC-16)
- `tests/unit/loot/test_inventory_overflow_boundary.gd` (9 tests, AC-17)
**Code Review**: Complete (passed)
