## #23 mailbox — integration tests(真 #17 fixture)。
## story 008:section render(AC-14/15 — F2-M + retention + receipt + badge)。
## story 009:claim dispatch + MAKE_ROOM(AC-16/17 + EC-16)— 加入呢個 file。
extends GutTest

const CoordinatorScript := preload("res://src/autoload/inventory_ui_coordinator.gd")
const InventoryScript := preload("res://src/autoload/inventory_system.gd")
const GSMScript := preload("res://src/autoload/game_state_machine.gd")
const TimingConfig := preload("res://src/ui/character_screen/char_screen_timing_config.gd")

const TZ_UTC: int = 0
## 2026-06-01 09:00 UTC(F1 golden 基準 — retention「保留至 6月7日」)。
const ACQ_JUNE1: int = 1780304400
const TABLE_PATH: String = "res://assets/data/equipment/stat_assignment_table.tres"


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
	# 全隔離(_ready 前注入 — suite 慣例):persistence / #17-GSM / stat / table。
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
	_sut._tz_offset_provider = func() -> int: return TZ_UTC  # injected tz(determinism)


func _put_mailbox_item(id: StringName, acquired: int, with_receipt: bool = false,
		mods: Dictionary = {}) -> void:
	var item: EquipmentItem = EquipmentItem.new()
	item.item_id = id
	item.item_type = LootEnums.ItemType.WEAPON
	item.slot_affinity = EquipmentEnums.EquipSlot.WEAPON
	item.lifecycle_state = EquipmentEnums.ItemLifecycle.IN_MAILBOX
	item.acquired_at_unix = acquired
	item.stat_modifiers = mods
	item.provenance_text = "prov %s" % String(id)
	if with_receipt:
		item.source_receipt = SourceReceipt.new()
	_inv._items[id] = item


func _fill_inventory(n: int) -> void:
	for i in n:
		var item: EquipmentItem = EquipmentItem.new()
		item.item_id = StringName("filler_%03d" % i)
		item.item_type = LootEnums.ItemType.ARMOR
		item.slot_affinity = EquipmentEnums.EquipSlot.ARMOR
		item.lifecycle_state = EquipmentEnums.ItemLifecycle.IN_INVENTORY
		item.acquired_at_unix = ACQ_JUNE1
		_inv._items[item.item_id] = item


func _open() -> void:
	assert_true(_sut.open())
	_sut.advance(TimingConfig.OPEN_ANIM_MS)
	_sut.set_active_section(CoordinatorScript.SectionKind.MAILBOX)


func _row_by_id(rows: Array, id: String) -> Dictionary:
	for row: Dictionary in rows:
		if String(row["item_id"]) == id:
			return row
	return {}


## ============ AC-15: mailbox 混合 fixture render ============

func test_ac15_f2m_sort_retention_receipt_and_badge() -> void:
	# Arrange: 混合 — 新普通件 / 舊普通件 / receipt 件(F2-M:acquired asc)。
	_put_mailbox_item(&"newer", ACQ_JUNE1 + 86400)
	_put_mailbox_item(&"older", ACQ_JUNE1)
	_put_mailbox_item(&"receipt_item", ACQ_JUNE1 + 172800, true)
	# Act
	_open()
	var rows: Array = _sut.get_mailbox_rows()
	# Assert: F2-M sort(acquired asc — 就嚟過期排最頂)。
	assert_eq(rows.size(), 3)
	assert_eq(String(rows[0]["item_id"]), "older", "F2-M acquired asc(AC-15)")
	assert_eq(String(rows[1]["item_id"]), "newer")
	assert_eq(String(rows[2]["item_id"]), "receipt_item")
	# 普通件 retention 行(F1 golden:6月1日 09:00 → 保留至 6月7日)。
	assert_eq(_row_by_id(rows, "older")["retention_line"], "保留至 6月7日")
	# Receipt 件:無 retention 行 + glyph + note(EC-08)。
	var receipt_row: Dictionary = _row_by_id(rows, "receipt_item")
	assert_eq(receipt_row["retention_line"], "", "receipt 件唔 render 限期(講大話)")
	assert_true(receipt_row["receipt_glyph"])
	assert_eq(receipt_row["receipt_note"], "收據件唔會自動分解")
	# Badge:dim text「(3)」。
	assert_eq(_sut.get_mailbox_badge_text(), "(3)")
	# Negative fold:#23 唔 render evict 預警(row 冇 evict 類 key)。
	for row: Dictionary in rows:
		assert_false(row.has("evict_warning"), "#23 唔 render evict 預警(Q-IU4 v0.2)")


func test_ac15_badge_zero_items_not_rendered() -> void:
	_open()
	assert_eq(_sut.get_mailbox_badge_text(), "", "0 件唔 render「(0)」(Rule 10)")
	assert_eq(_sut.get_mailbox_rows().size(), 0)


