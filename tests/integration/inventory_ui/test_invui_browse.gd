## #23 virtualized card list — integration tests(story 005;AC-13 + EC-14)。
## 560px viewport fixture;pool bound 讀 implementation 同一公式(pool_cap)。
## (View-model 接入 cases — story 006 加入呢個 file。)
extends GutTest

const ListScript := preload("res://src/ui/inventory_ui/virtualized_card_list.gd")

const VIEWPORT_SIZE := Vector2(360.0, 560.0)


var _sut = null
var _populate_log: Array = []


func before_each() -> void:
	_sut = ListScript.new()
	_sut.size = VIEWPORT_SIZE
	add_child_autofree(_sut)
	_populate_log = []
	var log_ref: Array = _populate_log  # lambda capture BY VALUE — 捉 reference,mutate 內容 OK
	_sut.setup(
		func() -> Control: return Control.new(),
		func(card: Control, index: int) -> void:
			card.set_meta(&"populated_index", index)
			log_ref.append(index))


## ============ AC-13: pool bound(120 件 @ 560px) ============

func test_ac13_120_items_card_nodes_within_pool_formula() -> void:
	# Act
	_sut.set_item_count(120, true)
	await get_tree().process_frame
	# Assert: instantiated card nodes ≤ ceil(560/ROW_H) + 2×buffer(讀同一常數)。
	var cap: int = _sut.pool_cap()
	assert_eq(cap, int(ceil(560.0 / ListScript.ROW_HEIGHT_PX)) + 2 * _sut.pool_buffer_rows,
		"pool_cap 公式 = AC-13 公式(test 讀 implementation 同一常數)")
	assert_lte(_sut.get_card_node_count(), cap,
		"120 件只 instantiate pool 上限(P-06 card node 計)")
	assert_gt(_sut.get_visible_card_count(), 0, "首屏有 render")


func test_ac13_scroll_to_bottom_pool_does_not_grow() -> void:
	# Arrange
	_sut.set_item_count(120, true)
	await get_tree().process_frame
	var cap: int = _sut.pool_cap()
	# Act: scroll 到底(120×96 − 560)。
	_sut.scroll_vertical = 120 * int(ListScript.ROW_HEIGHT_PX) - 560
	await get_tree().process_frame
	_sut.refresh_visible()
	# Assert: pool 重用唔加(同一 bound)。
	assert_lte(_sut.get_card_node_count(), cap, "scroll 到底 pool 唔增長(重用)")
	# 最尾 row(index 119)已被 populate。
	assert_has(_populate_log, 119, "底部 window 包含最後一件")


## ============ EC-14: scroll 雙軌 ============

func test_single_mutation_rebuild_keeps_scroll_offset() -> void:
	# Arrange: scroll 到中段。
	_sut.set_item_count(120, true)
	await get_tree().process_frame
	_sut.scroll_vertical = 960
	await get_tree().process_frame
	# Act: 單件 mutation rebuild(claim / 單件 salvage / equip / lock)。
	_sut.set_item_count(119, false)
	# Assert: offset 保留(clamped — 內容 99% 冇變)。
	assert_eq(_sut.scroll_vertical, 960, "單件 mutation 保留 offset(EC-14)")


func test_bulk_rebuild_resets_scroll_to_top() -> void:
	# Arrange
	_sut.set_item_count(120, true)
	await get_tree().process_frame
	_sut.scroll_vertical = 960
	await get_tree().process_frame
	# Act: bulk execute rebuild(120 → 8 — 內容根本唔同)。
	_sut.set_item_count(8, true)
	# Assert
	assert_eq(_sut.scroll_vertical, 0, "bulk rebuild reset 去頂(EC-14)")


func test_keep_offset_clamps_when_content_shrinks_below_offset() -> void:
	# Arrange: scroll 到底。
	_sut.set_item_count(120, true)
	await get_tree().process_frame
	_sut.scroll_vertical = 120 * int(ListScript.ROW_HEIGHT_PX) - 560
	await get_tree().process_frame
	# Act: 內容縮到 50 件(keep-offset 軌)。
	_sut.set_item_count(50, false)
	# Assert: clamped 到新 max(50×96 − 560),零 crash 零 ghost。
	var new_max: int = 50 * int(ListScript.ROW_HEIGHT_PX) - 560
	assert_lte(_sut.scroll_vertical, new_max, "offset clamp 到新 content 範圍")


## ============ 邊界:0 / 1 / 件數 < pool ============

func test_zero_items_renders_nothing_no_crash() -> void:
	_sut.set_item_count(0, true)
	await get_tree().process_frame
	_sut.refresh_visible()
	assert_eq(_sut.get_visible_card_count(), 0, "0 件 → 零 visible card,零 crash")


func test_single_item_renders_exactly_one() -> void:
	_sut.set_item_count(1, true)
	await get_tree().process_frame
	_sut.refresh_visible()
	assert_eq(_sut.get_visible_card_count(), 1)
	assert_has(_populate_log, 0)


func test_items_fewer_than_pool_no_ghost_rows() -> void:
	# Arrange: 3 件 < pool cap(~10)。
	_sut.set_item_count(3, true)
	await get_tree().process_frame
	_sut.refresh_visible()
	# Assert: 恰好 3 visible — 零 ghost row(隱藏 pool 唔 render)。
	assert_eq(_sut.get_visible_card_count(), 3, "件數 < pool → 恰好件數 visible")


## ============ caller 注入(component 唔識 #17) ============

func test_populate_callback_receives_window_indices() -> void:
	# Arrange/Act
	_sut.set_item_count(120, true)
	await get_tree().process_frame
	_populate_log.clear()
	_sut.refresh_visible()
	# Assert: 首屏 window 由 index 0 開始連續。
	assert_has(_populate_log, 0, "首 row populate")
	for i in range(_populate_log.size() - 1):
		assert_eq(_populate_log[i + 1], _populate_log[i] + 1, "window indices 連續")


## ============ focus-driven hook(story 015 接線;基本數學) ============

func test_ensure_index_visible_advances_window_past_first_screen() -> void:
	# Arrange: 首屏只見 ~6 rows。
	_sut.set_item_count(120, true)
	await get_tree().process_frame
	# Act: focus 行到超過首屏件數嘅 row(UI Req AC-31 case)。
	var new_scroll: int = _sut.ensure_index_visible(30)
	# Assert: 視窗推進到 row 30 可見(bottom-aligned:31×96 − 560)。
	assert_eq(new_scroll, 31 * int(ListScript.ROW_HEIGHT_PX) - 560,
		"focus-driven virtualization — 視窗跟 focus 推進")
	assert_has(_populate_log, 30, "row 30 已 populate")
	# 向上返 row 0。
	_sut.ensure_index_visible(0)
	assert_eq(_sut.scroll_vertical, 0, "向上 focus → 視窗跟返上去")
