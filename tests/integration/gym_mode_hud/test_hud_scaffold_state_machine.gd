## Integration test — GymModeHud Story 001: scaffold + 3-state view + GSM boot wiring
##
## Coverage:
##   AC-CR-3  — stat_changed filter: EXP triggers redraw; non-HUD stat_id early-returns
##   AC-UX-1  — pull-then-subscribe: initial GSM state applied before any signal fires
##   AC-UX-2  — _apply_state_matrix: all 9 GSM states dispatch correct emphasis enum
##   AC-CR-5  — LOOT_DROP: HP/EXP ○dim, PROG ▽defer, BOSS hidden
##   SM-D     — Booting exit branches to BANNER_GATE (locked) or ACTIVE (unlocked)
##   SM-B     — audio_unlocked moves BANNER_GATE → ACTIVE
extends GutTest

const SUT := preload("res://src/ui/gym_mode_hud/gym_mode_hud.gd")


# ── Stub classes ──

class _StubGSM:
	extends RefCounted
	signal state_changed(from_state: int, to_state: int, payload)
	var _current_state: int = GameStateMachine.GameState.IDLE

	func get_current_state() -> int:
		return _current_state

	## Mirrors ADR-0006 Contract 6: connect signal + deliver initial state synchronously.
	## Production GSM delivers on next process_frame; stub delivers immediately for test determinism.
	func connect_for_initial_state(callable: Callable) -> void:
		state_changed.connect(callable)
		callable.callv([_current_state, _current_state, null])

	func simulate_state_change(new_state: int) -> void:
		var old: int = _current_state
		_current_state = new_state
		state_changed.emit(old, new_state, null)


class _StubStatSystem:
	extends RefCounted
	signal stat_changed(stat_id: StringName, old_value: float, new_value: float, source: int, is_initial: bool)

	func connect_for_initial_state(callable: Callable) -> void:
		stat_changed.connect(callable)
		# No initial burst in stub — test fires events manually.

	func emit_stat_changed(stat_id: StringName, old_val: float, new_val: float) -> void:
		stat_changed.emit(stat_id, old_val, new_val, 0, false)


class _StubAbilitySystem:
	extends RefCounted
	signal ability_unlocked(ability_id: StringName, source: int)

	func connect_for_initial_state(callable: Callable) -> void:
		ability_unlocked.connect(callable)


class _StubAudioManager:
	extends RefCounted
	signal audio_unlocked
	var _unlocked: bool = false

	func is_audio_unlocked() -> bool:
		return _unlocked

	func simulate_unlock() -> void:
		_unlocked = true
		audio_unlocked.emit()


# ── Helpers ──

func _build_sut(gsm_state: int = GameStateMachine.GameState.IDLE, audio_locked: bool = true) -> SUT:
	var sut: SUT = SUT.new()
	var stub_gsm := _StubGSM.new()
	stub_gsm._current_state = gsm_state
	var stub_audio := _StubAudioManager.new()
	stub_audio._unlocked = not audio_locked
	sut._gsm = stub_gsm
	sut._stat_system = _StubStatSystem.new()
	sut._ability_system = _StubAbilitySystem.new()
	sut._audio_manager = stub_audio
	add_child_autofree(sut)
	return sut


# ── AC-CR-3: stat_changed O(1) filter ──

func test_stat_changed_exp_triggers_one_redraw() -> void:
	var sut := _build_sut()
	var stub_stat := sut._stat_system as _StubStatSystem
	stub_stat.emit_stat_changed(&"exp", 100.0, 150.0)
	assert_eq(sut.get_redraw_count(&"exp"), 1,
		"AC-CR-3: EXP stat_changed → exactly 1 EXP sub-widget redraw")


func test_stat_changed_non_hud_stat_no_redraw() -> void:
	var sut := _build_sut()
	var stub_stat := sut._stat_system as _StubStatSystem
	stub_stat.emit_stat_changed(&"attack_power", 10.0, 15.0)
	assert_eq(sut.get_redraw_count(&"attack_power"), 0,
		"AC-CR-3: non-HUD stat_id attack_power → O(1) early-return, no redraw")


