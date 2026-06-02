# AudioManager — #4 Story 006: GSM state → music transition (Integration, ADR-0006 C6).
#
# Covers AC-07 (BOSS_ENCOUNTER → boss_theme + bgm_changed emit-at-start), AC-08 (initial-state
# sentinel noop), AC-32 (untyped _gsm injection seam) + the state→track map (WORKOUT_ACTIVE /
# REST_PERIOD / no-entry) + 情境A/B (LOOT_DROP from BOSS vs non-boss). The handler is driven by
# a mock _gsm double; GameState enum values come from the real GameStateMachine autoload.
extends GutTest

const AM := preload("res://src/autoload/audio_manager.gd")


## Mock GSM: a real signal + connect_for_initial_state that wires the handler to it, so the test
## can emit state_changed and drive AudioManager (proves the untyped _gsm seam accepts a double).
class MockGSM:
	signal state_changed(from_state: Variant, to_state: Variant, payload: Variant)
	func connect_for_initial_state(c: Callable) -> void:
		state_changed.connect(c)

class MockPlatform:
	func is_web() -> bool:
		return false

class MockPersistence:
	func read(_key: String) -> Variant:
		return null
	func write(_key: String, _value: Variant, _flush: bool = false) -> bool:
		return true

## Minimal sentinel payload (matches StateTransitionPayload.source_event access via Object.get).
class MockPayload:
	var source_event: String = ""


func _boot() -> Node:
	var am := AM.new()
	am._gsm = MockGSM.new()
	am._platform_detect = MockPlatform.new()
	am._persistence = MockPersistence.new()
	am._sfx_catalog = {}  # silence the SfxCatalog-missing boot error (not under test here)
	am._bgm_catalog = {
		&"focus_low_pool": {"stream": null},
		&"boss_theme": {"stream": null},
		&"rest_calm": {"stream": null},
	}
	add_child_autofree(am)
	return am


func _emit(am: Node, from_state: int, to_state: int, payload: Variant = null) -> void:
	am._gsm.state_changed.emit(from_state, to_state, payload)


# ── AC-07: BOSS_ENCOUNTER → boss_theme + bgm_changed emitted at crossfade start ──

func test_boss_encounter_transition_starts_boss_theme() -> void:
	var am := _boot()
	watch_signals(am)
	_emit(am, GameStateMachine.GameState.IDLE, GameStateMachine.GameState.BOSS_ENCOUNTER)
	# Use assert_signal_emitted (boolean) + the track-value assertion below to verify the payload.
	# (GUT 9.6 assert_signal_emitted_with_parameters trips an internal type error on StringName
	# signal params; the value is verified deterministically via _current_bgm_track instead.)
	assert_signal_emitted(am, "bgm_changed",
		"BOSS_ENCOUNTER → bgm_changed emitted at crossfade START (no Tween advance needed)")
	assert_eq(am._current_bgm_track, &"boss_theme", "bgm_changed payload track == boss_theme")


# ── AC-08: initial-state sentinel → noop ─────────────────────────────────────────

func test_initial_state_sentinel_is_noop() -> void:
	var am := _boot()
	watch_signals(am)
	var p := MockPayload.new()
	p.source_event = "initial_state"
	_emit(am, GameStateMachine.GameState.WORKOUT_ACTIVE, GameStateMachine.GameState.WORKOUT_ACTIVE, p)
	assert_signal_not_emitted(am, "bgm_changed", "initial-state sentinel → no music change")
	assert_eq(am._current_bgm_track, &"", "no BGM auto-started at the sentinel (boot stays silent)")


# ── AC-32: untyped _gsm seam accepts a mock double ──────────────────────────────

func test_gsm_seam_accepts_mock_double() -> void:
	var am := _boot()
	# The handler is connected to the injected mock (not the real GSM); emitting on the mock drives it.
	_emit(am, GameStateMachine.GameState.IDLE, GameStateMachine.GameState.WORKOUT_ACTIVE)
	assert_eq(am._current_bgm_track, &"focus_low_pool", "mock _gsm double drives the handler (untyped seam)")


# ── state→track map ─────────────────────────────────────────────────────────────

func test_rest_period_starts_rest_calm() -> void:
	var am := _boot()
	_emit(am, GameStateMachine.GameState.WORKOUT_ACTIVE, GameStateMachine.GameState.REST_PERIOD)
	assert_eq(am._current_bgm_track, &"rest_calm", "REST_PERIOD → rest_calm (NOT REST_BETWEEN_SETS)")


func test_state_without_map_entry_keeps_current_bgm() -> void:
	var am := _boot()
	_emit(am, GameStateMachine.GameState.IDLE, GameStateMachine.GameState.WORKOUT_ACTIVE)  # focus_low
	_emit(am, GameStateMachine.GameState.WORKOUT_ACTIVE, GameStateMachine.GameState.COMBAT_ACTIVE)  # no entry
	assert_eq(am._current_bgm_track, &"focus_low_pool", "COMBAT_ACTIVE has no map entry → keep current BGM")


# ── 情境A / 情境B: LOOT_DROP conditional fade (EG-3 gated on #15 from-state) ──────

func test_loot_drop_from_boss_quick_fades_to_rest_calm() -> void:
	var am := _boot()
	_emit(am, GameStateMachine.GameState.BOSS_ENCOUNTER, GameStateMachine.GameState.LOOT_DROP)
	assert_eq(am._current_bgm_track, &"rest_calm",
		"情境A: BOSS_ENCOUNTER → LOOT_DROP quick-fades boss_theme → rest_calm (loot peak lands calm)")


func test_loot_drop_from_workout_keeps_focus_low() -> void:
	var am := _boot()
	_emit(am, GameStateMachine.GameState.IDLE, GameStateMachine.GameState.WORKOUT_ACTIVE)  # focus_low
	_emit(am, GameStateMachine.GameState.WORKOUT_ACTIVE, GameStateMachine.GameState.LOOT_DROP)  # 情境B
	assert_eq(am._current_bgm_track, &"focus_low_pool",
		"情境B: workout-time loot (non-boss) → keep focus_low (stinger duck suffices)")
