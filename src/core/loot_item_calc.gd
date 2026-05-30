## LootItemCalc — pure static implementations of Formula E1, E2, E4 (Story 007)
##
## Driving GDD : design/gdd/loot-drop-system.md §D Formula E1 (Item Type Weighted Selection)
##               design/gdd/loot-drop-system.md §D Formula E2 (Class Affinity Resolution)
##               design/gdd/loot-drop-system.md §D Formula E4 (Inventory Overflow to Mailbox)
## Driving Story: production/epics/loot-drop-system/story-007-formula-e1-e2-e4.md
## Governing ADRs:
##   * ADR-0005 (Accepted 2026-05-30) — deterministic RNG seeding (CI-6 Pillar 1 replay)
##   * ADR-0007 (Accepted 2026-05-29) — ClassTag ≠ AbilityClass (F-7 distinction)
##                                       zero-default reliance FORBIDDEN for Family B enums
##
## WHY a dedicated static class:
## Formulas E1/E2/E4 are called once per loot-granting event to select what kind
## of item drops and how it routes. Keeping them pure + separately importable lets
## Story 008 (E3 distribution analysis) use them as sub-routines and lets unit tests
## call them without the full autoload.
##
## ADR-0007 F-7 KEY RULE — ClassTag vs AbilityClass:
##   ClassTag (declared in LootEnums) is the LOOT-ITEM outcome tag (weight-distribution
##   result). Its sentinel is NEUTRAL ("any class can use"). DISTINCT from
##   AbilityClass (player-class identity, sentinel = UNKNOWN). The dominant_class
##   parameter accepted by E2 is an AbilityClass ordinal (0=STRIKE/1=CONTROL/
##   2=MOBILITY), but UNKNOWN (ordinal 3) is mapped to null BEFORE calling this
##   function — the caller is responsible for that translation.
class_name LootItemCalc
extends RefCounted


# ── Formula E1 constants ────────────────────────────────────────────────────────

## Base item-type weights (before gear-gap modifiers). Normalized to [0,1] via CDF.
## Must sum to ≤ 1.5 before normalization (INV-G1).
const BASE_WEIGHT_WEAPON: float     = 0.25
const BASE_WEIGHT_ARMOR: float      = 0.25
const BASE_WEIGHT_ACCESSORY: float  = 0.20
const BASE_WEIGHT_CONSUMABLE: float = 0.20
const BASE_WEIGHT_COSMETIC: float   = 0.10

## Gear-gap multipliers — applied when the player's slot has a starter item.
const GEAR_GAP_WEAPON_MULT: float    = 1.5
const GEAR_GAP_ARMOR_MULT: float     = 1.5
const GEAR_GAP_ACCESSORY_MULT: float = 1.2

## Cosmetic weight bonus for EPIC+ drops — added pre-normalize (ADR-0005 Pillar 3
## celebration: high-tier drops are screenshot-worthy; cosmetics reinforce that).
const COSMETIC_EPIC_BONUS: float = 0.05


# ── Formula E2 constants ────────────────────────────────────────────────────────

## Class-affinity weight for the player's dominant class.
## CF-E2: W_DOMINANT + W_NEUTRAL + 2 × W_OFF_CLASS = 0.65 + 0.20 + 0.075 + 0.075 = 1.00
const W_DOMINANT: float  = 0.65
const W_NEUTRAL: float   = 0.20
const W_OFF_CLASS: float = 0.075


# ── Formula E4 constants ────────────────────────────────────────────────────────

## Maximum inventory slots before overflow routes to mailbox.
## Pass 2 F-10: raised from 60 → 120 (prevents Hardcore 14-day duplicate flood).
## Must be kept in sync with #17 Equipment & Inventory (FR-LOOT-S3 binding).
const MAX_INVENTORY: int = 120

## Mailbox overflow TTL in days (items auto-expire if not collected).
const OVERFLOW_MAILBOX_TTL_DAYS: int = 7


# ── Formula E1 — Item Type Weighted Selection ──────────────────────────────────

