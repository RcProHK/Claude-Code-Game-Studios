# InventorySystem — Story 005: mailbox TTL auto-salvage + hard-cap FIFO + 時基.
#
# Scope (GDD Rule 4 [A3 binding] + EC-8/9 + Formula 2):
#   AC-09 — TTL sweep: >7d non-receipt → auto-salvage (shards + telemetry);
#           receipt-bearing kept (A3 never silently expire); server drift
#           beyond tolerance → grace (both kept)
#   AC-10 — hard cap: oldest (FIFO by acquired_at) non-receipt evicts; oldest
#           receipt-bearing skipped (next-oldest evicts)
#   EC-9  — all-receipt mailbox → soft-admit over cap + telemetry alert
#   Formula 2 — yield table 100/150/250/450/800
#
# Framework: GUT v9.x | TimeProvider seam 1 + server seam 7 injected
# Story: production/epics/equipment-inventory/story-005-mailbox-ttl-auto-salvage.md
extends GutTest

const InventorySystem := preload("res://src/autoload/inventory_system.gd")

const FIXED_NOW: int = 1764547300
const DAY_SEC: int = 86400

var _sut


func before_each() -> void:
	_sut = InventorySystem.new()
	_sut._now_unix_provider = func() -> int: return FIXED_NOW
	_sut._server_unix_provider = func() -> int: return FIXED_NOW  # sane by default
	add_child_autofree(_sut)


func _add_mailbox_item(
		id_suffix: String, age_days: int, rarity: int, with_receipt: bool) -> StringName:
	var item: EquipmentItem = EquipmentItem.new()
	item.item_id = StringName("tid_%s_D-0-%s" % [id_suffix, id_suffix])
	item.rarity = rarity
	item.lifecycle_state = EquipmentEnums.ItemLifecycle.IN_MAILBOX
	item.acquired_at_unix = FIXED_NOW - age_days * DAY_SEC
	if with_receipt:
		item.source_receipt = SourceReceipt.new()
	_sut._items[item.item_id] = item
	return item.item_id


# ─── Formula 2 ─────────────────────────────────────────────────────────────────


func test_salvage_yield_table_matches_gdd() -> void:
	assert_eq(InventorySystem.salvage_yield(LootEnums.RarityTier.COMMON), 100)
	assert_eq(InventorySystem.salvage_yield(LootEnums.RarityTier.UNCOMMON), 150)
	assert_eq(InventorySystem.salvage_yield(LootEnums.RarityTier.RARE), 250)
	assert_eq(InventorySystem.salvage_yield(LootEnums.RarityTier.EPIC), 450)
	assert_eq(InventorySystem.salvage_yield(LootEnums.RarityTier.LEGENDARY), 800)


# ─── AC-09: TTL sweep + receipt immunity + grace ───────────────────────────────


func test_sweep_auto_salvages_expired_non_receipt_keeps_receipt() -> void:
	# Arrange — both 8d old; A has no receipt, B has one
	var id_a: StringName = _add_mailbox_item("a", 8, LootEnums.RarityTier.RARE, false)
	var id_b: StringName = _add_mailbox_item("b", 8, LootEnums.RarityTier.EPIC, true)

	# Act
	_sut.sweep_mailbox()

	# Assert — A converted (250 shards + tombstone + telemetry), B untouched (A3)
	assert_null(_sut.get_item(id_a))
	assert_true(_sut._tombstones.has(id_a))
	assert_eq(_sut.get_forge_shards(), 250)
	assert_not_null(_sut.get_item(id_b))
	assert_eq(_sut.get_telemetry("inventory.mailbox.auto_salvaged").size(), 1)


func test_sweep_keeps_items_within_ttl() -> void:
	# Arrange — exactly 7.0d (boundary: strictly > expires) and 6d
	var id_edge: StringName = _add_mailbox_item("edge", 7, LootEnums.RarityTier.COMMON, false)
	var id_young: StringName = _add_mailbox_item("young", 6, LootEnums.RarityTier.COMMON, false)

	# Act
	_sut.sweep_mailbox()

	# Assert
	assert_not_null(_sut.get_item(id_edge))
	assert_not_null(_sut.get_item(id_young))
	assert_eq(_sut.get_forge_shards(), 0)


