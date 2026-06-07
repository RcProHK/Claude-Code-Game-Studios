## #23 bulk sheets — integration tests(真 #17 fixture,全隔離)。
## story 011:BULK_SELECT re-preview + BULK_CONFIRM D5 三層 + 退層 routing
## (AC-19/20/24)。story 012:execute(AC-21/22/23/36)— 加入呢個 file。
extends GutTest

const CoordinatorScript := preload("res://src/autoload/inventory_ui_coordinator.gd")
const InventoryScript := preload("res://src/autoload/inventory_system.gd")
const GSMScript := preload("res://src/autoload/game_state_machine.gd")
const TimingConfig := preload("res://src/ui/character_screen/char_screen_timing_config.gd")

const TABLE_PATH: String = "res://assets/data/equipment/stat_assignment_table.tres"
const ACQ: int = 1780304400


class MockGSM:
	extends Node
	signal state_changed(from_state, to_state, payload)
	var state: int = GSMScript.GameState.IDLE

	func get_current_state() -> int:
		return state

	func connect_for_initial_state(callable: Callable) -> void:
		state_changed.connect(callable)


var _sut = null
var _inv = null
var _gsm: MockGSM = null


func before_each() -> void:
	_inv = InventoryScript.new()
	_inv._persistence = MockPersistenceLayer.new()
	_inv._gsm = MockInventoryGSM.new()
	_inv._stat_system = MockInventoryStat.new()
	_inv._stat_table = load(TABLE_PATH)
	add_child_autofree(_inv)
	_gsm = MockGSM.new()
	add_child_autofree(_gsm)
	_sut = CoordinatorScript.new()
	add_child_autofree(_sut)
	_sut._gsm = _gsm
	_sut._inventory = _inv


func _put(id: StringName, rarity: int, lifecycle: int, locked: bool = false,
		with_receipt: bool = false, slot: int = EquipmentEnums.EquipSlot.WEAPON) -> void:
	var item: EquipmentItem = EquipmentItem.new()
	item.item_id = id
	item.item_type = LootEnums.ItemType.WEAPON
	item.slot_affinity = slot
	item.lifecycle_state = lifecycle
	item.rarity = rarity
	item.is_locked = locked
	item.acquired_at_unix = ACQ
	item.provenance_text = "prov %s" % String(id)
	if with_receipt:
		item.source_receipt = SourceReceipt.new()
	_inv._items[id] = item


func _open() -> void:
	assert_true(_sut.open())
	_sut.advance(TimingConfig.OPEN_ANIM_MS)


## ============ AC-19: BULK_SELECT rows 真值 + re-preview ============

func test_ac19_select_rows_match_preview_truth() -> void:
	# Arrange: rarity 0 ×2(1 locked)+ rarity 2 receipt 件。
	_put(&"c1", 0, EquipmentEnums.ItemLifecycle.IN_INVENTORY)
	_put(&"c2_locked", 0, EquipmentEnums.ItemLifecycle.IN_INVENTORY, true)
	_put(&"r1", 2, EquipmentEnums.ItemLifecycle.IN_INVENTORY, false, true)
	_open()
	_sut.open_bulk_select()
	assert_eq(_sut.get_modal(), CoordinatorScript.ModalKind.BULK_SELECT)
	# Act
	var rows: Array = _sut.get_bulk_select_rows()
	# Assert: 5 rows = preview 真值。
	assert_eq(rows.size(), 5)
	assert_eq(rows[0]["count"], 1, "rarity 0:locked 唔入(preview 真值)")
	assert_eq(rows[0]["yield"], InventoryScript.salvage_yield(0))
	assert_false(rows[0]["grayed"])
	assert_eq(rows[1]["count"], 0)
	assert_true(rows[1]["grayed"], "0 件 row 灰掉(唔 disable)")
	assert_eq(rows[2]["receipt_count"], 1)


func test_ac19_zero_row_tap_notes_ec02_ec03_variants() -> void:
	# Arrange: rarity 0 owned 2 全 locked(EC-03);rarity 3 零 owned(EC-02)。
	_put(&"lk1", 0, EquipmentEnums.ItemLifecycle.IN_INVENTORY, true)
	_put(&"lk2", 0, EquipmentEnums.ItemLifecycle.IN_MAILBOX, true)
	_open()
	_sut.open_bulk_select()
	# Act + Assert(EC-03 locked variant — N = view-model 點算)。
	var r0: Dictionary = _sut.bulk_row_tap(0)
	assert_false(r0["opened"])
	assert_eq(r0["note"], "0 件可分解(2 件已鎖)", "EC-03 — 30 件得 0 唔解釋就讀成 bug")
	assert_eq(_sut.get_modal(), CoordinatorScript.ModalKind.BULK_SELECT, "唔開 CONFIRM")
	# (EC-02 — owned 0)。
	var r3: Dictionary = _sut.bulk_row_tap(3)
	assert_eq(r3["note"], "呢個 tier 冇可分解嘅件")


