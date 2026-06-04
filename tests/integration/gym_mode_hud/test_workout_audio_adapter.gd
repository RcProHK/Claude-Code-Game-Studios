## Integration test — GymModeHud Story 007: WorkoutAudioAdapter buffer policy + gate + stagger
##
## Coverage (unblocked AC):
##   AC-CR-10  — LOCKED: buffer mid/high FIFO cap, drop low; unlock → flush priority-desc to empty
##   AC-EC-A1  — all-LOCKED 20 events ≤ cap, never flush; _exit_tree clears (no dangling)
##   AC-EC-A4  — deferred streak chime: out-of-gate when timer fires → guard drops (no play)
##   AC-EC-S4* — deny states (DISCONNECTED/LOOT_DROP/SUSPENDED/IDLE) → no SFX; WORKOUT → SFX
##   AC-CR-9   — unlocked + request → play_sfx once (code path; #2-GDD doc-gate noted)
##   AC-CR-11  — set_complete first + streak chime scheduled at stagger delay (code path; #8 gated)
##   AC-EC-S6  — no #8 streak → set_complete immediate, no deferred chime
extends GutTest

const ADAPTER := preload("res://src/ui/gym_mode_hud/workout_audio_adapter.gd")


class _StubAudio:
	extends RefCounted
	signal audio_unlocked
	var _unlocked: bool = false
	var played: Array = []
	func is_audio_unlocked() -> bool:
		return _unlocked
	func play_sfx(event_id: StringName) -> void:
		played.append(event_id)
	func unlock() -> void:
		_unlocked = true
		audio_unlocked.emit()


class _StubGSM:
	extends RefCounted
	var current: int = GameStateMachine.GameState.WORKOUT_ACTIVE
	func get_current_state() -> int:
		return current


class _FakeTimer:
	extends RefCounted
	var scheduled: Array = []  # {delay, cb}
	func schedule(delay: float, cb: Callable) -> void:
		scheduled.append({"delay": delay, "cb": cb})
	func fire_all() -> void:
		var to_fire: Array = scheduled.duplicate()
		scheduled.clear()
		for s: Dictionary in to_fire:
			(s["cb"] as Callable).call()


func _make_adapter(unlocked: bool = false, state: int = GameStateMachine.GameState.WORKOUT_ACTIVE) -> ADAPTER:
	var a: ADAPTER = ADAPTER.new()
	var audio := _StubAudio.new()
	audio._unlocked = unlocked
	var gsm := _StubGSM.new()
	gsm.current = state
	a._audio_manager = audio
	a._gsm = gsm
	a._sfx_catalog = {}  # tests override per case
	add_child_autofree(a)
	return a


# ── AC-CR-10: buffer policy ──

func test_locked_buffers_mid_high_fifo_cap() -> void:
	var a := _make_adapter(false)  # LOCKED
	a._sfx_catalog = {&"set_complete": ADAPTER.Priority.MID}
	for i in ADAPTER.PENDING_BUFFER_CAP + 2:
		a.handle_sfx_request(&"set_complete")
	assert_eq(a.get_pending_size(), ADAPTER.PENDING_BUFFER_CAP,
		"AC-CR-10: buffer capped at PENDING_BUFFER_CAP (FIFO drop oldest)")


func test_locked_drops_low_priority() -> void:
	var a := _make_adapter(false)
	a._sfx_catalog = {&"tiny": ADAPTER.Priority.LOW}
	a.handle_sfx_request(&"tiny")
	assert_eq(a.get_pending_size(), 0,
		"AC-CR-10: low-priority SFX not buffered (dropped while locked)")


func test_unlock_flushes_buffer_to_empty() -> void:
	var a := _make_adapter(false)
	a._sfx_catalog = {&"set_complete": ADAPTER.Priority.MID}
	a.handle_sfx_request(&"set_complete")
	a.handle_sfx_request(&"set_complete")
	assert_eq(a.get_pending_size(), 2, "precondition: 2 buffered")
	var audio := a._audio_manager as _StubAudio
	audio.unlock()  # audio_unlocked → flush
	assert_eq(a.get_pending_size(), 0,
		"AC-CR-10: unlock flushes buffer to empty")
	assert_eq(audio.played.size(), 2,
		"AC-CR-10: all buffered SFX played on flush")


# ── AC-EC-A1: all-locked never flush + exit clears ──

func test_locked_twenty_events_capped_then_exit_clears() -> void:
	var a := _make_adapter(false)
	a._sfx_catalog = {&"set_complete": ADAPTER.Priority.MID}
	for i in 20:
		a.handle_sfx_request(&"set_complete")
	assert_lte(a.get_pending_size(), ADAPTER.PENDING_BUFFER_CAP,
		"AC-EC-A1: pending ≤ cap across 20 locked events")
	var audio := a._audio_manager as _StubAudio
	assert_eq(audio.played.size(), 0, "AC-EC-A1: never flushed while locked (no tap)")
	a._exit_tree()
	assert_eq(a.get_pending_size(), 0, "AC-EC-A1: _exit_tree clears buffer (no dangling play_sfx)")


