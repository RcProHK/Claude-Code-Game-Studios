## test_equipment_types.gd — Story 001: EquipmentItem + SourceReceipt + Enums + StatAssignmentTable
##
## Governing story: production/epics/equipment-inventory/story-001-data-types-stat-table.md
## Governing ADRs : ADR-0006 Contract 3 (dict envelope) / ADR-0007 (enum families,
##                  string-name persistence) / GDD D8 (derived-keys-only) + D9 (fixed table)
##
## VALIDATE TESTING NOTE: StatAssignmentTable._validate() uses assert() (crash in
## debug, no-op in release) — same design-by-contract pattern as LootRarityConfig.
## Valid path = call _validate() on good table (no crash); invalid conditions are
## verified via bool comparison without calling _validate() (project pattern).
extends GutTest


const TABLE_PATH: String = "res://assets/data/equipment/stat_assignment_table.tres"


# ─── Fixtures ──────────────────────────────────────────────────────────────────


func _make_full_item() -> EquipmentItem:
	var receipt: SourceReceipt = SourceReceipt.new()
	receipt.workout_date_unix = 1764547200
	receipt.pr_snapshot = {"bench_press": 180.0}
	receipt.volume_snapshot = 5400.0
	receipt.signature_text = "鍛造自 180kg × 5"

	var item: EquipmentItem = EquipmentItem.new()
	item.item_id = &"1764547200123_42_combat_lootdrop_D-99-77"
	item.source_transition_id = "1764547200123_42_combat_lootdrop"
	item.item_type = LootEnums.ItemType.WEAPON
	item.rarity = LootEnums.RarityTier.LEGENDARY
	item.class_tag = LootEnums.ClassTag.STRIKE
	item.stat_modifiers = { &"ATTACK_POWER": 90.0 }
	item.source_receipt = receipt
	item.provenance_text = "拾於 12月1日・推日"
	item.is_cosmetic = false
	item.visual_id = ""
	item.lifecycle_state = EquipmentEnums.ItemLifecycle.EQUIPPED
	item.is_locked = true
	item.acquired_at_unix = 1764547300
	item.slot_affinity = EquipmentEnums.EquipSlot.WEAPON
	return item


# ─── EquipmentItem round-trip (AC: dict envelope symmetric) ────────────────────


func test_equipment_item_full_round_trip_preserves_all_fields() -> void:
	# Arrange
	var original: EquipmentItem = _make_full_item()

	# Act
	var restored: EquipmentItem = EquipmentItem.from_dict(original.to_dict())

	# Assert — deep field equality
	assert_eq(restored.item_id, original.item_id)
	assert_eq(restored.source_transition_id, original.source_transition_id)
	assert_eq(restored.item_type, original.item_type)
	assert_eq(restored.rarity, original.rarity)
	assert_eq(restored.class_tag, original.class_tag)
	assert_eq(restored.stat_modifiers, original.stat_modifiers)
	assert_eq(restored.provenance_text, original.provenance_text)
	assert_eq(restored.is_cosmetic, original.is_cosmetic)
	assert_eq(restored.lifecycle_state, original.lifecycle_state)
	assert_eq(restored.is_locked, original.is_locked)
	assert_eq(restored.acquired_at_unix, original.acquired_at_unix)
	assert_eq(restored.slot_affinity, original.slot_affinity)
	assert_not_null(restored.source_receipt)
	assert_eq(restored.source_receipt.signature_text, "鍛造自 180kg × 5")
	assert_eq(restored.source_receipt.workout_date_unix, 1764547200)
	assert_eq(restored.source_receipt.volume_snapshot, 5400.0)


func test_equipment_item_null_receipt_round_trips_as_null() -> void:
	# Arrange — COMMON item without receipt (nullable per Rule 10)
	var original: EquipmentItem = _make_full_item()
	original.rarity = LootEnums.RarityTier.COMMON
	original.source_receipt = null

	# Act
	var restored: EquipmentItem = EquipmentItem.from_dict(original.to_dict())

	# Assert
	assert_null(restored.source_receipt)
	assert_false(restored.has_receipt())


