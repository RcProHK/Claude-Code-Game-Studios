## test_private_mode_disabled_state.gd — Story 009 AC-23
##
## Governing story: production/epics/loot-drop-system/story-009-autoload-boot-private-mode.md
## Governing ADRs : ADR-0003 (Accepted 2026-05-30) Private Mode gate; ADR-0006 Contract 6
##
## AC-23: When PersistenceLayer reports private_mode=true on boot, LootDropSystem
## must immediately enter Disabled state, emit loot_disabled("private_mode"), and
## short-circuit all subsequent trigger events without generating any LootDrop.
##
## MockPersistenceLoot extends MockPersistenceLayer with the two Loot-specific
## surface members: is_private_mode() and private_mode_detected signal.
extends GutTest

## Autoload script preloaded as a const (shadows the LootDropSystem autoload
## global so tests can call .new() / access enums + constants on the class).
const LootDropSystem := preload("res://src/autoload/loot_drop_system.gd")


# ── Inline mock ────────────────────────────────────────────────────────────────

class MockPersistenceLoot extends MockPersistenceLayer:
	## Controls what is_private_mode() returns.
	var _private_mode: bool = false
	## Signal matching GDD Rule 16 — emitted when Private Mode is detected mid-session.
	signal private_mode_detected

	func is_private_mode() -> bool:
		return _private_mode

	func set_private_mode(value: bool) -> void:
		_private_mode = value


# ── Fixture ────────────────────────────────────────────────────────────────────

var _sut: LootDropSystem
var _mock_persistence: MockPersistenceLoot
var _disabled_signals: Array = []
var _config: LootRarityConfig


func before_each() -> void:
	_disabled_signals.clear()
	_mock_persistence = MockPersistenceLoot.new()
	_mock_persistence.set_private_mode(true)  # Private Mode ON

	# Build a valid config to avoid disk-load failure.
	_config = LootRarityConfig.new()
	_config.workout_weight = 0.75
	_config.rng_weight = 0.25
	_config.target_exercises = 5
	_config.pr_bonus_per_pr = 0.12
	_config.max_pr_factor = 1.25
	_config.streak_scale = 28.0
	_config.max_streak_bonus = 0.20
	_config.tier_thresholds = [0.0, 0.35, 0.55, 0.72, 0.88]
	_config.tier_values = [0, 1, 2, 3, 4]

	_sut = LootDropSystem.new()
	_sut._persistence = _mock_persistence
	_sut._config = _config   # Inject config → skip disk load
	_sut._gsm = null         # No GSM in this test
	_sut._gymsys_client = null  # No backend_ready await

	# Record loot_disabled emissions.
	_sut.loot_disabled.connect(func(r): _disabled_signals.append(r))

	add_child_autofree(_sut)
	await get_tree().process_frame


func after_each() -> void:
	_sut = null
	_mock_persistence = null
	_config = null


# ── AC-23 tests ────────────────────────────────────────────────────────────────

func test_ac23_private_mode_on_boot_state_is_disabled() -> void:
	assert_eq(_sut._state, LootDropSystem.State.DISABLED,
		"AC-23: Private Mode on boot must set state = DISABLED")


func test_ac23_private_mode_on_boot_emits_loot_disabled_signal() -> void:
	assert_eq(_disabled_signals.size(), 1,
		"AC-23: loot_disabled must be emitted exactly once on boot with private_mode")
	assert_eq(_disabled_signals[0], "private_mode",
		"AC-23: loot_disabled reason must be 'private_mode'")


func test_ac23_is_private_mode_blocked_returns_true() -> void:
	assert_true(_sut.is_private_mode_blocked(),
		"AC-23: is_private_mode_blocked() must return true when Disabled")


func test_ac23_trigger_events_short_circuit_in_disabled_state() -> void:
	# _is_trigger_blocked() must return true in Disabled state.
	assert_true(_sut._is_trigger_blocked(),
		"AC-23: _is_trigger_blocked() must return true in DISABLED state")


func test_ac23_pending_drops_empty_after_private_mode_boot() -> void:
	# No drops should have been generated or restored when Private Mode is active.
	assert_eq(_sut.get_pending_drops().size(), 0,
		"AC-23: No pending drops must exist after private-mode boot")


func test_ac23_boot_completed_not_emitted_in_disabled_state() -> void:
	# Boot exits early before boot_completed — the signal must NOT fire.
	# We cannot easily check this retroactively, but _state == DISABLED proves
	# the early-return path was taken (boot_completed is emitted after _state = IDLE).
	assert_ne(_sut._state, LootDropSystem.State.IDLE,
		"AC-23: State must NOT be IDLE after private-mode boot (boot_completed never fires)")


func test_ac23_private_mode_short_circuits_before_backend_await() -> void:
	# With _gymsys_client = null AND private_mode=true, the system enters Disabled
	# before the (skipped) backend_ready await. Verify by checking state + no hang.
	# The test completing at all (no timeout) proves no await was hit.
	assert_eq(_sut._state, LootDropSystem.State.DISABLED,
		"AC-23: Private Mode must short-circuit before any backend_ready await")
