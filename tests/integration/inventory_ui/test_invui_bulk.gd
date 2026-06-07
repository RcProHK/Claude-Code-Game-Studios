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

	func transition(to: int) -> void:
		var from: int = state
		state = to
		state_changed.emit(from, to, null)


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
		with_receipt: bool = false, slot: int = EquipmentEnums.EquipSlot.WEAPON,
		mods: Dictionary = {}) -> void:
	var item: EquipmentItem = EquipmentItem.new()
	item.item_id = id
	item.item_type = LootEnums.ItemType.WEAPON
	item.slot_affinity = slot
	item.lifecycle_state = lifecycle
	item.rarity = rarity
	item.is_locked = locked
	item.acquired_at_unix = ACQ
	item.stat_modifiers = mods
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


## ============ story 012: execute(AC-21/22/23/36) ============

## #17 subclass — bulk_salvage 完成嗰刻(return 前)觸發 GSM force-close,
## 模擬「confirm 同 frame force-close」嘅 executed 邊(EC-12 — transaction
## 已成立,presentation 必須 skip)。
class ForceCloseMidTransactionInventory:
	extends InventorySystem
	var gsm_to_transition = null

	func bulk_salvage(rarity: int) -> Dictionary:
		var result := super.bulk_salvage(rarity)
		if gsm_to_transition != null:
			gsm_to_transition.transition(GSMScript.GameState.WORKOUT_ACTIVE)
		return result


class SfxSpy:
	extends Node
	var sfx_calls: Array = []

	func play_sfx(event_id: StringName) -> void:
		sfx_calls.append(event_id)


func test_ac21_confirm_executes_with_toast_single_cue_locked_survive() -> void:
	# Arrange: 3 unlocked + 1 locked(rarity 0)+ SFX spy。
	for i in 3:
		_put(StringName("victim_%d" % i), 0, EquipmentEnums.ItemLifecycle.IN_INVENTORY)
	_put(&"protected", 0, EquipmentEnums.ItemLifecycle.IN_INVENTORY, true)
	var audio := SfxSpy.new()
	add_child_autofree(audio)
	_sut._audio = audio
	_open()
	_sut.open_bulk_select()
	_sut.bulk_row_tap(0)
	audio.sfx_calls.clear()
	# Act
	var result: Dictionary = _sut.confirm_bulk_salvage()
	# Assert: toast 報 execute return + 恰好 1 響 + modal NONE + re-read。
	assert_true(result["ok"])
	assert_eq(_sut.get_toast()["text"],
		"已分解 %d 件 — +%d 碎片" % [3, 3 * InventoryScript.salvage_yield(0)])
	assert_eq(audio.sfx_calls, [&"ui_salvage_execute"] as Array, "恰好一響(transaction stamp)")
	assert_eq(_sut.get_modal(), CoordinatorScript.ModalKind.NONE)
	assert_eq(_sut.get_inventory_view().size(), 1, "re-read — 剩 locked 件")
	assert_not_null(_inv.get_item(&"protected"), "locked 件全存活(AC-21)")


func test_ac22_drift_between_preview_and_execute_toasts_truth() -> void:
	# Arrange: 3 件 → row-tap preview = 3。
	for i in 3:
		_put(StringName("v%d" % i), 0, EquipmentEnums.ItemLifecycle.IN_INVENTORY)
	_open()
	_sut.open_bulk_select()
	_sut.bulk_row_tap(0)
	assert_eq(_sut.get_bulk_confirm_view()["header"]["count"], 3, "preview 快照 = 3")
	# Drift: execute 前外部 mutation(另一路徑食咗一件)。
	_inv.salvage(&"v0")
	# Act
	var result: Dictionary = _sut.confirm_bulk_salvage()
	# Assert: execute 用 #17 當下真值;toast ≠ preview;零 crash(EC-01)。
	assert_eq(int(result["count"]), 2, "execute 當下真值")
	assert_eq(_sut.get_toast()["text"],
		"已分解 %d 件 — +%d 碎片" % [2, 2 * InventoryScript.salvage_yield(0)],
		"toast 報 execute return,唔報 preview 數")


func test_ac22_boundary_execute_zero_count_honest_toast() -> void:
	# 邊界:preview 後全部被外部食晒 → execute 0 — toast 照報 execute 真值。
	_put(&"only", 0, EquipmentEnums.ItemLifecycle.IN_INVENTORY)
	_open()
	_sut.open_bulk_select()
	_sut.bulk_row_tap(0)
	_inv.salvage(&"only")
	var result: Dictionary = _sut.confirm_bulk_salvage()
	assert_eq(int(result["count"]), 0)
	assert_eq(_sut.get_toast()["text"], "已分解 0 件 — +0 碎片", "execute 真值照報")


