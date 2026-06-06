# InventorySystem + EquipmentClampCalc — Story 008: aggregation + AntiSnowball + push.
#
# Scope (GDD Rule 8 + Formula 4 + EC-16 + D8):
#   AC-16 — fresh account (SDA 28) + 3×LEGENDARY → single &"equipment_aggregate"
#           push with ATK 84 (= min(90, max(30, 84))), HP/MOVE/CRIT unclamped,
#           antisnowball telemetry emitted
#   AC-17 — per-key contract clamp: {ATK 350, HP 600, MOVE 150, CRIT 0.30} @
#           SDA 200 (cap 600) → {ATK 300, HP 500, MOVE 100, CRIT 0.20}
#   AC-22 — cosmetic structural exclusion from aggregation (last defense line)
#   AC-38 — get_aggregate_raw_and_effective() == {raw 90, effective 84}
#   Edge — SDA 0 (corruption path) → FLOOR 30 binds; raw 0 → no clamp telemetry
#
# Framework: GUT v9.x
# Story: production/epics/equipment-inventory/story-008-aggregation-antisnowball-push.md
extends GutTest

const InventorySystem := preload("res://src/autoload/inventory_system.gd")
const TABLE_PATH: String = "res://assets/data/equipment/stat_assignment_table.tres"

const FIXED_NOW: int = 1764547300

var _sut
var _mock_stat: MockStat


class MockStat extends RefCounted:
	var sda: float = 28.0
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


func _equip_fixture(slot: int, item_type: int, mods: Dictionary,
		cosmetic: bool = false) -> EquipmentItem:
	var item: EquipmentItem = EquipmentItem.new()
	item.item_id = StringName("fix_%d_D-0-%d" % [slot, slot])
	item.item_type = item_type
	item.stat_modifiers = mods
	item.is_cosmetic = cosmetic
	item.lifecycle_state = EquipmentEnums.ItemLifecycle.EQUIPPED
	item.slot_affinity = slot
	_sut._items[item.item_id] = item
	_sut._loadout[slot] = item.item_id
	return item


# ─── EquipmentClampCalc pure formula ───────────────────────────────────────────


func test_clamp_calc_fresh_account_caps_legendary_at_84() -> void:
	# cap = max(30, 3×28) = 84; effective = clamp(90, 0, min(84, 300)) = 84
	var out: Dictionary = EquipmentClampCalc.clamp_aggregate(
		{ &"ATTACK_POWER": 90.0 }, 28.0)
	assert_almost_eq(out[&"ATTACK_POWER"], 84.0, 0.0001)


func test_clamp_calc_floor_binds_on_corruption_path_sda_zero() -> void:
	# cap = max(30, 0) = 30 — the defense-in-depth floor (D4)
	var out: Dictionary = EquipmentClampCalc.clamp_aggregate(
		{ &"ATTACK_POWER": 90.0 }, 0.0)
	assert_almost_eq(out[&"ATTACK_POWER"], 30.0, 0.0001)


func test_clamp_calc_under_cap_passes_through() -> void:
	var out: Dictionary = EquipmentClampCalc.clamp_aggregate(
		{ &"ATTACK_POWER": 45.0 }, 28.0)
	assert_almost_eq(out[&"ATTACK_POWER"], 45.0, 0.0001)


func test_clamp_calc_does_not_mutate_input() -> void:
	var raw: Dictionary = { &"ATTACK_POWER": 90.0 }
	EquipmentClampCalc.clamp_aggregate(raw, 28.0)
	assert_eq(raw[&"ATTACK_POWER"], 90.0)


# ─── AC-17: per-key contract clamp ─────────────────────────────────────────────


func test_per_key_contract_clamp_all_four_keys() -> void:
	# Arrange — every key beyond its #11 contract ceiling; SDA 200 → cap 600
	var raw: Dictionary = {
		&"ATTACK_POWER": 350.0,
		&"MAX_HP": 600.0,
		&"MOVE_SPEED": 150.0,
		&"CRIT_CHANCE": 0.30,
	}

	# Act
	var out: Dictionary = EquipmentClampCalc.clamp_aggregate(raw, 200.0)

	# Assert — ATK = min(350, 600, 300) = 300; others at contract ceilings
	assert_almost_eq(out[&"ATTACK_POWER"], 300.0, 0.0001)
	assert_almost_eq(out[&"MAX_HP"], 500.0, 0.0001)
	assert_almost_eq(out[&"MOVE_SPEED"], 100.0, 0.0001)
	assert_almost_eq(out[&"CRIT_CHANCE"], 0.20, 0.0001)


