# InventorySystem — Story 011: manual override + item-level lock.
#
# Scope (GDD Rule 7 + AC-34):
#   AC-34 — manual equip of a WEAKER item succeeds (not score-gated) + one
#           re-push; next auto-equip trigger displaces it (unlocked = not
#           respected, by design); unequip → IN_INVENTORY + re-push
#   set_lock is item-level; type-mismatch guard refuses with zero mutation
#
# Framework: GUT v9.x
# Story: production/epics/equipment-inventory/story-011-manual-override-lock.md
extends GutTest

const InventorySystem := preload("res://src/autoload/inventory_system.gd")
const TABLE_PATH: String = "res://assets/data/equipment/stat_assignment_table.tres"

const FIXED_NOW: int = 1764547300

var _sut
var _mock_stat: MockInventoryStat




func before_each() -> void:
	_mock_stat = MockInventoryStat.new()
	_sut = InventorySystem.new()
	_sut._persistence = MockPersistenceLayer.new()
	_sut._gsm = MockInventoryGSM.new()
	_sut._stat_table = load(TABLE_PATH)
	_sut._stat_system = _mock_stat
	_sut._now_unix_provider = func() -> int: return FIXED_NOW
	add_child_autofree(_sut)


func _make_item(id_suffix: String, item_type: int, rarity: int,
		mods: Dictionary) -> EquipmentItem:
	var item: EquipmentItem = EquipmentItem.new()
	item.item_id = StringName("tid_%s_D-0-%s" % [id_suffix, id_suffix])
	item.item_type = item_type
	item.rarity = rarity
	item.stat_modifiers = mods
	item.acquired_at_unix = FIXED_NOW
	item.lifecycle_state = EquipmentEnums.ItemLifecycle.IN_INVENTORY
	item.slot_affinity = _sut._slot_affinity_for(item_type)
	_sut._items[item.item_id] = item
	return item


# ─── AC-34: manual equip not score-gated + auto-equip interplay ────────────────


func test_manual_equip_weaker_item_succeeds_with_one_push() -> void:
	# Arrange — EPIC equipped, COMMON banked
	var epic: EquipmentItem = _make_item("e", LootEnums.ItemType.WEAPON,
		LootEnums.RarityTier.EPIC, { &"attack_power": 45.0 })
	_sut._swap_into_slot(EquipmentEnums.EquipSlot.WEAPON, epic)
	var common: EquipmentItem = _make_item("c", LootEnums.ItemType.WEAPON,
		LootEnums.RarityTier.COMMON, { &"attack_power": 6.0 })
	_mock_stat.pushes.clear()

	# Act — player's call: equip the weaker one
	var result: Dictionary = _sut.equip(common.item_id, EquipmentEnums.EquipSlot.WEAPON)

	# Assert
	assert_true(result["ok"])
	assert_eq(common.lifecycle_state, EquipmentEnums.ItemLifecycle.EQUIPPED)
	assert_eq(epic.lifecycle_state, EquipmentEnums.ItemLifecycle.IN_INVENTORY)
	assert_eq(_mock_stat.pushes.size(), 1)
	assert_almost_eq(_mock_stat.pushes[0]["deltas"][&"attack_power"], 6.0, 0.0001)


func test_unlocked_manual_choice_displaced_by_next_auto_trigger() -> void:
	# Arrange — manual weaker choice in place (unlocked)
	var epic: EquipmentItem = _make_item("e", LootEnums.ItemType.WEAPON,
		LootEnums.RarityTier.EPIC, { &"attack_power": 45.0 })
	var common: EquipmentItem = _make_item("c", LootEnums.ItemType.WEAPON,
		LootEnums.RarityTier.COMMON, { &"attack_power": 6.0 })
	_sut.equip(common.item_id, EquipmentEnums.EquipSlot.WEAPON)

	# Act — any auto-equip evaluation runs (e.g. the banked EPIC re-evaluated)
	_sut._evaluate_auto_equip(epic)

	# Assert — unlocked manual choice does NOT survive (lock is the mechanism)
	assert_eq(epic.lifecycle_state, EquipmentEnums.ItemLifecycle.EQUIPPED)
	assert_eq(common.lifecycle_state, EquipmentEnums.ItemLifecycle.IN_INVENTORY)


