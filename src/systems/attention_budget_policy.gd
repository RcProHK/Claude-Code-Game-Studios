## AttentionBudgetPolicy — Pillar 2 input enforcement (Story 015 stub)
##
## Derives input permission from `GameStateMachine.get_current_state()`.
## States in INPUT_BLOCKED_STATES (workout-active gameplay) → input dropped.
## Full implementation owned by #33 AttentionBudget epic.
class_name AttentionBudgetPolicy extends IInputPolicy


## States that block input per Pillar 2 (Frictionless Companion).
## When in these states, the gym session is the user's focus — game input
## would steal attention from the workout.
const INPUT_BLOCKED_STATES: Array[int] = [
	GameStateMachine.GameState.WORKOUT_ACTIVE,
	GameStateMachine.GameState.COMBAT_ACTIVE,
	GameStateMachine.GameState.BOSS_ENCOUNTER,
]


func is_input_permitted() -> bool:
	return not (GameStateMachine.get_current_state() in INPUT_BLOCKED_STATES)
