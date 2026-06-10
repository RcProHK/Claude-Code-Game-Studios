extends GutTest
## Story 007: cast timing + 1-deep queue (CR-10). Injected monotonic clock for
## determinism. Covers AC-07 (queue depth 1, drop oldest), cast completion releasing the
## queue, EC-SIG-2 (pre-ready drop with telemetry), and the INV-2 timing invariants.
## See production/epics/avatar-renderer/story-007-*.

const AvatarRendererScript := preload("res://src/autoload/avatar_renderer.gd")


class FakeClock:
	extends RefCounted
	var ms: int = 0
	func now_ms() -> int:
		return ms


func _renderer():
	var r = AvatarRendererScript.new()
	r._gsm = GameStateMachine
	r._stat = StatSystem
	r._ability = AbilitySystem
	r._clock = FakeClock.new()
	r._ready_complete = true
	return r


func test_ac07_queue_depth_one_drops_oldest() -> void:
	var r = _renderer()
	var clk = r._clock
	clk.ms = 0
	r._on_ability_cast(&"cast_a", null, null)
	assert_eq(r.get_animation_state(), &"CAST", "first cast starts immediately (onset <=100ms)")
	assert_true(r._cast_active, "cast active")
	# 2nd cast within the hard window -> queued (depth 1).
	clk.ms = 100
	r._on_ability_cast(&"cast_b", null, null)
	assert_eq(r._cast_queue.size(), 1, "2nd cast queued at depth 1")
	# 3rd cast -> drop the oldest queued (most-recent intent wins) + telemetry.
	watch_signals(r)
	clk.ms = 150
	r._on_ability_cast(&"cast_c", null, null)
	assert_eq(r._cast_queue.size(), 1, "queue stays depth 1")
	assert_eq(r._cast_queue[0], &"cast_c", "most-recent intent wins (cast_c)")
	assert_signal_emitted(r, "avatar_cast_dropped", "dropped cast emits telemetry")
	r.free()


func test_cast_completes_and_releases_queue() -> void:
	var r = _renderer()
	var clk = r._clock
	clk.ms = 0
	r._on_ability_cast(&"cast_a", null, null)
	clk.ms = 100
	r._on_ability_cast(&"cast_b", null, null)  # queued
	# Advance past CAST_TOTAL_MS (500): cast_a finishes, cast_b releases.
	clk.ms = 600
	r._tick_cast(600)
	assert_true(r._cast_active, "queued cast_b is now active")
	assert_eq(r._cast_queue.size(), 0, "queue drained")
	assert_eq(r.get_animation_state(), &"CAST", "still casting the released one")
	# Finish cast_b with an empty queue -> back to IDLE.
	clk.ms = 1200
	r._tick_cast(1200)
	assert_false(r._cast_active, "cast machine idle")
	assert_eq(r.get_animation_state(), &"IDLE", "returns to IDLE after the cast")
	r.free()


func test_ec_sig2_cast_before_ready_dropped_with_telemetry() -> void:
	var r = _renderer()
	r._ready_complete = false
	watch_signals(r)
	r._on_ability_cast(&"cast_early", null, null)
	assert_false(r._cast_active, "no cast started before boot completes")
	assert_signal_emitted(r, "avatar_cast_dropped", "EC-SIG-2 pre-ready cast dropped with telemetry")
	r.free()


func test_inv2_timing_invariants_hold() -> void:
	# INV-2 (N-2 pin): hard window < total, and the posture cooldown covers a full cast.
	assert_lt(AvatarRendererScript.CAST_HARD_WINDOW_MS, AvatarRendererScript.CAST_TOTAL_MS,
		"INV-2: CAST_HARD_WINDOW_MS < CAST_TOTAL_MS")
	assert_true(AvatarRendererScript.POSTURE_HYSTERESIS_SECONDS * 1000 >= AvatarRendererScript.CAST_TOTAL_MS,
		"INV-2: POSTURE_HYSTERESIS_SECONDS*1000 >= CAST_TOTAL_MS")
	var r = _renderer()
	r._validate_knobs()  # must not trip on the shipped constants
	r.free()