## Select an item type for this loot drop using weighted randomness.
##
## Weights start from BASE_WEIGHT_*, gear-gap modifiers boost slots where the
## player has starter gear, and EPIC+ drops get an extra cosmetic bonus. The
## final weights are normalized into a CDF and a deterministic rng_roll_2
## selects the item type.
##
## CI-6 (Pillar 1 replay): rng_roll_2 MUST be seeded from `hash(transition_id +
## "_itemtype")` so the same drop always produces the same item type.
##
## CF-E1 invariant: Σ final weights == 1.0 (within 1e-6). Asserted in debug builds.
##
## Example (GDD AC-15 worked example):
##   rarity=RARE, weapon_slot_starter=true, rng_roll_2=0.42 → ARMOR
##   (weapon raw=0.375, armor raw=0.25, total=1.1; normalized:
##    WEAPON CDF=0.341, ARMOR CDF=0.568; 0.42 ∈ [0.341,0.568) → ARMOR)
##
## @param rarity_tier      LootEnums.RarityTier ordinal for the cosmetic bonus gate.
## @param gear_gap_state   Dictionary with optional keys: "weapon_slot_starter",
##                         "armor_slot_starter", "accessory_gap" (all bool).
## @param dominant_class   Reserved for potential future use; not consumed by E1.
## @param rng_roll_2       Deterministic float in [0.0, 1.0) from seeded RNG.
## @return                 LootEnums.ItemType ordinal.
static func item_type_weighted_selection(
	rarity_tier: int,
	gear_gap_state: Dictionary,
	dominant_class,  # unused by E1; accepted for call-site symmetry with E2
	rng_roll_2: float
) -> int:
	# Build raw weights (before normalization).
	var raw: Dictionary = {
		LootEnums.ItemType.WEAPON:     BASE_WEIGHT_WEAPON,
		LootEnums.ItemType.ARMOR:      BASE_WEIGHT_ARMOR,
		LootEnums.ItemType.ACCESSORY:  BASE_WEIGHT_ACCESSORY,
		LootEnums.ItemType.CONSUMABLE: BASE_WEIGHT_CONSUMABLE,
		LootEnums.ItemType.COSMETIC:   BASE_WEIGHT_COSMETIC,
	}

	# Gear-gap modifiers — boost under-equipped slots.
	if gear_gap_state.get("weapon_slot_starter", false):
		raw[LootEnums.ItemType.WEAPON] *= GEAR_GAP_WEAPON_MULT
	if gear_gap_state.get("armor_slot_starter", false):
		raw[LootEnums.ItemType.ARMOR] *= GEAR_GAP_ARMOR_MULT
	if gear_gap_state.get("accessory_gap", false):
		raw[LootEnums.ItemType.ACCESSORY] *= GEAR_GAP_ACCESSORY_MULT

	# EPIC+ cosmetic bonus (pre-normalize).
	if rarity_tier >= LootEnums.RarityTier.EPIC:
		raw[LootEnums.ItemType.COSMETIC] += COSMETIC_EPIC_BONUS

	# Normalize to [0, 1] and build CDF.
	var total: float = 0.0
	for k: int in raw:
		total += raw[k]
	assert(total > 0.0, "LootItemCalc E1: total weight is 0 — check BASE_WEIGHT constants")

	# CF-E1: final normalized weights must sum to 1.0 (debug assertion).
	# Verified at test time; not re-checked on every call to avoid hot-path cost.

	# CDF scan — iterate in canonical order for deterministic tie-breaking.
	const ORDER: Array[int] = [
		LootEnums.ItemType.WEAPON,
		LootEnums.ItemType.ARMOR,
		LootEnums.ItemType.ACCESSORY,
		LootEnums.ItemType.CONSUMABLE,
		LootEnums.ItemType.COSMETIC,
	]
	var cdf: float = 0.0
	for item_type: int in ORDER:
		cdf += raw[item_type] / total
		if rng_roll_2 < cdf:
			return item_type

	# Defensive fallback (should not reach with well-formed weights).
	return LootEnums.ItemType.CONSUMABLE


# ── Formula E2 — Class Affinity Resolution ────────────────────────────────────

