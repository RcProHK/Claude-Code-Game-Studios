# InventorySystem — Story 006: slot model + auto-equip-if-better orchestration.
#
# Scope (GDD Rule 5/6/7 + EC-11/12):
#   AC-12 — stronger candidate swaps in; previous → IN_INVENTORY
#   AC-13 — locked equipped item freezes its slot (lock always wins)
#   AC-14 — deterministic tie-break (rarity ↓ → acquired_at ↑ → item_id ↑)
#   AC-15 — empty-slot backfill (baseline 0); cosmetic never auto-equips
#   AC-19 — clamp-aware marginal: capped ATK never displaces HP (loadout-level)
#   AC-23 — slot affinity routing; CONSUMABLE no slot, no auto-equip
#   AC-41 — claim 後 auto-equip evaluation runs
#
# Framework: GUT v9.x | mock StatSystem seam (untyped — project DI pattern)
# Story: production/epics/equipment-inventory/story-006-auto-equip-orchestration.md
extends GutTest

const InventorySystem := preload("res://src/autoload/inventory_system.gd")
const TABLE_PATH: String = "res://assets/data/equipment/stat_assignment_table.tres"

const FIXED_NOW: int = 1764547300

var _sut
var _mock_stat: MockStat


class MockStat extends RefCounted:
	var sda: float = 28.0  # fresh account default
	var pushes: Array[Dictionary] = []

	func get_attack_power_excluding_equipment() -> float:
		return sda

	func apply_equipment_modifier(equipment_id: StringName, modifier) -> void:
		pushes.append({"id": equipment_id, "deltas": modifier.deltas.duplicate()})


func before_each() -> void:
	_mock_stat = MockStat.new()
	_sut = InventorySystem.new()
	_sut._stat_table = load(TABLE_PATH)
	_sut._stat_system = _mock_stat
	_sut._now_unix_provider = func() -> int: return FIXED_NOW
	add_child_autofree(_sut)


func _make_item(
		id_suffix: String, item_type: int, rarity: int,
		mods: Dictionary, acquired_at: int = FIXED_NOW) -> EquipmentItem:
	var item: EquipmentItem = EquipmentItem.new()
	item.item_id = StringName("tid_%s_D-0-%s" % [id_suffix, id_suffix])
	item.item_type = item_type
	item.rarity = rarity
	item.stat_modifiers = mods
	item.acquired_at_unix = acquired_at
	item.lifecycle_state = EquipmentEnums.ItemLifecycle.IN_INVENTORY
	item.slot_affinity = _sut._slot_affinity_for(item_type)
	item.is_cosmetic = item_type == LootEnums.ItemType.COSMETIC
	_sut._items[item.item_id] = item
	return item


func _receive(item_type: String, rarity: String, drop_id: String) -> StringName:
	var record: LootDrop = LootDrop.new()
	record.drop_id = drop_id
	record.transition_id = "tid_live"
	record.item_type = item_type
	record.rarity_tier = rarity
	record.class_tag = "STRIKE"
	if rarity == "LEGENDARY":
		record.item_metadata["source_receipt"] = {"signature_text": "鍛造自 180kg × 5"}
	_sut.receive_loot(record)
	return StringName("tid_live_" + drop_id)


# ─── AC-12: stronger candidate swaps ───────────────────────────────────────────


func test_stronger_weapon_swaps_in_previous_returns_to_inventory() -> void:
	# Arrange — RARE (+22) equipped
	var rare: EquipmentItem = _make_item("rare", LootEnums.ItemType.WEAPON,
		LootEnums.RarityTier.RARE, { &"ATTACK_POWER": 22.0 })
	_sut._swap_into_slot(EquipmentEnums.EquipSlot.WEAPON, rare)

	# Act — EPIC (+45) arrives via the live path
	var epic_id: StringName = _receive("WEAPON", "EPIC", "D-9-1")

	# Assert
	assert_eq(_sut.get_item(epic_id).lifecycle_state,
		EquipmentEnums.ItemLifecycle.EQUIPPED)
	assert_eq(rare.lifecycle_state, EquipmentEnums.ItemLifecycle.IN_INVENTORY)


