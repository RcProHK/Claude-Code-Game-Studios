extends GutTest
## Story 013: weekly micro-evolution (CR-5b / Formula 3b). Drives _maybe_emit_micro with a
## controllable FakeGSM workout-window + MockPersistence + the real StatSystem (for the
## _stat_total_now() sync-read). Covers AC-15 (emit on weekly cadence + positive 7-day stat
## delta outside the workout window) plus the three suppression branches (in-workout, no
## growth, within-cadence) and the reduced-motion accessibility rule (micro recorded, visual
## tween suppressed). See production/epics/avatar-renderer/story-013-*.

const AvatarRendererScript := preload("res://src/autoload/avatar_renderer.gd")
const PAST_CADENCE_SECONDS := 700000  # > MICRO_EVOLUTION_CADENCE_SECONDS (604800)


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
	r._stat = StatSystem  # real autoload: provides StatId + get_stat for _stat_total_now()
	r._persistence = MockPersistence.new()
	r._ready_complete = true
	return r


func _arm_due(r: Node) -> void:
	r._last_micro_emit_unix = int(Time.get_unix_time_from_system()) - PAST_CADENCE_SECONDS


func test_ac15_micro_emits_on_weekly_stat_growth() -> void:
	var gsm = FakeGSM.new()
	gsm.state = FakeGSM.GameState.IDLE
	var r := _renderer(gsm)
	_arm_due(r)
	watch_signals(r)
	r._maybe_emit_micro(5.0)  # positive 7-day delta
	assert_signal_emitted(r, "avatar_micro_evolution",
		"AC-15: weekly cadence + positive delta outside workout emits the shader-only micro")
	r.free()


func test_micro_suppressed_in_workout_window() -> void:
	var gsm = FakeGSM.new()
	gsm.state = FakeGSM.GameState.WORKOUT_ACTIVE
	var r := _renderer(gsm)
	_arm_due(r)
	watch_signals(r)
	r._maybe_emit_micro(5.0)
	assert_signal_not_emitted(r, "avatar_micro_evolution", "Formula 3b: in-workout suppresses the micro")
	r.free()


func test_micro_suppressed_without_growth() -> void:
	var gsm = FakeGSM.new()
	gsm.state = FakeGSM.GameState.IDLE
	var r := _renderer(gsm)
	_arm_due(r)
	watch_signals(r)
	r._maybe_emit_micro(0.0)  # no growth
	assert_signal_not_emitted(r, "avatar_micro_evolution", "Formula 3b: non-positive delta -> no micro")
	r.free()


func test_micro_suppressed_within_cadence() -> void:
	var gsm = FakeGSM.new()
	gsm.state = FakeGSM.GameState.IDLE
	var r := _renderer(gsm)
	r._last_micro_emit_unix = int(Time.get_unix_time_from_system()) - 100  # within the weekly window
	watch_signals(r)
	r._maybe_emit_micro(5.0)
	assert_signal_not_emitted(r, "avatar_micro_evolution", "Formula 3b: within weekly cadence -> no micro")
	r.free()


func test_reduced_motion_records_micro_without_visual_tween() -> void:
	# CR-5b accessibility: reduced-motion suppresses the visual tween, but the micro is still
	# recorded (information is never carried by motion alone).
	var gsm = FakeGSM.new()
	gsm.state = FakeGSM.GameState.IDLE
	var r := _renderer(gsm)
	r._reduced_motion = true
	_arm_due(r)
	watch_signals(r)
	r._maybe_emit_micro(5.0)
	assert_signal_emitted(r, "avatar_micro_evolution", "CR-5b: micro is recorded even under reduced-motion")
	assert_eq(r._micro_palette_shift, 0.0, "CR-5b: reduced-motion applies no palette tween")
	assert_eq(r._micro_outline_intensity, 0.0, "CR-5b: reduced-motion applies no outline tween")
	r.free()
