extends GutTest
## Story 012: milestone emit / defer / buffer at the autoload level (CR-5 / CR-15 / EC-MILE-5).
## Drives _maybe_emit_milestone directly through the returning-account cadence branch
## (last_milestone_emit_unix > 0, so the epoch-zero first-boot guard is bypassed) with a
## controllable FakeGSM workout-window + MockPersistence. Covers AC-14 (emit on promotion
## past cadence outside the workout window), AC-17 (defer in-workout via _pending_milestone,
## CR-15), AC-21 (buffer when #29 has no listener yet, EC-MILE-5), and EC-MILE-1 (cadence
## unmet = suppress-only, no defer/absorb).
## See production/epics/avatar-renderer/story-012-*.

const AvatarRendererScript := preload("res://src/autoload/avatar_renderer.gd")
const PAST_CADENCE_SECONDS := 700000  # > MILESTONE_CADENCE_SECONDS (604800)


class FakeGSM:
	extends RefCounted
	enum GameState {BOOTING, IDLE, WORKOUT_ACTIVE, REST_PERIOD, COMBAT_ACTIVE, BOSS_ENCOUNTER, SUSPENDED}
	var state: int = GameState.IDLE
	func get_current_state() -> int:
		return state


class MockPersistence:
	extends RefCounted
	var store: Dictionary = {}
	func read(key: String):
		return store.get(key, null)
	func write(key: String, value, _flush: bool = false) -> bool:
		store[key] = value.duplicate(true) if value is Dictionary else value
		return true


func _renderer(gsm) -> Node:
	var r = AvatarRendererScript.new()
	r._gsm = gsm
	r._persistence = MockPersistence.new()
	r._ready_complete = true
	return r


## Arrange a clean promotion (tier 1 over last-emitted 0) that already cleared the weekly
## cadence, leaving only gate_c (workout window) and the listener check to vary per test.
func _arm_promotion(r: Node) -> void:
	r._visual_state.evolution_tier = 1
	r._last_emitted_tier = 0
	r._last_milestone_emit_unix = int(Time.get_unix_time_from_system()) - PAST_CADENCE_SECONDS


func test_ac14_milestone_emits_on_promotion_past_cadence() -> void:
	var gsm = FakeGSM.new()
	gsm.state = FakeGSM.GameState.IDLE  # not in the workout window
	var r := _renderer(gsm)
	_arm_promotion(r)
	watch_signals(r)  # a connected listener -> emit (not buffer)
	r._maybe_emit_milestone(80.0, 3, 2)
	assert_signal_emitted(r, "avatar_evolution_milestone",
		"AC-14: promotion past cadence outside workout emits the ceremony trigger")
	assert_eq(r._last_emitted_tier, 1, "AC-14: last_emitted_tier advances to the emitted tier")
	assert_false(r._pending_milestone, "AC-14: nothing left pending after a clean emit")
	r.free()


func test_ac17_milestone_defers_in_workout_window() -> void:
	var gsm = FakeGSM.new()
	gsm.state = FakeGSM.GameState.WORKOUT_ACTIVE  # CR-15: never interrupt a set
	var r := _renderer(gsm)
	_arm_promotion(r)
	watch_signals(r)
	r._maybe_emit_milestone(80.0, 3, 2)
	assert_signal_not_emitted(r, "avatar_evolution_milestone",
		"AC-17: a satisfied two-gate inside the workout window does NOT emit")
	assert_true(r._pending_milestone, "AC-17: it defers via the persisted _pending_milestone flag")
	assert_eq(r._last_emitted_tier, 0, "AC-17: last_emitted_tier unchanged while deferred")
	r.free()


func test_ac21_milestone_buffers_when_no_listener() -> void:
	var gsm = FakeGSM.new()
	gsm.state = FakeGSM.GameState.IDLE
	var r := _renderer(gsm)
	_arm_promotion(r)
	# No watch_signals / no connection -> #29 is not listening yet.
	r._maybe_emit_milestone(80.0, 3, 2)
	assert_eq(r._pending_emit_queue.size(), 1, "AC-21/EC-MILE-5: a listener-less milestone is buffered, never dropped")
	assert_true(r._pending_milestone, "AC-21: pending flag set so it re-surfaces next boot")
	r.free()


func test_ec_mile1_cadence_unmet_suppresses_without_defer() -> void:
	var gsm = FakeGSM.new()
	gsm.state = FakeGSM.GameState.IDLE
	var r := _renderer(gsm)
	r._visual_state.evolution_tier = 1
	r._last_emitted_tier = 0
	r._last_milestone_emit_unix = int(Time.get_unix_time_from_system()) - 100  # cadence NOT met
	watch_signals(r)
	r._maybe_emit_milestone(80.0, 3, 2)
	assert_signal_not_emitted(r, "avatar_evolution_milestone", "EC-MILE-1: cadence unmet -> no emit")
	assert_false(r._pending_milestone, "EC-MILE-1: suppress-only — NOT deferred, no absorb")
	assert_eq(r._last_emitted_tier, 0, "EC-MILE-1: last_emitted_tier left untouched")
	r.free()


func test_buffer_caps_at_three() -> void:
	# EC-MILE-5: the listener-less buffer is bounded (MIRROR_MOMENT_PENDING_BUFFER = 3).
	var gsm = FakeGSM.new()
	gsm.state = FakeGSM.GameState.IDLE
	var r := _renderer(gsm)
	for tier in [1, 2, 3, 3, 3]:
		r._visual_state.evolution_tier = tier
		r._last_emitted_tier = tier - 1 if tier > 0 else 0
		r._last_milestone_emit_unix = int(Time.get_unix_time_from_system()) - PAST_CADENCE_SECONDS
		r._maybe_emit_milestone(80.0, 3, 2)
	assert_eq(r._pending_emit_queue.size(), 3, "EC-MILE-5: buffer is capped at MIRROR_MOMENT_PENDING_BUFFER")
	r.free()