func test_weaker_candidate_does_not_swap() -> void:
	# Arrange — EPIC (+45) equipped
	var epic: EquipmentItem = _make_item("epic", LootEnums.ItemType.WEAPON,
		LootEnums.RarityTier.EPIC, { &"ATTACK_POWER": 45.0 })
	_sut._swap_into_slot(EquipmentEnums.EquipSlot.WEAPON, epic)

	# Act — COMMON (+6) arrives
	var common_id: StringName = _receive("WEAPON", "COMMON", "D-9-2")

	# Assert — strictly-greater rule: stays banked
	assert_eq(_sut.get_item(common_id).lifecycle_state,
		EquipmentEnums.ItemLifecycle.IN_INVENTORY)
	assert_eq(epic.lifecycle_state, EquipmentEnums.ItemLifecycle.EQUIPPED)


# ─── AC-13: lock always wins ───────────────────────────────────────────────────


func test_locked_equipped_item_freezes_slot() -> void:
	# Arrange — locked COMMON equipped
	var locked: EquipmentItem = _make_item("locked", LootEnums.ItemType.WEAPON,
		LootEnums.RarityTier.COMMON, { &"ATTACK_POWER": 6.0 })
	locked.is_locked = true
	_sut._swap_into_slot(EquipmentEnums.EquipSlot.WEAPON, locked)

	# Act — LEGENDARY arrives
	var legendary_id: StringName = _receive("WEAPON", "LEGENDARY", "D-9-3")

	# Assert — skip: new item banked, loadout unchanged
	assert_eq(_sut.get_item(legendary_id).lifecycle_state,
		EquipmentEnums.ItemLifecycle.IN_INVENTORY)
	assert_eq(locked.lifecycle_state, EquipmentEnums.ItemLifecycle.EQUIPPED)


# ─── AC-14: deterministic tie-break ────────────────────────────────────────────


func test_backfill_tie_break_prefers_older_acquired_at() -> void:
	# Arrange — two identical-score COMMON weapons, different ages
	_make_item("newer", LootEnums.ItemType.WEAPON, LootEnums.RarityTier.COMMON,
		{ &"ATTACK_POWER": 6.0 }, FIXED_NOW)
	var older: EquipmentItem = _make_item("older", LootEnums.ItemType.WEAPON,
		LootEnums.RarityTier.COMMON, { &"ATTACK_POWER": 6.0 }, FIXED_NOW - 1000)

	# Act — deterministic re-runs (AC-14: same result every time)
	_sut._backfill_slot(EquipmentEnums.EquipSlot.WEAPON)

	# Assert — older kept... er, older WINS the empty slot (less churn ordering)
	assert_eq(older.lifecycle_state, EquipmentEnums.ItemLifecycle.EQUIPPED)


func test_backfill_tie_break_prefers_higher_rarity_first() -> void:
	# Arrange — equal score, different rarity (fixture forces the tie)
	_make_item("common", LootEnums.ItemType.WEAPON, LootEnums.RarityTier.COMMON,
		{ &"ATTACK_POWER": 10.0 })
	var rare: EquipmentItem = _make_item("rare", LootEnums.ItemType.WEAPON,
		LootEnums.RarityTier.RARE, { &"ATTACK_POWER": 10.0 })

	# Act
	_sut._backfill_slot(EquipmentEnums.EquipSlot.WEAPON)

	# Assert
	assert_eq(rare.lifecycle_state, EquipmentEnums.ItemLifecycle.EQUIPPED)


# ─── AC-15: empty-slot backfill + cosmetic manual-only ─────────────────────────


func test_positive_candidate_backfills_empty_slot() -> void:
	# Arrange — empty WEAPON slot + one COMMON weapon banked
	var weapon: EquipmentItem = _make_item("w", LootEnums.ItemType.WEAPON,
		LootEnums.RarityTier.COMMON, { &"ATTACK_POWER": 6.0 })

	# Act
	_sut._backfill_slot(EquipmentEnums.EquipSlot.WEAPON)

	# Assert — baseline 0, any positive candidate wins
	assert_eq(weapon.lifecycle_state, EquipmentEnums.ItemLifecycle.EQUIPPED)


func test_cosmetic_never_auto_equips() -> void:
	# Arrange / Act — cosmetic arrives with COSMETIC slot empty
	var record: LootDrop = LootDrop.new()
	record.drop_id = "D-9-5"
	record.transition_id = "tid_live"
	record.item_type = "COSMETIC"
	record.rarity_tier = "EPIC"
	record.item_metadata["visual_id"] = "cape"
	_sut.receive_loot(record)

	# Assert — manual-only: stays IN_INVENTORY, COSMETIC slot stays empty
	var item: EquipmentItem = _sut.get_item(&"tid_live_D-9-5")
	assert_eq(item.lifecycle_state, EquipmentEnums.ItemLifecycle.IN_INVENTORY)
	assert_eq(_sut._loadout[EquipmentEnums.EquipSlot.COSMETIC], &"")


