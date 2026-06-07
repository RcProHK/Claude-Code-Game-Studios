## #23 Inventory UI — lifecycle integration tests。
## story 002:scaffold shape(boot / FSM fork / clean-slate / boot order)。
## story 007:Group B AC suite(AC-04..08 + AC-37 — mechanism-agnostic 驗收;
## AC-04 = whitelist tests / AC-07 = clean-slate test 已喺 002 段 cover)。
##
## Conventions: GUT test_ prefix;preload SUT pattern;engine 唔 tick test child
## _process — 全部經 injected clock advance(delta_ms) 手動 drive;
## frame-stepping 一律 await process_frame(禁 wait_frames)。
## FSM = #22 fork(CD binding)— 行為等價由兩邊 AC contract-pin。
extends GutTest

const CoordinatorScript := preload("res://src/autoload/inventory_ui_coordinator.gd")
const CharScreenScript := preload("res://src/autoload/character_screen_coordinator.gd")
const GSMScript := preload("res://src/autoload/game_state_machine.gd")
const TimingConfig := preload("res://src/ui/character_screen/char_screen_timing_config.gd")
const InventoryScript := preload("res://src/autoload/inventory_system.gd")
const PROJECT_GODOT := "res://project.godot"
const COORDINATOR_SRC := "res://src/autoload/inventory_ui_coordinator.gd"


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


## ============ story 007: Group B AC suite ============


func _put_item(inv, id: StringName, lifecycle: int) -> void:
	var item: EquipmentItem = EquipmentItem.new()
	item.item_id = id
	item.slot_affinity = EquipmentEnums.EquipSlot.WEAPON
	item.lifecycle_state = lifecycle
	item.acquired_at_unix = 1000
	inv._items[id] = item


func test_ac05_force_close_with_bulk_confirm_inventory_untouched() -> void:
	# Arrange: 真 #17(count/shards 基準)+ BULK_CONFIRM 開緊。
	var inv = InventoryScript.new()
	inv._persistence = MockPersistenceLayer.new()  # 隔離 user://(_ready 前注入)
	add_child_autofree(inv)
	_put_item(inv, &"a", EquipmentEnums.ItemLifecycle.IN_INVENTORY)
	_put_item(inv, &"b", EquipmentEnums.ItemLifecycle.IN_INVENTORY)
	inv._forge_shards = 500
	_sut._inventory = inv
	_gsm.state = GSMScript.GameState.IDLE
	# Positive control(AC-05 同 test):player-initiated open cue 恰好一響。
	_open_to_state_open()
	assert_eq(_audio.sfx_calls.count(&"ui_charscreen_open"), 1,
		"positive control — open cue 一響(同 test 內,防 spy 接錯線假陰性)")
	_sut._modal = CoordinatorScript.ModalKind.BULK_CONFIRM
	_audio.sfx_calls.clear()
	# Act: GSM → WORKOUT_ACTIVE(force-close)。
	_gsm.transition(GSMScript.GameState.WORKOUT_ACTIVE)
	# Assert: modal cancel(永不 confirm — #17 不變)+ ≤cap CLOSED + 零 SFX。
	assert_eq(_sut.get_modal(), CoordinatorScript.ModalKind.NONE)
	_sut.advance(TimingConfig.FORCE_CLOSE_MAX_MS)
	assert_eq(_sut.get_screen_state(), CoordinatorScript.ScreenState.CLOSED)
	assert_eq(inv.get_inventory_count(), 2, "bulk 永不被 system event confirm(AC-05)")
	assert_eq(inv.get_forge_shards(), 500, "shards 不變")
	assert_eq(_audio.sfx_calls.size(), 0, "force-close 零 play_sfx(CD C1)")


func test_ac06_suspended_snap_and_resume_does_not_auto_reopen() -> void:
	# Arrange
	_gsm.state = GSMScript.GameState.IDLE
	_open_to_state_open()
	# Act ①: SUSPENDED → instant snap(無 animation)。
	_gsm.transition(GSMScript.GameState.SUSPENDED)
	assert_eq(_sut.get_screen_state(), CoordinatorScript.ScreenState.CLOSED, "instant snap")
	# Act ②: resume 返 IDLE。
	_gsm.transition(GSMScript.GameState.IDLE)
	# Assert: 唔 auto-reopen(player-initiated only — AC-06)。
	assert_eq(_sut.get_screen_state(), CoordinatorScript.ScreenState.CLOSED,
		"resume 唔 auto-reopen")
	assert_false(_sut._layer.visible)