func test_equipment_item_empty_stat_modifiers_round_trips_empty() -> void:
	# Arrange — cosmetic carries {}
	var original: EquipmentItem = _make_full_item()
	original.is_cosmetic = true
	original.stat_modifiers = {}
	original.source_receipt = null

	# Act
	var restored: EquipmentItem = EquipmentItem.from_dict(original.to_dict())

	# Assert
	assert_eq(restored.stat_modifiers, {})


func test_equipment_item_enums_persist_as_string_names() -> void:
	# Arrange / Act — ADR-0007: string names, not ordinals
	var dict: Dictionary = _make_full_item().to_dict()

	# Assert
	assert_eq(dict["rarity"], "LEGENDARY")
	assert_eq(dict["item_type"], "WEAPON")
	assert_eq(dict["class_tag"], "STRIKE")
	assert_eq(dict["lifecycle_state"], "EQUIPPED")
	assert_eq(dict["slot_affinity"], "WEAPON")
	assert_eq(dict["payload_type"], "EquipmentItem")


func test_equipment_item_from_dict_missing_keys_fall_back_to_safe_defaults() -> void:
	# Arrange / Act — Contract 3 defensive read on empty dict
	var restored: EquipmentItem = EquipmentItem.from_dict({})

	# Assert — Family A safe defaults / Family B sentinels
	assert_eq(restored.rarity, LootEnums.RarityTier.COMMON)
	assert_eq(restored.lifecycle_state, EquipmentEnums.ItemLifecycle.IN_MAILBOX)
	assert_eq(restored.slot_affinity, EquipmentEnums.EquipSlot.NONE)
	assert_eq(restored.class_tag, LootEnums.ClassTag.NEUTRAL)
	assert_false(restored.is_locked)
	assert_null(restored.source_receipt)


# ─── SourceReceipt round-trip ──────────────────────────────────────────────────


func test_source_receipt_round_trip_symmetric() -> void:
	# Arrange
	var receipt: SourceReceipt = SourceReceipt.new()
	receipt.workout_date_unix = 1764547200
	receipt.pr_snapshot = {"deadlift": 200.0}
	receipt.volume_snapshot = 6000.0
	receipt.signature_text = "鍛造自 200kg × 3"

	# Act
	var restored: SourceReceipt = SourceReceipt.from_dict(receipt.to_dict())

	# Assert
	assert_eq(restored.workout_date_unix, receipt.workout_date_unix)
	assert_eq(restored.pr_snapshot, receipt.pr_snapshot)
	assert_eq(restored.volume_snapshot, receipt.volume_snapshot)
	assert_eq(restored.signature_text, receipt.signature_text)


# ─── EquipmentEnums conventions (ADR-0007) ─────────────────────────────────────


func test_receive_result_ordinal_zero_is_conservative_failed_rollback() -> void:
	# ADR-0007 Family A: zero-default must never fabricate success (Pillar 3).
	assert_eq(EquipmentEnums.ReceiveResult.FAILED_ROLLBACK, 0)


func test_item_lifecycle_ordinal_zero_is_in_mailbox() -> void:
	# Conservative default: parked, not feeding combat, not losable (A3).
	assert_eq(EquipmentEnums.ItemLifecycle.IN_MAILBOX, 0)


func test_equip_slot_sentinel_none_is_last() -> void:
	# Family B sentinel placed last.
	assert_eq(EquipmentEnums.EquipSlot.NONE, 4)


func test_allowed_stat_keys_are_the_four_derived_keys() -> void:
	# D8 derived-keys-only contract surface.
	assert_eq(EquipmentItem.ALLOWED_STAT_KEYS.size(), 4)
	assert_has(EquipmentItem.ALLOWED_STAT_KEYS, &"ATTACK_POWER")
	assert_has(EquipmentItem.ALLOWED_STAT_KEYS, &"MAX_HP")
	assert_has(EquipmentItem.ALLOWED_STAT_KEYS, &"MOVE_SPEED")
	assert_has(EquipmentItem.ALLOWED_STAT_KEYS, &"CRIT_CHANCE")


# ─── StatAssignmentTable (D9) ──────────────────────────────────────────────────


