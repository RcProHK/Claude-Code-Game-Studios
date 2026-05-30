## test_schema_migration_under_900ms.gd — Story 012 AC-35
##
## Governing story: production/epics/loot-drop-system/story-012-persistence-schema-migration.md
## Governing ADRs : ADR-0003 (Accepted 2026-05-30) schema migration 900ms ceiling
##
## AC-35: LootDrop schema migration:
##   - CURRENT_SCHEMA (v1) → no migration, pass through.
##   - schema_version < CURRENT (e.g. v0) → quarantine + telemetry (no migration table yet).
##   - schema_version > CURRENT (future build) → quarantine + telemetry.
##   - Boot NOT blocked by quarantine.
##   - Full chain within 900ms ADR-0003 ceiling.
extends GutTest

## Autoload script preloaded as a const (shadows the LootDropSystem autoload
## global so tests can call .new() / access enums + constants on the class).
const LootDropSystem := preload("res://src/autoload/loot_drop_system.gd")


# ── Inline mock with list_keys support ────────────────────────────────────────

class MockPersistenceLootMigration extends MockPersistenceLayer:
	var write_ok: bool = true
	signal private_mode_detected

	func is_private_mode() -> bool:
		return false

	func write_async(key: String, value: Variant) -> bool:
		return write(key, value)

	## Return all keys that start with the given prefix.
	func list_keys(prefix: String) -> Array:
		var result: Array = []
		for k: String in _data.keys():
			if k.begins_with(prefix):
				result.append(k)
		return result


# ── Fixture ────────────────────────────────────────────────────────────────────

var _sut: LootDropSystem
var _mock_persistence: MockPersistenceLootMigration
var _config: LootRarityConfig


func _make_config() -> LootRarityConfig:
	var c := LootRarityConfig.new()
	c.workout_weight = 0.75
	c.rng_weight = 0.25
	c.target_exercises = 5
	c.pr_bonus_per_pr = 0.12
	c.max_pr_factor = 1.25
	c.streak_scale = 28.0
	c.max_streak_bonus = 0.20
	c.tier_thresholds = [0.0, 0.35, 0.55, 0.72, 0.88]
	c.tier_values = [0, 1, 2, 3, 4]
	return c


func before_each() -> void:
	_mock_persistence = MockPersistenceLootMigration.new()
	_config = _make_config()
	_sut = LootDropSystem.new()
	_sut._config = _config
	_sut._persistence = _mock_persistence
	_sut._gsm = null
	_sut._gymsys_client = null
	add_child_autofree(_sut)
	await get_tree().process_frame
	_sut.clear_telemetry()


func after_each() -> void:
	_sut = null
	_mock_persistence = null
	_config = null


# ── AC-35: schema migration ────────────────────────────────────────────────────

func test_ac35_current_schema_pass_through_no_migration() -> void:
	var drop_dict := {
		"drop_id": "D-current",
		"transition_id": "T-current",
		"rarity_tier": "COMMON",
		"item_type": "WEAPON",
		"class_tag": "NEUTRAL",
		"source_event_kind": "WORKOUT_DAILY",
		"created_at_unix": 1748563200,
		"schema_version": 1,  # CURRENT_SCHEMA
		"item_metadata": {},
	}
	var result := _sut._migrate_pending_drop(drop_dict)
	assert_eq(result, drop_dict,
		"AC-35: CURRENT_SCHEMA drop must pass through unchanged (no migration needed)")


func test_ac35_older_schema_quarantined_when_no_migration_table() -> void:
	# Schema 0 has no migration path → quarantine.
	var drop_dict := {
		"drop_id": "D-old",
		"transition_id": "T-old",
		"rarity_tier": "COMMON",
		"item_type": "WEAPON",
		"class_tag": "NEUTRAL",
		"source_event_kind": "WORKOUT_DAILY",
		"created_at_unix": 1748563200,
		"schema_version": 0,  # Older than CURRENT
		"item_metadata": {},
	}
	var result := _sut._migrate_pending_drop(drop_dict)
	assert_eq(result.size(), 0,
		"AC-35: Unmigratable schema_version=0 must return {} (quarantine)")


func test_ac35_older_schema_writes_to_quarantine_namespace() -> void:
	var drop_dict := {
		"drop_id": "D-quarantine-test",
		"schema_version": 0,
		"rarity_tier": "COMMON",
	}
	_sut._migrate_pending_drop(drop_dict)
	var quarantine_key: String = "loot.pending.quarantine.D-quarantine-test"
	assert_not_null(_mock_persistence.read(quarantine_key),
		"AC-35: Unmigratable drop must be written to loot.pending.quarantine.*")


func test_ac35_older_schema_emits_quarantined_telemetry() -> void:
	var drop_dict := {"drop_id": "D-telem", "schema_version": 0}
	_sut._migrate_pending_drop(drop_dict)
	var q_events := _sut.get_telemetry("loot.migration.quarantined")
	assert_eq(q_events.size(), 1,
		"AC-35: Quarantined drop must emit loot.migration.quarantined telemetry")


func test_ac35_future_schema_quarantined() -> void:
	var drop_dict := {
		"drop_id": "D-future",
		"schema_version": 99,  # Far future
	}
	var result := _sut._migrate_pending_drop(drop_dict)
	assert_eq(result.size(), 0,
		"AC-35: schema_version > CURRENT must also be quarantined (cannot downgrade)")


func test_ac35_migration_does_not_block_boot() -> void:
	# Pre-seed unmigratable drop in PL.
	_mock_persistence.write("loot.pending.D-block-test", {
		"drop_id": "D-block-test",
		"schema_version": 0,
	})
	# _restore_pending_drops must complete without error.
	_sut._restore_pending_drops()
	pass_test("AC-35: _restore_pending_drops must not crash or block on unmigratable entries")


func test_ac35_migration_under_900ms() -> void:
	# Process 100 unmigratable drops — must complete well under 900ms.
	var start_ms: int = Time.get_ticks_msec()
	for i: int in range(100):
		_sut._migrate_pending_drop({"drop_id": "D-%d" % i, "schema_version": 0})
	var elapsed_ms: int = Time.get_ticks_msec() - start_ms
	assert_lt(elapsed_ms, 900,
		"AC-35: 100 migration+quarantine operations must complete under 900ms (ADR-0003 ceiling)")


# ── _on_backend_ack rename stub ────────────────────────────────────────────────

func test_backend_ack_moves_pending_to_committed() -> void:
	# Pre-seed a pending drop.
	var drop := LootDrop.new()
	drop.drop_id = "D-pending-001"
	drop.transition_id = "T-ack-test"
	drop.rarity_tier = "RARE"
	drop.item_type = "ARMOR"
	drop.class_tag = "NEUTRAL"
	drop.source_event_kind = "WORKOUT_DAILY"
	drop.schema_version = 1
	_sut._pending_drops["D-pending-001"] = drop
	_mock_persistence.write("loot.pending.D-pending-001", drop.to_dict())

	# Simulate backend ACK.
	_sut._on_backend_ack({"drop_id": "D-pending-001", "canonical_id": "C-server-007"})

	# pending → committed rename.
	assert_null(_mock_persistence.read("loot.pending.D-pending-001"),
		"Pending key must be deleted after ACK")
	assert_not_null(_mock_persistence.read("loot.committed.C-server-007"),
		"Committed key must be written after ACK")
	assert_false(_sut._pending_drops.has("D-pending-001"),
		"Drop must be removed from _pending_drops after ACK")
