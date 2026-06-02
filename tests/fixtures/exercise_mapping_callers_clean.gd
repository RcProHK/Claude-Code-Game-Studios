# FIXTURE (not a test) — for tests/unit/ci/test_exercise_mapping_caller_ban.gd.
# Read-only usage of the closed ExerciseClassMapping API plus a commented-out ban: the lint
# must flag ZERO of these. Read as TEXT by the lint unit test.
extends Node


func _legal_reads() -> void:
	# Read-only public API — all permitted (no leading underscore, no assignment).
	var c: int = ExerciseClassMapping.get_class_for_exercise("bench_press")
	var p: int = ExerciseClassMapping.get_class_for_movement_pattern(0)
	var known: bool = ExerciseClassMapping.is_known_exercise("bench_press")
	# Comparisons (==) are reads, not writes — must NOT be flagged.
	if ExerciseClassMapping.get_class_for_movement_pattern(0) == 0:
		pass
	# Commented ban must NOT be flagged:
	# ExerciseClassMapping._create_test_registry([])
	print(c, p, known)
