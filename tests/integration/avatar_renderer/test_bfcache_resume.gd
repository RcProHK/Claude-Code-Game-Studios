extends GutTest
## Story 010: Formula 5 bfcache suspend/resume. Injected monotonic clock + a spy
## AnimatedSprite2D double. Covers AC-11 (pause() NOT stop() — the CR-8 hallucination
## regression guard), exact-frame restore (EC-SUS-1), long/negative-delta reset
## (EC-SUS-2 / AC-18), and mid-cast suspend (EC-SUS-3).
## See production/epics/avatar-renderer/story-010-*.

const AvatarRendererScript := preload("res://src/autoload/avatar_renderer.gd")


class FakeClock:
	extends RefCounted
	var ms: int = 0
	func now_ms() -> int:
		return ms


class SpySprite:
	extends Node
	var calls: Array = []
	var frame: int = 0
	var frame_progress: float = 0.0
	func pause() -> void:
		calls.append("pause")
	func stop() -> void:
		calls.append("stop")
	func play(anim = &"") -> void:
		calls.append("play:" + str(anim))
	func get_frame() -> int:
		return frame
	func set_frame_and_progress(f: int, p: float) -> void:
		calls.append("set_frame_and_progress")
		frame = f
		frame_progress = p


func _renderer():
	var r = AvatarRendererScript.new()
	r._gsm = GameStateMachine
	r._stat = StatSystem
	r._ability = AbilitySystem
	r._persistence = PersistenceLayer
	r._config = load("res://assets/data/avatar_evolution_config.tres")
	r._posture_config = load("res://assets/data/posture_config.tres")
	r._clock = FakeClock.new()
	r._ready_complete = true
	r._first_posture_applied = true
	return r


func test_ac11_suspend_pauses_not_stops_then_restores_exact_frame() -> void:
	var r = _renderer()
	var sprite = SpySprite.new()
	sprite.frame = 7
	sprite.frame_progress = 0.5
	r.register_sprite(sprite)
	r._clock.ms = 1000
	r._on_gsm_state_changed(GameStateMachine.GameState.IDLE, GameStateMachine.GameState.COMBAT_ACTIVE, {})
	# Suspend.
	r._clock.ms = 2000
	r._on_gsm_state_changed(GameStateMachine.GameState.COMBAT_ACTIVE, GameStateMachine.GameState.SUSPENDED, {})
	assert_true(r._suspended, "suspended flagged")
	assert_true("pause" in sprite.calls, "pause() called on suspend")
	assert_false("stop" in sprite.calls, "stop() NOT called (CR-8 hallucination fix)")
	# Resume within 30s -> RESTORE exact frame.
	r._clock.ms = 2000 + 5000
	r._on_gsm_state_changed(GameStateMachine.GameState.SUSPENDED, GameStateMachine.GameState.COMBAT_ACTIVE, {})
	assert_false(r._suspended, "resumed")
	assert_true("set_frame_and_progress" in sprite.calls, "exact frame restored (EC-SUS-1)")
	r.free()
	sprite.free()


func test_ec_sus2_long_suspend_resets_to_idle() -> void:
	var r = _renderer()
	var sprite = SpySprite.new()
	r.register_sprite(sprite)
	r._clock.ms = 1000
	r._on_gsm_state_changed(GameStateMachine.GameState.IDLE, GameStateMachine.GameState.COMBAT_ACTIVE, {})
	r._clock.ms = 2000
	r._on_gsm_state_changed(GameStateMachine.GameState.COMBAT_ACTIVE, GameStateMachine.GameState.SUSPENDED, {})
	# Resume after 31s (> 30s threshold) -> RESET to IDLE + re-derive.
	r._clock.ms = 2000 + 31000
	r._on_gsm_state_changed(GameStateMachine.GameState.SUSPENDED, GameStateMachine.GameState.IDLE, {})
	assert_eq(r.get_animation_state(), &"IDLE", "long suspend resets to IDLE (EC-SUS-2)")
	assert_false("set_frame_and_progress" in sprite.calls, "no frame restore on reset")
	r.free()
	sprite.free()


func test_ec_sus_negative_delta_resets_rederive() -> void:
	var r = _renderer()
	var sprite = SpySprite.new()
	r.register_sprite(sprite)
	r._clock.ms = 10000
	r._on_gsm_state_changed(GameStateMachine.GameState.IDLE, GameStateMachine.GameState.COMBAT_ACTIVE, {})
	r._clock.ms = 20000
	r._on_gsm_state_changed(GameStateMachine.GameState.COMBAT_ACTIVE, GameStateMachine.GameState.SUSPENDED, {})
	# NTP anomaly: resume clock earlier than suspend -> negative delta -> reset.
	r._clock.ms = 15000
	r._on_gsm_state_changed(GameStateMachine.GameState.SUSPENDED, GameStateMachine.GameState.IDLE, {})
	assert_eq(r.get_animation_state(), &"IDLE", "negative delta -> RESET (AC-18)")
	assert_false("set_frame_and_progress" in sprite.calls, "no restore on anomaly")
	r.free()
	sprite.free()


func test_ec_sus3_midcast_suspend_synthesizes_finish() -> void:
	var r = _renderer()
	var sprite = SpySprite.new()
	r.register_sprite(sprite)
	r._clock.ms = 1000
	r._on_ability_cast(&"cast_a", null, null)
	assert_eq(r.get_animation_state(), &"CAST", "casting")
	# Suspend mid-cast.
	r._clock.ms = 1100
	r._on_gsm_state_changed(GameStateMachine.GameState.WORKOUT_ACTIVE, GameStateMachine.GameState.SUSPENDED, {})
	assert_true("pause" in sprite.calls, "pause() on suspend even mid-cast")
	# Resume quickly: never restore a mid-cast frame; synthesize animation_finished.
	r._clock.ms = 1200
	r._on_gsm_state_changed(GameStateMachine.GameState.SUSPENDED, GameStateMachine.GameState.IDLE, {})
	assert_false(r._cast_active, "mid-cast suspend synthesizes finish (EC-SUS-3)")
	assert_false("set_frame_and_progress" in sprite.calls, "mid-cast frame NOT restored")
	r.free()
	sprite.free()
