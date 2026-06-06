extends GutTest
## Story 003 — pr.state envelope round-trip (AC-17) + persist-fail (AC-26).
## The round-trip is forced through JSON.stringify → JSON.parse_string — the
## exact #3 disk path — so JSON coercion (int→float, key stringification) is
## genuinely exercised (same-instance cache reads are a known phantom-pass trap).

const PrDetectionScript := preload("res://src/autoload/pr_detection.gd")


class FailingPersistence:
	extends RefCounted
	var reads: int = 0

	func read(_key: String) -> Variant:
		reads += 1
		return null

	func write(_key: String, _value: Variant, _flush: bool = false) -> bool:
		return false


func _populated_state() -> PrState:
	var s := PrState.new()
	s.baselines = {"bench_press": 75.833, "barbell_squat": 120.0}
	s.pending = {"bench_press": {
		"e1rm_raw": 94.5, "weight": 90.0, "reps": 3, "opened_seq": 4}}
	s.candidates = {"bent_over_row": 60.0}
	s.workout_seq = 5
	s.lifetime_count = 12
	s.lifetime_pr_score = 1.0833
	return s


# --- AC-17: full round-trip through the real JSON disk path --------------------

func test_envelope_roundtrip_through_json_restores_all_fields() -> void:
	# Arrange — serialize through the exact #3 path (stringify → parse).
	var original := _populated_state()
	var json_text: String = JSON.stringify(original.to_dict())
	var reloaded_raw: Variant = JSON.parse_string(json_text)
	assert_true(reloaded_raw is Dictionary, "JSON path must yield a Dictionary")

	# Act
	var restored: PrState = PrState.from_dict(reloaded_raw)

	# Assert — typed restoration (JSON floats re-coerced to int where typed).
	assert_almost_eq(restored.baselines["bench_press"], 75.833, 0.0001)
	assert_almost_eq(restored.baselines["barbell_squat"], 120.0, 0.0001)
	assert_eq(restored.pending["bench_press"]["reps"], 3, "reps must be int after JSON")
	assert_eq(restored.pending["bench_press"]["opened_seq"], 4)
	assert_almost_eq(restored.pending["bench_press"]["e1rm_raw"], 94.5, 0.0001)
	assert_almost_eq(restored.candidates["bent_over_row"], 60.0, 0.0001)
	assert_eq(restored.workout_seq, 5, "workout_seq must be int after JSON")
	assert_eq(restored.lifetime_count, 12)
	assert_almost_eq(restored.lifetime_pr_score, 1.0833, 0.0001)


func test_boot_restores_envelope_and_discards_stale_candidates() -> void:
	# Arrange — boot from a mock whose store carries a JSON-roundtripped envelope
	# with leftover candidates (mid-workout crash scenario — Rule 8a).
	var mock := MockPersistenceLayer.new()
	var dict: Variant = JSON.parse_string(JSON.stringify(_populated_state().to_dict()))
	mock.write("pr.state", dict)
	var sut: Node = PrDetectionScript.new()
	sut._persistence = mock

	# Act
	add_child_autofree(sut)

	# Assert — baselines/counters restored; candidates discarded (window reopens).
	assert_almost_eq(sut._pr_state.baselines["bench_press"], 75.833, 0.0001)
	assert_eq(sut._pr_state.lifetime_count, 12)
	assert_true(sut._pr_state.candidates.is_empty(),
		"stale candidates must be discarded at boot (Rule 8a — never fake a PR)")


func test_corrupt_envelope_degrades_to_fresh_state() -> void:
	var mock := MockPersistenceLayer.new()
	mock.write("pr.state", "garbage-not-a-dict")
	var sut: Node = PrDetectionScript.new()
	sut._persistence = mock
	add_child_autofree(sut)
	assert_true(sut._pr_state.baselines.is_empty(),
		"corrupt envelope → fresh state (INV-PR-1 keeps it safe)")
	assert_true(sut.is_ready(), "corrupt envelope must not break boot")


# --- AC-26: persist-fail keeps in-memory state + telemetry ----------------------

func test_persist_fail_keeps_memory_and_emits_telemetry() -> void:
	# Arrange
	var failing := FailingPersistence.new()
	var sut: Node = PrDetectionScript.new()
	sut._persistence = failing
	add_child_autofree(sut)
	sut._pr_state.baselines["bench_press"] = 70.0

	# Act
	var ok: bool = sut._persist_state(true)

	# Assert
	assert_false(ok)
	assert_almost_eq(sut._pr_state.baselines["bench_press"], 70.0, 0.0001,
		"in-memory state must survive a failed write (AC-26)")
	var events: Array = sut.get_telemetry().map(func(e: Dictionary) -> String:
		return e["event"])
	assert_has(events, "pr.persist_failed")


# --- Rule 8 lifecycle: workout_seq increments on #2 workout_started -------------

func test_workout_seq_increments_on_workout_started() -> void:
	var mock := MockPersistenceLayer.new()
	var sut: Node = PrDetectionScript.new()
	sut._persistence = mock
	add_child_autofree(sut)
	assert_eq(sut._pr_state.workout_seq, 0)
	sut._on_workout_started()
	sut._on_workout_started()
	assert_eq(sut._pr_state.workout_seq, 2)
