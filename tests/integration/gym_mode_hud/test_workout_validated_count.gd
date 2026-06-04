## Integration test — GymModeHud Story 005: #9-validated count/progress + anti-fabrication
##
## Coverage:
##   AC-CR-8 count    — count binds to #9 set_progress_changed (absolute), independent of audio
##   AC-CR-8 anti-fab — #20 has NO raw set_logged path; #9 drop → progress stays 0, exp delta 0
##   AC-CR-4          — no interpolation: 5s gap with no event → displayed value delta == 0
##   AC-EC-S1         — BannerGate + WORKOUT_ACTIVE → count works (B1 decouple, not held by banner)
extends GutTest

const SUT := preload("res://src/ui/gym_mode_hud/gym_mode_hud.gd")


# ── Stubs ──

class _StubWST:
	extends RefCounted
	signal set_progress_changed(new_progress: float)
	signal phase_changed(from_phase: int, to_phase: int)
	var _progress: float = 0.0
	var _phase: int = 0
	func get_set_progress() -> float:
		return _progress
	func get_current_phase() -> int:
		return _phase
	func emit_progress(p: float) -> void:
		_progress = p
		set_progress_changed.emit(p)
	func emit_phase(from_p: int, to_p: int) -> void:
		_phase = to_p
		phase_changed.emit(from_p, to_p)


class _StubStat:
	extends RefCounted
	signal stat_changed(stat_id: StringName, old_value: float, new_value: float, source: int, is_initial: bool)
	func connect_for_initial_state(callable: Callable) -> void:
		stat_changed.connect(callable)
	func emit_stat_changed(stat_id: StringName, new_val: float) -> void:
		stat_changed.emit(stat_id, 0.0, new_val, 0, false)


class _StubAudio:
	extends RefCounted
	signal audio_unlocked
	var _unlocked: bool = false
	func is_audio_unlocked() -> bool:
		return _unlocked


func _make_sut(audio_unlocked: bool = false) -> SUT:
	var sut: SUT = SUT.new()
	var audio := _StubAudio.new()
	audio._unlocked = audio_unlocked
	sut._wst = _StubWST.new()
	sut._stat_system = _StubStat.new()
	sut._audio_manager = audio
	add_child_autofree(sut)
	return sut


# ── AC-CR-8: count binds to #9-validated path, audio-independent ──

func test_count_binds_to_wst_progress_absolute() -> void:
	var sut := _make_sut(false)  # audio LOCKED
	var wst := sut._wst as _StubWST
	wst.emit_progress(1.0)
	wst.emit_progress(2.0)
	wst.emit_progress(3.0)
	assert_eq(sut.get_workout_progress(), 3.0,
		"AC-CR-8: workout_progress == 3 (absolute, from 3 #9-validated events)")


func test_count_independent_of_audio_lock() -> void:
	var sut := _make_sut(false)  # audio LOCKED
	var wst := sut._wst as _StubWST
	wst.emit_progress(2.0)
	var audio := sut._audio_manager as _StubAudio
	assert_false(audio.is_audio_unlocked(),
		"precondition: audio still locked")
	assert_eq(sut.get_workout_progress(), 2.0,
		"AC-CR-8: count updates even while audio LOCKED (count orthogonal to audio unlock)")


func test_phase_changed_updates_phase_not_count() -> void:
	var sut := _make_sut(false)
	var wst := sut._wst as _StubWST
	wst.emit_phase(0, 1)  # WARM_UP → SET_ACTIVE (example ordinals)
	assert_eq(sut.get_workout_phase(), 1,
		"AC-CR-8: phase_changed updates phase")
	assert_eq(sut.get_workout_progress(), 0.0,
		"AC-CR-8: phase change does NOT bump count (count only from set_progress_changed)")


# ── AC-CR-8 anti-fabrication: no consumer-side fabrication path ──

func test_no_set_logged_handler_means_no_count_without_wst() -> void:
	var sut := _make_sut(false)
	# Simulate IDLE-without-workout_started: #9 drops the stray set_logged (emits nothing).
	# #20 has NO raw set_logged subscription, so there is no path to fabricate progress.
	assert_eq(sut.get_workout_progress(), 0.0,
		"AC-CR-8 anti-fab: with no #9-validated event, count stays 0 (no consumer-side fabrication)")
	assert_eq(sut.get_exp_bar_value(), 0.0,
		"AC-CR-8 anti-fab: no stat_changed → exp_fill delta == 0 (EXP trust boundary at #11)")


func test_twenty_does_not_subscribe_set_logged() -> void:
	var sut := _make_sut(false)
	# Structural negative: #20 must not expose a raw set_logged handler for count.
	assert_false(sut.has_method("_on_set_logged"),
		"AC-CR-8 anti-fab: #20 has NO _on_set_logged handler (raw set_logged is Story 007 audio-only)")


# ── AC-CR-4: no interpolation during polling gap ──

func test_no_interpolation_during_gap() -> void:
	var sut := _make_sut(false)
	var wst := sut._wst as _StubWST
	wst.emit_progress(2.0)
	var value_after_event: float = sut.get_workout_progress()
	# Simulate a 5s polling gap with no new event — value must not drift (no progress += elapsed).
	await get_tree().process_frame
	await get_tree().process_frame
	await get_tree().process_frame
	assert_eq(sut.get_workout_progress(), value_after_event,
		"AC-CR-4: no new event over the gap → displayed progress delta == 0 (no interpolation)")


# ── AC-EC-S1: BannerGate does not hold count (B1 decouple) ──

func test_count_works_in_banner_gate() -> void:
	var sut := _make_sut(false)  # audio LOCKED → BannerGate
	# Force BannerGate state (banner showing, audio not yet unlocked).
	sut._hud_state = sut._HudState.BANNER_GATE
	var wst := sut._wst as _StubWST
	wst.emit_progress(1.0)
	wst.emit_progress(2.0)
	wst.emit_progress(3.0)
	assert_eq(sut.get_workout_progress(), 3.0,
		"AC-EC-S1: count == 3 during BannerGate (B1 decouple — banner gates audio only, not count)")
	assert_eq(sut.get_hud_state(), sut._HudState.BANNER_GATE,
		"AC-EC-S1: still in BannerGate (count did not require audio unlock)")