func test_ac23_equipped_in_range_auto_unequip_backfill_reflected() -> void:
	# Arrange: equipped rarity-0 件(range 內)+ 後備同 slot rarity-4 件
	#(range 外;有 mods — backfill 要 strictly-better-than-empty)。
	_put(&"worn_cheap", 0, EquipmentEnums.ItemLifecycle.EQUIPPED)
	_inv._loadout[EquipmentEnums.EquipSlot.WEAPON] = &"worn_cheap"
	_put(&"backup_epic", 4, EquipmentEnums.ItemLifecycle.IN_INVENTORY, false, false,
		EquipmentEnums.EquipSlot.WEAPON, {&"max_hp": 10.0})
	_open()
	_sut.open_bulk_select()
	_sut.bulk_row_tap(0)
	# Act
	var result: Dictionary = _sut.confirm_bulk_salvage()
	# Assert: equipped 件被食 → #17 auto-unequip + backfill → re-read 反映。
	assert_true(result["ok"])
	assert_null(_inv.get_item(&"worn_cheap"), "equipped unlocked 件喺 range 內(Rule 18)")
	var views: Array = _sut.get_inventory_view()
	assert_eq(views.size(), 1)
	assert_true(bool(views[0]["equipped"]),
		"backfill 後備件自動補上 — re-read 反映現役 badge(AC-23)")


func test_ac36_force_close_mid_transaction_executes_skips_presentation() -> void:
	# Arrange: mid-transaction force-close 特製 #17(EC-12 executed 邊)。
	var inv2 := ForceCloseMidTransactionInventory.new()
	inv2._persistence = MockPersistenceLayer.new()
	inv2._gsm = MockInventoryGSM.new()
	inv2._stat_system = MockInventoryStat.new()
	inv2._stat_table = load(TABLE_PATH)
	add_child_autofree(inv2)
	inv2.gsm_to_transition = _gsm
	var item: EquipmentItem = EquipmentItem.new()
	item.item_id = &"victim"
	item.item_type = LootEnums.ItemType.WEAPON
	item.slot_affinity = EquipmentEnums.EquipSlot.WEAPON
	item.lifecycle_state = EquipmentEnums.ItemLifecycle.IN_INVENTORY
	item.rarity = 0
	item.acquired_at_unix = ACQ
	inv2._items[&"victim"] = item
	_sut._inventory = inv2
	var audio := SfxSpy.new()
	add_child_autofree(audio)
	_sut._audio = audio
	_open()
	_sut.open_bulk_select()
	_sut.bulk_row_tap(0)
	audio.sfx_calls.clear()
	var view_before: Array = _sut.get_inventory_view()
	# Act: confirm — dispatch 期間 GSM → WORKOUT_ACTIVE(force-close 落地)。
	var result: Dictionary = _sut.confirm_bulk_salvage()
	# Assert: #17 state 已變(transaction 成立)。
	assert_true(result["ok"])
	assert_null(inv2.get_item(&"victim"), "#17 已執行(synchronous 已執行就成立)")
	assert_eq(inv2.get_forge_shards(), InventoryScript.salvage_yield(0))
	# 零 toast 零 SFX 零 re-read(presentation skip)。
	assert_true(_sut.get_toast().is_empty(), "零 toast(AC-36)")
	assert_eq(audio.sfx_calls.size(), 0, "零 SFX(force-close path CD C1)")
	assert_true(is_same(view_before, _sut.get_inventory_view()), "零 re-read(同一 view object)")
	# Screen 跟 force-close 收口;下次 open render 新 state。
	_sut.advance(TimingConfig.FORCE_CLOSE_MAX_MS)
	assert_eq(_sut.get_screen_state(), CoordinatorScript.ScreenState.CLOSED)
	_gsm.state = GSMScript.GameState.IDLE
	assert_true(_sut.open())
	assert_eq(_sut.get_inventory_view().size(), 0, "下次 open 收割 — render 新 state")


func test_tabs_blocked_while_modal_open() -> void:
	_put(&"x", 0, EquipmentEnums.ItemLifecycle.IN_INVENTORY)
	_open()
	_sut.open_bulk_select()
	# Act: modal ≠ NONE ⇒ tabs scrim 封鎖(States 表)。
	_sut.set_active_section(CoordinatorScript.SectionKind.MAILBOX)
	assert_eq(_sut.get_active_section(), CoordinatorScript.SectionKind.INVENTORY,
		"modal 開緊 tabs 封鎖")