func test_stat_changed_same_frame_each_stat_id_filtered_independently() -> void:
	var sut := _build_sut()
	var stub_stat := sut._stat_system as _StubStatSystem
	stub_stat.emit_stat_changed(&"exp", 100.0, 110.0)
	stub_stat.emit_stat_changed(&"max_hp", 200.0, 210.0)
	stub_stat.emit_stat_changed(&"attack_power", 10.0, 11.0)
	stub_stat.emit_stat_changed(&"move_speed", 5.0, 5.0)
	assert_eq(sut.get_redraw_count(&"exp"), 1,
		"AC-CR-3: EXP redraws once")
	assert_eq(sut.get_redraw_count(&"max_hp"), 1,
		"AC-CR-3: max_hp redraws once")
	assert_eq(sut.get_redraw_count(&"attack_power"), 0,
		"AC-CR-3: attack_power no redraw (non-HUD)")
	assert_eq(sut.get_redraw_count(&"move_speed"), 0,
		"AC-CR-3: move_speed no redraw (non-HUD)")


func test_stat_changed_multiple_hud_stat_ids_each_get_own_count() -> void:
	var sut := _build_sut()
	var stub_stat := sut._stat_system as _StubStatSystem
	# Fire EXP twice, max_hp once, str once
	stub_stat.emit_stat_changed(&"exp", 100.0, 110.0)
	stub_stat.emit_stat_changed(&"exp", 110.0, 120.0)
	stub_stat.emit_stat_changed(&"max_hp", 200.0, 210.0)
	stub_stat.emit_stat_changed(&"str", 10.0, 11.0)
	assert_eq(sut.get_redraw_count(&"exp"), 2,
		"AC-CR-3: EXP redraws twice for two consecutive pushes")
	assert_eq(sut.get_redraw_count(&"max_hp"), 1,
		"AC-CR-3: max_hp redraws once")
	assert_eq(sut.get_redraw_count(&"str"), 1,
		"AC-CR-3: str redraws once")


# ── AC-UX-1: pull-then-subscribe structural guarantee ──

func test_ready_applies_initial_gsm_state_synchronously() -> void:
	# AC-UX-1: after _ready(), the initial GSM state matrix is already applied.
	# No blank frame — pull happens before subscribe.
	var sut: SUT = SUT.new()
	var stub_gsm := _StubGSM.new()
	stub_gsm._current_state = GameStateMachine.GameState.WORKOUT_ACTIVE
	sut._gsm = stub_gsm
	sut._stat_system = _StubStatSystem.new()
	sut._ability_system = _StubAbilitySystem.new()
	sut._audio_manager = _StubAudioManager.new()
	add_child_autofree(sut)
	# _ready() has run by here — initial state should be applied
	assert_eq(sut.get_element_emphasis(&"hp"), sut.Emphasis.EMPHASIS,
		"AC-UX-1: HP=◉ immediately after _ready() from WORKOUT_ACTIVE initial state")
	assert_eq(sut.get_element_emphasis(&"exp"), sut.Emphasis.EMPHASIS,
		"AC-UX-1: EXP=◉ immediately after _ready() from WORKOUT_ACTIVE initial state")


# ── AC-UX-2: 9-state matrix dispatch ──

func test_state_matrix_booting_all_hidden() -> void:
	var sut := _build_sut()
	sut._apply_state_matrix(GameStateMachine.GameState.BOOTING)
	for elem in [&"hp", &"exp", &"stat", &"skills", &"prog", &"boss"]:
		assert_eq(sut.get_element_emphasis(elem), sut.Emphasis.HIDDEN,
			"AC-UX-2 BOOTING: %s == HIDDEN" % elem)


