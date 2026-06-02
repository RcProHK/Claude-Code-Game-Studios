# AudioManager — #4 Story 008: SUSPENDED multi-source + resume (Integration, ADR-0006 C4).
#
# Covers AC-14 (pause/record/resume), AC-14b (suspend kills in-flight crossfade), AC-14c (LOCKED ×
# SUSPENDED coexist — no permanent mute), AC-24a (_handle_focus_change pure), AC-24b (_notification
# wiring), AC-30 (bitmask multi-source dedup), AC-33 (suspend duck-kill + retain + resume recompute),
# AC-34 (_paused_focus_low × _suspended_bgm_state independence).
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


func _boot(web: bool) -> Node:
	var am := AM.new()
	am._gsm = MockGSM.new()
	am._platform_detect = MockPlatform.new(web)
	am._persistence = MockPersistence.new()
	am._sfx_catalog = {&"audio_unlock_confirm": {"priority": AM.SfxPriority.MID}}
	am._bgm_catalog = {
		&"focus_low_pool": {"stream": null},
		&"boss_theme": {"stream": null},
		&"rest_calm": {"stream": null},
		&"track_a": {"stream": null},
	}
	add_child_autofree(am)
	return am


func _emit(am: Node, from_state: int, to_state: int, payload: Variant = null) -> void:
	am._gsm.state_changed.emit(from_state, to_state, payload)


# ── AC-14: GSM SUSPENDED pauses + records; resume restores ──────────────────────

func test_gsm_suspend_pauses_records_resume_restores() -> void:
	var am := _boot(false)
	_emit(am, GameStateMachine.GameState.IDLE, GameStateMachine.GameState.WORKOUT_ACTIVE)
	assert_eq(am._current_bgm_track, &"focus_low_pool")
	_emit(am, GameStateMachine.GameState.WORKOUT_ACTIVE, GameStateMachine.GameState.SUSPENDED)
	assert_eq(am._lifecycle_state, AM.LifecycleState.SUSPENDED, "GSM SUSPENDED → SUSPENDED lifecycle")
	assert_eq(am._suspended_bgm_state.get("variant_id"), &"focus_low_pool", "recorded current track at pause")
	_emit(am, GameStateMachine.GameState.SUSPENDED, GameStateMachine.GameState.WORKOUT_ACTIVE)
	assert_eq(am._lifecycle_state, AM.LifecycleState.READY, "resume → READY")
	assert_eq(am._current_bgm_track, &"focus_low_pool", "track preserved across suspend/resume")


# ── AC-14b: suspend mid-crossfade kills the crossfade ───────────────────────────

func test_suspend_during_crossfade_kills_it() -> void:
	var am := _boot(false)
	_emit(am, GameStateMachine.GameState.IDLE, GameStateMachine.GameState.WORKOUT_ACTIVE)  # crossfade fade 1.0
	assert_eq(am._test_get_active_crossfade_count(), 1, "crossfade in-flight after WORKOUT_ACTIVE")
	_emit(am, GameStateMachine.GameState.WORKOUT_ACTIVE, GameStateMachine.GameState.SUSPENDED)
	assert_false(am._crossfade_tween != null and am._crossfade_tween.is_valid(), "crossfade tween killed on suspend")
	assert_eq(am._test_get_active_crossfade_count(), 0, "crossfade count reset on suspend (not stuck mid-mix)")


# ── AC-14c: LOCKED × SUSPENDED coexist — no permanent mute ──────────────────────

func test_locked_and_suspended_coexist() -> void:
	var am := _boot(true)  # web LOCKED
	am.play_bgm(&"track_a", 0.0)  # LOCKED → deferred
	_emit(am, GameStateMachine.GameState.IDLE, GameStateMachine.GameState.SUSPENDED)
	assert_false(am.is_audio_unlocked(), "still LOCKED during suspend (unlock flag orthogonal)")
	assert_eq(am._deferred_bgm_track, &"track_a", "deferred slot preserved through suspend")
	_emit(am, GameStateMachine.GameState.SUSPENDED, GameStateMachine.GameState.IDLE)
	assert_false(am.is_audio_unlocked(), "still LOCKED after resume")
	am._do_unlock()
	assert_true(am.is_audio_unlocked(), "first gesture still unlocks after suspend/resume — no permanent mute")


# ── AC-24a: _handle_focus_change pure pause/resume ──────────────────────────────