func test_ac19_reverse_drift_tap_re_preview_opens_confirm() -> void:
	# Arrange: sheet enter 時 rarity 1 零件(row render 0)。
	_open()
	_sut.open_bulk_select()
	assert_true(_sut.get_bulk_select_rows()[1]["grayed"])
	# Drift: enter 之後先有件(claim auto / 另一路徑)。
	_put(&"late", 1, EquipmentEnums.ItemLifecycle.IN_INVENTORY)
	# Act: tap — tap-time re-preview 攞新真值。
	var result: Dictionary = _sut.bulk_row_tap(1)
	# Assert: reverse drift → 照開 CONFIRM(Rule 15)。
	assert_true(result["opened"])
	assert_eq(_sut.get_modal(), CoordinatorScript.ModalKind.BULK_CONFIRM)
	assert_eq(_sut.get_bulk_confirm_view()["header"]["count"], 1, "tap-time 數")


## ============ AC-20: BULK_CONFIRM D5 三層 + 結構 ============

func test_ac20_three_honesty_layers_with_cap_and_pending_warning() -> void:
	# Arrange: 9 receipt inventory 件 + 2 mailbox plain(1 = pending target)+
	# 1 equipped — 全 rarity 0 unlocked。
	for i in 9:
		_put(StringName("rc_%d" % i), 0, EquipmentEnums.ItemLifecycle.IN_INVENTORY,
			false, true)
	_put(&"wanted", 0, EquipmentEnums.ItemLifecycle.IN_MAILBOX)
	_put(&"mb2", 0, EquipmentEnums.ItemLifecycle.IN_MAILBOX)
	_put(&"worn", 0, EquipmentEnums.ItemLifecycle.EQUIPPED)
	_inv._loadout[EquipmentEnums.EquipSlot.WEAPON] = &"worn"
	_open()
	_sut._make_room_pending = &"wanted"  # MAKE_ROOM context(story 009 set)
	_sut.open_bulk_select()
	_sut.bulk_row_tap(0)
	# Act
	var view: Dictionary = _sut.get_bulk_confirm_view()
	# Assert ①: receipt itemised cap 8 +「+1 more」;總數照報(header + warning)。
	assert_eq((view["receipt_lines"] as Array).size(), 8, "cap BULK_CONFIRM_RECEIPT_LIST_MAX")
	assert_eq(view["receipt_overflow"], "+1 more")
	assert_eq(view["header"]["receipt_total_line"], "內含 9 件收據件", "above-fold 總數")
	assert_eq(view["receipt_warning"], "呢 9 件帶收據,分解後簽名永久消失")
	assert_ne(view["receipt_lines"][0]["provenance"], "", "逐件列 name + provenance")
	# Assert ②: conditional breakdown(M=2 mailbox、K=1 現役)。
	assert_eq(view["breakdown_line"], "內含信箱 2 件、現役 1 件")
	# Assert ③: pending warning 第一行(rarity match + unlocked)。
	assert_eq(view["pending_warning"], "⚠ 包括你想領取嗰件「wanted」")
	# 結構:header count/yield above-fold + footer default focus = cancel。
	assert_eq(view["header"]["count"], 12)
	assert_eq(view["default_focus"], "cancel")


func test_ac20_breakdown_and_warning_zero_cases_render_nothing() -> void:
	# Arrange: 純 inventory plain 件(零信箱零現役零 receipt 零 pending)。
	_put(&"plain", 0, EquipmentEnums.ItemLifecycle.IN_INVENTORY)
	_open()
	_sut.open_bulk_select()
	_sut.bulk_row_tap(0)
	var view: Dictionary = _sut.get_bulk_confirm_view()
	# Assert: 零中招 → 全部唔出(static copy 喺冇人中招時係 noise)。
	assert_eq(view["breakdown_line"], "", "M=0 K=0 → 唔 render")
	assert_eq(view["pending_warning"], "", "無 pending → 唔 render")
	assert_eq(view["receipt_warning"], "", "零 receipt → 唔 render")
	assert_eq(view["header"]["receipt_total_line"], "")


func test_ac20_mailbox_zero_equipped_only_breakdown() -> void:
	# QA 邊界:M=0 K>0 → 只現役行。
	_put(&"worn", 0, EquipmentEnums.ItemLifecycle.EQUIPPED)
	_inv._loadout[EquipmentEnums.EquipSlot.WEAPON] = &"worn"
	_open()
	_sut.open_bulk_select()
	_sut.bulk_row_tap(0)
	assert_eq(_sut.get_bulk_confirm_view()["breakdown_line"], "內含現役 1 件")