func test_ac15_same_second_tie_breaks_by_id() -> void:
	# 同秒 tie 常態(unix seconds)→ item_id asc(strict total order)。
	_put_mailbox_item(&"b_item", ACQ_JUNE1)
	_put_mailbox_item(&"a_item", ACQ_JUNE1)
	_open()
	var rows: Array = _sut.get_mailbox_rows()
	assert_eq(String(rows[0]["item_id"]), "a_item", "tie → item_id asc(F2-M)")


func test_sub_header_hidden_on_mailbox_section() -> void:
	_put_mailbox_item(&"x", ACQ_JUNE1)
	_open()
	assert_false(_sut.is_sub_header_visible(), "MAILBOX 冇 Z3 sub-header(UX Zones)")
	_sut.set_active_section(CoordinatorScript.SectionKind.INVENTORY)
	assert_true(_sut.is_sub_header_visible())


## ============ AC-14: grace 過期件誠實 render + rescue ============

func test_ac14_expired_item_rendered_verbatim_and_rescuable() -> void:
	# Arrange: DISCONNECTED(grace path 必觸發 — sweep skip)+ 過期 non-receipt 件
	# (acquired 遠過 TTL — retention date 已過)。
	_gsm.state = GSMScript.GameState.DISCONNECTED
	var expired_acquired: int = ACQ_JUNE1 - 30 * 86400  # 30 日前
	_put_mailbox_item(&"expired_item", expired_acquired)
	# Act
	_open()
	var rows: Array = _sut.get_mailbox_rows()
	# Assert: row 照列 + 過去日期原文案(D2 — 零改寫零 urgency)+ 領取 enabled。
	assert_eq(rows.size(), 1, "過期件照列(EC-15 grace)")
	var row: Dictionary = rows[0]
	assert_ne(row["retention_line"], "", "過去日期照 render 原文案(D2)")
	assert_true(row["retention_line"].begins_with("保留至 "), "同一文案,零 urgency 改寫")
	assert_true(row["claim_enabled"], "rescue window —「領取」照 enabled(Rule 12)")
	# Act ②: claim → ok(#17 claim 零 TTL check — rescue 救返件)。
	var result: Dictionary = _sut.claim_item(&"expired_item")
	assert_true(result["ok"], "rescue claim 成功(AC-14)")
	assert_eq(_sut.get_mailbox_rows().size(), 0, "re-read 後件已離開 mailbox")
	assert_eq(_inv.get_item(&"expired_item").lifecycle_state,
		EquipmentEnums.ItemLifecycle.IN_INVENTORY)


func test_ac14_swept_item_claim_returns_not_in_mailbox_toast_reread() -> void:
	# Arrange: 件顯示緊,但已被 sweep 食咗(fixture erase — EC-07 race)。
	_put_mailbox_item(&"ghost", ACQ_JUNE1)
	_open()
	assert_eq(_sut.get_mailbox_rows().size(), 1)
	_inv._items.erase(&"ghost")  # 另一 boot sweep 模擬
	# Act
	var result: Dictionary = _sut.claim_item(&"ghost")
	# Assert: not_in_mailbox → toast + re-read。
	assert_false(result["ok"])
	assert_eq(String(result["error"]), "not_in_mailbox")
	assert_eq(_sut.get_toast()["text"], "件物品已唔喺信箱(可能已自動分解)")
	assert_eq(_sut.get_mailbox_rows().size(), 0, "section re-read 收走 ghost row")


func test_ac14_expired_receipt_item_still_no_retention_line() -> void:
	# 過期 + receipt 並存:receipt guard 行先(sweep 免疫 — 永遠唔 render 限期)。
	_put_mailbox_item(&"old_receipt", ACQ_JUNE1 - 30 * 86400, true)
	_open()
	var row: Dictionary = _sut.get_mailbox_rows()[0]
	assert_eq(row["retention_line"], "", "receipt guard 凌駕過期狀態(EC-08)")
	assert_true(row["receipt_glyph"])


## ============ story 009: AC-16 — claim auto-equip 判定分支 ============

