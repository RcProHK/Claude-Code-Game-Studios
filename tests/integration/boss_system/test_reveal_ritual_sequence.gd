# BossRevealCoordinator Camera-leading reveal dispatch (Story 010: AC-07 / AC-07b).
extends GutTest


# One mock injected as all 4 seams; records every call in order with args.
class MockReveal extends RefCounted:
	var calls: Array = []
	func request_focal(target: Vector2, duration: float, zoom: float) -> void:
		calls.append({"m": "request_focal", "target": target, "duration": duration, "zoom": zoom})
	func shake(intensity: float, duration: float) -> void:
		calls.append({"m": "shake", "intensity": intensity, "duration": duration})
	func play(_preset: int, position: Vector2, mult: float) -> void:
		calls.append({"m": "play", "position": position, "mult": mult})
	func play_sfx(id: StringName) -> void:
		calls.append({"m": "play_sfx", "id": id})


func _coordinator(mock: MockReveal) -> BossRevealCoordinator:
	var c := BossRevealCoordinator.new()
	c._camera = mock
	c._screen_effects = mock
	c._particles = mock
	c._audio = mock
	add_child_autofree(c)  # in tree so dispatch_reveal can await a frame
	return c


# ---------------------------------------------------------------------------
# AC-07 — Camera LEADING order + cached spawn_pos + caller_mult
# ---------------------------------------------------------------------------

func test_ac07_camera_dispatched_first() -> void:
	var mock := MockReveal.new()
	var c := _coordinator(mock)
	await c.dispatch_reveal(Vector2(800, 300), 1.0, &"cue")
	assert_gt(mock.calls.size(), 0, "something dispatched")
	assert_eq(mock.calls[0]["m"], "request_focal", "AC-07: Camera.request_focal dispatched FIRST (frame 0)")


func test_ac07_shake_and_particles_after_camera() -> void:
	var mock := MockReveal.new()
	var c := _coordinator(mock)
	await c.dispatch_reveal(Vector2(800, 300), 1.0, &"cue")
	var methods: Array = mock.calls.map(func(d): return d["m"])
	var cam_idx: int = methods.find("request_focal")
	var shake_idx: int = methods.find("shake")
	var play_idx: int = methods.find("play")
	assert_true(shake_idx > cam_idx, "AC-07: shake dispatched AFTER camera (frame 1-2)")
	assert_true(play_idx > cam_idx, "AC-07: particles dispatched AFTER camera (frame 1-2)")


func test_ac07_camera_target_is_cached_spawn_pos() -> void:
	var mock := MockReveal.new()
	var c := _coordinator(mock)
	await c.dispatch_reveal(Vector2(800, 300), 1.0, &"cue")
	assert_eq(mock.calls[0]["target"], Vector2(800, 300),
		"AC-07: camera target === cached spawn_pos (not late global_position read)")


func test_ac07_caller_mult_scales_dispatch() -> void:
	var mock := MockReveal.new()
	var c := _coordinator(mock)
	await c.dispatch_reveal(Vector2(800, 300), 1.0, &"cue")
	# focal duration = 0.6 * 1.0; particle multiplier = 1.0
	assert_almost_eq(float(mock.calls[0]["duration"]), 0.6, 0.001, "AC-07: focal duration = 0.6 * ritual_mult")
	var play_call: Dictionary = mock.calls.filter(func(d): return d["m"] == "play")[0]
	assert_eq(play_call["mult"], 1.0, "AC-07: particle multiplier == ritual_mult")


func test_ac07_audio_sfx_dispatched() -> void:
	var mock := MockReveal.new()
	var c := _coordinator(mock)
	await c.dispatch_reveal(Vector2(800, 300), 1.0, &"boss_reveal")
	var sfx: Array = mock.calls.filter(func(d): return d["m"] == "play_sfx")
	assert_eq(sfx.size(), 1, "AudioManager.play_sfx dispatched once")
	assert_eq(sfx[0]["id"], &"boss_reveal", "audio_template_id forwarded")


# ---------------------------------------------------------------------------
# AC-07b — logical dispatch budget (injectable clock)
# ---------------------------------------------------------------------------

func test_ac07b_within_budget_passes() -> void:
	var mock := MockReveal.new()
	var c := _coordinator(mock)
	# MockClock: start 0, end 32ms (2 frames * 16ms) -> 32 <= 200 PASS.
	var seq := [0, 32]
	var i := [0]
	c._now_ms = func() -> int:
		var v: int = seq[i[0]]
		i[0] += 1
		return v
	await c.dispatch_reveal(Vector2(800, 300), 1.0, &"cue")
	assert_eq(c._last_dispatch_elapsed_ms, 32, "AC-07b: logical elapsed = 32ms")
	assert_true(c.dispatch_within_budget(), "AC-07b: 32ms <= 200ms budget -> PASS")


func test_ac07b_stall_exceeds_budget_fails() -> void:
	var mock := MockReveal.new()
	var c := _coordinator(mock)
	# MockClock: a 250ms single-frame stall -> 250 > 200 FAIL boundary.
	var seq := [0, 250]
	var i := [0]
	c._now_ms = func() -> int:
		var v: int = seq[i[0]]
		i[0] += 1
		return v
	await c.dispatch_reveal(Vector2(800, 300), 1.0, &"cue")
	assert_eq(c._last_dispatch_elapsed_ms, 250, "AC-07b: stalled elapsed = 250ms")
	assert_false(c.dispatch_within_budget(), "AC-07b: 250ms > 200ms budget -> FAIL (falsifiable gate)")
