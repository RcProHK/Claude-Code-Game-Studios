## test_private_mode_mid_session.gd — Story 009 AC-24
##
## Governing story: production/epics/loot-drop-system/story-009-autoload-boot-private-mode.md
## Governing ADRs : ADR-0003 (Accepted 2026-05-30) Private Mode gate (mid-session)
##
## AC-24: When Private Mode is detected MID-SESSION (system already Idle), the
## LootDropSystem must transition to Disabled, emit loot_disabled("private_mode"),
## and short-circuit future triggers — while leaving already-revealed volatile
## drops in _pending_drops unchanged.
extends GutTest


# ── Inline mock ────────────────────────────────────────────────────────────────

class MockPersistenceLoot extends MockPersistenceLayer:
	var _private_mode: bool = false
	signal private_mode_detected

	func is_private_mode() -> bool:
		return _private_mode

	func set_private_mode(value: bool) -> void:
		_private_mode = value

	## Expose method to simulate mid-session private mode detection.
	func trigger_private_mode_detected() -> void:
		private_mode_detected.emit()


# ── Fixture ────────────────────────────────────────────────────────────────────

var _sut: LootDropSystem
var _mock_persistence: MockPersistenceLoot
var _disabled_signals: Array = []
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
	_disabled_signals.clear()
	_mock_persistence = MockPersistenceLoot.new()
	_mock_persistence.set_private_mode(false)  # Private Mode OFF initially → boots to IDLE

	_config = _make_config()
	_sut = LootDropSystem.new()
	_sut._persistence = _mock_persistence
	_sut._config = _config
	_sut._gsm = null
	_sut._gymsys_client = null

	_sut.loot_disabled.connect(func(r): _disabled_signals.append(r))

	add_child_autofree(_sut)
	await get_tree().process_frame
	# At this point, system should be IDLE (private_mode=false, config valid).


func after_each() -> void:
	_sut = null
	_mock_persistence = null
	_config = null


# ── AC-24 tests ────────────────────────────────────────────────────────────────

func test_ac24_system_starts_idle_before_mid_session_trigger() -> void:
	# Precondition: system boots to IDLE when private_mode is false.
	assert_eq(_sut._state, LootDropSystem.State.IDLE,
		"AC-24 precondition: system must start in IDLE (private_mode=false on boot)")


func test_ac24_mid_session_private_mode_transitions_to_disabled() -> void:
	# Act: simulate mid-session detection.
	_mock_persistence.trigger_private_mode_detected()
	await get_tree().process_frame
	# Assert: state → DISABLED.
	assert_eq(_sut._state, LootDropSystem.State.DISABLED,
		"AC-24: Private Mode detected mid-session must transition state to DISABLED")


func test_ac24_mid_session_emits_loot_disabled_signal() -> void:
	# No signal before trigger.
	assert_eq(_disabled_signals.size(), 0, "No loot_disabled before mid-session trigger")
	_mock_persistence.trigger_private_mode_detected()
	await get_tree().process_frame
	assert_eq(_disabled_signals.size(), 1, "loot_disabled must be emitted once mid-session")
	assert_eq(_disabled_signals[0], "private_mode",
		"AC-24: loot_disabled reason must be 'private_mode'")


func test_ac24_mid_session_no_double_emit_if_already_disabled() -> void:
	# Trigger once → Disabled. Trigger again → no second emit.
	_mock_persistence.trigger_private_mode_detected()
	await get_tree().process_frame
	_mock_persistence.trigger_private_mode_detected()
	await get_tree().process_frame
	assert_eq(_disabled_signals.size(), 1,
		"AC-24: loot_disabled must NOT be double-emitted if already Disabled")


func test_ac24_trigger_blocked_after_mid_session_private_mode() -> void:
	_mock_persistence.trigger_private_mode_detected()
	await get_tree().process_frame
	assert_true(_sut._is_trigger_blocked(),
		"AC-24: _is_trigger_blocked() must return true after mid-session private mode")


func test_ac24_is_private_mode_blocked_true_after_mid_session() -> void:
	_mock_persistence.trigger_private_mode_detected()
	await get_tree().process_frame
	assert_true(_sut.is_private_mode_blocked(),
		"AC-24: is_private_mode_blocked() must return true after mid-session disable")


func test_ac24_existing_pending_drops_retained_volatile_after_disable() -> void:
	# Pre-seed a volatile pending drop (simulating a revealed drop already in memory).
	var fake_drop := LootDrop.new()
	fake_drop.drop_id = "D-volatile-001"
	fake_drop.rarity_tier = "RARE"
	_sut._pending_drops["D-volatile-001"] = fake_drop

	# Trigger mid-session private mode.
	_mock_persistence.trigger_private_mode_detected()
	await get_tree().process_frame

	# The volatile drop must still be in memory (not silently deleted).
	assert_true(_sut._pending_drops.has("D-volatile-001"),
		"AC-24: Already-revealed volatile drops must remain in _pending_drops after disable")
	assert_eq(_sut.get_drop("D-volatile-001"), fake_drop,
		"AC-24: get_drop() must return the retained volatile drop")