# ─── AC-19: clamp-aware marginal (never weaken) ────────────────────────────────


func test_capped_atk_candidate_does_not_displace_hp_item() -> void:
	# Arrange — SDA 28 → cap 84. L weapon (+90 → 84 capped) + RARE armor (+60 HP).
	var weapon: EquipmentItem = _make_item("w", LootEnums.ItemType.WEAPON,
		LootEnums.RarityTier.LEGENDARY, { &"ATTACK_POWER": 90.0 })
	_sut._swap_into_slot(EquipmentEnums.EquipSlot.WEAPON, weapon)
	var armor: EquipmentItem = _make_item("a", LootEnums.ItemType.ARMOR,
		LootEnums.RarityTier.RARE, { &"MAX_HP": 60.0 })
	_sut._swap_into_slot(EquipmentEnums.EquipSlot.ARMOR, armor)

	# Act — hypothetical ATK-heavy armor-slot fixture (ATK already at cap):
	# current score = 84 + 15 = 99; with swap = clamp(90+100)=84 → 84 < 99.
	var atk_armor: EquipmentItem = _make_item("x", LootEnums.ItemType.ARMOR,
		LootEnums.RarityTier.LEGENDARY, { &"ATTACK_POWER": 100.0 })
	_sut._evaluate_auto_equip(atk_armor)

	# Assert — loadout-marginal refuses the strictly-worse swap
	assert_eq(armor.lifecycle_state, EquipmentEnums.ItemLifecycle.EQUIPPED)
	assert_eq(atk_armor.lifecycle_state, EquipmentEnums.ItemLifecycle.IN_INVENTORY)


# ─── AC-23: slot routing + CONSUMABLE inert ────────────────────────────────────


func test_each_functional_type_routes_to_its_slot() -> void:
	# Arrange / Act
	var weapon_id: StringName = _receive("WEAPON", "COMMON", "D-9-10")
	var armor_id: StringName = _receive("ARMOR", "COMMON", "D-9-11")
	var accessory_id: StringName = _receive("ACCESSORY", "COMMON", "D-9-12")

	# Assert — empty slots backfilled 1:1 on receive
	assert_eq(_sut._loadout[EquipmentEnums.EquipSlot.WEAPON], weapon_id)
	assert_eq(_sut._loadout[EquipmentEnums.EquipSlot.ARMOR], armor_id)
	assert_eq(_sut._loadout[EquipmentEnums.EquipSlot.ACCESSORY], accessory_id)


func test_consumable_grants_but_never_triggers_auto_equip() -> void:
	# Arrange / Act
	var consumable_id: StringName = _receive("CONSUMABLE", "COMMON", "D-9-13")

	# Assert — banked, NONE slot, loadout untouched, zero pushes
	var item: EquipmentItem = _sut.get_item(consumable_id)
	assert_eq(item.slot_affinity, EquipmentEnums.EquipSlot.NONE)
	assert_eq(item.lifecycle_state, EquipmentEnums.ItemLifecycle.IN_INVENTORY)
	assert_eq(_mock_stat.pushes.size(), 0)


# ─── AC-41: claim 後 auto-equip ─────────────────────────────────────────────────


func test_claim_triggers_auto_equip_for_stronger_item() -> void:
	# Arrange — weak weapon equipped; stronger one parked in mailbox
	var weak: EquipmentItem = _make_item("weak", LootEnums.ItemType.WEAPON,
		LootEnums.RarityTier.COMMON, { &"ATTACK_POWER": 6.0 })
	_sut._swap_into_slot(EquipmentEnums.EquipSlot.WEAPON, weak)
	var strong: EquipmentItem = _make_item("strong", LootEnums.ItemType.WEAPON,
		LootEnums.RarityTier.EPIC, { &"ATTACK_POWER": 45.0 })
	strong.lifecycle_state = EquipmentEnums.ItemLifecycle.IN_MAILBOX

	# Act
	var result: Dictionary = _sut.claim(strong.item_id)

	# Assert — claimed → evaluated → equipped
	assert_true(result["ok"])
	assert_eq(strong.lifecycle_state, EquipmentEnums.ItemLifecycle.EQUIPPED)
	assert_eq(weak.lifecycle_state, EquipmentEnums.ItemLifecycle.IN_INVENTORY)
