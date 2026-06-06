# InventorySystem — Story 016: re-entrancy guard (_mutating, EC-15).
#
# Scope (GDD Rule 6 + EC-15 + AC-33):
#   AC-33 — a stat_changed-style handler that synchronously calls back into a
#           mutation API mid-push is blocked (push_error + telemetry) and the
#           retry defers to the next frame; state never corrupts
#   Guard window — _mutating stays true THROUGH the #11 push (the emission
#           window is the entire reason the guard exists)
#
# The CI half of Story 016 is tools/ci/check_inventory_reentrancy.gd (static
# scan, owner-exempt); this file covers the runtime guard.
#
# Framework: GUT v9.x
# Story: production/epics/equipment-inventory/story-016-reentrancy-ci-autoload.md
extends GutTest

const InventorySystem := preload("res://src/autoload/inventory_system.gd")
const TABLE_PATH: String = "res://assets/data/equipment/stat_assignment_table.tres"

const FIXED_NOW: int = 1764547300

var _sut
var _mock_stat: ReentrantMockStat


## A hostile #11 mock: its apply (the synchronous stat_changed emission window)
## calls straight back into the SUT's mutation API — the exact EC-15 vector.
class ReentrantMockStat extends RefCounted:
	var sut = null
	var reentry_target: StringName = &""
	var reentry_results: Array = []
	var pushes: int = 0

	func get_attack_power_excluding_equipment() -> float:
		return 28.0

	func apply_equipment_modifier(_id: StringName, _modifier) -> void:
		pushes += 1
		if sut != null and reentry_target != &"":
			# Synchronous callback DURING the push — must be blocked.
			reentry_results.append(sut.salvage(reentry_target))


func before_each() -> void:
	_mock_stat = ReentrantMockStat.new()
	_sut = InventorySystem.new()
	_sut._stat_table = load(TABLE_PATH)
	_sut._stat_system = _mock_stat
	_sut._now_unix_provider = func() -> int: return FIXED_NOW
	_mock_stat.sut = _sut
	add_child_autofree(_sut)


func _make_banked_item(id_suffix: String, mods: Dictionary) -> EquipmentItem:
	var item: EquipmentItem = EquipmentItem.new()
	item.item_id = StringName("tid_%s_D-0-%s" % [id_suffix, id_suffix])
	item.item_type = LootEnums.ItemType.WEAPON
	item.rarity = LootEnums.RarityTier.RARE
	item.stat_modifiers = mods
	item.acquired_at_unix = FIXED_NOW
	item.lifecycle_state = EquipmentEnums.ItemLifecycle.IN_INVENTORY
	item.slot_affinity = EquipmentEnums.EquipSlot.WEAPON
	_sut._items[item.item_id] = item
	return item


# ─── AC-33: synchronous re-entry blocked + deferred ────────────────────────────


func test_reentrant_mutation_during_push_is_blocked_and_deferred() -> void:
	# Arrange — equip will push; the hostile mock re-enters salvage(victim)
	var weapon: EquipmentItem = _make_banked_item("w", { &"ATTACK_POWER": 22.0 })
	var victim: EquipmentItem = _make_banked_item("v", { &"ATTACK_POWER": 6.0 })
	_mock_stat.reentry_target = victim.item_id

	# Act — the equip's push triggers the synchronous re-entry
	var result: Dictionary = _sut.equip(weapon.item_id, EquipmentEnums.EquipSlot.WEAPON)

	# Assert — outer op succeeded; re-entry was refused inside the window
	assert_true(result["ok"])
	assert_eq(_mock_stat.reentry_results.size(), 1)
	assert_false(_mock_stat.reentry_results[0]["ok"])
	assert_eq(_mock_stat.reentry_results[0]["error"], "deferred_reentrancy")
	assert_eq(_sut.get_telemetry("inventory.reentrancy.blocked").size(), 1)
	# State NOT corrupted mid-operation: victim still alive at this point
	assert_not_null(_sut.get_item(victim.item_id))

	# The deferred retry runs next frame and completes the salvage cleanly
	_mock_stat.reentry_target = &""  # disarm the hostile mock for the retry's push
	await get_tree().process_frame
	assert_null(_sut.get_item(victim.item_id))
	assert_eq(_sut.get_forge_shards(), 250)


func test_guard_window_extends_through_the_push() -> void:
	# Arrange — guard must still be up DURING apply_equipment_modifier
	var weapon: EquipmentItem = _make_banked_item("w", { &"ATTACK_POWER": 22.0 })
	var probe: Array = []
	_sut._stat_system = ProbingStat.new(_sut, probe)

	# Act
	_sut.equip(weapon.item_id, EquipmentEnums.EquipSlot.WEAPON)

	# Assert — _mutating observed true inside the push window
	assert_eq(probe, [true])


class ProbingStat extends RefCounted:
	var _sut_ref
	var _probe: Array

	func _init(sut_ref, probe: Array) -> void:
		_sut_ref = sut_ref
		_probe = probe

	func get_attack_power_excluding_equipment() -> float:
		return 28.0

	func apply_equipment_modifier(_id: StringName, _modifier) -> void:
		_probe.append(_sut_ref._mutating)


func test_sequential_mutations_do_not_trip_the_guard() -> void:
	# Arrange
	var a: EquipmentItem = _make_banked_item("a", { &"ATTACK_POWER": 22.0 })
	var b: EquipmentItem = _make_banked_item("b", { &"ATTACK_POWER": 6.0 })

	# Act — back-to-back (non-nested) mutations are normal
	var r1: Dictionary = _sut.salvage(a.item_id)
	var r2: Dictionary = _sut.salvage(b.item_id)

	# Assert
	assert_true(r1["ok"])
	assert_true(r2["ok"])
	assert_eq(_sut.get_telemetry("inventory.reentrancy.blocked").size(), 0)
