## #22 Character Screen — lifecycle + subscription integration tests
## (story 002 scaffold + story 007 FSM AC-10..17 + story 008 AC-18).
##
## Conventions: GUT test_ prefix;preload SUT pattern;engine 唔 tick test child
## _process — 全部經 injected clock advance(delta_ms) 手動 drive;
## frame-stepping 一律 await process_frame(禁 wait_frames)。
extends GutTest

const CoordinatorScript := preload("res://src/autoload/character_screen_coordinator.gd")
const GSMScript := preload("res://src/autoload/game_state_machine.gd")
const TimingConfig := preload("res://src/ui/character_screen/char_screen_timing_config.gd")


## GSM mock — 3-arg signal shape(from, to, payload)+ cfis counter(AC-18)。
class MockGSM:
	extends Node
	signal state_changed(from_state, to_state, payload)
	var state: int = 2  # GameState.IDLE
	var cfis_call_count: int = 0
	var mutation_call_count: int = 0  # AC-10 pure overlay assert

	func get_current_state() -> int:
		return state

	func connect_for_initial_state(callable: Callable) -> void:
		cfis_call_count += 1
		state_changed.connect(callable)
		# 真 GSM sentinel 係 deferred next-frame callv — ghost test 手動模擬

	func transition(to: int) -> void:
		var from: int = state
		state = to
		state_changed.emit(from, to, null)


## #11 mock — 5-arg signal + cfis counter(burst 喺 story 009 先用)。
class MockStat:
	extends Node
	signal stat_changed(stat_id, old_value, new_value, source, meta)
	var cfis_call_count: int = 0

	func connect_for_initial_state(callable: Callable) -> void:
		cfis_call_count += 1
		stat_changed.connect(callable)


## #26 mock — plain signal only(#26 冇 cfis — Pass 1 phantom fix)。
class MockAvatar:
	extends Node
	signal avatar_visual_updated(visual_state)


## #4 spy — AC-11 零 SFX assert + player-initiated cue 正控。
class MockAudio:
	extends Node
	var sfx_calls: Array = []

	func play_sfx(event_id: StringName) -> void:
		sfx_calls.append(event_id)


var _sut = null
var _gsm: MockGSM = null
var _stat: MockStat = null
var _avatar: MockAvatar = null
var _audio: MockAudio = null


func before_each() -> void:
	_sut = CoordinatorScript.new()
	add_child_autofree(_sut)
	_gsm = MockGSM.new()
	add_child_autofree(_gsm)
	_stat = MockStat.new()
	add_child_autofree(_stat)
	_avatar = MockAvatar.new()
	add_child_autofree(_avatar)
	_audio = MockAudio.new()
	add_child_autofree(_audio)
	_sut._gsm = _gsm
	_sut._stat_system = _stat
	_sut._avatar = _avatar
	_sut._audio = _audio


func _open_to_state_open() -> void:
	assert_true(_sut.open())
	_sut.advance(TimingConfig.OPEN_ANIM_MS)
	assert_eq(_sut.get_screen_state(), CoordinatorScript.ScreenState.OPEN)


## ============ story 002: boot shape ============

func test_boot_layer_is_60_pausable_hidden() -> void:
	var layer: CanvasLayer = _sut._layer
	assert_not_null(layer)
	assert_eq(layer.layer, 60, "ADR-0001 #22 revision pins layer 60")
	assert_eq(layer.process_mode, Node.PROCESS_MODE_PAUSABLE)
	assert_false(layer.visible, "pre-warmed hidden")


func test_boot_state_is_closed_with_zero_subscriptions() -> void:
	assert_eq(_sut.get_screen_state(), CoordinatorScript.ScreenState.CLOSED)
	assert_eq(_gsm.state_changed.get_connections().size(), 0, "CLOSED invariant @ boot")
	assert_eq(_stat.stat_changed.get_connections().size(), 0)
	assert_false(_sut.is_processing())


## ============ story 007: AC-10 — open guard + clean slate + pure overlay ============

