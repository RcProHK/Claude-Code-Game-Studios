## #23 Inventory UI — lifecycle integration tests(story 002 scaffold)。
##
## Conventions: GUT test_ prefix;preload SUT pattern;engine 唔 tick test child
## _process — 全部經 injected clock advance(delta_ms) 手動 drive;
## frame-stepping 一律 await process_frame(禁 wait_frames)。
## FSM = #22 fork(CD binding)— 行為等價由兩邊 AC contract-pin,呢度驗
## #23-specific scaffold shape;full Group B lifecycle suite = story 007。
extends GutTest

const CoordinatorScript := preload("res://src/autoload/inventory_ui_coordinator.gd")
const GSMScript := preload("res://src/autoload/game_state_machine.gd")
const TimingConfig := preload("res://src/ui/character_screen/char_screen_timing_config.gd")
const PROJECT_GODOT := "res://project.godot"


## GSM mock — 3-arg signal shape(from, to, payload)+ cfis counter(= #22 先例)。
class MockGSM:
	extends Node
	signal state_changed(from_state, to_state, payload)
	var state: int = GSMScript.GameState.IDLE
	var cfis_call_count: int = 0
	var mutation_call_count: int = 0  # pure overlay assert(Rule 2 cite #22)

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


## #4 spy — 零 SFX assert + player-initiated cue 正控。
class MockAudio:
	extends Node
	var sfx_calls: Array = []

	func play_sfx(event_id: StringName) -> void:
		sfx_calls.append(event_id)


var _sut = null
var _gsm: MockGSM = null
var _audio: MockAudio = null


func before_each() -> void:
	_sut = CoordinatorScript.new()
	add_child_autofree(_sut)
	_gsm = MockGSM.new()
	add_child_autofree(_gsm)
	_audio = MockAudio.new()
	add_child_autofree(_audio)
	_sut._gsm = _gsm
	_sut._audio = _audio


func _open_to_state_open() -> void:
	assert_true(_sut.open())
	_sut.advance(TimingConfig.OPEN_ANIM_MS)
	assert_eq(_sut.get_screen_state(), CoordinatorScript.ScreenState.OPEN)


## ============ AC: boot shape(layer 61 PAUSABLE pre-warm hidden) ============

func test_boot_layer_is_61_pausable_hidden() -> void:
	var layer: CanvasLayer = _sut._layer
	assert_not_null(layer)
	assert_eq(layer.layer, 61, "ADR-0001 #23 revision pins layer 61")
	assert_eq(layer.process_mode, Node.PROCESS_MODE_PAUSABLE)
	assert_false(layer.visible, "pre-warmed hidden")


func test_boot_state_is_closed_with_zero_subscriptions() -> void:
	assert_eq(_sut.get_screen_state(), CoordinatorScript.ScreenState.CLOSED)
	assert_eq(_gsm.state_changed.get_connections().size(), 0, "CLOSED invariant @ boot(Rule 6)")
	assert_false(_sut.is_processing())


## ============ AC: project.godot 登記(tail after CharacterScreenCoordinator) ============

## Parse the [autoload] section of project.godot — ordered key list(#15 先例 pattern)。
func _read_autoload_order() -> Array[String]:
	var abs := ProjectSettings.globalize_path(PROJECT_GODOT)
	var file := FileAccess.open(abs, FileAccess.READ)
	assert_not_null(file, "project.godot must be readable")
	var in_section := false
	var order: Array[String] = []
	while not file.eof_reached():
		var line := file.get_line().strip_edges()
		if line == "[autoload]":
			in_section = true
			continue
		if in_section and line.begins_with("["):
			break
		if in_section and "=" in line and not line.begins_with(";"):
			order.append(line.split("=")[0].strip_edges())
	file.close()
	return order


func test_project_godot_registers_inventory_ui_after_character_screen() -> void:
	var order := _read_autoload_order()
	var cs_idx := order.find("CharacterScreenCoordinator")
	var iu_idx := order.find("InventoryUICoordinator")
	assert_gt(cs_idx, -1, "CharacterScreenCoordinator must be in project.godot autoloads")
	assert_gt(iu_idx, -1, "G-IU-2: InventoryUICoordinator must be in project.godot autoloads")
	assert_lt(cs_idx, iu_idx,
		"G-IU-2: InventoryUICoordinator tail-appends after CharacterScreenCoordinator (ADR-0008)")
	assert_eq(order.find("InventoryUICoordinator"), order.size() - 1,
		"tail append — #28 Telemetry not yet written, #23 is last")


