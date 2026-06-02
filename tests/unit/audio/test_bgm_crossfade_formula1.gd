# AudioManager — #4 Story 005: BGM equal-power crossfade (Formula 1).
#
# Covers AC-04 (idempotent same-track no-op), AC-12 (equal-power gains), AC-18 (mid-crossfade
# latest-wins, no stacking), AC-21 (fade_sec=0 instant-swap, no NaN). Crossfade STATE is asserted
# (_active_crossfade_count / _crossfade_progress / _current_bgm_track / bgm_changed) — headless
# Tweens do not advance, so mid-tween player gains are never asserted (GDD design).
extends GutTest

const AM := preload("res://src/autoload/audio_manager.gd")


class MockGSM:
	func connect_for_initial_state(_c: Callable) -> void:
		pass

class MockPlatform:
	func is_web() -> bool:
		return false

class MockPersistence:
	func read(_key: String) -> Variant:
		return null
	func write(_key: String, _value: Variant, _flush: bool = false) -> bool:
		return true


func _boot(bgm_catalog: Variant) -> Node:
	var am := AM.new()
	am._gsm = MockGSM.new()
	am._platform_detect = MockPlatform.new()
	am._persistence = MockPersistence.new()
	if bgm_catalog != null:
		am._bgm_catalog = bgm_catalog
	add_child_autofree(am)
	return am


## Catalog with three known tracks (streams null — real audio is /asset-spec, Q8). Entries are
## non-empty so _lookup_bgm treats them as known.
func _cat() -> Dictionary:
	return {
		&"track_a": {"stream": null},
		&"track_b": {"stream": null},
		&"track_c": {"stream": null},
	}


# ── AC-12: equal-power gains (constant perceived loudness, no mid dip) ───────────

func test_equal_power_gains_constant_loudness() -> void:
	var am := AM.new()
	autofree(am)
	var g: Vector2 = am._equal_power_gains(0.5)
	assert_almost_eq(g.x, 0.70710678, 0.001, "out_gain at p=0.5 ≈ 0.707 (-3 dB)")
	assert_almost_eq(g.y, 0.70710678, 0.001, "in_gain at p=0.5 ≈ 0.707 (-3 dB)")
	assert_almost_eq(g.x * g.x + g.y * g.y, 1.0, 0.001, "equal-power: out² + in² == 1")
	assert_almost_eq(am._equal_power_gains(0.0).x, 1.0, 0.001, "p=0 → out at full gain")
	assert_almost_eq(am._equal_power_gains(1.0).y, 1.0, 0.001, "p=1 → in at full gain")


# ── AC-04: same track already playing → idempotent no-op (no re-emit) ───────────

func test_same_track_is_idempotent_no_reemit() -> void:
	var am := _boot(_cat())
	watch_signals(am)
	am.play_bgm(&"track_a", 0.0)
	am.play_bgm(&"track_a", 0.0)
	assert_signal_emit_count(am, "bgm_changed", 1, "same track twice → bgm_changed emitted exactly once")
	assert_eq(am._current_bgm_track, &"track_a", "current track unchanged")


# ── AC-21: fade_sec = 0 → instant swap, no crossfade, no NaN ─────────────────────

func test_fade_zero_instant_swap() -> void:
	var am := _boot(_cat())
	am.play_bgm(&"track_a", 0.0)
	am.play_bgm(&"track_b", 0.0)
	assert_eq(am._current_bgm_track, &"track_b", "track switched")
	assert_eq(am._test_get_active_crossfade_count(), 0, "instant swap → no crossfade in-flight")
	assert_lt(am._crossfade_progress, 0.0, "sentinel: no crossfade (progress < 0)")
	var active: AudioStreamPlayer = am._bgm_players[am._bgm_active_idx]
	assert_almost_eq(active.volume_db, 0.0, 0.01, "in player at full gain (0 dB), no NaN/click")


# ── AC-18: mid-crossfade interrupt → latest wins, no stacking ───────────────────

func test_mid_crossfade_interrupt_does_not_stack() -> void:
	var am := _boot(_cat())
	am.play_bgm(&"track_a", 0.0)   # steady state
	am.play_bgm(&"track_b", 1.0)   # crossfade A→B in-flight
	assert_eq(am._test_get_active_crossfade_count(), 1, "exactly one crossfade in-flight")
	am.play_bgm(&"track_c", 1.0)   # interrupt mid-crossfade
	assert_eq(am._test_get_active_crossfade_count(), 1, "interrupt does NOT stack Tweens — still exactly 1")
	assert_eq(am._current_bgm_track, &"track_c", "latest track wins")
	assert_eq(am._bgm_players.size(), 2, "still only 2 BGM players (no unbounded growth)")
