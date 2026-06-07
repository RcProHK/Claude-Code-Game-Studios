## #23 ARIA + audio — integration tests(story 015;AC-28/29)。
## AC-29 係 mapping-level:逐 event assert = map 指派 cue(唔係 set-membership);
## silent set 零 call;ui_back 零 call。真 #17 全隔離 fixture。
extends GutTest

const CoordinatorScript := preload("res://src/autoload/inventory_ui_coordinator.gd")
const InventoryScript := preload("res://src/autoload/inventory_system.gd")
const GSMScript := preload("res://src/autoload/game_state_machine.gd")
const TimingConfig := preload("res://src/ui/character_screen/char_screen_timing_config.gd")
const ListScript := preload("res://src/ui/inventory_ui/virtualized_card_list.gd")

const TABLE_PATH: String = "res://assets/data/equipment/stat_assignment_table.tres"
const COORDINATOR_SRC := "res://src/autoload/inventory_ui_coordinator.gd"
const ACQ: int = 1780304400


class MockGSM:
	extends Node
	signal state_changed(from_state, to_state, payload)
	var state: int = GSMScript.GameState.IDLE

	func get_current_state() -> int:
		return state

	func connect_for_initial_state(callable: Callable) -> void:
		state_changed.connect(callable)


class SfxSpy:
	extends Node
	var sfx_calls: Array = []

	func play_sfx(event_id: StringName) -> void:
		sfx_calls.append(event_id)


class AriaSpy:
	extends Node
	var announcements: Array = []

	func announce_aria(text: String) -> void:
		announcements.append(text)


var _sut = null
var _inv = null
var _gsm: MockGSM = null
var _audio: SfxSpy = null
var _aria: AriaSpy = null


func before_each() -> void:
	_inv = InventoryScript.new()
	_inv._persistence = MockPersistenceLayer.new()
	_inv._gsm = MockInventoryGSM.new()
	_inv._stat_system = MockInventoryStat.new()
	_inv._stat_table = load(TABLE_PATH)
	add_child_autofree(_inv)
	_gsm = MockGSM.new()
	add_child_autofree(_gsm)
	_audio = SfxSpy.new()
	add_child_autofree(_audio)
	_aria = AriaSpy.new()
	add_child_autofree(_aria)
	_sut = CoordinatorScript.new()
	add_child_autofree(_sut)
	_sut._gsm = _gsm
	_sut._inventory = _inv
	_sut._audio = _audio
	_sut._platform = _aria


func _put(id: StringName, lifecycle: int, locked: bool = false,
		mods: Dictionary = {}) -> void:
	var item: EquipmentItem = EquipmentItem.new()
	item.item_id = id
	item.item_type = LootEnums.ItemType.WEAPON
	item.slot_affinity = EquipmentEnums.EquipSlot.WEAPON
	item.lifecycle_state = lifecycle
	item.rarity = 0
	item.is_locked = locked
	item.acquired_at_unix = ACQ
	item.stat_modifiers = mods
	item.provenance_text = "prov %s" % String(id)
	_inv._items[id] = item


func _open() -> void:
	assert_true(_sut.open())
	_sut.advance(TimingConfig.OPEN_ANIM_MS)


## ============ AC-29: event→cue mapping(逐 event,唔係 set-membership) ============

func test_ac29_screen_open_close_exact_cues() -> void:
	_open()
	assert_eq(_audio.sfx_calls, [&"ui_charscreen_open"] as Array,
		"open → ui_charscreen_open(family cue;positive control)")
	_audio.sfx_calls.clear()
	_sut.close()
	assert_eq(_audio.sfx_calls, [&"ui_charscreen_close"] as Array)


func test_ac29_modal_open_close_cues_layer_by_layer() -> void:
	_put(&"item", EquipmentEnums.ItemLifecycle.IN_INVENTORY)
	_open()
	_audio.sfx_calls.clear()
	# inspect 開 → sheet_open;salvage 兩步第二層開 → sheet_open。
	_sut.open_inspect(&"item")
	assert_eq(_audio.sfx_calls, [&"ui_sheet_open"] as Array)
	_sut.request_salvage(&"item")
	assert_eq(_audio.sfx_calls, [&"ui_sheet_open", &"ui_sheet_open"] as Array)
	# 逐層退 = 該層一響 close ×2。
	_audio.sfx_calls.clear()
	_sut.handle_escape()  # → ITEM_INSPECT
	_sut.handle_escape()  # → NONE
	assert_eq(_audio.sfx_calls, [&"ui_sheet_close", &"ui_sheet_close"] as Array,
		"逐層退 = 該層一響 close")