func test_handle_focus_change_pure_pause_resume() -> void:
	var am := _boot(false)
	am._handle_focus_change(true)
	assert_eq(am._lifecycle_state, AM.LifecycleState.SUSPENDED, "focus out → suspended")
	am._handle_focus_change(false)
	assert_eq(am._lifecycle_state, AM.LifecycleState.READY, "focus in → resumed")


# ── AC-24b: _notification wiring drives the suspend bits ────────────────────────

func test_notification_wiring_drives_suspend() -> void:
	var am := _boot(false)
	am._notification(NOTIFICATION_APPLICATION_PAUSED)
	assert_eq(am._lifecycle_state, AM.LifecycleState.SUSPENDED, "APPLICATION_PAUSED → suspended")
	am._notification(NOTIFICATION_APPLICATION_RESUMED)
	assert_eq(am._lifecycle_state, AM.LifecycleState.READY, "APPLICATION_RESUMED → resumed")


# ── AC-30: bitmask multi-source dedup (latch / last-exit) ───────────────────────

func test_bitmask_multisource_dedup() -> void:
	var am := _boot(false)
	_emit(am, GameStateMachine.GameState.IDLE, GameStateMachine.GameState.SUSPENDED)  # GSM bit
	assert_eq(am._pause_fire_count, 1, "first source → pause exactly once")
	am._handle_focus_change(true)  # focus bit while already suspended
	assert_eq(am._pause_fire_count, 1, "second source → NOT re-paused (first-entry latch)")
	_emit(am, GameStateMachine.GameState.SUSPENDED, GameStateMachine.GameState.IDLE)  # clear GSM bit
	assert_eq(am._resume_fire_count, 0, "one source cleared but focus remains → no resume")
	am._handle_focus_change(false)  # clear focus → last exit
	assert_eq(am._resume_fire_count, 1, "last source cleared → resume exactly once")


# ── AC-33: suspend kills duck Tween + retains _active_ducks; resume recomputes ──

func test_suspend_kills_duck_retains_and_resume_recomputes() -> void:
	var am := _boot(false)
	var h: int = am._register_duck(AM.DUCK_OFFSET_DB)  # -8
	am._apply_duck()
	_emit(am, GameStateMachine.GameState.IDLE, GameStateMachine.GameState.SUSPENDED)
	assert_false(am._duck_tween != null and am._duck_tween.is_valid(), "duck Tween killed on suspend")
	var midx: int = AudioServer.get_bus_index(&"Music")
	assert_almost_eq(AudioServer.get_bus_volume_db(midx), am._base_music_db, 0.01,
		"Music bus hard-set to base on suspend")
	assert_true(am._active_ducks.has(h), "_active_ducks RETAINED (not cleared) for resume")
	_emit(am, GameStateMachine.GameState.SUSPENDED, GameStateMachine.GameState.IDLE)
	assert_almost_eq(am._compute_duck_target(am._active_ducks),
		maxf(am._base_music_db + AM.DUCK_OFFSET_DB, AM.MUTE_FLOOR_DB), 0.01,
		"resume recomputes the duck target (-14) from the retained ducks")


# ── AC-34: _paused_focus_low × _suspended_bgm_state are independent ─────────────

func test_paused_focus_low_and_suspended_bgm_independent() -> void:
	var am := _boot(false)
	_emit(am, GameStateMachine.GameState.IDLE, GameStateMachine.GameState.WORKOUT_ACTIVE)  # focus_low
	_emit(am, GameStateMachine.GameState.WORKOUT_ACTIVE, GameStateMachine.GameState.BOSS_ENCOUNTER)  # boss replaces focus_low
	assert_eq(am._paused_focus_low.get("variant_id"), &"focus_low_pool",
		"boss entry recorded focus_low for boss-exit resume")
	assert_eq(am._current_bgm_track, &"boss_theme", "now playing boss_theme")
	_emit(am, GameStateMachine.GameState.BOSS_ENCOUNTER, GameStateMachine.GameState.SUSPENDED)
	assert_eq(am._suspended_bgm_state.get("variant_id"), &"boss_theme", "suspend recorded boss_theme (audible track)")
	assert_eq(am._paused_focus_low.get("variant_id"), &"focus_low_pool",
		"_paused_focus_low NOT overwritten by suspend — the two fields record independently")
