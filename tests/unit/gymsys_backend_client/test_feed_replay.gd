## GymSysBackendClient (#2) — Option B feed→signal replay core (ADR-0002).
##
## Tests `_process_feed`: a GYM `/api/game/feed` response (completed workouts) is replayed as the
## locked signal stream WST consumes (workout_started → set_logged×N → workout_completed) and the
## differential cursor advances. SUT is the autoload SCRIPT (no class_name → preload, fresh
## instance per test — never the live autoload, to avoid cross-test pollution).
extends GutTest

const SUT := preload("res://src/autoload/gym_sys_backend_client.gd")

var _c: Node


func before_each() -> void:
	_c = SUT.new()
	add_child_autofree(_c)
	watch_signals(_c)


func test_completed_workout_replayed_as_signal_burst() -> void:
	var feed := {
		"cursor": 5000, "count": 1,
		"workouts": [{
			"id": "w1", "date": "2026-06-13", "saved_at": 5000,
			"exercises": [
				{"exercise_id": "bench_press", "sets": [{"weight": 60.0, "reps": 8}, {"weight": 62.5, "reps": 8}]},
				{"exercise_id": "squat", "sets": [{"weight": 100.0, "reps": 5}]},
			],
		}],
	}
	_c._process_feed(feed)
	assert_signal_emit_count(_c, "workout_started", 1, "one workout_started per workout")
	assert_signal_emit_count(_c, "set_logged", 3, "one set_logged per set across all exercises")
	assert_signal_emit_count(_c, "workout_completed", 1, "one workout_completed per workout")
	assert_eq(_c.get_cursor(), 5000, "cursor advances to server high-water mark")


func test_set_logged_carries_exercise_reps_weight() -> void:
	var feed := {"cursor": 100, "workouts": [{
		"saved_at": 100, "exercises": [{"exercise_id": "deadlift", "sets": [{"weight": 140.0, "reps": 3}]}],
	}]}
	_c._process_feed(feed)
	assert_signal_emitted_with_parameters(_c, "set_logged", [&"deadlift", 3, 140.0], 0)


func test_workout_completed_carries_saved_at() -> void:
	var feed := {"cursor": 7777, "workouts": [{"saved_at": 7777, "exercises": []}]}
	_c._process_feed(feed)
	assert_signal_emitted_with_parameters(_c, "workout_completed", [7777], 0)


func test_empty_feed_emits_nothing_and_keeps_cursor() -> void:
	_c._process_feed({"cursor": 300, "workouts": []})
	assert_signal_emit_count(_c, "workout_started", 0)
	assert_signal_emit_count(_c, "set_logged", 0)
	assert_eq(_c.get_cursor(), 300, "empty feed still adopts server cursor")


func test_multiple_workouts_each_replayed() -> void:
	var feed := {"cursor": 2, "workouts": [
		{"saved_at": 1, "exercises": [{"exercise_id": "squat", "sets": [{"weight": 100.0, "reps": 5}]}]},
		{"saved_at": 2, "exercises": [{"exercise_id": "bench_press", "sets": [{"weight": 60.0, "reps": 8}]}]},
	]}
	_c._process_feed(feed)
	assert_signal_emit_count(_c, "workout_started", 2)
	assert_signal_emit_count(_c, "workout_completed", 2)
	assert_signal_emit_count(_c, "set_logged", 2)
	assert_eq(_c.get_cursor(), 2)


func test_malformed_entries_skipped_no_crash() -> void:
	# non-dict workout / exercise / set entries must be skipped, not crash
	var feed := {"cursor": 9, "workouts": [
		"garbage",
		{"saved_at": 9, "exercises": ["junk", {"exercise_id": "lunge", "sets": ["x", {"weight": 0.0, "reps": 10}]}]},
	]}
	_c._process_feed(feed)
	assert_signal_emit_count(_c, "workout_started", 1, "only the one valid dict workout replays")
	assert_signal_emit_count(_c, "set_logged", 1, "only the one valid dict set replays")
	assert_eq(_c.get_cursor(), 9)
