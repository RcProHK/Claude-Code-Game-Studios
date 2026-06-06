# InventorySystem — Story 002: receive_loot hydration + validation + ReceiveResult.
#
# Scope (GDD Rule 1 + EC-1/2/3 + D9):
#   AC-01 — valid record → typed EquipmentItem, stats from StatAssignmentTable,
#           IN_INVENTORY, returns OK
#   AC-02 — missing source_transition_id → FAILED_ROLLBACK + CRITICAL telemetry,
#           inventory unchanged (recovery-namespace write is #15's job, EC-48)
#   AC-03 — LEGENDARY missing receipt → FAILED_ROLLBACK (F-12); COMMON missing
#           receipt → OK with null receipt + provenance still derived
#   AC-04 — rarity missing/unknown → COMMON floor, no rollback
#   AC-35 — unknown item_type string → FAILED_ROLLBACK + CRITICAL
#   D9    — metadata stat keys NEVER merged (detection-only telemetry)
#
# Framework: GUT v9.x | SUT preloaded (autoload has no class_name — project pattern)
# Story: production/epics/equipment-inventory/story-002-receive-loot-hydration.md
extends GutTest

const InventorySystem := preload("res://src/autoload/inventory_system.gd")
const TABLE_PATH: String = "res://assets/data/equipment/stat_assignment_table.tres"

const FIXED_NOW: int = 1764547300  # 2025-12-01T01:21:40Z (UTC: 12月1日)

var _sut


func before_each() -> void:
	_sut = InventorySystem.new()
	_sut._stat_table = load(TABLE_PATH)
	_sut._now_unix_provider = func() -> int: return FIXED_NOW
	add_child_autofree(_sut)


func _make_record(
		item_type: String = "WEAPON",
		rarity: String = "RARE",
		with_receipt: bool = false) -> LootDrop:
	var record: LootDrop = LootDrop.new()
	record.drop_id = "D-1000-42"
	record.transition_id = "1764547200123_7_combat_lootdrop"
	record.item_type = item_type
	record.rarity_tier = rarity
	record.class_tag = "MOBILITY"
	if with_receipt:
		record.item_metadata["source_receipt"] = {
			"workout_date_unix": 1764540000,
			"pr_snapshot": {"squat": 180.0},
			"volume_snapshot": 5400.0,
			"signature_text": "鍛造自 180kg × 5",
		}
	return record


# ─── AC-01: valid record → typed item, table stats, IN_INVENTORY, OK ───────────


func test_receive_valid_weapon_returns_ok_and_grants_item() -> void:
	# Arrange
	var record: LootDrop = _make_record("WEAPON", "RARE")

	# Act
	var result: int = _sut.receive_loot(record)

	# Assert
	assert_eq(result, EquipmentEnums.ReceiveResult.OK)
	assert_eq(_sut.get_inventory_count(), 1)
	var item: EquipmentItem = _sut.get_item(&"1764547200123_7_combat_lootdrop_D-1000-42")
	assert_not_null(item)
	assert_eq(item.item_type, LootEnums.ItemType.WEAPON)
	assert_eq(item.rarity, LootEnums.RarityTier.RARE)
	assert_eq(item.lifecycle_state, EquipmentEnums.ItemLifecycle.IN_INVENTORY)
	assert_eq(item.slot_affinity, EquipmentEnums.EquipSlot.WEAPON)
	# D9: stats come from the table cell (WEAPON × RARE = +22 ATK)
	assert_eq(item.stat_modifiers, { &"ATTACK_POWER": 22.0 })
	assert_eq(item.acquired_at_unix, FIXED_NOW)


func test_receive_stamps_provenance_from_utc_date_and_class_tag() -> void:
	# Arrange — MOBILITY → 腿日; FIXED_NOW is 12月1日 UTC
	var record: LootDrop = _make_record()

	# Act
	_sut.receive_loot(record)

	# Assert
	var item: EquipmentItem = _sut.get_item(&"1764547200123_7_combat_lootdrop_D-1000-42")
	assert_eq(item.provenance_text, "拾於 12月1日・腿日")


# ─── AC-02: missing transition_id → FAILED_ROLLBACK ────────────────────────────


func test_receive_missing_transition_id_rolls_back() -> void:
	# Arrange
	var record: LootDrop = _make_record()
	record.transition_id = ""

	# Act
	var result: int = _sut.receive_loot(record)

	# Assert
	assert_eq(result, EquipmentEnums.ReceiveResult.FAILED_ROLLBACK)
	assert_eq(_sut.get_inventory_count(), 0)
	var events: Array[Dictionary] = _sut.get_telemetry("loot.inventory.grant_fail")
	assert_eq(events.size(), 1)
	assert_eq(events[0]["data"]["severity"], "CRITICAL")
	assert_eq(events[0]["data"]["reason"], "missing_source_transition_id")


# ─── AC-03: LEGENDARY receipt binding (F-12) ───────────────────────────────────


func test_receive_legendary_without_receipt_rolls_back() -> void:
	# Arrange
	var record: LootDrop = _make_record("WEAPON", "LEGENDARY", false)

	# Act
	var result: int = _sut.receive_loot(record)

	# Assert
	assert_eq(result, EquipmentEnums.ReceiveResult.FAILED_ROLLBACK)
	assert_eq(_sut.get_inventory_count(), 0)
	assert_eq(_sut.get_telemetry("loot.inventory.grant_fail").size(), 1)


