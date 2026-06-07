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
	_inv._persistence = MockPersistenceLayer.new()  # 隔離 user://(_ready 前注入 — suite 慣例)
	add_child_autofree(_inv)
	_gsm = MockGSM.new()
	add_child_autofree(_gsm)
	_sut = CoordinatorScript.new()
	add_child_autofree(_sut)
	_sut._gsm = _gsm
	_sut._inventory = _inv
	_sut._tz_offset_provider = func() -> int: return TZ_UTC  # injected tz(determinism)


func _put_mailbox_item(id: StringName, acquired: int, with_receipt: bool = false) -> void:
	var item: EquipmentItem = EquipmentItem.new()
	item.item_id = id
	item.slot_affinity = EquipmentEnums.EquipSlot.WEAPON
	item.lifecycle_state = EquipmentEnums.ItemLifecycle.IN_MAILBOX
	item.acquired_at_unix = acquired
	item.provenance_text = "prov %s" % String(id)
	if with_receipt:
		item.source_receipt = SourceReceipt.new()
	_inv._items[id] = item


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
