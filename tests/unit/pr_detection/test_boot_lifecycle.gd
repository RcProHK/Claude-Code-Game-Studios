extends GutTest
## Story 002 — PrDetection autoload skeleton boot lifecycle (AC-27).
## Asserts: load pr.state BEFORE subscribing #2; READY synchronous by _ready end;
## reverse-wire direction (pr_breakthrough → injected consumer handlers).

const PrDetectionScript := preload("res://src/autoload/pr_detection.gd")


## Mock #2 source — carries the three GDD-contract signals.
class MockGymSys:
	extends Node
	signal set_logged(exercise_id: String, reps: int, weight: float)
	signal workout_started()
	signal workout_completed(completed_at: int)


## Persistence mock that records, AT READ TIME, whether the #2 source already
## had subscribers — proving the load-before-subscribe order (AC-27).
class OrderProbePersistence:
	extends RefCounted
	var source: Node
	var read_calls: int = 0
	var source_already_subscribed_at_read: bool = false

	func read(_key: String) -> Variant:
		read_calls += 1
		if source != null:
			source_already_subscribed_at_read = \
				not source.set_logged.get_connections().is_empty()
		return null

	func write(_key: String, _value: Variant, _flush: bool = false) -> bool:
		return true


var _sut: Node
var _source: MockGymSys
var _probe: OrderProbePersistence


func before_each() -> void:
	_source = MockGymSys.new()
	add_child_autofree(_source)
	_probe = OrderProbePersistence.new()
	_probe.source = _source
	_sut = PrDetectionScript.new()
	_sut._persistence = _probe
	_sut._gym_sys = _source


func test_ready_is_synchronous_and_loads_before_subscribe() -> void:
	add_child_autofree(_sut)
	# READY by the end of _ready — no frame was awaited.
	assert_true(_sut.is_ready(), "INITIALISING must not span frames (AC-27)")
	assert_eq(_probe.read_calls, 1, "pr.state must be read exactly once at boot")
	assert_false(_probe.source_already_subscribed_at_read,
		"load must happen BEFORE subscribing #2 (AC-27 order)")
	# After _ready the source IS subscribed.
	assert_false(_source.set_logged.get_connections().is_empty(),
		"set_logged must be subscribed by end of _ready")
	assert_false(_source.workout_started.get_connections().is_empty())
	assert_false(_source.workout_completed.get_connections().is_empty())


func test_reverse_wire_connects_injected_consumer_handlers() -> void:
	var received: Array = []
	_sut._ability_handler = func(stat_id: StringName, magnitude: float) -> void:
		received.append([stat_id, magnitude])
	add_child_autofree(_sut)
	_sut.pr_breakthrough.emit(&"str", 0.0833)
	assert_eq(received.size(), 1, "reverse-wired handler must receive the emit")
	assert_eq(received[0][0], &"str")


func test_boot_safe_with_stub_source_without_signals() -> void:
	# #2 shipped stub has no signals — has_signal guards must keep boot green.
	var bare_stub := Node.new()
	add_child_autofree(bare_stub)
	var sut2: Node = PrDetectionScript.new()
	sut2._persistence = _probe
	sut2._gym_sys = bare_stub
	add_child_autofree(sut2)
	assert_true(sut2.is_ready(), "stub source (no signals) must not break boot")
