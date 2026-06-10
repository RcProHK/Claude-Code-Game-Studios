extends GutTest
## Story 009: CR-12 persistence schema round-trip + boot-counter rebuild + the four
## EC-BOOT recovery branches. Injects a MockPersistence seam (per
## reference_test_persistence_isolation — never touch the real autoload cache) and drives
## _read_persistence() directly so each recovery path is deterministic.
## See production/epics/avatar-renderer/story-009-*.

const AvatarRendererScript := preload("res://src/autoload/avatar_renderer.gd")


class MockPersistence:
	extends Node
	var store: Dictionary = {}
	var writable: bool = true
	var use_forced: bool = false
	var forced_read = null
	func read(key: String):
		if use_forced:
			return forced_read
		return store.get(key, null)
	func write(key: String, value, _flush: bool = false) -> bool:
		if not writable:
			return false
		store[key] = value.duplicate(true) if value is Dictionary else value
		return true


func _renderer(persist: Node, cfg: AvatarEvolutionConfig) -> Node:
	var r = AvatarRendererScript.new()
	r._persistence = persist  # untyped DI seam, no _ready() boot
	r._config = cfg
	return r


func test_schema_round_trip() -> void:
	# CR-12: every persisted field round-trips through a fresh instance.
	var p := MockPersistence.new()
	var cfg := AvatarEvolutionConfig.new()
	var a := _renderer(p, cfg)
	a._historical_max_tier = 2
	a._last_emitted_tier = 1
	a._last_milestone_emit_unix = 12345
	a._last_micro_emit_unix = 6789
	a._pending_milestone = true
	a._tier_attainment_log = [{"tier": 1, "at_unix": 100}, {"tier": 2, "at_unix": 200}]
	a._config_hash_at_last_emit = cfg.version_hash
	assert_true(a._write_persistence(), "write returns true when writable")

	var b := _renderer(p, cfg)
	b._read_persistence()
	assert_eq(b._historical_max_tier, 2, "current_tier round-trips")
	assert_eq(b._last_emitted_tier, 1, "last_emitted_tier round-trips")
	assert_eq(b._last_milestone_emit_unix, 12345, "last_milestone_emit_unix round-trips")
	assert_eq(b._last_micro_emit_unix, 6789, "last_micro_emit_unix round-trips")
	assert_eq(b._pending_milestone, true, "pending_milestone round-trips")
	assert_eq(b._tier_attainment_log.size(), 2, "tier_attainment_log round-trips")
	a.free()
	b.free()
	p.free()


func test_attainment_log_fifo_cap() -> void:
	# CR-12: append-only log caps at 52, dropping the oldest entries.
	var p := MockPersistence.new()
	var a := _renderer(p, AvatarEvolutionConfig.new())
	for i in range(60):
		a._append_tier_attainment(3, i)
	assert_eq(a._tier_attainment_log.size(), 52, "FIFO cap 52")
	assert_eq(int(a._tier_attainment_log[0]["at_unix"]), 8, "oldest 8 dropped (0..7), index0 = 8")
	a.free()
	p.free()


func test_ec_boot1_private_mode_suppresses_emits() -> void:
	# EC-BOOT-1 (CRITICAL): user:// unavailable -> degraded -> emits suppressed this session.
	var p := MockPersistence.new()
	p.writable = false
	p.use_forced = true
	p.forced_read = null
	var a := _renderer(p, AvatarEvolutionConfig.new())
	a._read_persistence()
	assert_true(a._persistence_degraded, "degraded flagged when write probe fails")
	assert_true(a._suppress_emit_this_session, "milestone+micro suppressed this session")
	a.free()
	p.free()


func test_ec_boot5_corruption_repaired_no_emit() -> void:
	# EC-BOOT-5 (CRITICAL): last_emitted > current = corruption -> repair + suppress.
	var p := MockPersistence.new()
	p.use_forced = true
	p.forced_read = {"current_tier": 1, "last_emitted_tier": 3, "schema_version": 1}
	var a := _renderer(p, AvatarEvolutionConfig.new())
	a._read_persistence()
	assert_eq(a._last_emitted_tier, 1, "repair: last_emitted_tier clamped to current_tier")
	assert_true(a._suppress_emit_this_session, "no emit this session after corruption")
	a.free()
	p.free()


func test_ec_boot4_future_tier_clamps_to_t3() -> void:
	# EC-BOOT-4: persisted T4+ -> clamp T3 + downgrade migration.
	var p := MockPersistence.new()
	p.use_forced = true
	p.forced_read = {"current_tier": 5, "last_emitted_tier": 5, "schema_version": 1}
	var a := _renderer(p, AvatarEvolutionConfig.new())
	a._read_persistence()
	assert_eq(a._historical_max_tier, 3, "clamp T5 -> T3")
	assert_eq(a._last_emitted_tier, 3, "last_emitted clamped post-migration")
	a.free()
	p.free()


func test_ec_boot3_config_drift_recovery() -> void:
	# EC-BOOT-3: config version_hash changed -> arm rebase, clear pending, no replay.
	var p := MockPersistence.new()
	var cfg := AvatarEvolutionConfig.new()
	p.use_forced = true
	p.forced_read = {
		"current_tier": 2, "last_emitted_tier": 2, "pending_milestone": true,
		"config_hash_at_last_emit": "OLD-HASH-v0", "schema_version": 1,
	}
	var a := _renderer(p, cfg)
	a._read_persistence()
	assert_true(a._config_drift_recovery, "drift recovery armed for first derive")
	assert_false(a._pending_milestone, "pending cleared on config drift")
	assert_eq(a._config_hash_at_last_emit, cfg.version_hash, "hash rebased to current config")
	a.free()
	p.free()