func test_state_matrix_disconnected() -> void:
	var sut := _build_sut()
	sut._apply_state_matrix(GameStateMachine.GameState.DISCONNECTED)
	assert_eq(sut.get_element_emphasis(&"hp"), sut.Emphasis.AMBIENT_DIM,
		"AC-UX-2 DISCONNECTED: HP == ○dim")
	assert_eq(sut.get_element_emphasis(&"exp"), sut.Emphasis.HIDDEN,
		"AC-UX-2 DISCONNECTED: EXP == —")
	assert_eq(sut.get_element_emphasis(&"boss"), sut.Emphasis.HIDDEN,
		"AC-UX-2 DISCONNECTED: BOSS == —")


func test_state_matrix_idle() -> void:
	var sut := _build_sut()
	sut._apply_state_matrix(GameStateMachine.GameState.IDLE)
	assert_eq(sut.get_element_emphasis(&"hp"), sut.Emphasis.AMBIENT,
		"AC-UX-2 IDLE: HP == ○")
	assert_eq(sut.get_element_emphasis(&"exp"), sut.Emphasis.AMBIENT,
		"AC-UX-2 IDLE: EXP == ○")
	assert_eq(sut.get_element_emphasis(&"stat"), sut.Emphasis.AMBIENT,
		"AC-UX-2 IDLE: STAT == ○")
	assert_eq(sut.get_element_emphasis(&"skills"), sut.Emphasis.AMBIENT,
		"AC-UX-2 IDLE: SKILLS == ○")
	assert_eq(sut.get_element_emphasis(&"prog"), sut.Emphasis.HIDDEN,
		"AC-UX-2 IDLE: PROG == — (no workout)")


func test_state_matrix_workout_active() -> void:
	var sut := _build_sut()
	sut._apply_state_matrix(GameStateMachine.GameState.WORKOUT_ACTIVE)
	assert_eq(sut.get_element_emphasis(&"hp"), sut.Emphasis.EMPHASIS,
		"AC-UX-2 WORKOUT_ACTIVE: HP == ◉")
	assert_eq(sut.get_element_emphasis(&"exp"), sut.Emphasis.EMPHASIS,
		"AC-UX-2 WORKOUT_ACTIVE: EXP == ◉")
	assert_eq(sut.get_element_emphasis(&"stat"), sut.Emphasis.DEEP_DIM,
		"AC-UX-2 WORKOUT_ACTIVE: STAT == ◐ (R5 B2 — glance count=3)")
	assert_eq(sut.get_element_emphasis(&"skills"), sut.Emphasis.DEEP_DIM,
		"AC-UX-2 WORKOUT_ACTIVE: SKILLS == ◐ (R5 B2)")
	assert_eq(sut.get_element_emphasis(&"prog"), sut.Emphasis.AMBIENT,
		"AC-UX-2 WORKOUT_ACTIVE: PROG == ○")
	assert_eq(sut.get_element_emphasis(&"boss"), sut.Emphasis.HIDDEN,
		"AC-UX-2 WORKOUT_ACTIVE: BOSS == —")


func test_state_matrix_rest_period() -> void:
	var sut := _build_sut()
	sut._apply_state_matrix(GameStateMachine.GameState.REST_PERIOD)
	assert_eq(sut.get_element_emphasis(&"stat"), sut.Emphasis.SURFACE,
		"AC-UX-2 REST_PERIOD: STAT == ▷ (唯一對焦窗)")
	assert_eq(sut.get_element_emphasis(&"skills"), sut.Emphasis.SURFACE,
		"AC-UX-2 REST_PERIOD: SKILLS == ▷")
	assert_eq(sut.get_element_emphasis(&"prog"), sut.Emphasis.SURFACE,
		"AC-UX-2 REST_PERIOD: PROG == ▷ (set X/Y + next action)")
	assert_eq(sut.get_element_emphasis(&"boss"), sut.Emphasis.HIDDEN,
		"AC-UX-2 REST_PERIOD: BOSS == —")