func test_stat_table_weapon_legendary_lookup_returns_atk_90() -> void:
	# Arrange
	var table: StatAssignmentTable = load(TABLE_PATH)

	# Act
	var mods: Dictionary = table.lookup(
		LootEnums.ItemType.WEAPON, LootEnums.RarityTier.LEGENDARY)

	# Assert — golden cell (deliberately > fresh-account cap 84)
	assert_eq(mods, { &"ATTACK_POWER": 90.0 })


func test_stat_table_accessory_uncommon_lookup_returns_move_and_crit() -> void:
	# Arrange
	var table: StatAssignmentTable = load(TABLE_PATH)

	# Act
	var mods: Dictionary = table.lookup(
		LootEnums.ItemType.ACCESSORY, LootEnums.RarityTier.UNCOMMON)

	# Assert
	assert_eq(mods, { &"MOVE_SPEED": 8.0, &"CRIT_CHANCE": 0.01 })


func test_stat_table_accessory_common_has_no_crit_key() -> void:
	# Arrange
	var table: StatAssignmentTable = load(TABLE_PATH)

	# Act
	var mods: Dictionary = table.lookup(
		LootEnums.ItemType.ACCESSORY, LootEnums.RarityTier.COMMON)

	# Assert — COMMON accessory carries no crit (0.0 cell omitted)
	assert_eq(mods, { &"MOVE_SPEED": 5.0 })


func test_stat_table_armor_common_lookup_returns_hp_20() -> void:
	# Arrange
	var table: StatAssignmentTable = load(TABLE_PATH)

	# Act / Assert
	assert_eq(
		table.lookup(LootEnums.ItemType.ARMOR, LootEnums.RarityTier.COMMON),
		{ &"MAX_HP": 20.0 })


func test_stat_table_consumable_and_cosmetic_lookup_empty() -> void:
	# Arrange
	var table: StatAssignmentTable = load(TABLE_PATH)

	# Act / Assert — D1 inert + Rule 5 parallel pipeline
	assert_eq(table.lookup(LootEnums.ItemType.CONSUMABLE, LootEnums.RarityTier.EPIC), {})
	assert_eq(table.lookup(LootEnums.ItemType.COSMETIC, LootEnums.RarityTier.LEGENDARY), {})


func test_stat_table_shipped_tres_passes_validate() -> void:
	# Arrange
	var table: StatAssignmentTable = load(TABLE_PATH)

	# Act — must not crash (asserts are the guard)
	table._validate()
	pass_test("shipped stat_assignment_table.tres satisfies #11 contract ranges")


func test_stat_table_all_cells_within_contract_ranges() -> void:
	# Arrange — verify the invariant conditions directly (bool form)
	var table: StatAssignmentTable = load(TABLE_PATH)

	# Assert
	for value: int in table.weapon_atk:
		assert_true(value >= 0 and value <= StatAssignmentTable.ATK_CONTRACT_MAX,
			"weapon_atk %d within [0,300]" % value)
	for value: int in table.armor_hp:
		assert_true(value >= 0 and value <= StatAssignmentTable.HP_CONTRACT_MAX,
			"armor_hp %d within [0,500]" % value)
	for value: int in table.accessory_move:
		assert_true(value >= 0 and value <= StatAssignmentTable.MOVE_CONTRACT_MAX,
			"accessory_move %d within [0,100]" % value)
	for value: float in table.accessory_crit:
		assert_true(value >= 0.0 and value <= StatAssignmentTable.CRIT_CONTRACT_MAX,
			"accessory_crit %f within [0,0.20]" % value)


func test_stat_table_full_table_matches_gdd_golden_values() -> void:
	# Arrange — re-pin every cell against the GDD Stat Assignment Table
	var table: StatAssignmentTable = load(TABLE_PATH)

	# Assert
	assert_eq(table.weapon_atk, Array([6, 12, 22, 45, 90], TYPE_INT, "", null))
	assert_eq(table.armor_hp, Array([20, 35, 60, 100, 160], TYPE_INT, "", null))
	assert_eq(table.accessory_move, Array([5, 8, 12, 18, 25], TYPE_INT, "", null))
	assert_eq(table.accessory_crit, Array([0.0, 0.01, 0.02, 0.04, 0.06], TYPE_FLOAT, "", null))
