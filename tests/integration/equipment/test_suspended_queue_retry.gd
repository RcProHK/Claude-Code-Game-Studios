# InventorySystem — Story 015: SUSPENDED durable queue + drain + rejection retry.
#
# Scope (GDD Rule 15 + EC-14/22):
#   AC-29 — SUSPENDED: receive ×3 (1 dup) all QUEUED; resume drain = FIFO grant,
#           dup no-op, push/flush each exactly once (batch); READY burst also
#           batches (boot drain path covers the batch machinery)
#   AC-30 — Suspended-at-boot: no push until GSM leaves suspension, then exactly
#           one deferred push (merged dedup flag)
#   AC-21 — stat_mutation_rejected (EQUIPMENT source) → pending flag → deferred
#           re-push after Ready; non-EQUIPMENT rejections ignored
#   Durability — suspended enqueue mirrors to inventory.pending_queue
#
# Framework: GUT v9.x | MockPersistenceLayer + MockStat + MockGSM (deliverable)
# Story: production/epics/equipment-inventory/story-015-suspended-queue-retry.md
extends GutTest

const InventorySystem := preload("res://src/autoload/inventory_system.gd")
const StatSystemScript := preload("res://src/autoload/stat_system.gd")
const TABLE_PATH: String = "res://assets/data/equipment/stat_assignment_table.tres"

const FIXED_NOW: int = 1764547300

var _mock_persistence: MockPersistenceLayer
var _mock_stat: MockStat
var _mock_gsm: MockGSM
var _write_log: Array = []


class MockStat extends RefCounted:
	var pushes: Array[Dictionary] = []

	func is_boot_completed() -> bool:
		return true

	func get_attack_power_excluding_equipment() -> float:
		return 28.0

	func apply_equipment_modifier(equipment_id: StringName, modifier) -> void:
		pushes.append({"id": equipment_id, "deltas": modifier.deltas.duplicate()})


class MockGSM extends RefCounted:
	var handler: Callable = Callable()

	func connect_for_initial_state(callable: Callable) -> void:
		handler = callable

	func deliver(state: StringName) -> void:
		handler.call(&"", state, null)


func before_each() -> void:
	_mock_persistence = MockPersistenceLayer.new()
	_mock_stat = MockStat.new()
	_mock_gsm = MockGSM.new()
	_write_log = []
	_mock_persistence.attach_write_spy(func(entry: Dictionary) -> void:
		_write_log.append(entry))


func _make_sut():
	var sut = InventorySystem.new()
	sut._persistence = _mock_persistence
	sut._stat_system = _mock_stat
	sut._gsm = _mock_gsm
	sut._stat_table = load(TABLE_PATH)
	sut._now_unix_provider = func() -> int: return FIXED_NOW
	add_child_autofree(sut)
	return sut


func _record(drop_id: String) -> LootDrop:
	var record: LootDrop = LootDrop.new()
	record.drop_id = drop_id
	record.transition_id = "tid_sq"
	record.item_type = "ARMOR"
	record.rarity_tier = "COMMON"
	return record


# ─── AC-29: suspended queue + FIFO batch drain ─────────────────────────────────