func test_state_matrix_combat_active_mirrors_workout_active() -> void:
	var sut := _build_sut()
	sut._apply_state_matrix(GameStateMachine.GameState.COMBAT_ACTIVE)
	assert_eq(sut.get_element_emphasis(&"hp"), sut.Emphasis.EMPHASIS,
		"AC-UX-2 COMBAT_ACTIVE: HP == ◉")
	assert_eq(sut.get_element_emphasis(&"exp"), sut.Emphasis.EMPHASIS,
		"AC-UX-2 COMBAT_ACTIVE: EXP == ◉")
	assert_eq(sut.get_element_emphasis(&"stat"), sut.Emphasis.DEEP_DIM,
		"AC-UX-2 COMBAT_ACTIVE: STAT == ◐ (R5 B2, same as WORKOUT)")
	assert_eq(sut.get_element_emphasis(&"skills"), sut.Emphasis.DEEP_DIM,
		"AC-UX-2 COMBAT_ACTIVE: SKILLS == ◐")
	assert_eq(sut.get_element_emphasis(&"boss"), sut.Emphasis.HIDDEN,
		"AC-UX-2 COMBAT_ACTIVE: BOSS == —")


func test_state_matrix_boss_encounter_r8_b8_exp_stays_ambient() -> void:
	var sut := _build_sut()
	sut._apply_state_matrix(GameStateMachine.GameState.BOSS_ENCOUNTER)
	assert_eq(sut.get_element_emphasis(&"hp"), sut.Emphasis.EMPHASIS,
		"AC-UX-2 BOSS_ENCOUNTER: HP == ◉")
	assert_eq(sut.get_element_emphasis(&"exp"), sut.Emphasis.AMBIENT,
		"AC-UX-2 BOSS_ENCOUNTER: EXP == ○ (R8 B8 — reward stays in glance, honor CR-1)")
	assert_eq(sut.get_element_emphasis(&"stat"), sut.Emphasis.DEEP_DIM,
		"AC-UX-2 BOSS_ENCOUNTER: STAT == ◐")
	assert_eq(sut.get_element_emphasis(&"skills"), sut.Emphasis.EMPHASIS,
		"AC-UX-2 BOSS_ENCOUNTER: SKILLS == ◉")
	assert_eq(sut.get_element_emphasis(&"prog"), sut.Emphasis.DEEP_DIM,
		"AC-UX-2 BOSS_ENCOUNTER: PROG == ◐")
	assert_eq(sut.get_element_emphasis(&"boss"), sut.Emphasis.EMPHASIS,
		"AC-UX-2 BOSS_ENCOUNTER: BOSS HP == ◉")


func test_state_matrix_suspended_all_frozen() -> void:
	var sut := _build_sut()
	sut._apply_state_matrix(GameStateMachine.GameState.SUSPENDED)
	for elem in [&"hp", &"exp", &"stat", &"skills", &"prog", &"boss"]:
		assert_eq(sut.get_element_emphasis(elem), sut.Emphasis.FROZEN,
			"AC-UX-2 SUSPENDED: %s == ❄" % elem)


# ── AC-CR-5: LOOT_DROP visibility ──

func test_loot_drop_dims_hp_exp_defers_prog_hides_rest() -> void:
	var sut := _build_sut()
	sut._apply_state_matrix(GameStateMachine.GameState.LOOT_DROP)
	assert_eq(sut.get_element_emphasis(&"hp"), sut.Emphasis.AMBIENT_DIM,
		"AC-CR-5: HP == ○dim in LOOT_DROP")
	assert_eq(sut.get_element_emphasis(&"exp"), sut.Emphasis.AMBIENT_DIM,
		"AC-CR-5: EXP == ○dim in LOOT_DROP")
	assert_eq(sut.get_element_emphasis(&"prog"), sut.Emphasis.DEFER,
		"AC-CR-5: PROG == ▽defer (yield to #21 loot modal)")
	assert_eq(sut.get_element_emphasis(&"stat"), sut.Emphasis.HIDDEN,
		"AC-CR-5: STAT == — in LOOT_DROP (no distraction)")
	assert_eq(sut.get_element_emphasis(&"skills"), sut.Emphasis.HIDDEN,
		"AC-CR-5: SKILLS == — in LOOT_DROP")
	assert_eq(sut.get_element_emphasis(&"boss"), sut.Emphasis.HIDDEN,
		"AC-CR-5: BOSS == — in LOOT_DROP")