func test_sweep_grace_when_server_drift_exceeds_tolerance() -> void:
	# Arrange — expired item but server clock off by 3601s (> 3600 tolerance)
	var id_a: StringName = _add_mailbox_item("a", 8, LootEnums.RarityTier.RARE, false)
	_sut._server_unix_provider = func() -> int: return FIXED_NOW + 3601

	# Act
	_sut.sweep_mailbox()

	# Assert — grace: nothing expires, retry next boot
	assert_not_null(_sut.get_item(id_a))
	assert_eq(_sut.get_forge_shards(), 0)


func test_sweep_grace_when_offline() -> void:
	# Arrange — empty server seam = offline (G-7)
	var id_a: StringName = _add_mailbox_item("a", 8, LootEnums.RarityTier.RARE, false)
	_sut._server_unix_provider = Callable()

	# Act
	_sut.sweep_mailbox()

	# Assert — grace
	assert_not_null(_sut.get_item(id_a))


func test_sweep_proceeds_when_drift_within_tolerance() -> void:
	# Arrange — 3599s drift (≤ 3600) is sane
	var id_a: StringName = _add_mailbox_item("a", 8, LootEnums.RarityTier.COMMON, false)
	_sut._server_unix_provider = func() -> int: return FIXED_NOW - 3599

	# Act
	_sut.sweep_mailbox()

	# Assert
	assert_null(_sut.get_item(id_a))
	assert_eq(_sut.get_forge_shards(), 100)


# ─── AC-10: hard-cap FIFO evict + receipt skip ─────────────────────────────────


func test_hard_cap_evicts_oldest_non_receipt_first() -> void:
	# Arrange — fill mailbox to the 180 cap; "oldest" has no receipt
	for i: int in 180:
		_add_mailbox_item("f%d" % i, 1, LootEnums.RarityTier.COMMON, false)
	var oldest_id: StringName = _add_mailbox_item(
		"oldest", 5, LootEnums.RarityTier.COMMON, false)

	# Act — one more overflow crosses the cap → oldest evicts
	_sut._enforce_mailbox_hard_cap()

	# Assert — FIFO by acquired_at: the 5d-old item went first
	assert_null(_sut.get_item(oldest_id))
	assert_eq(_sut._mailbox_count(), 180)
	assert_eq(_sut.get_forge_shards(), 100)


func test_hard_cap_skips_receipt_bearing_oldest() -> void:
	# Arrange — oldest carries a receipt; next-oldest does not
	for i: int in 180:
		_add_mailbox_item("f%d" % i, 1, LootEnums.RarityTier.COMMON, false)
	var receipt_id: StringName = _add_mailbox_item(
		"receipt", 9, LootEnums.RarityTier.LEGENDARY, true)
	var next_oldest_id: StringName = _add_mailbox_item(
		"next", 5, LootEnums.RarityTier.COMMON, false)

	# Act
	_sut._enforce_mailbox_hard_cap()

	# Assert — receipt item survives; next-oldest evicted instead
	assert_not_null(_sut.get_item(receipt_id))
	assert_null(_sut.get_item(next_oldest_id))


func test_hard_cap_all_receipt_soft_admits_with_alert() -> void:
	# Arrange — 181 receipt-bearing items (no evictable candidates)
	for i: int in 181:
		_add_mailbox_item("r%d" % i, 1, LootEnums.RarityTier.LEGENDARY, true)

	# Act
	_sut._enforce_mailbox_hard_cap()

	# Assert — soft-admit over cap + loud alert (EC-9 fallback)
	assert_eq(_sut._mailbox_count(), 181)
	assert_eq(_sut.get_telemetry("inventory.mailbox.all_receipt_soft_admit").size(), 1)
