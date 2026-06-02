# AudioManager — #4 Story 007: mobile Safari unlock gate (Integration, ADR-0001).
#
# Covers AC-05 (deferred BGM on unlock), AC-06 (LOCKED play_sfx dropped), AC-06b (flag flip +
# audio_unlocked emit), AC-19a (unlock prefers GSM-current over deferred — anti-stale), AC-19b
# (deferred fallback latest-wins), AC-26 (unlock confirm chime), AC-31 (desktop no-confirm),
# AC-32b (PlatformDetect mock seam drives LOCKED). Unlock is driven via _do_unlock() (the call
# _input() makes on the first gesture); the engine _input dispatch itself is ADVISORY (headless).
extends GutTest

const AM := preload("res://src/autoload/audio_manager.gd")


class MockGSM:
	signal state_changed(from_state: Variant, to_state: Variant, payload: Variant)
	var current: int = 0
	func connect_for_initial_state(c: Callable) -> void:
		state_changed.connect(c)
	func get_current_state() -> int:
		return current

class MockPlatform:
	var _web: bool = false
	func _init(web: bool) -> void:
		_web = web
	func is_web() -> bool:
		return _web

class MockPersistence:
	func read(_key: String) -> Variant:
		return null
	func write(_key: String, _value: Variant, _flush: bool = false) -> bool:
		return true


func _boot(web: bool, gsm_current: int) -> Node:
	var am := AM.new()
	var gsm := MockGSM.new()
	gsm.current = gsm_current
	am._gsm = gsm
	am._platform_detect = MockPlatform.new(web)
	am._persistence = MockPersistence.new()
	am._sfx_catalog = {&"audio_unlock_confirm": {"priority": AM.SfxPriority.MID}}
	am._bgm_catalog = {
		&"focus_low_pool": {"stream": null},
		&"track_a": {"stream": null},
		&"track_b": {"stream": null},
		&"track_c": {"stream": null},
	}
	add_child_autofree(am)
	return am


# ── AC-06b: web LOCKED → unlock flips flag + emits once ─────────────────────────

func test_web_locked_then_unlock_flips_flag_and_emits_once() -> void:
	var am := _boot(true, GameStateMachine.GameState.IDLE)
	assert_false(am.is_audio_unlocked(), "web boot → LOCKED")
	watch_signals(am)
	am._do_unlock()
	assert_true(am.is_audio_unlocked(), "first gesture → unlocked")
	assert_signal_emit_count(am, "audio_unlocked", 1, "audio_unlocked emitted exactly once")


# ── AC-26: unlock plays the confirm chime ───────────────────────────────────────

func test_unlock_plays_confirm_chime() -> void:
	var am := _boot(true, GameStateMachine.GameState.IDLE)
	am._do_unlock()
	assert_eq(am._test_get_active_voice_count(), 1, "audio_unlock_confirm consumed one SFX voice")


# ── AC-06: LOCKED play_sfx dropped ──────────────────────────────────────────────

func test_locked_play_sfx_dropped() -> void:
	var am := _boot(true, GameStateMachine.GameState.IDLE)
	am.play_sfx(&"audio_unlock_confirm")
	assert_eq(am._test_get_active_voice_count(), 0, "LOCKED → one-shot SFX dropped (no voice)")


# ── AC-05: deferred BGM starts on unlock when GSM-current has no mapping ────────

func test_locked_deferred_bgm_starts_on_unlock() -> void:
	var am := _boot(true, GameStateMachine.GameState.IDLE)  # IDLE has no map entry
	am.play_bgm(&"track_a", 0.0)
	assert_eq(am._current_bgm_track, &"", "LOCKED: play_bgm deferred, not started")
	am._do_unlock()
	assert_eq(am._current_bgm_track, &"track_a", "unlock → deferred track_a starts (no GSM mapping)")


# ── AC-19a: unlock prefers GSM-current over the deferred slot (anti-stale) ──────

func test_unlock_prefers_gsm_current_over_deferred() -> void:
	var am := _boot(true, GameStateMachine.GameState.WORKOUT_ACTIVE)  # maps focus_low_pool
	am.play_bgm(&"track_a", 0.0)
	am.play_bgm(&"track_b", 0.0)
	am.play_bgm(&"track_c", 0.0)  # deferred slot = track_c (latest-wins)
	am._do_unlock()
	assert_eq(am._current_bgm_track, &"focus_low_pool",
		"unlock → GSM-current focus_low (NOT stale deferred track_c)")


# ── AC-19b: deferred fallback (latest-wins) when GSM-current has no mapping ─────

func test_unlock_falls_back_to_latest_deferred() -> void:
	var am := _boot(true, GameStateMachine.GameState.IDLE)  # no mapping
	am.play_bgm(&"track_a", 0.0)
	am.play_bgm(&"track_b", 0.0)
	am.play_bgm(&"track_c", 0.0)
	am._do_unlock()
	assert_eq(am._current_bgm_track, &"track_c", "no GSM mapping → latest deferred (track_c) wins")


# ── AC-31: desktop boots unlocked → _do_unlock is a no-op (no confirm, no re-emit) ─

func test_desktop_boot_unlocked_no_confirm() -> void:
	var am := _boot(false, GameStateMachine.GameState.IDLE)
	assert_true(am.is_audio_unlocked(), "desktop boot → unlocked immediately")
	watch_signals(am)
	am._do_unlock()
	assert_signal_not_emitted(am, "audio_unlocked", "desktop: _do_unlock no-op (already unlocked)")
	assert_eq(am._test_get_active_voice_count(), 0, "desktop: no unlock-confirm chime")


# ── AC-32b: PlatformDetect mock seam drives the lock state ──────────────────────

func test_platform_seam_drives_lock_state() -> void:
	var am_web := _boot(true, GameStateMachine.GameState.IDLE)
	assert_false(am_web.is_audio_unlocked(), "inject is_web=true → LOCKED")
	var am_desktop := _boot(false, GameStateMachine.GameState.IDLE)
	assert_true(am_desktop.is_audio_unlocked(), "inject is_web=false → unlocked")