func test_ac29_salvage_lock_error_cues() -> void:
	_put(&"junk", EquipmentEnums.ItemLifecycle.IN_INVENTORY)
	_put(&"lockable", EquipmentEnums.ItemLifecycle.IN_INVENTORY)
	_open()
	# 單件 salvage execute → ui_salvage_execute 恰好一響(零 sheet_close —
	# 兩層閂係 state change,execute 係 transaction stamp)。
	_sut.open_inspect(&"junk")
	_sut.request_salvage(&"junk")
	_audio.sfx_calls.clear()
	_sut.confirm_salvage()
	assert_eq(_audio.sfx_calls, [&"ui_salvage_execute"] as Array)
	# lock on / off。
	_audio.sfx_calls.clear()
	_sut.toggle_lock(&"lockable", true)
	assert_eq(_audio.sfx_calls, [&"ui_lock_on"] as Array)
	_audio.sfx_calls.clear()
	_sut.toggle_lock(&"lockable", false)
	assert_eq(_audio.sfx_calls, [&"ui_lock_off"] as Array)
	# error toast → ui_error。
	_audio.sfx_calls.clear()
	_sut.equip_item(&"ghost")
	assert_eq(_audio.sfx_calls, [&"ui_error"] as Array, "error toast → ui_error(map)")


func test_ac29_silent_set_zero_calls() -> void:
	# Silent 名單:equip / unequip / claim 成功 / section / filter 切換。
	_put(&"sword", EquipmentEnums.ItemLifecycle.IN_INVENTORY)
	_put(&"mb", EquipmentEnums.ItemLifecycle.IN_MAILBOX)
	_open()
	_audio.sfx_calls.clear()
	assert_true(_sut.equip_item(&"sword")["ok"])
	assert_eq(_audio.sfx_calls.size(), 0, "equip 成功 silent(明文 — toast/badge 承擔)")
	assert_true(_sut.unequip_slot(EquipmentEnums.EquipSlot.WEAPON)["ok"])
	assert_eq(_audio.sfx_calls.size(), 0, "unequip 成功 silent")
	assert_true(_sut.claim_item(&"mb")["ok"])
	assert_eq(_audio.sfx_calls.size(), 0, "claim 成功 silent(provisional — inversion 在案)")
	_sut.set_active_section(CoordinatorScript.SectionKind.MAILBOX)
	_sut.set_slot_filter(CoordinatorScript.SlotFilter.WEAPON)
	assert_eq(_audio.sfx_calls.size(), 0, "section / filter 切換 silent")


func test_ac29_make_room_bulk_entry_dual_cue() -> void:
	for i in 120:
		_put(StringName("f%d" % i), EquipmentEnums.ItemLifecycle.IN_INVENTORY)
	_put(&"wanted", EquipmentEnums.ItemLifecycle.IN_MAILBOX)
	_open()
	_audio.sfx_calls.clear()
	_sut.claim_item(&"wanted")
	assert_eq(_audio.sfx_calls, [&"ui_sheet_open"] as Array, "MAKE_ROOM 開一響")
	_audio.sfx_calls.clear()
	_sut.make_room_bulk_entry()
	assert_eq(_audio.sfx_calls, [&"ui_sheet_close", &"ui_sheet_open"] as Array,
		"入口 (a) 轉場 = 前層關一響 + 後層開一響(map「兩層連開 = 兩響」口徑)")


func test_ac29_ui_back_never_used() -> void:
	# ui_back 由 reuse 名單剔走(modal 退層 = ui_sheet_close)— source-level。
	var src: String = FileAccess.get_file_as_string(COORDINATOR_SRC)
	assert_false("ui_back" in src, "coordinator source 零 ui_back 引用")


