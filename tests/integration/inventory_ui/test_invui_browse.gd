## #23 browse — integration tests。
## story 005:virtualized list(AC-13 + EC-14;560px viewport fixture)。
## story 006:view models + binding(AC-10/11/12/35;真 #17 fixture)。
extends GutTest

const ListScript := preload("res://src/ui/inventory_ui/virtualized_card_list.gd")
const CoordinatorScript := preload("res://src/autoload/inventory_ui_coordinator.gd")
const InventoryScript := preload("res://src/autoload/inventory_system.gd")
const GSMScript := preload("res://src/autoload/game_state_machine.gd")
const TimingConfig := preload("res://src/ui/character_screen/char_screen_timing_config.gd")

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


## ============ story 006: view models + binding(真 #17 fixture) ============

class MockGSM:
	extends Node
	signal state_changed(from_state, to_state, payload)
	var state: int = GSMScript.GameState.IDLE

	func get_current_state() -> int:
		return state

	func connect_for_initial_state(callable: Callable) -> void:
		state_changed.connect(callable)


func _make_coordinator_with_real_inventory() -> Array:
	var inv = InventoryScript.new()
	add_child_autofree(inv)
	var gsm := MockGSM.new()
	add_child_autofree(gsm)
	var coord = CoordinatorScript.new()
	add_child_autofree(coord)
	coord._gsm = gsm
	coord._inventory = inv
	return [coord, inv]


func _put_item(inv, id: StringName, lifecycle: int, slot: int = 0,
		rarity: int = 0, acquired: int = 1000) -> void:
	var item: EquipmentItem = EquipmentItem.new()
	item.item_id = id
	item.slot_affinity = slot
	item.lifecycle_state = lifecycle
	item.rarity = rarity
	item.acquired_at_unix = acquired
	item.provenance_text = "test provenance %s" % String(id)
	inv._items[id] = item


func _view_ids(views: Array) -> Array[String]:
	var out: Array[String] = []
	for v: Dictionary in views:
		out.append(String(v["item_id"]))
	return out


func test_ac10_open_first_frame_five_reads_and_zero_live_ref() -> void:
	# Arrange: 真 #17 混合 fixture。
	var pair := _make_coordinator_with_real_inventory()
	var coord = pair[0]
	var inv = pair[1]
	_put_item(inv, &"inv_a", EquipmentEnums.ItemLifecycle.IN_INVENTORY)
	_put_item(inv, &"eq_b", EquipmentEnums.ItemLifecycle.EQUIPPED,
		EquipmentEnums.EquipSlot.WEAPON)
	inv._loadout[EquipmentEnums.EquipSlot.WEAPON] = &"eq_b"
	_put_item(inv, &"mb_c", EquipmentEnums.ItemLifecycle.IN_MAILBOX)
	inv._forge_shards = 1400
	# Act: open(Rule 5 — 第一 frame sync read 齊)。
	assert_true(coord.open())
	# Assert: 五 read 齊 — views + count + shards + badge set。
	assert_eq(coord.get_inventory_view().size(), 2, "all-inventory 含 EQUIPPED(G-IU-1)")
	assert_eq(coord.get_mailbox_view().size(), 1)
	assert_eq(coord.get_count_readout(), "2/120")
	assert_eq(coord.get_forge_shards_display(), "1400")
	# 零 live ref(AC-10):view 係 Dictionary snapshot — mutate #17 後 view 不變。
	var view: Dictionary = coord.get_inventory_view()[0]
	assert_eq(typeof(view), TYPE_DICTIONARY, "view model 係 snapshot,唔係 EquipmentItem")
	var name_before: String = view["provenance"]
	inv.get_item(StringName(view["item_id"])).provenance_text = "MUTATED"
	assert_eq(coord.get_inventory_view()[0]["provenance"], name_before,
		"#17 mutate 後 snapshot 不變(欄位 copy — 零 live reference)")