## ============ AC: public surface(can_open whitelist + double guard) ============

func test_can_open_only_in_permitted_states() -> void:
	for s in GSMScript.GameState.values():
		_gsm.state = s
		var expected: bool = (
			s == GSMScript.GameState.IDLE or s == GSMScript.GameState.DISCONNECTED
		)
		assert_eq(_sut.can_open(), expected, str(GSMScript.GameState.find_key(s)))


func test_open_rejected_outside_permitted_and_zero_gsm_mutation() -> void:
	for s in GSMScript.GameState.values():
		if s == GSMScript.GameState.IDLE or s == GSMScript.GameState.DISCONNECTED:
			continue
		_gsm.state = s
		assert_false(_sut.open())
	assert_eq(_gsm.mutation_call_count, 0, "pure overlay — 零 GSM mutation(Rule 2 cite #22)")


## ============ AC: clean-slate reset(QA case:close→open 全 reset) ============

func test_open_clean_slate_resets_all_axes_and_pending() -> void:
	# Arrange: open,搞亂四軸 + pending,close 到 CLOSED。
	_gsm.state = GSMScript.GameState.IDLE
	_open_to_state_open()
	_sut._active_section = CoordinatorScript.SectionKind.MAILBOX
	_sut._slot_filter = CoordinatorScript.SlotFilter.WEAPON
	_sut._modal = CoordinatorScript.ModalKind.BULK_CONFIRM
	_sut._make_room_pending = &"item_abc"
	_sut.close()
	_sut.advance(TimingConfig.CLOSE_ANIM_MS)
	assert_eq(_sut.get_screen_state(), CoordinatorScript.ScreenState.CLOSED)
	# Act: re-open。
	assert_true(_sut.open())
	# Assert: 全 reset(INVENTORY / ALL / NONE / &"")— Rule 3。
	assert_eq(_sut.get_active_section(), CoordinatorScript.SectionKind.INVENTORY)
	assert_eq(_sut.get_slot_filter(), CoordinatorScript.SlotFilter.ALL)
	assert_eq(_sut.get_modal(), CoordinatorScript.ModalKind.NONE)
	assert_eq(_sut.get_make_room_pending(), &"", "make_room_pending 清空(States 表)")


## ============ AC: FSM fork(injected clock + timing knobs reuse) ============

func test_fsm_open_close_happy_path_on_injected_clock() -> void:
	_gsm.state = GSMScript.GameState.IDLE
	assert_true(_sut.open())
	assert_eq(_sut.get_screen_state(), CoordinatorScript.ScreenState.OPENING)
	_sut.advance(TimingConfig.OPEN_ANIM_MS - 1.0)
	assert_eq(_sut.get_screen_state(), CoordinatorScript.ScreenState.OPENING, "未夠 OPEN_ANIM_MS")
	_sut.advance(1.0)
	assert_eq(_sut.get_screen_state(), CoordinatorScript.ScreenState.OPEN)
	_sut.close()
	assert_eq(_sut.get_screen_state(), CoordinatorScript.ScreenState.CLOSING)
	_sut.advance(TimingConfig.CLOSE_ANIM_MS)
	assert_eq(_sut.get_screen_state(), CoordinatorScript.ScreenState.CLOSED)
	assert_false(_sut._layer.visible, "close 後 layer 收埋")
	# Player-initiated cues(reuse #22 family — GDD #4 row)。
	assert_eq(_audio.sfx_calls, [&"ui_charscreen_open", &"ui_charscreen_close"])


func test_open_subscribes_gsm_only_and_closed_disconnects() -> void:
	_gsm.state = GSMScript.GameState.IDLE
	_open_to_state_open()
	assert_eq(_gsm.cfis_call_count, 1, "GSM 經 cfis 訂(ADR-0006 C6)")
	assert_eq(_gsm.state_changed.get_connections().size(), 1)
	_sut.close()
	assert_eq(_gsm.state_changed.get_connections().size(), 1,
		"CLOSING 照聽 GSM — disconnect 唔可以提早(header rationale)")
	_sut.advance(TimingConfig.CLOSE_ANIM_MS)
	assert_eq(_gsm.state_changed.get_connections().size(), 0, "CLOSED invariant(Rule 6)")