func test_ac16_claim_auto_equip_branch_toasts() -> void:
	# Arrange: 有料件(空 slot ⇒ auto-equip)+ 零料件({} mods — strictly-better
	# 不成立 ⇒ 留 IN_INVENTORY)。
	_put_mailbox_item(&"good_sword", ACQ_JUNE1, false, {&"max_hp": 20.0})
	_put_mailbox_item(&"plain_item", ACQ_JUNE1 + 100)
	_open()
	# Act + Assert ①: auto-equip 分支(EC-05 predicate = re-read 後 lifecycle)。
	var r1: Dictionary = _sut.claim_item(&"good_sword")
	assert_true(r1["ok"])
	assert_eq(_inv.get_item(&"good_sword").lifecycle_state,
		EquipmentEnums.ItemLifecycle.EQUIPPED, "claim 觸發 #17 auto-equip")
	assert_eq(_sut.get_toast()["text"], "已領取並裝上", "AC-16 equipped 分支")
	# Act + Assert ②: 無 auto-equip 分支(WEAPON slot 已有更好件)。
	var r2: Dictionary = _sut.claim_item(&"plain_item")
	assert_true(r2["ok"])
	assert_eq(_inv.get_item(&"plain_item").lifecycle_state,
		EquipmentEnums.ItemLifecycle.IN_INVENTORY)
	assert_eq(_sut.get_toast()["text"], "已領取", "AC-16 plain 分支")
	# 零 lock nudge:#23 coordinator 冇 nudge state 被觸發(auto-equip 係 #17
	# 機器 — silent accept;manual-equip nudge positive control → story 013)。


## ============ story 009: AC-17 — MAKE_ROOM D4 全套 ============

func test_ac17_full_inventory_claim_opens_make_room_zero_auto_salvage() -> void:
	# Arrange: 120 滿 + mailbox 件;shards 基準。
	_fill_inventory(120)
	_put_mailbox_item(&"wanted", ACQ_JUNE1)
	_inv._forge_shards = 500
	_open()
	# Act
	var result: Dictionary = _sut.claim_item(&"wanted")
	# Assert: MAKE_ROOM + pending + shortfall verbatim;零自動分解(state-based)。
	assert_false(result["ok"])
	assert_eq(_sut.get_modal(), CoordinatorScript.ModalKind.MAKE_ROOM)
	assert_eq(_sut.get_make_room_pending(), &"wanted")
	assert_eq(_sut.get_make_room_view()["title"], "倉滿 — 要騰 1 個位", "shortfall verbatim(N≡1)")
	assert_eq(_inv.get_inventory_count(), 120, "零自動分解 — count 不變")
	assert_eq(_inv.get_forge_shards(), 500, "零自動分解 — shards 不變")


func test_ac17_bulk_entry_keeps_pending_dismiss_clears_and_retry_works() -> void:
	# Arrange: full + MAKE_ROOM 開咗。
	_fill_inventory(120)
	_put_mailbox_item(&"wanted", ACQ_JUNE1)
	_open()
	_sut.claim_item(&"wanted")
	# Act ①: 入口 (a)「批量分解」→ BULK_SELECT,pending 保留(011 warning 用)。
	_sut.make_room_bulk_entry()
	assert_eq(_sut.get_modal(), CoordinatorScript.ModalKind.BULK_SELECT)
	assert_eq(_sut.get_make_room_pending(), &"wanted", "入口 (a) pending 保留")
	# Act ②: 重開 MAKE_ROOM(再 claim)→ dismiss = 放棄。
	_sut._modal = CoordinatorScript.ModalKind.NONE
	_sut.claim_item(&"wanted")
	assert_eq(_sut.get_modal(), CoordinatorScript.ModalKind.MAKE_ROOM)
	_sut.make_room_dismiss()
	assert_eq(_sut.get_modal(), CoordinatorScript.ModalKind.NONE)
	assert_eq(_sut.get_make_room_pending(), &"", "dismiss 清 pending(States 表)")
	# Act ③: claim 可重試(button 唔 disable — EC-04)。
	var retry: Dictionary = _sut.claim_item(&"wanted")
	assert_false(retry["ok"])
	assert_eq(_sut.get_modal(), CoordinatorScript.ModalKind.MAKE_ROOM, "重試照開 MAKE_ROOM")


func test_ac17_self_organize_then_hint_one_tap_claims() -> void:
	# Arrange: full + MAKE_ROOM。
	_fill_inventory(120)
	_put_mailbox_item(&"wanted", ACQ_JUNE1)
	_open()
	_sut.claim_item(&"wanted")
	# Act ①: 入口 (b)「自行整理」→ NONE + INVENTORY(visibility re-read)。
	_sut.make_room_self_organize()
	assert_eq(_sut.get_modal(), CoordinatorScript.ModalKind.NONE)
	assert_eq(_sut.get_active_section(), CoordinatorScript.SectionKind.INVENTORY)
	assert_eq(_sut.get_make_room_pending(), &"wanted", "入口 (b) pending 保留")
	# 未騰位:hint 唔出(count == 120)。
	assert_true(_sut.get_make_room_hint().is_empty(), "未騰位 hint 唔 render")
	# Act ②: 騰位(玩家分解一件 — fixture erase)→ re-read → hint 出。
	_inv._items.erase(&"filler_000")
	_sut._reread_all()
	var hint: Dictionary = _sut.get_make_room_hint()
	assert_eq(hint["text"], "已騰出空位 — 領取「wanted」", "P-14 hint 文法(AC-17)")
	# Act ③: one-tap claim。
	var result: Dictionary = _sut.hint_claim_tap()
	assert_true(result["ok"])
	assert_eq(_sut.get_make_room_pending(), &"", "claim 成功清 pending")
	assert_true(_sut.get_make_room_hint().is_empty())