# ── AC-EC-A4: deferred chime guard ──

func test_deferred_streak_chime_dropped_when_out_of_gate() -> void:
	var a := _make_adapter(true, GameStateMachine.GameState.WORKOUT_ACTIVE)
	var timer := _FakeTimer.new()
	a._timer_service = timer
	a._sfx_catalog = {&"set_complete": ADAPTER.Priority.MID, &"streak_chime": ADAPTER.Priority.MID}
	a.handle_set_complete(true)  # set_complete plays now, streak chime scheduled
	var gsm := a._gsm as _StubGSM
	gsm.current = GameStateMachine.GameState.SUSPENDED  # leave gate before timer fires
	timer.fire_all()
	var audio := a._audio_manager as _StubAudio
	assert_false(audio.played.has(&"streak_chime"),
		"AC-EC-A4: deferred chime dropped when no longer in a gate state at fire time")


# ── AC-EC-S4*: deny-side gate ──

func test_deny_states_no_sfx() -> void:
	for state in [
		GameStateMachine.GameState.DISCONNECTED,
		GameStateMachine.GameState.LOOT_DROP,
		GameStateMachine.GameState.SUSPENDED,
		GameStateMachine.GameState.IDLE,
	]:
		var a := _make_adapter(true, state)
		a._sfx_catalog = {&"set_complete": ADAPTER.Priority.MID}
		a.handle_sfx_request(&"set_complete")
		var audio := a._audio_manager as _StubAudio
		assert_eq(audio.played.size(), 0,
			"AC-EC-S4: state %d outside gate → SFX denied (spy count 0)" % state)


func test_workout_state_allows_sfx() -> void:
	var a := _make_adapter(true, GameStateMachine.GameState.WORKOUT_ACTIVE)
	a._sfx_catalog = {&"set_complete": ADAPTER.Priority.MID}
	a.handle_sfx_request(&"set_complete")
	var audio := a._audio_manager as _StubAudio
	assert_eq(audio.played, [&"set_complete"],
		"AC-EC-S4: WORKOUT_ACTIVE in gate → SFX triggers (count 1)")


# ── AC-CR-9: unlocked play once (code path) ──

func test_unlocked_plays_immediately_once() -> void:
	var a := _make_adapter(true, GameStateMachine.GameState.WORKOUT_ACTIVE)
	a._sfx_catalog = {&"set_complete": ADAPTER.Priority.MID}
	a.handle_sfx_request(&"set_complete")
	var audio := a._audio_manager as _StubAudio
	assert_eq(audio.played.size(), 1, "AC-CR-9: unlocked → play_sfx exactly once")


func test_set_logged_handler_routes_to_set_complete() -> void:
	var a := _make_adapter(true, GameStateMachine.GameState.WORKOUT_ACTIVE)
	a._sfx_catalog = {&"set_complete": ADAPTER.Priority.MID}
	a._on_set_logged(&"bench_press", 8, 60.0)
	var audio := a._audio_manager as _StubAudio
	assert_eq(audio.played, [&"set_complete"],
		"AC-CR-9: raw set_logged → set_complete SFX (only audio path consumes raw set_logged)")


# ── AC-CR-11: stagger schedule (code path; #8 streak gated) ──

func test_set_complete_then_streak_chime_staggered() -> void:
	var a := _make_adapter(true, GameStateMachine.GameState.WORKOUT_ACTIVE)
	var timer := _FakeTimer.new()
	a._timer_service = timer
	a._sfx_catalog = {&"set_complete": ADAPTER.Priority.MID, &"streak_chime": ADAPTER.Priority.MID}
	a.handle_set_complete(true)
	var audio := a._audio_manager as _StubAudio
	assert_eq(audio.played[0], &"set_complete",
		"AC-CR-11: set_complete plays first (immediate)")
	assert_eq(timer.scheduled.size(), 1, "AC-CR-11: streak chime scheduled once")
	assert_almost_eq(float(timer.scheduled[0]["delay"]), ADAPTER.SET_STREAK_CHIME_STAGGER_MS / 1000.0, 0.0001,
		"AC-CR-11: chime scheduled at SET_STREAK_CHIME_STAGGER_MS stagger")
	timer.fire_all()
	assert_true(audio.played.has(&"streak_chime"),
		"AC-CR-11: chime plays after stagger delay")


# ── AC-EC-S6: no #8 streak → immediate, no defer ──

func test_no_streak_plays_immediately_no_defer() -> void:
	var a := _make_adapter(true, GameStateMachine.GameState.WORKOUT_ACTIVE)
	var timer := _FakeTimer.new()
	a._timer_service = timer
	a._sfx_catalog = {&"set_complete": ADAPTER.Priority.MID}
	a.handle_set_complete(false)  # no streak (#8 not wired)
	var audio := a._audio_manager as _StubAudio
	assert_eq(audio.played, [&"set_complete"],
		"AC-EC-S6: no streak → set_complete plays immediately")
	assert_eq(timer.scheduled.size(), 0,
		"AC-EC-S6: no deferred chime scheduled (CR-11 logic dormant)")
