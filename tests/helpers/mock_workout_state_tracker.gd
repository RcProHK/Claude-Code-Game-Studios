# Test helper — mock WorkoutStateTracker (Story 020).
# DI-compatible stub matching the WST queries EnemyDirector reads. Plain public vars + getters,
# no logic. Used by Story 011 (wave scheduler) + Story 016 (boss anchor) + deferred AC tests.
extends RefCounted

## Configurable AbilityClass ordinal (0=STRIKE/1=CONTROL/2=MOBILITY/3=UNKNOWN).
var dominant_ability_class: int = 3  # UNKNOWN — mirrors production default

## Configurable set_progress in [0,1].
var set_progress: float = 0.0

## Configurable boss-trigger inputs (Story 016).
var final_set: bool = false
var planned_total_sets: int = 0
var reps_completed: int = 0
var planned_reps: int = 0


func get_dominant_ability_class() -> int:
	return dominant_ability_class


func get_set_progress() -> float:
	return set_progress


func get_current_set_progress() -> float:
	return set_progress


func is_final_set() -> bool:
	return final_set


func get_planned_total_sets() -> int:
	return planned_total_sets


func get_reps_completed() -> int:
	return reps_completed


func get_planned_reps() -> int:
	return planned_reps


## Self-check (Story 020 QA).
static func _static_check() -> bool:
	var m = (load("res://tests/helpers/mock_workout_state_tracker.gd") as GDScript).new()
	m.dominant_ability_class = 2
	m.set_progress = 0.85
	assert(m.get_dominant_ability_class() == 2, "mock WST: dominant class")
	assert(is_equal_approx(m.get_set_progress(), 0.85), "mock WST: set_progress")
	return true