func test_ac08_subscription_introspection_and_three_close_paths() -> void:
	_gsm.state = GSMScript.GameState.IDLE
	# ① Positive:open 後 GSM connect 存在,而且只此一條。
	_open_to_state_open()
	assert_eq(_gsm.state_changed.get_connections().size(), 1,
		"GSM connect 存在(positive)+ 只此一條(AC-08)")
	# ② #11/#26 零 connect:#23 根本冇 stat/avatar seam(明文唔訂 — GDD #26/#11 row)。
	assert_null(_sut.get("_stat_system"), "#23 冇 #11 seam")
	assert_null(_sut.get("_avatar"), "#23 冇 #26 seam")
	# ③ 零 is_input_permitted call(Rule 1 明文拒用 #33)— source-level introspect。
	var src: String = FileAccess.get_file_as_string(COORDINATOR_SRC)
	assert_false("is_input_permitted" in src.replace("拒用 #33 is_input_permitted", ""),
		"coordinator source 零 is_input_permitted 引用(doc comment 豁免)")
	# ④ 3 close paths 後零 active subscription:
	# path 1 — player close。
	_sut.close()
	_sut.advance(TimingConfig.CLOSE_ANIM_MS)
	assert_eq(_gsm.state_changed.get_connections().size(), 0, "player close → 零 active")
	# path 2 — force-close。
	_open_to_state_open()
	_gsm.transition(GSMScript.GameState.WORKOUT_ACTIVE)
	_sut.advance(TimingConfig.FORCE_CLOSE_MAX_MS)
	assert_eq(_gsm.state_changed.get_connections().size(), 0, "force-close → 零 active")
	# path 3 — SUSPENDED snap。
	_gsm.state = GSMScript.GameState.IDLE
	_open_to_state_open()
	_gsm.transition(GSMScript.GameState.SUSPENDED)
	assert_eq(_gsm.state_changed.get_connections().size(), 0, "snap → 零 active")


## ============ story 016: G-IU-4 #22 link + sequential glue(AC-09) ============

func _make_charscreen() -> Node:
	var cs = CharScreenScript.new()
	add_child_autofree(cs)
	cs._gsm = _gsm        # 共用 GSM(sequential 切換同一 state machine)
	cs._audio = _audio    # 共用 audio spy(雙 cue 政策 assert)
	cs._inventory_ui = _sut  # G-IU-4 glue seam(test 注入 — 唔行 /root)
	return cs


func test_ac09_link_sequential_close_then_open_with_dual_cue() -> void:
	# Arrange: #22 open 喺 LOADOUT panel。
	var cs := _make_charscreen()
	_gsm.state = GSMScript.GameState.IDLE
	assert_true(cs.open())
	cs.advance(TimingConfig.OPEN_ANIM_MS)
	cs.set_active_panel(CharScreenScript.PanelKind.LOADOUT)
	_audio.sfx_calls.clear()
	# Act: 「查看全部 →」tap — close 後同 gesture deferred open #23。
	cs.loadout_view_all_tap()
	assert_eq(cs.get_screen_state(), CharScreenScript.ScreenState.CLOSING,
		"#22 normal close path")
	await get_tree().process_frame  # deferred open fires
	# Assert: sequential — #23 OPENING(CLOSING×OPENING crossfade 接受)。
	assert_eq(_sut.get_screen_state(), CoordinatorScript.ScreenState.OPENING,
		"#23 同 gesture deferred open(EC-11 — 唔等 #22 CLOSED)")
	# 雙 cue 各一響(政策 verify — sequential 切換嘅誠實聲)。
	assert_eq(_audio.sfx_calls.count(&"ui_charscreen_close"), 1)
	assert_eq(_audio.sfx_calls.count(&"ui_charscreen_open"), 1)
	# 收口:兩邊 settle。
	cs.advance(TimingConfig.CLOSE_ANIM_MS)
	_sut.advance(TimingConfig.OPEN_ANIM_MS)
	assert_eq(cs.get_screen_state(), CharScreenScript.ScreenState.CLOSED)
	assert_eq(_sut.get_screen_state(), CoordinatorScript.ScreenState.OPEN)


