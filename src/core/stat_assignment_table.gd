## StatAssignmentTable — D9 fixed item-stat lookup for #17 Equipment & Inventory
##
## Driving GDD: design/gdd/equipment-inventory.md § Stat Assignment Table (D9)
## Driving Story: production/epics/equipment-inventory/story-001-data-types-stat-table.md
## Governing ADRs: ADR-0003 (data-driven .tres in res://, NEVER user://)
##
## WHY a fixed lookup (vs per-tier budget roll):
## D9 — MVP item stats are deterministic: zero runtime RNG, golden-vector
## testable, no seed seam needed. Same (item_type, rarity) ⇒ identical stats;
## dup flood is answered by salvage, not stat variety. The budget-roll framework
## (Formula 7) is deferred to v0.2 Forge.
##
## CONTRACT RANGES (config-load assertion): every cell must stay within the #11
## per-key contract range — ATK ≤ +300 / HP ≤ +500 / MOVE ≤ +100 / CRIT ≤ 0.20.
## LEGENDARY WEAPON +90 is deliberately ABOVE the fresh-account AntiSnowball cap
## (84 = 3 × SDA 28) so the "+84 / +90 受真身上限約束" badge triggers in real play
## (Pillar 1 positive narrative).
class_name StatAssignmentTable extends Resource


## #11 per-key contract ceilings (registry: equipment_*_mod ranges). NOT knobs.
const ATK_CONTRACT_MAX: int = 300
const HP_CONTRACT_MAX: int = 500
const MOVE_CONTRACT_MAX: int = 100
const CRIT_CONTRACT_MAX: float = 0.20


## WEAPON → ATTACK_POWER per rarity ordinal [COMMON..LEGENDARY].
@export var weapon_atk: Array[int] = [6, 12, 22, 45, 90]

## ARMOR → MAX_HP per rarity ordinal.
@export var armor_hp: Array[int] = [20, 35, 60, 100, 160]

## ACCESSORY → MOVE_SPEED per rarity ordinal.
@export var accessory_move: Array[int] = [5, 8, 12, 18, 25]

## ACCESSORY → CRIT_CHANCE per rarity ordinal (COMMON carries no crit).
@export var accessory_crit: Array[float] = [0.0, 0.01, 0.02, 0.04, 0.06]


## Look up the stat_modifiers Dictionary for (item_type, rarity).
## CONSUMABLE / COSMETIC ⇒ {} (D1 inert / Rule 5 parallel pipeline).
## Keys are the D8 derived StringNames consumed by Formula 1 / Rule 8.
func lookup(item_type: LootEnums.ItemType, rarity: LootEnums.RarityTier) -> Dictionary:
	match item_type:
		LootEnums.ItemType.WEAPON:
			return { &"ATTACK_POWER": float(weapon_atk[rarity]) }
		LootEnums.ItemType.ARMOR:
			return { &"MAX_HP": float(armor_hp[rarity]) }
		LootEnums.ItemType.ACCESSORY:
			var mods: Dictionary = { &"MOVE_SPEED": float(accessory_move[rarity]) }
			if accessory_crit[rarity] > 0.0:
				mods[&"CRIT_CHANCE"] = accessory_crit[rarity]
			return mods
		_:
			return {}


## Config-load assertion (design-by-contract; same pattern as LootRarityConfig).
## Crashes loud in debug builds on a table that violates the #11 contract or has
## the wrong tier count. Call at boot (Story 014) and in tests.
func _validate() -> void:
	assert(weapon_atk.size() == 5, "weapon_atk must cover the 5 rarity tiers")
	assert(armor_hp.size() == 5, "armor_hp must cover the 5 rarity tiers")
	assert(accessory_move.size() == 5, "accessory_move must cover the 5 rarity tiers")
	assert(accessory_crit.size() == 5, "accessory_crit must cover the 5 rarity tiers")
	for value: int in weapon_atk:
		assert(value >= 0 and value <= ATK_CONTRACT_MAX,
			"weapon_atk cell outside #11 contract [0, %d]" % ATK_CONTRACT_MAX)
	for value: int in armor_hp:
		assert(value >= 0 and value <= HP_CONTRACT_MAX,
			"armor_hp cell outside #11 contract [0, %d]" % HP_CONTRACT_MAX)
	for value: int in accessory_move:
		assert(value >= 0 and value <= MOVE_CONTRACT_MAX,
			"accessory_move cell outside #11 contract [0, %d]" % MOVE_CONTRACT_MAX)
	for value: float in accessory_crit:
		assert(value >= 0.0 and value <= CRIT_CONTRACT_MAX,
			"accessory_crit cell outside #11 contract [0, %f]" % CRIT_CONTRACT_MAX)
