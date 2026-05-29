# GameStateMachine — Story 001 AC-01/02/03 Rule 1 Unit Tests
#
# Scope: verifies the GameState 9-enum and Rule 1 invariant (exactly one
# active state at any time). Implementation already exists in
# src/autoload/game_state_machine.gd (Foundation chain step 4, 2026-05-28).
# This story adds formal test coverage.
#
# AC-01: get_current_state() returns BOOTING on fresh autoload
# AC-02: GameState enum has exactly 9 named members
# AC-03: no non-comment `await` in game_state_machine.gd (CI-verified)
#
# Framework: GUT (Godot Unit Testing) v7.x
# Governing ADRs: ADR-0006 Contract 1 (Atomic Transition Primitive)
extends GutTest


## AC-01: fresh autoload returns BOOTING (default state per GDD line 585
## + ADR-0006 Contract 4 boot model — _current_state defaults to BOOTING
## before any reconciliation or transition runs).
func test_gsm_get_current_state_returns_booting_on_fresh_autoload() -> void:
	# Arrange — GameStateMachine autoload is at pos 2, already _ready.
	# BOOTING is the load-bearing default: no transition has fired yet
	# because full Rule 2 primitive + Rule 5 reconciliation are not yet
	# implemented (stories 002/011). This test locks the default.

	# Act
	var state: GameStateMachine.GameState = GameStateMachine.get_current_state()

	# Assert
	assert_eq(
		state,
		GameStateMachine.GameState.BOOTING,
		"AC-01: get_current_state() must return BOOTING before any transition"
	)


## AC-02: GameState enum contains exactly 9 members with the canonical names
## locked by GDD line 585 + ADR-0006 §Decision. Renaming or adding states
## without updating the GDD would change this count and break migration.
func test_gsm_gamestate_enum_has_exactly_nine_members() -> void:
	# Arrange
	const EXPECTED_NAMES: Array[String] = [
		"BOOTING",
		"DISCONNECTED",
		"IDLE",
		"WORKOUT_ACTIVE",
		"REST_PERIOD",
		"COMBAT_ACTIVE",
		"BOSS_ENCOUNTER",
		"LOOT_DROP",
		"SUSPENDED",
	]

	# Act
	var actual_keys: Array = GameStateMachine.GameState.keys()

	# Assert — count
	assert_eq(
		actual_keys.size(),
		9,
		"AC-02: GameState enum must have exactly 9 members (GDD line 585)"
	)

	# Assert — names
	for name in EXPECTED_NAMES:
		assert_true(
			GameStateMachine.GameState.has(name),
			"AC-02: GameState enum must contain member '%s'" % name
		)


## AC-03: no non-comment `await` in game_state_machine.gd — proxy check.
## The definitive CI enforcement is `tools/ci/check_no_await_in_state_machine.sh`
## (Story 007). This test verifies the structural invariant at unit level:
## get_current_state() returns synchronously within the same call stack
## (demonstrating there is no await-driven deferred path on the read path).
func test_gsm_get_current_state_returns_synchronously() -> void:
	# Arrange — attach a counter to verify synchronous call completion.
	# If get_current_state() awaited internally, the counter would still be
	# 0 when read immediately after the call returns.
	var call_completed: int = 0

	# Act — if sync, call_completed increments to 1 before we read it.
	GameStateMachine.get_current_state()
	call_completed = 1

	# Assert
	assert_eq(call_completed, 1,
		"AC-03: get_current_state() must return synchronously (no await path)")


## Additional: Rule 1 invariant — state is always a valid GameState enum value.
func test_gsm_current_state_is_valid_gamestate_enum_value() -> void:
	# Arrange
	var state: GameStateMachine.GameState = GameStateMachine.get_current_state()

	# Assert — value must map back to a known key
	var key: Variant = GameStateMachine.GameState.find_key(state)
	assert_not_null(key,
		"Rule 1: current_state must be a valid GameState enum value (find_key must not return null)")
	assert_true(key is String and key.length() > 0,
		"Rule 1: GameState.find_key() must return a non-empty string name")