func test_ac10_can_open_only_in_permitted_states() -> void:
	for s in GSMScript.GameState.values():
		_gsm.state = s
		var expected: bool = (
			s == GSMScript.GameState.IDLE or s == GSMScript.GameState.DISCONNECTED
		)
		assert_eq(_sut.can_open(), expected, str(GSMScript.GameState.find_key(s)))


func test_ac10_open_rejected_outside_permitted_and_zero_gsm_mutation() -> void:
	for s in GSMScript.GameState.values():
		if s == GSMScript.GameState.IDLE or s == GSMScript.GameState.DISCONNECTED:
			continue
		_gsm.state = s
		assert_false(_sut.open())
	assert_eq(_gsm.mutation_call_count, 0, "pure overlay — 零 GSM mutation (Rule 2)")


func test_ac10_open_clean_slate_reset() -> void:
	_gsm.state = GSMScript.GameState.IDLE
	_sut._active_panel = CoordinatorScript.PanelKind.LOADOUT
	_sut._modal = CoordinatorScript.ModalKind.SALVAGE_CONFIRM
	assert_true(_sut.open())
	assert_eq(_sut.get_active_panel(), CoordinatorScript.PanelKind.STATS)
	assert_eq(_sut.get_modal(), CoordinatorScript.ModalKind.NONE)


## ============ story 007: AC-11 — force-close × destructive modal,零 SFX ============

func test_ac11_force_close_cancels_modal_within_cap_zero_sfx() -> void:
	_gsm.state = GSMScript.GameState.IDLE
	_open_to_state_open()
	_sut._modal = CoordinatorScript.ModalKind.SALVAGE_CONFIRM
	_audio.sfx_calls.clear()  # open cue 唔算 — 由依家起計零
	_gsm.transition(GSMScript.GameState.WORKOUT_ACTIVE)
	assert_eq(_sut.get_modal(), CoordinatorScript.ModalKind.NONE, "modal cancel,永不 confirm (EC-01)")
	assert_eq(_sut.get_screen_state(), CoordinatorScript.ScreenState.FORCE_CLOSING)
	_sut.advance(TimingConfig.FORCE_CLOSE_MAX_MS)  # injected clock,唔係 wall clock
	assert_eq(_sut.get_screen_state(), CoordinatorScript.ScreenState.CLOSED)
	assert_eq(_audio.sfx_calls.size(), 0, "force-close 零 play_sfx (CD C1)")


func test_ac11_force_close_from_opening_aborts_straight_to_closed() -> void:
	_gsm.state = GSMScript.GameState.IDLE
	assert_true(_sut.open())  # OPENING
	_gsm.transition(GSMScript.GameState.COMBAT_ACTIVE)
	assert_eq(_sut.get_screen_state(), CoordinatorScript.ScreenState.CLOSED,
		"OPENING abort 直接 CLOSED,skip OPEN (States table)")


## ============ story 007: AC-12 — SUSPENDED instant snap,唔 auto-reopen ============

func test_ac12_suspended_instant_snap_and_no_auto_reopen() -> void:
	_gsm.state = GSMScript.GameState.IDLE
	_open_to_state_open()
	_audio.sfx_calls.clear()
	_gsm.transition(GSMScript.GameState.SUSPENDED)
	assert_eq(_sut.get_screen_state(), CoordinatorScript.ScreenState.CLOSED, "instant snap,無 animation")
	assert_false(_sut._layer.visible)
	assert_eq(_audio.sfx_calls.size(), 0, "snap 零 SFX (CD C1)")
	# resume 返 IDLE → 唔 auto-reopen(screen 係玩家主動行為 — CD 裁決 3)
	_gsm.transition(GSMScript.GameState.IDLE)
	assert_eq(_sut.get_screen_state(), CoordinatorScript.ScreenState.CLOSED)


## ============ story 007: AC-13 — IDLE↔DISCONNECTED banner toggle ============