# ── SM-D + SM-B: 3-state thin view ──

func test_booting_exit_branches_to_banner_gate_when_audio_locked() -> void:
	# Start in BOOTING; simulate GSM leaving BOOTING while audio still locked.
	var sut := _build_sut(GameStateMachine.GameState.BOOTING, true)
	assert_eq(sut.get_hud_state(), sut._HudState.BOOTING,
		"SM-D pre-condition: HUD starts in BOOTING")
	var stub_gsm := sut._gsm as _StubGSM
	stub_gsm.simulate_state_change(GameStateMachine.GameState.IDLE)
	assert_eq(sut.get_hud_state(), sut._HudState.BANNER_GATE,
		"SM-D: BOOTING exit → BANNER_GATE when audio locked")


func test_booting_exit_branches_to_active_when_audio_unlocked() -> void:
	var sut := _build_sut(GameStateMachine.GameState.BOOTING, false) # false = not locked = unlocked
	assert_eq(sut.get_hud_state(), sut._HudState.BOOTING,
		"SM-D pre-condition: HUD starts in BOOTING")
	var stub_gsm := sut._gsm as _StubGSM
	stub_gsm.simulate_state_change(GameStateMachine.GameState.WORKOUT_ACTIVE)
	assert_eq(sut.get_hud_state(), sut._HudState.ACTIVE,
		"SM-D: BOOTING exit → ACTIVE when audio already unlocked (e.g. desktop build)")


func test_audio_unlocked_signal_promotes_banner_gate_to_active() -> void:
	var sut := _build_sut(GameStateMachine.GameState.BOOTING, true)
	var stub_gsm := sut._gsm as _StubGSM
	stub_gsm.simulate_state_change(GameStateMachine.GameState.IDLE)
	assert_eq(sut.get_hud_state(), sut._HudState.BANNER_GATE,
		"SM-B pre-condition: in BANNER_GATE")
	var stub_audio := sut._audio_manager as _StubAudioManager
	stub_audio.simulate_unlock()
	assert_eq(sut.get_hud_state(), sut._HudState.ACTIVE,
		"SM-B: audio_unlocked signal → BANNER_GATE → ACTIVE")


func test_gsm_suspended_sets_hud_suspended() -> void:
	var sut := _build_sut(GameStateMachine.GameState.IDLE, false)
	var stub_gsm := sut._gsm as _StubGSM
	stub_gsm.simulate_state_change(GameStateMachine.GameState.SUSPENDED)
	assert_eq(sut.get_hud_state(), sut._HudState.SUSPENDED,
		"GSM SUSPENDED → HUD _HudState.SUSPENDED")


func test_state_transitions_apply_matrix_on_each_change() -> void:
	var sut := _build_sut(GameStateMachine.GameState.IDLE, false)
	var stub_gsm := sut._gsm as _StubGSM
	# IDLE → WORKOUT_ACTIVE: HP should switch from AMBIENT to EMPHASIS
	stub_gsm.simulate_state_change(GameStateMachine.GameState.WORKOUT_ACTIVE)
	assert_eq(sut.get_element_emphasis(&"hp"), sut.Emphasis.EMPHASIS,
		"Matrix updated on IDLE→WORKOUT_ACTIVE: HP == ◉")
	# WORKOUT_ACTIVE → LOOT_DROP: HP switches to AMBIENT_DIM
	stub_gsm.simulate_state_change(GameStateMachine.GameState.LOOT_DROP)
	assert_eq(sut.get_element_emphasis(&"hp"), sut.Emphasis.AMBIENT_DIM,
		"Matrix updated on WORKOUT_ACTIVE→LOOT_DROP: HP == ○dim")