func test_ac20_pending_locked_no_warning() -> void:
	# QA 邊界:pending 件 locked(bulk 唔會食佢)→ warning 唔出。
	_put(&"safe_pending", 0, EquipmentEnums.ItemLifecycle.IN_MAILBOX, true)
	_put(&"victim", 0, EquipmentEnums.ItemLifecycle.IN_INVENTORY)
	_open()
	_sut._make_room_pending = &"safe_pending"
	_sut.open_bulk_select()
	_sut.bulk_row_tap(0)
	assert_eq(_sut.get_bulk_confirm_view()["pending_warning"], "",
		"locked pending 唔喺 bulk range — warning 係 false alarm")


## ============ AC-24: dismiss / ESC 退層 routing ============

func test_ac20_confirm_dismiss_returns_to_select() -> void:
	_put(&"x", 0, EquipmentEnums.ItemLifecycle.IN_INVENTORY)
	_open()
	_sut.open_bulk_select()
	_sut.bulk_row_tap(0)
	# cancel button / scrim(cancel_modal)→ BULK_SELECT 逐層退。
	_sut.cancel_modal()
	assert_eq(_sut.get_modal(), CoordinatorScript.ModalKind.BULK_SELECT)
	# re-enter CONFIRM 再用 ESC — 同一 return target(三者等效)。
	_sut.bulk_row_tap(0)
	assert_true(_sut.handle_escape())
	assert_eq(_sut.get_modal(), CoordinatorScript.ModalKind.BULK_SELECT)


func test_ac24_esc_layer_by_layer_then_screen_close() -> void:
	_put(&"x", 0, EquipmentEnums.ItemLifecycle.IN_INVENTORY)
	_open()
	_sut.open_bulk_select()
	_sut.bulk_row_tap(0)
	# CONFIRM → SELECT → NONE → close screen(EC-07:modal 先 screen 後)。
	assert_true(_sut.handle_escape())
	assert_eq(_sut.get_modal(), CoordinatorScript.ModalKind.BULK_SELECT)
	assert_true(_sut.handle_escape())
	assert_eq(_sut.get_modal(), CoordinatorScript.ModalKind.NONE)
	assert_eq(_sut.get_screen_state(), CoordinatorScript.ScreenState.OPEN, "modal 退完 screen 未閂")
	assert_false(_sut.handle_escape(), "modal NONE → ESC close screen")
	assert_eq(_sut.get_screen_state(), CoordinatorScript.ScreenState.CLOSING)


func test_ac24_salvage_confirm_esc_returns_to_inspect() -> void:
	_put(&"item", 0, EquipmentEnums.ItemLifecycle.IN_INVENTORY)
	_open()
	_sut.open_inspect(&"item")
	_sut.request_salvage(&"item")
	assert_eq(_sut.get_modal(), CoordinatorScript.ModalKind.SALVAGE_CONFIRM)
	# ESC → ITEM_INSPECT(逐層退;item 未毀)。
	assert_true(_sut.handle_escape())
	assert_eq(_sut.get_modal(), CoordinatorScript.ModalKind.ITEM_INSPECT)
	assert_not_null(_inv.get_item(&"item"), "cancel 唔 dispatch")


func test_ac24_make_room_esc_clears_pending() -> void:
	for i in 120:
		_put(StringName("f%d" % i), 4, EquipmentEnums.ItemLifecycle.IN_INVENTORY)
	_put(&"wanted", 0, EquipmentEnums.ItemLifecycle.IN_MAILBOX)
	_open()
	_sut.claim_item(&"wanted")
	assert_eq(_sut.get_modal(), CoordinatorScript.ModalKind.MAKE_ROOM)
	assert_true(_sut.handle_escape())
	assert_eq(_sut.get_modal(), CoordinatorScript.ModalKind.NONE)
	assert_eq(_sut.get_make_room_pending(), &"", "MAKE_ROOM ESC = 放棄(pending 清)")


func test_tabs_blocked_while_modal_open() -> void:
	_put(&"x", 0, EquipmentEnums.ItemLifecycle.IN_INVENTORY)
	_open()
	_sut.open_bulk_select()
	# Act: modal ≠ NONE ⇒ tabs scrim 封鎖(States 表)。
	_sut.set_active_section(CoordinatorScript.SectionKind.MAILBOX)
	assert_eq(_sut.get_active_section(), CoordinatorScript.SectionKind.INVENTORY,
		"modal 開緊 tabs 封鎖")