func test_ac29_deferred_error_zero_toast_zero_announce_zero_cue() -> void:
	_put(&"sword", EquipmentEnums.ItemLifecycle.IN_INVENTORY)
	_open()
	_inv._mutating = true
	_audio.sfx_calls.clear()
	_aria.announcements.clear()
	_sut.equip_item(&"sword")
	assert_true(_sut.get_toast().is_empty(), "deferred 零 toast")
	assert_eq(_aria.announcements.size(), 0, "零 announce")
	assert_eq(_audio.sfx_calls.size(), 0, "零 cue")
	_inv._mutating = false


## ============ AC-28: ARIA announce set ============

func test_ac28_command_result_announces_with_positive_control() -> void:
	_put(&"sword", EquipmentEnums.ItemLifecycle.IN_INVENTORY)
	_put(&"junk", EquipmentEnums.ItemLifecycle.IN_INVENTORY)
	_put(&"mb", EquipmentEnums.ItemLifecycle.IN_MAILBOX)
	_open()
	_aria.announcements.clear()
	# Positive control + command set:equip / unequip / claim / salvage / error。
	_sut.equip_item(&"sword")
	assert_has(_aria.announcements, "已裝備 sword", "positive control — toast=ARIA live region")
	_sut.unequip_slot(EquipmentEnums.EquipSlot.WEAPON)
	assert_has(_aria.announcements, "已卸下")
	_sut.claim_item(&"mb")
	assert_has(_aria.announcements, "已領取")
	_sut.open_inspect(&"junk")
	_sut.request_salvage(&"junk")
	_sut.confirm_salvage()
	assert_has(_aria.announcements,
		"已分解 junk — +%d 碎片" % InventoryScript.salvage_yield(0))
	_sut.equip_item(&"ghost")
	assert_has(_aria.announcements, "件物品已唔存在", "error toast → announce")


func test_ac28_section_switch_coalesced_last_wins() -> void:
	_put(&"a", EquipmentEnums.ItemLifecycle.IN_INVENTORY)
	_put(&"mb", EquipmentEnums.ItemLifecycle.IN_MAILBOX)
	_open()
	_aria.announcements.clear()
	# Window 內連續切換 → 最後一條為準,window 完先讀一句。
	_sut.set_active_section(CoordinatorScript.SectionKind.MAILBOX)
	_sut.set_active_section(CoordinatorScript.SectionKind.INVENTORY)
	assert_eq(_aria.announcements.size(), 0, "window 未完 — 未讀")
	_sut.advance(TimingConfig.ARIA_COALESCE_WINDOW_MS)
	assert_eq(_aria.announcements, ["收藏庫,收藏 1 件"] as Array,
		"coalesced — 最後一條為準(section 名 + list summary)")


func test_ac28_filter_switch_announces_count() -> void:
	_put(&"sword", EquipmentEnums.ItemLifecycle.IN_INVENTORY)
	_open()
	_aria.announcements.clear()
	_sut.set_slot_filter(CoordinatorScript.SlotFilter.ARMOR)
	_sut.advance(TimingConfig.ARIA_COALESCE_WINDOW_MS)
	assert_eq(_aria.announcements, ["收藏 0 件"] as Array, "filter 切換報數(coalesced)")


func test_ac28_disabled_entry_focus_announces_reason() -> void:
	_open()
	_aria.announcements.clear()
	_sut.announce_disabled_focus("裝備", "先領取先用得")
	assert_eq(_aria.announcements, ["裝備 — 先領取先用得"] as Array,
		"SR 玩家唔可以得個謎(UI Req binding)")


## ============ focus-driven virtualization 接線(005 hook;SR policy) ============

func test_focus_driven_virtualization_window_follows_focus() -> void:
	# SR/keyboard focus 行到 pool 視窗邊 → 視窗跟 focus 推進(唔係跟 scroll)。
	var list = ListScript.new()
	list.size = Vector2(360.0, 560.0)
	add_child_autofree(list)
	var populated: Array = []
	var log_ref: Array = populated
	list.setup(
		func() -> Control: return Control.new(),
		func(_card: Control, index: int) -> void: log_ref.append(index))
	list.set_item_count(120, true)
	await get_tree().process_frame
	# focus 行到超過首屏件數嘅 row(AC-31 walkthrough case)。
	list.ensure_index_visible(40)
	assert_has(populated, 40, "視窗跟 focus 推進 — row 40 populate(SR policy)")