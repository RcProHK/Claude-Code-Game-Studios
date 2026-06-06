# InventorySystem — Story 003: idempotency + timestamped tombstone + prune.
#
# Scope (GDD Rule 2 + Formula 6 + EC-6):
#   AC-07 — same (transition_id, drop_id) re-entry → DUPLICATE_NOOP, size
#           unchanged; different drop_id same transition → both granted;
#           SALVAGED item_id replay → no resurrection, shards unchanged
#   AC-39 — tombstone prune: salvaged_at older than 37d (#15 HARD_CAP_DAYS,
#           LOCKED) → removed; 36d → kept (boundary keeps at exactly 37.0d)
#   Formula 6 — composite StringName, no hash; Contract 2: transition_id never parsed
#
# Framework: GUT v9.x
# Story: production/epics/equipment-inventory/story-003-idempotency-tombstone.md
extends GutTest

const InventorySystem := preload("res://src/autoload/inventory_system.gd")
const TABLE_PATH: String = "res://assets/data/equipment/stat_assignment_table.tres"

const FIXED_NOW: int = 1764547300
const DAY_SEC: int = 86400

var _sut


func before_each() -> void:
	_sut = InventorySystem.new()
	_sut._stat_table = load(TABLE_PATH)
	_sut._now_unix_provider = func() -> int: return FIXED_NOW
	add_child_autofree(_sut)


func _make_record(drop_id: String = "D-1000-42") -> LootDrop:
	var record: LootDrop = LootDrop.new()
	record.drop_id = drop_id
	record.transition_id = "1764547200123_7_combat_lootdrop"
	record.item_type = "WEAPON"
	record.rarity_tier = "RARE"
	record.class_tag = "STRIKE"
	return record


# ─── AC-07: dedup ──────────────────────────────────────────────────────────────


func test_same_record_reentry_is_duplicate_noop() -> void:
	# Arrange
	var record: LootDrop = _make_record()
	_sut.receive_loot(record)

	# Act — #15 retry / bfcache replay delivers the same record again
	var result: int = _sut.receive_loot(record)

	# Assert
	assert_eq(result, EquipmentEnums.ReceiveResult.DUPLICATE_NOOP)
	assert_eq(_sut.get_inventory_count(), 1)


func test_same_transition_different_drop_id_grants_both() -> void:
	# Arrange — one transition can mint multiple drops
	_sut.receive_loot(_make_record("D-1000-42"))

	# Act
	var result: int = _sut.receive_loot(_make_record("D-1000-43"))

	# Assert
	assert_eq(result, EquipmentEnums.ReceiveResult.OK)
	assert_eq(_sut.get_inventory_count(), 2)


func test_tombstoned_item_replay_does_not_resurrect_or_repay() -> void:
	# Arrange — item salvaged: live entry gone, tombstone holds the id
	var record: LootDrop = _make_record()
	_sut.receive_loot(record)
	var item_id: StringName = &"1764547200123_7_combat_lootdrop_D-1000-42"
	_sut._items.erase(item_id)
	_sut.register_tombstone(item_id)
	var shards_before: int = _sut.get_forge_shards()

	# Act — replay of the salvaged item
	var result: int = _sut.receive_loot(record)

	# Assert — no resurrection, no shard double-pay
	assert_eq(result, EquipmentEnums.ReceiveResult.DUPLICATE_NOOP)
	assert_eq(_sut.get_inventory_count(), 0)
	assert_eq(_sut.get_forge_shards(), shards_before)


func test_item_id_is_composite_string_not_hash() -> void:
	# Arrange / Act — Formula 6: human-readable composite (devtools debuggable)
	_sut.receive_loot(_make_record())

	# Assert
	assert_not_null(_sut.get_item(&"1764547200123_7_combat_lootdrop_D-1000-42"))


# ─── Tombstone registration ────────────────────────────────────────────────────


func test_register_tombstone_stamps_now_unix() -> void:
	# Arrange / Act
	_sut.register_tombstone(&"some_item_id")

	# Assert — {item_id: salvaged_at_unix}, NOT an id-only set
	assert_eq(_sut._tombstones[&"some_item_id"], FIXED_NOW)


# ─── AC-39: prune at the 37-day horizon ────────────────────────────────────────


func test_prune_removes_entries_older_than_37_days() -> void:
	# Arrange
	var tombstones: Dictionary = {
		&"old_38d": FIXED_NOW - 38 * DAY_SEC,
		&"young_36d": FIXED_NOW - 36 * DAY_SEC,
	}

	# Act
	var kept: Dictionary = InventorySystem.prune_tombstones(tombstones, FIXED_NOW)

	# Assert
	assert_false(kept.has(&"old_38d"))
	assert_true(kept.has(&"young_36d"))


func test_prune_boundary_exactly_37_days_keeps() -> void:
	# Arrange — strictly-older-than semantics (37.0d keeps)
	var tombstones: Dictionary = { &"edge_37d": FIXED_NOW - 37 * DAY_SEC }

	# Act
	var kept: Dictionary = InventorySystem.prune_tombstones(tombstones, FIXED_NOW)

	# Assert
	assert_true(kept.has(&"edge_37d"))


func test_prune_empty_dict_returns_empty() -> void:
	# Act / Assert
	assert_eq(InventorySystem.prune_tombstones({}, FIXED_NOW), {})