func test_receive_legendary_with_receipt_grants_ok() -> void:
	# Arrange
	var record: LootDrop = _make_record("WEAPON", "LEGENDARY", true)

	# Act
	var result: int = _sut.receive_loot(record)

	# Assert
	assert_eq(result, EquipmentEnums.ReceiveResult.OK)
	var item: EquipmentItem = _sut.get_item(&"1764547200123_7_combat_lootdrop_D-1000-42")
	assert_true(item.has_receipt())
	assert_eq(item.source_receipt.signature_text, "鍛造自 180kg × 5")
	assert_eq(item.stat_modifiers, { &"ATTACK_POWER": 90.0 })


func test_receive_common_without_receipt_grants_ok_with_null_receipt() -> void:
	# Arrange
	var record: LootDrop = _make_record("ARMOR", "COMMON", false)

	# Act
	var result: int = _sut.receive_loot(record)

	# Assert — nullable receipt + provenance still derived
	assert_eq(result, EquipmentEnums.ReceiveResult.OK)
	var item: EquipmentItem = _sut.get_item(&"1764547200123_7_combat_lootdrop_D-1000-42")
	assert_false(item.has_receipt())
	assert_ne(item.provenance_text, "")


# ─── AC-04: rarity floor ───────────────────────────────────────────────────────


func test_receive_unknown_rarity_floors_to_common_no_rollback() -> void:
	# Arrange
	var record: LootDrop = _make_record("ARMOR", "MYTHICAL_NONSENSE")

	# Act
	var result: int = _sut.receive_loot(record)

	# Assert — Pillar 3 floor, granted as COMMON
	assert_eq(result, EquipmentEnums.ReceiveResult.OK)
	var item: EquipmentItem = _sut.get_item(&"1764547200123_7_combat_lootdrop_D-1000-42")
	assert_eq(item.rarity, LootEnums.RarityTier.COMMON)
	assert_eq(item.stat_modifiers, { &"MAX_HP": 20.0 })


# ─── AC-35: unknown item_type → rollback ───────────────────────────────────────


func test_receive_unknown_item_type_rolls_back() -> void:
	# Arrange
	var record: LootDrop = _make_record("SPACESHIP", "RARE")

	# Act
	var result: int = _sut.receive_loot(record)

	# Assert
	assert_eq(result, EquipmentEnums.ReceiveResult.FAILED_ROLLBACK)
	assert_eq(_sut.get_telemetry("loot.inventory.grant_fail")[0]["data"]["reason"],
		"unknown_item_type")


# ─── D9: metadata stats never merged ───────────────────────────────────────────


func test_receive_metadata_stat_keys_are_ignored_with_telemetry() -> void:
	# Arrange — injected metadata stats must NOT override the table (D9)
	var record: LootDrop = _make_record("WEAPON", "COMMON")
	record.item_metadata["stat_modifiers"] = {"ATTACK_POWER": 999.0, "STR": 50.0}

	# Act
	_sut.receive_loot(record)

	# Assert — table value wins; detection telemetry fired
	var item: EquipmentItem = _sut.get_item(&"1764547200123_7_combat_lootdrop_D-1000-42")
	assert_eq(item.stat_modifiers, { &"ATTACK_POWER": 6.0 })
	assert_eq(_sut.get_telemetry("inventory.stat_key.dropped").size(), 1)


# ─── Defaults: class_tag / cosmetic forcing ────────────────────────────────────


func test_receive_unknown_class_tag_defaults_neutral() -> void:
	# Arrange
	var record: LootDrop = _make_record("ACCESSORY", "UNCOMMON")
	record.class_tag = "WIZARDRY"

	# Act
	_sut.receive_loot(record)

	# Assert
	var item: EquipmentItem = _sut.get_item(&"1764547200123_7_combat_lootdrop_D-1000-42")
	assert_eq(item.class_tag, LootEnums.ClassTag.NEUTRAL)


func test_receive_cosmetic_forces_neutral_and_empty_stats() -> void:
	# Arrange — cosmetic with a (bogus) class tag
	var record: LootDrop = _make_record("COSMETIC", "EPIC")
	record.class_tag = "STRIKE"
	record.item_metadata["visual_id"] = "skin_red_cape"

	# Act
	var result: int = _sut.receive_loot(record)

	# Assert — parallel pipeline: NEUTRAL forced, {} stats, COSMETIC slot
	assert_eq(result, EquipmentEnums.ReceiveResult.OK)
	var item: EquipmentItem = _sut.get_item(&"1764547200123_7_combat_lootdrop_D-1000-42")
	assert_true(item.is_cosmetic)
	assert_eq(item.class_tag, LootEnums.ClassTag.NEUTRAL)
	assert_eq(item.stat_modifiers, {})
	assert_eq(item.visual_id, "skin_red_cape")
	assert_eq(item.slot_affinity, EquipmentEnums.EquipSlot.COSMETIC)


# ─── Static guard unit coverage (EC-4 shared path) ─────────────────────────────


func test_guard_stat_dict_drops_base_keys_and_clamps_negatives() -> void:
	# Arrange
	var sink: Array[Dictionary] = []

	# Act — STR is a base key (D8 forbidden); negative ATK clamps to 0
	var out: Dictionary = InventorySystem.guard_stat_dict(
		{"STR": 20.0, "ATTACK_POWER": -5.0, "MAX_HP": 35.0}, sink)

	# Assert
	assert_eq(out, { &"ATTACK_POWER": 0.0, &"MAX_HP": 35.0 })
	assert_eq(sink.size(), 2)  # one drop + one clamp, both loud