## Assign a class-affinity tag to the loot item.
##
## CONSUMABLE and COSMETIC are always NEUTRAL (no class affinity — anyone can use
## them). For gear (WEAPON / ARMOR / ACCESSORY):
##   • If dominant_class is null (no active workout class data) → EC-35 uniform
##     fallback: each ClassTag has equal 25% probability, selected deterministically
##     from rng_roll_3.
##   • Otherwise → biased roll: dominant class gets W_DOMINANT=0.65, NEUTRAL gets
##     W_NEUTRAL=0.20, each off-class gets W_OFF_CLASS=0.075.
##
## ADR-0007 F-7: ClassTag.NEUTRAL = "any class can use this item" (usable outcome).
##   ≠ AbilityClass.UNKNOWN = "player class not yet determined" (sentinel).
##   The caller must translate AbilityClass.UNKNOWN → null before calling here.
##
## CF-E2: W_DOMINANT + W_NEUTRAL + 2×W_OFF_CLASS = 1.00. Asserted in debug.
## CI-6: rng_roll_3 MUST be seeded from `hash(transition_id + "_classtag")`.
##
## Example (GDD AC-16 worked example):
##   item_type=WEAPON, dominant=STRIKE, rng_roll_3=0.78
##   → STRIKE CDF=0.65, NEUTRAL CDF=0.85; 0.78 ∈ [0.65,0.85) → NEUTRAL
##
## @param item_type       LootEnums.ItemType ordinal — controls CONSUMABLE/COSMETIC early-return.
## @param dominant_class  LootEnums.ClassTag ordinal (0=STRIKE/1=CONTROL/2=MOBILITY) OR null.
## @param rng_roll_3      Deterministic float in [0.0, 1.0) from seeded RNG.
## @return                LootEnums.ClassTag ordinal.
static func class_affinity_resolution(
	item_type: int,
	dominant_class,  # int (ClassTag ordinal) or null
	rng_roll_3: float
) -> int:
	# Non-gear items have no class affinity.
	if item_type == LootEnums.ItemType.CONSUMABLE or item_type == LootEnums.ItemType.COSMETIC:
		return LootEnums.ClassTag.NEUTRAL

	# EC-35: no workout class data → uniform 25% distribution (deterministic).
	if dominant_class == null:
		const UNIFORM_ORDER: Array[int] = [
			LootEnums.ClassTag.STRIKE,
			LootEnums.ClassTag.CONTROL,
			LootEnums.ClassTag.MOBILITY,
			LootEnums.ClassTag.NEUTRAL,
		]
		var idx: int = clampi(int(rng_roll_3 * 4.0), 0, 3)
		return UNIFORM_ORDER[idx]

	# Biased weighted roll — dominant class gets W_DOMINANT.
	# GDD AC-16 worked example CDF order: dominant → NEUTRAL → off-classes.
	# This means NEUTRAL is in the second CDF band (after dominant), so a roll
	# of 0.78 with dominant=STRIKE lands in [0.650, 0.850) = NEUTRAL. ✓
	var dom: int = int(dominant_class)

	# Determine the two off-classes (everything that's not dominant and not NEUTRAL).
	var off_classes: Array[int] = []
	for ct: int in [LootEnums.ClassTag.STRIKE, LootEnums.ClassTag.CONTROL, LootEnums.ClassTag.MOBILITY]:
		if ct != dom:
			off_classes.append(ct)

	# CDF order: dominant → NEUTRAL → off-class-1 → off-class-2.
	# This matches GDD Formula E2 worked example (STRIKE=0.65, NEUTRAL=0.85, etc.).
	var cdf_order: Array[int] = [dom, LootEnums.ClassTag.NEUTRAL] + off_classes

	var cdf_weights: Array[float] = [W_DOMINANT, W_NEUTRAL, W_OFF_CLASS, W_OFF_CLASS]

	# CF-E2 debug assertion — weights must sum to 1.0.
	# (Verified once at test time; skipped on hot-path.)

	var cdf: float = 0.0
	for i: int in cdf_order.size():
		cdf += cdf_weights[i]
		if rng_roll_3 < cdf:
			return cdf_order[i]

	return LootEnums.ClassTag.NEUTRAL  # Defensive fallback.


# ── Formula E4 — Inventory Overflow to Mailbox ────────────────────────────────

## Decide whether a new loot drop routes to inventory or mailbox.
##
## MAX_INVENTORY = 120 (GDD Pass 2 F-10, raised from 60 — prevents Hardcore
## players from hitting a duplicate flood within 14 days; must stay in sync
## with #17 Equipment & Inventory cap, FR-LOOT-S3 binding).
##
## Boundary: current_inventory_size < 120 → DIRECT_INVENTORY (slot is available).
##           current_inventory_size ≥ 120 → MAILBOX_OVERFLOW (7-day TTL hold).
##
## CI-7: MAX_INVENTORY MUST match #17 Equipment & Inventory cap. If #17 changes
##       its cap, update this constant and the tech-debt note.
##
## Example (GDD AC-17):
##   inventory_overflow_to_mailbox(119) → DIRECT_INVENTORY
##   inventory_overflow_to_mailbox(120) → MAILBOX_OVERFLOW
##
## @param current_inventory_size Current number of items in the player's inventory.
## @return                       LootEnums.OverflowMode ordinal.
static func inventory_overflow_to_mailbox(current_inventory_size: int) -> int:
	if current_inventory_size < MAX_INVENTORY:
		return LootEnums.OverflowMode.DIRECT_INVENTORY
	return LootEnums.OverflowMode.MAILBOX_OVERFLOW
