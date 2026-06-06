extends GutTest
## Story 011 — Rule 6.7 emit gate + one-slot pending-emit buffer + GSM silence.
## Covers AC-30: the gate is LOAD-BEARING on the δ==0 short-circuit path
## (the #11 suspended check in 6.3 never runs for a capped player).

const PrDetectionScript := preload("res://src/autoload/pr_detection.gd")
const SUSPENDED: int = 8
const IDLE: int = 2


class MockStat:
	extends RefCounted
	var stat_value: float = 999.0  # capped → δ==0 short-circuit path
	var calls: int = 0

	func get_stat(_stat_id: StringName) -> float:
		return stat_value

	func apply_stat_delta(_s: StringName, _src: int, _d: float) -> bool:
		calls += 1
		return true


class MockClassMapping:
	extends RefCounted
	func get_class_for_exercise(_exercise_id: StringName) -> int:
		return 0


class MockGSM:
	extends RefCounted
	var state: int = IDLE

	func get_current_state() -> int:
		return state


var _sut: Node
var _gsm: MockGSM
var _signals: Array = []


func before_each() -> void:
	_gsm = MockGSM.new()
	_sut = PrDetectionScript.new()
	_sut._persistence = MockPersistenceLayer.new()
	_sut._stat_system = MockStat.new()
	_sut._class_mapping = MockClassMapping.new()
	_sut._gsm = _gsm
	add_child_autofree(_sut)
	_sut.pr_breakthrough.connect(func(sid: StringName, m: float) -> void:
		_signals.append([sid, m]))
	_signals = []


func test_suspended_holds_emit_then_flushes_exactly_once_on_leave() -> void:
	# Arrange — capped player (δ==0 short-circuit: gate is the ONLY defence)
	# + GSM SUSPENDED at PR time.
	_sut._pr_state.baselines["bench_press"] = 70.0
	_gsm.state = SUSPENDED

	# Act 1 — PR pipeline reaches 6.7.
	_sut._on_set_logged("bench_press", 5, 65.0)

	# Assert 1 — held in the one-slot buffer; the rest of the chain stands.
	assert_eq(_signals.size(), 0, "AC-30: no emit while SUSPENDED")
	assert_false(_sut._pending_emit.is_empty())
	assert_almost_eq(_sut._pr_state.baselines["bench_press"], 75.833, 0.001,
		"the PR itself committed — only the emit is gated")

	# Act 2 — leave SUSPENDED.
	_gsm.state = IDLE
	_sut._on_gsm_state_changed(SUSPENDED, IDLE, null)

	# Assert 2 — flushed exactly once; buffer empty; repeated transitions emit nothing.
	assert_eq(_signals.size(), 1, "AC-30: flush emits exactly once")
	assert_almost_eq(_signals[0][1], 0.0833, 0.001)
	assert_true(_sut._pending_emit.is_empty())
	_sut._on_gsm_state_changed(IDLE, IDLE, null)
	assert_eq(_signals.size(), 1, "no re-emit on later transitions")


func test_suspended_sliver_second_pr_keeps_latest() -> void:
	_sut._pr_state.baselines["bench_press"] = 70.0
	_gsm.state = SUSPENDED
	_sut._on_set_logged("bench_press", 5, 65.0)   # m ≈ 0.0833 buffered
	_sut._on_set_logged("bench_press", 2, 75.0)   # m ≈ 0.0550 — keep-LATEST overwrite
	_gsm.state = IDLE
	_sut._on_gsm_state_changed(SUSPENDED, IDLE, null)
	assert_eq(_signals.size(), 1)
	assert_almost_eq(_signals[0][1], 0.0550, 0.001,
		"keep-latest overwrite in the SUSPENDED sliver (self-healing: #12 is threshold-based)")


func test_gsm_silence_outside_the_flush() -> void:
	# State churn with an empty buffer → zero active behaviour (telemetry-silent).
	_sut._on_gsm_state_changed(IDLE, SUSPENDED, null)
	_sut._on_gsm_state_changed(SUSPENDED, IDLE, null)
	assert_eq(_signals.size(), 0)
	assert_true(_sut._pending_emit.is_empty())


func test_normal_state_emits_directly() -> void:
	_sut._pr_state.baselines["bench_press"] = 70.0
	_gsm.state = IDLE
	_sut._on_set_logged("bench_press", 5, 65.0)
	assert_eq(_signals.size(), 1, "non-SUSPENDED states pass the gate untouched")