func test_ac13_idle_disconnected_toggle_keeps_screen_and_modal() -> void:
	_gsm.state = GSMScript.GameState.IDLE
	_open_to_state_open()
	_sut._modal = CoordinatorScript.ModalKind.ITEM_INSPECT
	_gsm.transition(GSMScript.GameState.DISCONNECTED)
	assert_eq(_sut.get_screen_state(), CoordinatorScript.ScreenState.OPEN, "唔 close")
	assert_true(_sut.is_offline_banner_visible())
	assert_eq(_sut.get_modal(), CoordinatorScript.ModalKind.ITEM_INSPECT, "modal 唔受影響 (EC-06)")
	_gsm.transition(GSMScript.GameState.IDLE)
	assert_false(_sut.is_offline_banner_visible())
	assert_eq(_sut.get_screen_state(), CoordinatorScript.ScreenState.OPEN)


## ============ story 007: AC-14 — DISCONNECTED 直跳 workout ============

func test_ac14_disconnected_direct_jump_force_closes() -> void:
	_gsm.state = GSMScript.GameState.DISCONNECTED
	_open_to_state_open()
	assert_true(_sut.is_offline_banner_visible())
	_gsm.transition(GSMScript.GameState.WORKOUT_ACTIVE)  # resume_target 直跳,唔經 IDLE
	assert_eq(_sut.get_screen_state(), CoordinatorScript.ScreenState.FORCE_CLOSING)
	_sut.advance(TimingConfig.FORCE_CLOSE_MAX_MS)
	assert_eq(_sut.get_screen_state(), CoordinatorScript.ScreenState.CLOSED)


## ============ story 007: AC-15 — 3 close paths × 零 active subscription ============

func _assert_all_disconnected(path_name: String) -> void:
	assert_false(_gsm.state_changed.is_connected(_sut._on_gsm_state_changed),
		"%s: GSM disconnected" % path_name)
	assert_false(_stat.stat_changed.is_connected(_sut._on_stat_changed),
		"%s: #11 disconnected" % path_name)
	assert_false(_avatar.avatar_visual_updated.is_connected(_sut._on_avatar_visual_updated),
		"%s: #26 disconnected" % path_name)


func test_ac15_normal_close_zero_subscriptions() -> void:
	_gsm.state = GSMScript.GameState.IDLE
	_open_to_state_open()
	_sut.close()
	_sut.advance(TimingConfig.CLOSE_ANIM_MS)
	assert_eq(_sut.get_screen_state(), CoordinatorScript.ScreenState.CLOSED)
	_assert_all_disconnected("normal")


func test_ac15_force_close_zero_subscriptions() -> void:
	_gsm.state = GSMScript.GameState.IDLE
	_open_to_state_open()
	_gsm.transition(GSMScript.GameState.WORKOUT_ACTIVE)
	_sut.advance(TimingConfig.FORCE_CLOSE_MAX_MS)
	_assert_all_disconnected("force")


func test_ac15_suspend_snap_zero_subscriptions() -> void:
	_gsm.state = GSMScript.GameState.IDLE
	_open_to_state_open()
	_gsm.transition(GSMScript.GameState.SUSPENDED)
	_assert_all_disconnected("suspend-snap")


## ============ story 007: AC-16 — CLOSING re-tap ignore ============

func test_ac16_reopen_during_closing_is_ignored() -> void:
	_gsm.state = GSMScript.GameState.IDLE
	_open_to_state_open()
	_sut.close()
	assert_eq(_sut.get_screen_state(), CoordinatorScript.ScreenState.CLOSING)
	assert_false(_sut.open(), "CLOSING re-tap = ignore,無鬼 open")
	_sut.advance(TimingConfig.CLOSE_ANIM_MS)
	assert_eq(_sut.get_screen_state(), CoordinatorScript.ScreenState.CLOSED)


## ============ story 007: AC-17 — 非 active states signal no-op(含 CLOSED ghost)============