# ─── AC-16: full fresh-account push ────────────────────────────────────────────


func test_three_legendary_push_single_aggregate_id_with_clamped_atk() -> void:
	# Arrange — table LEGENDARY cells on all three functional slots
	_equip_fixture(EquipmentEnums.EquipSlot.WEAPON, LootEnums.ItemType.WEAPON,
		{ &"ATTACK_POWER": 90.0 })
	_equip_fixture(EquipmentEnums.EquipSlot.ARMOR, LootEnums.ItemType.ARMOR,
		{ &"MAX_HP": 160.0 })
	_equip_fixture(EquipmentEnums.EquipSlot.ACCESSORY, LootEnums.ItemType.ACCESSORY,
		{ &"MOVE_SPEED": 25.0, &"CRIT_CHANCE": 0.06 })

	# Act
	_sut._push_aggregate()

	# Assert — exactly one push, synthetic id, clamped ATK, others intact
	assert_eq(_mock_stat.pushes.size(), 1)
	assert_eq(_mock_stat.pushes[0]["id"], &"equipment_aggregate")
	var deltas: Dictionary = _mock_stat.pushes[0]["deltas"]
	assert_almost_eq(deltas[&"ATTACK_POWER"], 84.0, 0.0001)
	assert_almost_eq(deltas[&"MAX_HP"], 160.0, 0.0001)
	assert_almost_eq(deltas[&"MOVE_SPEED"], 25.0, 0.0001)
	assert_almost_eq(deltas[&"CRIT_CHANCE"], 0.06, 0.0001)
	# EC-16: clamp is NEVER silent
	assert_eq(_sut.get_telemetry("equipment.antisnowball.clamp").size(), 1)


func test_unclamped_push_emits_no_clamp_telemetry() -> void:
	# Arrange — RARE weapon (+22) well under cap 84
	_equip_fixture(EquipmentEnums.EquipSlot.WEAPON, LootEnums.ItemType.WEAPON,
		{ &"ATTACK_POWER": 22.0 })

	# Act
	_sut._push_aggregate()

	# Assert
	assert_eq(_sut.get_telemetry("equipment.antisnowball.clamp").size(), 0)
	assert_almost_eq(
		_mock_stat.pushes[0]["deltas"][&"ATTACK_POWER"], 22.0, 0.0001)


# ─── AC-22: cosmetic structural exclusion ──────────────────────────────────────


func test_cosmetic_slot_stats_never_reach_the_push() -> void:
	# Arrange — scrub-escaped stats injected onto the COSMETIC slot (worst case)
	_equip_fixture(EquipmentEnums.EquipSlot.WEAPON, LootEnums.ItemType.WEAPON,
		{ &"ATTACK_POWER": 22.0 })
	_equip_fixture(EquipmentEnums.EquipSlot.COSMETIC, LootEnums.ItemType.COSMETIC,
		{ &"ATTACK_POWER": 999.0, &"MAX_HP": 999.0 }, true)

	# Act
	_sut._push_aggregate()

	# Assert — aggregation iterates the 3 functional slots only
	var deltas: Dictionary = _mock_stat.pushes[0]["deltas"]
	assert_almost_eq(deltas[&"ATTACK_POWER"], 22.0, 0.0001)
	assert_false(deltas.has(&"MAX_HP"))


# ─── AC-38: badge data contract ────────────────────────────────────────────────


func test_badge_getter_returns_raw_90_effective_84() -> void:
	# Arrange — fresh account + LEGENDARY weapon
	_equip_fixture(EquipmentEnums.EquipSlot.WEAPON, LootEnums.ItemType.WEAPON,
		{ &"ATTACK_POWER": 90.0 })

	# Act
	var badge: Dictionary = _sut.get_aggregate_raw_and_effective()

	# Assert — #22 renders "+84 / +90 受真身上限約束" off this
	assert_almost_eq(badge["raw"], 90.0, 0.0001)
	assert_almost_eq(badge["effective"], 84.0, 0.0001)


func test_empty_loadout_pushes_empty_deltas() -> void:
	# Arrange — nothing equipped (same-id replace with zero deltas)

	# Act
	_sut._push_aggregate()

	# Assert
	assert_eq(_mock_stat.pushes.size(), 1)
	assert_eq(_mock_stat.pushes[0]["deltas"], {})