func test_locked_manual_choice_survives_auto_trigger() -> void:
	# Arrange — manual weaker choice, then locked
	var epic: EquipmentItem = _make_item("e", LootEnums.ItemType.WEAPON,
		LootEnums.RarityTier.EPIC, { &"attack_power": 45.0 })
	var common: EquipmentItem = _make_item("c", LootEnums.ItemType.WEAPON,
		LootEnums.RarityTier.COMMON, { &"attack_power": 6.0 })
	_sut.equip(common.item_id, EquipmentEnums.EquipSlot.WEAPON)
	_sut.set_lock(common.item_id, true)

	# Act
	_sut._evaluate_auto_equip(epic)

	# Assert — lock always wins (Rule 7)
	assert_eq(common.lifecycle_state, EquipmentEnums.ItemLifecycle.EQUIPPED)


# ─── unequip ───────────────────────────────────────────────────────────────────


func test_unequip_returns_item_to_inventory_with_push() -> void:
	# Arrange
	var weapon: EquipmentItem = _make_item("w", LootEnums.ItemType.WEAPON,
		LootEnums.RarityTier.RARE, { &"attack_power": 22.0 })
	_sut._swap_into_slot(EquipmentEnums.EquipSlot.WEAPON, weapon)
	_mock_stat.pushes.clear()

	# Act
	var result: Dictionary = _sut.unequip(EquipmentEnums.EquipSlot.WEAPON)

	# Assert
	assert_true(result["ok"])
	assert_eq(weapon.lifecycle_state, EquipmentEnums.ItemLifecycle.IN_INVENTORY)
	assert_eq(_sut._loadout[EquipmentEnums.EquipSlot.WEAPON], &"")
	assert_eq(_mock_stat.pushes.size(), 1)
	assert_eq(_mock_stat.pushes[0]["deltas"], {})


func test_unequip_empty_slot_errors() -> void:
	var result: Dictionary = _sut.unequip(EquipmentEnums.EquipSlot.ARMOR)
	assert_false(result["ok"])
	assert_eq(result["error"], "slot_empty")


# ─── Guards ────────────────────────────────────────────────────────────────────


func test_equip_type_mismatch_refused_zero_mutation() -> void:
	# Arrange — weapon into the ARMOR slot
	var weapon: EquipmentItem = _make_item("w", LootEnums.ItemType.WEAPON,
		LootEnums.RarityTier.RARE, { &"attack_power": 22.0 })

	# Act
	var result: Dictionary = _sut.equip(weapon.item_id, EquipmentEnums.EquipSlot.ARMOR)

	# Assert
	assert_false(result["ok"])
	assert_eq(result["error"], "slot_type_mismatch")
	assert_eq(weapon.lifecycle_state, EquipmentEnums.ItemLifecycle.IN_INVENTORY)
	assert_eq(_mock_stat.pushes.size(), 0)


func test_equip_mailbox_item_requires_claim_first() -> void:
	# Arrange
	var item: EquipmentItem = _make_item("m", LootEnums.ItemType.WEAPON,
		LootEnums.RarityTier.RARE, { &"attack_power": 22.0 })
	item.lifecycle_state = EquipmentEnums.ItemLifecycle.IN_MAILBOX

	# Act / Assert
	var result: Dictionary = _sut.equip(item.item_id, EquipmentEnums.EquipSlot.WEAPON)
	assert_false(result["ok"])
	assert_eq(result["error"], "in_mailbox_claim_first")


func test_set_lock_unknown_item_errors() -> void:
	var result: Dictionary = _sut.set_lock(&"no_such_item", true)
	assert_false(result["ok"])