func test_suspended_receives_queue_durably_then_drain_batches() -> void:
	# Arrange — booted, then suspended
	var sut = _make_sut()
	_mock_gsm.deliver(&"suspended")

	# Act 1 — three receives while suspended (one duplicate)
	var r1: int = sut.receive_loot(_record("D-1"))
	var r2: int = sut.receive_loot(_record("D-2"))
	var r3: int = sut.receive_loot(_record("D-1"))  # dup of r1

	# Assert 1 — all parked, durable mirror written, nothing granted
	assert_eq(r1, EquipmentEnums.ReceiveResult.QUEUED_SUSPENDED)
	assert_eq(r2, EquipmentEnums.ReceiveResult.QUEUED_SUSPENDED)
	assert_eq(r3, EquipmentEnums.ReceiveResult.QUEUED_SUSPENDED)
	assert_eq(sut.get_inventory_count(), 0)
	var queue_mirror: Variant = _mock_persistence.read("inventory.pending_queue")
	assert_eq((queue_mirror as Array).size(), 3)

	# Act 2 — resume: drain is deferred one frame (Contract 5)
	_mock_stat.pushes.clear()
	_write_log.clear()
	_mock_gsm.deliver(&"gameplay")
	await get_tree().process_frame
	await get_tree().process_frame  # drain ran; allow its own deferred work

	# Assert 2 — FIFO grant (2 unique), dup no-op, push + state flush once each
	assert_eq(sut.get_inventory_count(), 2)
	assert_not_null(sut.get_item(&"tid_sq_D-1"))
	assert_not_null(sut.get_item(&"tid_sq_D-2"))
	# batch semantics: exactly one aggregate push for the whole drain
	assert_eq(_mock_stat.pushes.size(), 1)
	var state_writes: Array = _write_log.filter(
		func(e: Dictionary) -> bool: return e["key"] == "inventory.state")
	assert_eq(state_writes.size(), 1)
	# durable mirror cleared after the drain
	assert_eq((_mock_persistence.read("inventory.pending_queue") as Array).size(), 0)


# ─── AC-30: Suspended-at-boot pending replay ───────────────────────────────────


func test_suspended_at_boot_defers_push_until_ready() -> void:
	# Arrange — persisted loadout exists; GSM initial delivery = suspended
	var item_dict: Dictionary = {
		"item_id": "tid_sq_D-w", "item_type": "WEAPON", "rarity": "RARE",
		"stat_modifiers": {"ATTACK_POWER": 22.0},
		"lifecycle_state": "EQUIPPED", "slot_affinity": "WEAPON",
		"acquired_at_unix": FIXED_NOW,
	}
	_mock_persistence.write("inventory.state", {
		"items": [item_dict], "shards": 0,
		"loadout": {"WEAPON": "tid_sq_D-w"},
	})

	# Act 1 — boot, then the initial delivery says suspended
	var sut = _make_sut()
	_mock_gsm.deliver(&"suspended")
	await get_tree().process_frame

	# Assert 1 — push has NOT happened (crash-recovery gate, #11 would reject)
	assert_eq(_mock_stat.pushes.size(), 0)

	# Act 2 — GSM leaves suspension
	_mock_gsm.deliver(&"gameplay")
	await get_tree().process_frame

	# Assert 2 — exactly one deferred boot-replay push with the loadout
	assert_eq(_mock_stat.pushes.size(), 1)
	assert_almost_eq(_mock_stat.pushes[0]["deltas"][&"ATTACK_POWER"], 22.0, 0.0001)
	assert_true(sut != null)


# ─── AC-21: rejection retry (EQUIPMENT-filtered) ───────────────────────────────


func test_rejected_equipment_push_retries_after_ready() -> void:
	# Arrange — booted + gameplay
	var sut = _make_sut()
	_mock_gsm.deliver(&"gameplay")
	await get_tree().process_frame
	_mock_stat.pushes.clear()

	# Act — #11 rejects an equipment mutation (Suspended/Reconciling window)
	sut._on_stat_mutation_rejected(
		&"ATTACK_POWER", StatSystemScript.StatSource.EQUIPMENT, 0.0, "suspended_substate")
	_mock_gsm.deliver(&"gameplay")  # Ready (re)delivery triggers the retry
	await get_tree().process_frame

	# Assert — exactly one deferred re-push (flag consumed, no desync)
	assert_eq(_mock_stat.pushes.size(), 1)


func test_non_equipment_rejections_ignored() -> void:
	# Arrange
	var sut = _make_sut()
	_mock_gsm.deliver(&"gameplay")
	await get_tree().process_frame
	_mock_stat.pushes.clear()

	# Act — a VOLUME_TICK rejection is not ours
	sut._on_stat_mutation_rejected(
		&"STR", StatSystemScript.StatSource.VOLUME_TICK, 1.0, "whatever")
	_mock_gsm.deliver(&"gameplay")
	await get_tree().process_frame

	# Assert — no retry push
	assert_eq(_mock_stat.pushes.size(), 0)