## ============ AC: force-close / SUSPENDED / ghost guard(fork 語意) ============

func test_force_close_cancels_modal_and_pending_zero_sfx() -> void:
	_gsm.state = GSMScript.GameState.IDLE
	_open_to_state_open()
	_sut._modal = CoordinatorScript.ModalKind.MAKE_ROOM
	_sut._make_room_pending = &"item_xyz"
	_audio.sfx_calls.clear()  # open cue 唔算 — 由依家起計零
	_gsm.transition(GSMScript.GameState.WORKOUT_ACTIVE)
	assert_eq(_sut.get_modal(), CoordinatorScript.ModalKind.NONE, "modal 一律 cancel(Rule 3)")
	assert_eq(_sut.get_screen_state(), CoordinatorScript.ScreenState.FORCE_CLOSING)
	_sut.advance(TimingConfig.FORCE_CLOSE_MAX_MS)
	assert_eq(_sut.get_screen_state(), CoordinatorScript.ScreenState.CLOSED)
	assert_eq(_sut.get_make_room_pending(), &"", "force-close 清 pending(States 表)")
	assert_eq(_audio.sfx_calls.size(), 0, "force-close 零 play_sfx(CD C1)")


func test_suspended_snaps_to_closed_instantly_zero_sfx() -> void:
	_gsm.state = GSMScript.GameState.IDLE
	_open_to_state_open()
	_audio.sfx_calls.clear()
	_gsm.transition(GSMScript.GameState.SUSPENDED)
	assert_eq(_sut.get_screen_state(), CoordinatorScript.ScreenState.CLOSED,
		"SUSPENDED → instant snap,無 animation(Rule 3)")
	assert_eq(_audio.sfx_calls.size(), 0, "snap 零 SFX(CD C1)")


func test_idle_disconnected_toggle_keeps_screen_open_with_banner() -> void:
	_gsm.state = GSMScript.GameState.IDLE
	_open_to_state_open()
	assert_false(_sut.is_offline_banner_visible())
	_gsm.transition(GSMScript.GameState.DISCONNECTED)
	assert_eq(_sut.get_screen_state(), CoordinatorScript.ScreenState.OPEN, "唔 close(Rule 3)")
	assert_true(_sut.is_offline_banner_visible())
	_gsm.transition(GSMScript.GameState.IDLE)
	assert_false(_sut.is_offline_banner_visible())


func test_ghost_callv_after_close_is_hard_noop() -> void:
	# Arrange: open → close 到 CLOSED(handler 已 disconnect,但 ghost sentinel
	# 仍可 callv — = #22 EC-05 class)。
	_gsm.state = GSMScript.GameState.IDLE
	_open_to_state_open()
	_sut.close()
	_sut.advance(TimingConfig.CLOSE_ANIM_MS)
	assert_eq(_sut.get_screen_state(), CoordinatorScript.ScreenState.CLOSED)
	# Act: 手動模擬 ghost callv(deferred one-shot lambda 喺 close 後先 fire)。
	_sut._on_gsm_state_changed(
		GSMScript.GameState.IDLE, GSMScript.GameState.WORKOUT_ACTIVE, null)
	# Assert: hard no-op — state 不變,layer 不變。
	assert_eq(_sut.get_screen_state(), CoordinatorScript.ScreenState.CLOSED)
	assert_false(_sut._layer.visible)


func test_opening_abort_skips_open_straight_to_closed() -> void:
	_gsm.state = GSMScript.GameState.IDLE
	assert_true(_sut.open())
	assert_eq(_sut.get_screen_state(), CoordinatorScript.ScreenState.OPENING)
	_gsm.transition(GSMScript.GameState.WORKOUT_ACTIVE)
	assert_eq(_sut.get_screen_state(), CoordinatorScript.ScreenState.CLOSED,
		"OPENING abort 直接去 CLOSED,skip OPEN(= #22 States)")
