## Integration test — GymModeHud Story 010: bfcache/resume reconcile + SUSPENDED (headless)
##
## Coverage (unblocked AC; S9b real-browser pageshow is ADVISORY/BLOCKED Q-OQ12):
##   AC-EC-S9a — reconcile(pulled): one-shot snap to pulled matrix; banner dismiss flag preserved
##   EC-S2     — SUSPENDED banner re-appears on resume while locked; never after an unlock
##   EC-S9/SM  — leave Suspended ⟺ dom_visible AND gsm≠SUSPENDED; generational defer one frame
##   AC-EC-R4  — count/EXP result is ordering-independent of unlock×WORKOUT (count ⊥ audio)
extends GutTest

const SUT := preload("res://src/ui/gym_mode_hud/gym_mode_hud.gd")


class _StubGSM:
	extends RefCounted
	signal state_changed(from_state: int, to_state: int, payload)
	var current: int = GameStateMachine.GameState.IDLE
	var transitioning: bool = false
	func get_current_state() -> int:
		return current
	func is_transitioning() -> bool:
		return transitioning
	func connect_for_initial_state(callable: Callable) -> void:
		state_changed.connect(callable)
		callable.callv([current, current, null])


class _StubAudio:
	extends RefCounted
	signal audio_unlocked
	var _unlocked: bool = false
	func is_audio_unlocked() -> bool:
		return _unlocked
	func unlock() -> void:
		_unlocked = true
		audio_unlocked.emit()


class _StubStat:
	extends RefCounted
	signal stat_changed(stat_id: StringName, old_value: float, new_value: float, source: int, is_initial: bool)
	func connect_for_initial_state(callable: Callable) -> void:
		stat_changed.connect(callable)


class _StubWST:
	extends RefCounted
	signal set_progress_changed(new_progress: float)
	signal phase_changed(from_phase: int, to_phase: int)
	var _p: float = 0.0
	func get_set_progress() -> float:
		return _p
	func get_current_phase() -> int:
		return 0
	func emit_progress(p: float) -> void:
		_p = p
		set_progress_changed.emit(p)


func _make_sut(audio_unlocked: bool = false) -> SUT:
	var sut: SUT = SUT.new()
	var audio := _StubAudio.new()
	audio._unlocked = audio_unlocked
	sut._gsm = _StubGSM.new()
	sut._audio_manager = audio
	sut._stat_system = _StubStat.new()
	sut._wst = _StubWST.new()
	add_child_autofree(sut)
	return sut


# ── AC-EC-S9a: reconcile one-shot snap ──

func test_reconcile_snaps_to_pulled_matrix() -> void:
	var sut := _make_sut(true)
	sut._apply_state_matrix(GameStateMachine.GameState.WORKOUT_ACTIVE)  # freeze @ WORKOUT
	sut.reconcile(GameStateMachine.GameState.LOOT_DROP)  # resume pulled LOOT_DROP
	assert_eq(sut.get_element_emphasis(&"hp"), sut.Emphasis.AMBIENT_DIM,
		"AC-EC-S9a: reconcile snaps HP to LOOT_DROP matrix (○dim)")
	assert_eq(sut.get_element_emphasis(&"prog"), sut.Emphasis.DEFER,
		"AC-EC-S9a: reconcile snaps PROG to LOOT_DROP ▽defer")


func test_reconcile_preserves_banner_dismiss_flag() -> void:
	var sut := _make_sut(false)
	sut._banner_dismissed_this_session = true  # already dismissed earlier this session
	sut.reconcile(GameStateMachine.GameState.WORKOUT_ACTIVE)
	assert_true(sut._banner_dismissed_this_session,
		"AC-EC-S9a: reconcile never resets banner dismiss flag (防重彈)")


# ── EC-S2: banner re-appears on locked resume, never after unlock ──

func test_banner_reappears_on_locked_resume() -> void:
	var sut := _make_sut(false)  # locked, not yet dismissed
	sut.reconcile(GameStateMachine.GameState.WORKOUT_ACTIVE)  # resume, still locked
	assert_true(sut.should_show_banner(),
		"EC-S2: banner re-appears on resume while still locked + not dismissed")


func test_banner_never_reappears_after_unlock() -> void:
	var sut := _make_sut(false)
	var audio := sut._audio_manager as _StubAudio
	audio.unlock()  # unlock during session → dismiss flag set
	audio._unlocked = false  # resume re-locked
	sut.reconcile(GameStateMachine.GameState.WORKOUT_ACTIVE)
	assert_false(sut.should_show_banner(),
		"EC-S2: once unlocked this session, banner never re-appears even if re-locked")


# ── EC-S9 / SM: AND guard + terminal branch + generational defer ──

func test_stay_suspended_when_dom_hidden_and_guard() -> void:
	var sut := _make_sut(true)
	# DOM hidden even though GSM left SUSPENDED → AND guard keeps HUD suspended.
	sut.reconcile(GameStateMachine.GameState.WORKOUT_ACTIVE, false)
	assert_eq(sut.get_hud_state(), sut._HudState.SUSPENDED,
		"EC-S9/SM-B: dom_visible==false → stay SUSPENDED (AND guard, not OR)")


func test_terminal_branch_active_when_unlocked() -> void:
	var sut := _make_sut(true)  # unlocked
	sut.reconcile(GameStateMachine.GameState.WORKOUT_ACTIVE, true)
	assert_eq(sut.get_hud_state(), sut._HudState.ACTIVE,
		"SM-D: visible + not suspended + unlocked → ACTIVE")


func test_terminal_branch_banner_gate_when_locked() -> void:
	var sut := _make_sut(false)  # locked
	sut.reconcile(GameStateMachine.GameState.WORKOUT_ACTIVE, true)
	assert_eq(sut.get_hud_state(), sut._HudState.BANNER_GATE,
		"SM-D: visible + not suspended + locked → BannerGate")


func test_generational_guard_defers_during_transition() -> void:
	var sut := _make_sut(true)
	sut._apply_state_matrix(GameStateMachine.GameState.WORKOUT_ACTIVE)
	var gsm := sut._gsm as _StubGSM
	gsm.transitioning = true  # GSM mid-transition → reconcile must defer
	sut.reconcile(GameStateMachine.GameState.LOOT_DROP)
	assert_eq(sut.get_element_emphasis(&"hp"), sut.Emphasis.EMPHASIS,
		"SM-C: reconcile deferred while GSM in-flight (matrix NOT yet applied)")
	gsm.transitioning = false
	await get_tree().process_frame  # deferred reconcile fires next frame
	assert_eq(sut.get_element_emphasis(&"hp"), sut.Emphasis.AMBIENT_DIM,
		"SM-C: after transition settles, deferred reconcile applies pulled matrix")


# ── AC-EC-R4: count/EXP ordering-independent of unlock×WORKOUT ──

func test_count_ordering_independent_of_unlock_and_state() -> void:
	var sut := _make_sut(false)
	var gsm := sut._gsm as _StubGSM
	var audio := sut._audio_manager as _StubAudio
	var wst := sut._wst as _StubWST
	# Interleave unlock, state change, and progress in an arbitrary order.
	wst.emit_progress(1.0)
	audio.unlock()
	gsm.state_changed.emit(GameStateMachine.GameState.IDLE, GameStateMachine.GameState.WORKOUT_ACTIVE, null)
	wst.emit_progress(2.0)
	wst.emit_progress(3.0)
	assert_eq(sut.get_workout_progress(), 3.0,
		"AC-EC-R4: workout_progress == 3 regardless of unlock/state ordering (count ⊥ audio)")
