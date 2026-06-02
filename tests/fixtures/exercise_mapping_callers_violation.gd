# FIXTURE (not a test) — for tests/unit/ci/test_exercise_mapping_caller_ban.gd.
# Contains exactly ONE forbidden ExerciseClassMapping mutation/private-access that
# check_exercise_mapping_callers.gd must flag. Lives in tests/fixtures/ (not scanned by the
# real lint, which targets src/), and is read as TEXT by the lint unit test.
extends Node


func _illegal_mutation() -> void:
	# VIOLATION: external code calling the private test factory on the closed singleton.
	ExerciseClassMapping._create_test_registry([])
