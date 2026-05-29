# GameStateMachine — Story 015 Rule 6 Zero-Input (Pillar 2)
extends GutTest


var _policy: AttentionBudgetPolicy


func before_each() -> void:
	_policy = AttentionBudgetPolicy.new()


## AC-gsm-r6-1: WORKOUT_ACTIVE → input blocked
func test_attention_budget_blocks_input_in_workout_active() -> void:
	GameStateMachine.set(&"_current_state", GameStateMachine.GameState.WORKOUT_ACTIVE)
	assert_false(_policy.is_input_permitted(),
		"AC-r6-1: WORKOUT_ACTIVE must block input")


## AC-gsm-r6-1 (also): COMBAT_ACTIVE blocked
func test_attention_budget_blocks_input_in_combat_active() -> void:
	GameStateMachine.set(&"_current_state", GameStateMachine.GameState.COMBAT_ACTIVE)
	assert_false(_policy.is_input_permitted(),
		"COMBAT_ACTIVE must block input (Pillar 2)")


## AC-gsm-r6-1 (also): BOSS_ENCOUNTER blocked
func test_attention_budget_blocks_input_in_boss_encounter() -> void:
	GameStateMachine.set(&"_current_state", GameStateMachine.GameState.BOSS_ENCOUNTER)
	assert_false(_policy.is_input_permitted(),
		"BOSS_ENCOUNTER must block input")


## AC-gsm-r6-2: IDLE → input allowed
func test_attention_budget_allows_input_in_idle() -> void:
	GameStateMachine.set(&"_current_state", GameStateMachine.GameState.IDLE)
	assert_true(_policy.is_input_permitted(),
		"AC-r6-2: IDLE must allow input")


## AC-gsm-r6-3: transition from blocked → allowed
func test_attention_budget_transitions_blocked_to_allowed() -> void:
	# Blocked
	GameStateMachine.set(&"_current_state", GameStateMachine.GameState.WORKOUT_ACTIVE)
	assert_false(_policy.is_input_permitted())
	# Transitioned to allowed
	GameStateMachine.set(&"_current_state", GameStateMachine.GameState.REST_PERIOD)
	assert_true(_policy.is_input_permitted(),
		"AC-r6-3: WORKOUT_ACTIVE → REST_PERIOD must flip input permission")