func test_ac17_data_signals_noop_in_closing_states() -> void:
	_gsm.state = GSMScript.GameState.IDLE
	_open_to_state_open()
	_sut.close()  # CLOSING
	_stat.stat_changed.emit(&"attack_power", 84.0, 90.0, 0, null)
	_avatar.avatar_visual_updated.emit(null)
	assert_eq(_sut.get_screen_state(), CoordinatorScript.ScreenState.CLOSING, "no-op,無 error")


func test_ac17_ghost_sentinel_callv_at_closed_is_noop() -> void:
	_gsm.state = GSMScript.GameState.IDLE
	_open_to_state_open()
	_sut.close()
	_sut.advance(TimingConfig.CLOSE_ANIM_MS)  # CLOSED;disconnect 已做
	# Ghost callv:真 GSM 嘅 deferred sentinel disconnect 取消唔到 — 手動重演
	_sut._on_gsm_state_changed(GSMScript.GameState.IDLE, GSMScript.GameState.IDLE, null)
	assert_eq(_sut.get_screen_state(), CoordinatorScript.ScreenState.CLOSED, "CLOSED ghost callv no-op")
	_sut._on_stat_changed(&"STR", 30.0, 47.0, 0, null)
	assert_eq(_sut.get_screen_state(), CoordinatorScript.ScreenState.CLOSED)


func test_closing_upgrades_to_force_closing_on_gsm_exit() -> void:
	_gsm.state = GSMScript.GameState.IDLE
	_open_to_state_open()
	_sut.close()  # CLOSING — GSM 照聽 (States table rationale)
	_gsm.transition(GSMScript.GameState.WORKOUT_ACTIVE)
	assert_eq(_sut.get_screen_state(), CoordinatorScript.ScreenState.FORCE_CLOSING,
		"CLOSING 期間 GSM 退出 permitted → upgrade FORCE_CLOSING")


func test_closing_suspended_snaps() -> void:
	_gsm.state = GSMScript.GameState.IDLE
	_open_to_state_open()
	_sut.close()
	_gsm.transition(GSMScript.GameState.SUSPENDED)
	assert_eq(_sut.get_screen_state(), CoordinatorScript.ScreenState.CLOSED, "CLOSING + SUSPENDED → snap")


## ============ story 008: AC-18 — cfis ×2 + #26 plain connect ============

func test_ac18_subscription_mechanisms() -> void:
	_gsm.state = GSMScript.GameState.IDLE
	assert_true(_sut.open())
	assert_eq(_gsm.cfis_call_count, 1, "GSM 經 connect_for_initial_state 恰好一次")
	assert_eq(_stat.cfis_call_count, 1, "#11 經 connect_for_initial_state 恰好一次")
	# 連接總數 = 恰好 cfis/plain 嗰一條(零額外 raw connect)
	assert_eq(_gsm.state_changed.get_connections().size(), 1)
	assert_eq(_stat.stat_changed.get_connections().size(), 1)
	assert_eq(_avatar.avatar_visual_updated.get_connections().size(), 1,
		"#26 plain connect(cfis 對 #26 係 phantom — Pass 1 fix)")


func test_ac18_reopen_resubscribes_exactly_once() -> void:
	_gsm.state = GSMScript.GameState.IDLE
	_open_to_state_open()
	_sut.close()
	_sut.advance(TimingConfig.CLOSE_ANIM_MS)
	assert_true(_sut.open(), "re-open")
	assert_eq(_gsm.cfis_call_count, 2, "每次 open 重新 cfis(close 已 disconnect)")
	assert_eq(_gsm.state_changed.get_connections().size(), 1, "唔會疊 connection")


## ============ player-initiated SFX 正控(CD C1 另一半;AC-42 全套喺 story 019)============

func test_player_open_close_fire_cues() -> void:
	_gsm.state = GSMScript.GameState.IDLE
	_open_to_state_open()
	_sut.close()
	assert_eq(_audio.sfx_calls, [&"ui_charscreen_open", &"ui_charscreen_close"],
		"player-initiated 先有 cue")