func test_hint_cleared_silently_when_pending_item_gone() -> void:
	# QA note:pending 件被 bulk 食咗 → hint render 前 verify → 清 pending,silent。
	_fill_inventory(120)
	_put_mailbox_item(&"doomed", ACQ_JUNE1)
	_open()
	_sut.claim_item(&"doomed")
	_sut.make_room_self_organize()
	# 騰位 + pending 件同時消失(bulk 連 mailbox 件都食 — Rule 18 range)。
	_inv._items.erase(&"filler_000")
	_inv._items.erase(&"doomed")
	_sut._reread_all()
	assert_true(_sut.get_make_room_hint().is_empty(), "件唔再喺 mailbox → 唔 render")
	assert_eq(_sut.get_make_room_pending(), &"", "pending 清空,silent")
	assert_true(_sut.get_toast().is_empty(), "零 toast(silent)")


func test_hint_dismiss_clears_pending() -> void:
	_fill_inventory(120)
	_put_mailbox_item(&"wanted", ACQ_JUNE1)
	_open()
	_sut.claim_item(&"wanted")
	_sut.make_room_self_organize()
	_inv._items.erase(&"filler_000")
	_sut._reread_all()
	assert_false(_sut.get_make_room_hint().is_empty())
	# Act: hint dismiss X。
	_sut.hint_dismiss()
	assert_eq(_sut.get_make_room_pending(), &"")
	assert_true(_sut.get_make_room_hint().is_empty())
	# claim 可重試(dismiss 唔 disable button;騰咗位 → 今次成功)。
	assert_true(_sut.claim_item(&"wanted")["ok"], "dismiss 後 claim 可重試")


## ============ story 009: EC-16 — deferred claim replay return 丟棄 ============

func test_ec16_deferred_replay_void_shortfall_re_tap_recovery() -> void:
	# Arrange: 119 件(未滿 — #17 claim 嘅 full check 行先過 _mutating check,
	# 要俾佢到達 reentrancy 分支)+ _mutating 注入。
	_fill_inventory(119)
	_put_mailbox_item(&"stuck", ACQ_JUNE1)
	_open()
	_inv._mutating = true
	# Act ①: claim 撞 reentrancy → deferred;無 toast 無 MAKE_ROOM(#22 EC-23 口徑)。
	var r1: Dictionary = _sut.claim_item(&"stuck")
	assert_eq(String(r1["error"]), "deferred_reentrancy")
	assert_true(_sut.get_toast().is_empty(), "deferred 唔 toast")
	assert_eq(_sut.get_modal(), CoordinatorScript.ModalKind.NONE)
	# Act ②: replay 前倉滿咗(EC-16 場景:replay 嗰下先至 full)→ 解鎖 →
	# replay 下 frame 行,shortfall return 落 void(func() -> void)。
	var late_filler: EquipmentItem = EquipmentItem.new()
	late_filler.item_id = &"late_filler"
	late_filler.item_type = LootEnums.ItemType.ARMOR
	late_filler.slot_affinity = EquipmentEnums.EquipSlot.ARMOR
	late_filler.lifecycle_state = EquipmentEnums.ItemLifecycle.IN_INVENTORY
	late_filler.acquired_at_unix = ACQ_JUNE1
	_inv._items[&"late_filler"] = late_filler  # count 119 → 120
	_inv._mutating = false
	await get_tree().process_frame
	await get_tree().process_frame
	# Assert: MAKE_ROOM 冇開(return 冇人收 — 設計接受)+ 件仍 IN_MAILBOX。
	assert_eq(_sut.get_modal(), CoordinatorScript.ModalKind.NONE,
		"replay shortfall 落 void — MAKE_ROOM 唔會開(EC-16 設計接受)")
	assert_eq(_inv.get_item(&"stuck").lifecycle_state,
		EquipmentEnums.ItemLifecycle.IN_MAILBOX, "件仍 IN_MAILBOX")
	# Act ③: re-tap = recovery path(claim button 唔 disable)。
	var r2: Dictionary = _sut.claim_item(&"stuck")
	assert_false(r2["ok"])
	assert_eq(_sut.get_modal(), CoordinatorScript.ModalKind.MAKE_ROOM, "re-tap → MAKE_ROOM(recovery)")