func test_ac09_gsm_race_both_closed_no_limbo() -> void:
	# Arrange
	var cs := _make_charscreen()
	_gsm.state = GSMScript.GameState.IDLE
	assert_true(cs.open())
	cs.advance(TimingConfig.OPEN_ANIM_MS)
	cs.set_active_panel(CharScreenScript.PanelKind.LOADOUT)
	# Act: link tap 之後、deferred open 之前 GSM 轉 state(race)。
	cs.loadout_view_all_tap()
	_gsm.transition(GSMScript.GameState.WORKOUT_ACTIVE)
	await get_tree().process_frame  # deferred open fires — double guard 拒
	# Assert: #23 double guard 拒 → 兩邊 CLOSED 無 limbo(EC-11)。
	assert_eq(_sut.get_screen_state(), CoordinatorScript.ScreenState.CLOSED,
		"#23 open() double guard 拒(GSM ∉ whitelist)")
	cs.advance(TimingConfig.FORCE_CLOSE_MAX_MS + TimingConfig.CLOSE_ANIM_MS)
	assert_eq(cs.get_screen_state(), CharScreenScript.ScreenState.CLOSED, "無 limbo")


func test_ac09_link_when_inv_ui_already_open_is_noop() -> void:
	# 邊界:#23 已 OPEN(理論 race)→ deferred open no-op(double guard)。
	var cs := _make_charscreen()
	_gsm.state = GSMScript.GameState.IDLE
	_open_to_state_open()  # #23 已 OPEN
	assert_true(cs.open())
	cs.advance(TimingConfig.OPEN_ANIM_MS)
	cs.set_active_panel(CharScreenScript.PanelKind.LOADOUT)
	cs.loadout_view_all_tap()
	await get_tree().process_frame
	assert_eq(_sut.get_screen_state(), CoordinatorScript.ScreenState.OPEN,
		"#23 已 OPEN — open() no-op(state != CLOSED),無 crash 無 reset")


func test_ac09_rapid_double_tap_no_crash() -> void:
	# 邊界:rapid double-tap link — 第二下 close no-op + 第二下 deferred open false。
	var cs := _make_charscreen()
	_gsm.state = GSMScript.GameState.IDLE
	assert_true(cs.open())
	cs.advance(TimingConfig.OPEN_ANIM_MS)
	cs.set_active_panel(CharScreenScript.PanelKind.LOADOUT)
	cs.loadout_view_all_tap()
	cs.loadout_view_all_tap()  # 第二下:state CLOSING — handler guard 拒
	await get_tree().process_frame
	_sut.advance(TimingConfig.OPEN_ANIM_MS)
	assert_eq(_sut.get_screen_state(), CoordinatorScript.ScreenState.OPEN,
		"double-tap 安全 — 一次 open")


func test_ac37_zero_persist_full_session_with_positive_control() -> void:
	# Arrange: mock persistence + write spy 注入 #17 seam(_ready 前 — 隔離
	# user:// 兼收集 writes);真 #17 + coordinator full session。
	var inv = InventoryScript.new()
	var mock_persist := MockPersistenceLayer.new()
	var write_log: Array = []
	mock_persist.attach_write_spy(write_log.append)
	inv._persistence = mock_persist
	add_child_autofree(inv)
	_put_item(inv, &"a", EquipmentEnums.ItemLifecycle.IN_INVENTORY)
	_sut._inventory = inv
	_gsm.state = GSMScript.GameState.IDLE
	write_log.clear()  # boot 階段(#17 自己)唔計 — session 由 open 起
	# Act: 完整操作 session — open / section 切換 / filter / 3 close paths。
	_open_to_state_open()
	_sut.set_active_section(CoordinatorScript.SectionKind.MAILBOX)
	_sut.set_active_section(CoordinatorScript.SectionKind.INVENTORY)
	_sut.set_slot_filter(CoordinatorScript.SlotFilter.WEAPON)
	_sut.close()
	_sut.advance(TimingConfig.CLOSE_ANIM_MS)
	_open_to_state_open()
	_gsm.transition(GSMScript.GameState.WORKOUT_ACTIVE)  # force-close
	_sut.advance(TimingConfig.FORCE_CLOSE_MAX_MS)
	_gsm.state = GSMScript.GameState.IDLE
	_open_to_state_open()
	_gsm.transition(GSMScript.GameState.SUSPENDED)  # snap
	# Assert ①: 零 write(#23 連 namespace 都唔開 — 全 session 零 write)。
	assert_eq(write_log.size(), 0,
		"完整 session + 3 close paths → 零 PersistenceLayer write(AC-37)")
	# Assert ②(positive control):#17 自己 write 照行(spy 接線正確,唔係假陰性)。
	inv.set_lock(&"a", true)  # 真 #17 command → _mark_dirty_and_flush
	assert_gt(write_log.size(), 0, "positive control — #17 自己嘅 write 照行")
	for w: Dictionary in write_log:
		assert_true(String(w["key"]).begins_with("inventory"),
			"所有 write 都係 #17-origin(inventory.*)— 零 #23 key:%s" % w["key"])