func test_ac11_f3_sort_and_equipped_badge() -> void:
	# Arrange: rarity 混合 + equipped 件。
	var pair := _make_coordinator_with_real_inventory()
	var coord = pair[0]
	var inv = pair[1]
	_put_item(inv, &"common_new", EquipmentEnums.ItemLifecycle.IN_INVENTORY, 0, 0, 300)
	_put_item(inv, &"rare_old", EquipmentEnums.ItemLifecycle.IN_INVENTORY, 0, 2, 100)
	_put_item(inv, &"rare_new", EquipmentEnums.ItemLifecycle.EQUIPPED,
		EquipmentEnums.EquipSlot.WEAPON, 2, 300)
	inv._loadout[EquipmentEnums.EquipSlot.WEAPON] = &"rare_new"
	# Act
	assert_true(coord.open())
	# Assert: F3 序(rarity desc → acquired desc → id asc)byte-identical。
	assert_eq(_view_ids(coord.get_inventory_view()),
		["rare_new", "rare_old", "common_new"] as Array[String],
		"F3 = #22 picker_before 同一 code(AC-11)")
	# 現役 badge 恰好 equipped 件有(loadout set O(1))。
	for v: Dictionary in coord.get_inventory_view():
		assert_eq(bool(v["equipped"]), String(v["item_id"]) == "rare_new",
			"現役 badge 恰好 EQUIPPED 件有(%s)" % v["item_id"])


func test_ac12_filter_identity_section_reread_and_empty_copies() -> void:
	# Arrange
	var pair := _make_coordinator_with_real_inventory()
	var coord = pair[0]
	var inv = pair[1]
	_put_item(inv, &"sword", EquipmentEnums.ItemLifecycle.IN_INVENTORY,
		EquipmentEnums.EquipSlot.WEAPON)
	assert_true(coord.open())
	coord.advance(TimingConfig.OPEN_ANIM_MS)  # → OPEN(setters 要 OPEN state)
	# Act + Assert ①: filter 切換 → view model array object identity 不變(零 re-read)。
	var view_before: Array = coord.get_inventory_view()
	coord.set_slot_filter(CoordinatorScript.SlotFilter.ARMOR)
	assert_true(is_same(view_before, coord.get_inventory_view()),
		"filter 係 view predicate — 主 view object 不變(AC-12)")
	# ②: filter 收窄到 0 件 → 「呢類暫時冇收藏」(唔 auto-reset filter)。
	assert_eq(coord.get_filtered_inventory_view().size(), 0)
	assert_eq(coord.get_inventory_empty_copy(), "呢類暫時冇收藏")
	# ③: section 切返 → re-read(新 object)。
	coord.set_active_section(CoordinatorScript.SectionKind.MAILBOX)
	coord.set_active_section(CoordinatorScript.SectionKind.INVENTORY)
	assert_false(is_same(view_before, coord.get_inventory_view()),
		"section visibility re-read → 新 view object(Rule 23)")
	# ④: first-run copy(ALL + 0 件)。
	inv._items.clear()
	coord.set_slot_filter(CoordinatorScript.SlotFilter.ALL)
	coord.set_active_section(CoordinatorScript.SectionKind.INVENTORY)  # re-read
	assert_eq(coord.get_inventory_empty_copy(),
		"收據庫仲未有收藏 — 完成 workout 之後,loot 會喺度等你", "first-run copy(EC-09)")


func test_ac35_count_readout_updates_after_mutation() -> void:
	# Arrange: 3 件(2 inventory + 1 equipped)。
	var pair := _make_coordinator_with_real_inventory()
	var coord = pair[0]
	var inv = pair[1]
	_put_item(inv, &"a", EquipmentEnums.ItemLifecycle.IN_INVENTORY)
	_put_item(inv, &"b", EquipmentEnums.ItemLifecycle.IN_INVENTORY)
	_put_item(inv, &"c", EquipmentEnums.ItemLifecycle.EQUIPPED,
		EquipmentEnums.EquipSlot.WEAPON)
	inv._loadout[EquipmentEnums.EquipSlot.WEAPON] = &"c"
	assert_true(coord.open())
	assert_eq(coord.get_count_readout(), "3/120", "verbatim readout(AC-35)")
	# Act: mutation(件消失)→ re-read(command-then-re-read 範圍 = Rule 5 全套)。
	inv._items.erase(&"a")
	coord._reread_all()
	# Assert
	assert_eq(coord.get_count_readout(), "2/120", "mutation 後更新")


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
