## #23 單件 ops — integration tests(story 013;AC-25 Rule 13 per-lifecycle
## affordances + nudge locus + salvage 兩步兩層閂)。真 #17 全隔離 fixture。
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


func _view_for(views: Array, id: String) -> Dictionary:
	for v: Dictionary in views:
		if String(v["item_id"]) == id:
			return v
	return {}


## ============ AC-25 (a): IN_INVENTORY equip + inline nudge ============

func test_ac25a_equip_from_inspect_with_inline_nudge() -> void:
	# Arrange
	_put(&"sword", EquipmentEnums.ItemLifecycle.IN_INVENTORY, false, {&"max_hp": 5.0})
	_open()
	_sut.open_inspect(&"sword")
	var view: Dictionary = _sut.get_inspect_view()
	assert_true(view["equip_visible"])
	assert_true(view["equip_enabled"], "(a) IN_INVENTORY —「裝備」available")
	assert_false(view["equipped_badge"])
	assert_false(view["unequip_visible"])
	# Act: 裝備。
	var result: Dictionary = _sut.equip_item(&"sword")
	# Assert: ok + toast + 現役 badge + nudge inline(unconditional;
	# AC-16 positive control 對照 — manual equip 有 nudge,claim auto-equip 零)。
	assert_true(result["ok"])
	assert_eq(_sut.get_toast()["text"], "已裝備 sword")
	assert_true(bool(_view_for(_sut.get_inventory_view(), "sword")["equipped"]))
	var nudge: Dictionary = _sut.get_inspect_nudge()
	assert_eq(nudge["item_id"], &"sword", "lock nudge inline 喺 sheet 內(Rule 13 (a))")
	assert_false(nudge["confirmed"])
	# Act ②: [鎖定] one-tap → set_lock + 確認態。
	_sut.nudge_lock_tap()
	assert_true(bool(_inv.get_item(&"sword").is_locked))
	assert_true(_sut.get_inspect_nudge()["confirmed"], "確認態")
	# Act ③: sheet 閂咗 nudge 即棄。
	_sut.cancel_modal()
	assert_true(_sut.get_inspect_nudge().is_empty(), "閂 sheet → nudge 棄(唔跟去 list)")


func test_ac25a_equip_already_locked_item_no_nudge() -> void:
	# 已 lock 件 equip → 無 nudge(#22 Rule 18 同款)。
	_put(&"locked_sword", EquipmentEnums.ItemLifecycle.IN_INVENTORY, true)
	_open()
	_sut.open_inspect(&"locked_sword")
	assert_true(_sut.equip_item(&"locked_sword")["ok"])
	assert_true(_sut.get_inspect_nudge().is_empty(), "已鎖 → 無 nudge")


## ============ AC-25 (b): EQUIPPED「卸下」 ============

func test_ac25b_equipped_affordances_and_unequip() -> void:
	# Arrange: equipped 件。
	_put(&"worn", EquipmentEnums.ItemLifecycle.EQUIPPED)
	_inv._loadout[EquipmentEnums.EquipSlot.WEAPON] = &"worn"
	_open()
	_sut.open_inspect(&"worn")
	var view: Dictionary = _sut.get_inspect_view()
	# Assert (b):「裝備」唔 render(benign self-swap 唔靠 error 擋);
	#「現役」標記 +「卸下」。
	assert_false(view["equip_visible"], "(b)「裝備」button 唔 render")
	assert_true(view["equipped_badge"], "「現役」標記")
	assert_true(view["unequip_visible"], "「卸下」button")
	# Act: 卸下。
	var count_before: int = _inv.get_inventory_count()
	var result: Dictionary = _sut.unequip_slot(EquipmentEnums.EquipSlot.WEAPON)
	# Assert: ok + re-read badge 消失 + count 不變(L1125 口徑 — 永不爆 cap)。
	assert_true(result["ok"])
	assert_false(bool(_view_for(_sut.get_inventory_view(), "worn")["equipped"]),
		"badge 消失(re-read)")
	assert_eq(_inv.get_inventory_count(), count_before, "unequip count 不變(口徑)")


func test_boundary_equip_then_inspect_same_item_shows_b_affordances() -> void:
	# 邊界:equip 後即 inspect 同一件 → affordance 變 (b)。
	_put(&"fresh", EquipmentEnums.ItemLifecycle.IN_INVENTORY, false, {&"max_hp": 5.0})
	_open()
	_sut.equip_item(&"fresh")
	_sut.open_inspect(&"fresh")
	var view: Dictionary = _sut.get_inspect_view()
	assert_false(view["equip_visible"])
	assert_true(view["equipped_badge"], "equip 後即 inspect → (b) affordances")


## ============ AC-25 (c): salvage 兩步 + 兩層一齊閂 ============

func test_ac25c_salvage_confirm_closes_both_sheets() -> void:
	# Arrange
	_put(&"junk", EquipmentEnums.ItemLifecycle.IN_INVENTORY)
	_open()
	_sut.open_inspect(&"junk")
	_sut.request_salvage(&"junk")
	assert_eq(_sut.get_modal(), CoordinatorScript.ModalKind.SALVAGE_CONFIRM)
	# P-15 view(yield + provenance + default focus cancel)。
	var view: Dictionary = _sut.get_salvage_confirm_view()
	assert_eq(view["yield"], InventoryScript.salvage_yield(0))
	assert_eq(view["provenance"], "prov junk")
	assert_eq(view["default_focus"], "cancel")
	# Act: confirm。
	var result: Dictionary = _sut.confirm_salvage()
	# Assert: 兩層一齊閂 → NONE + toast(件已毀,inspect 係 limbo)。
	assert_true(result["ok"])
	assert_eq(_sut.get_modal(), CoordinatorScript.ModalKind.NONE, "兩層一齊閂(Rule 13 (c))")
	assert_true(_sut.get_inspect_view().is_empty(), "inspect 對象已清")
	assert_eq(_sut.get_toast()["text"],
		"已分解 junk — +%d 碎片" % InventoryScript.salvage_yield(0))


func test_ac25_salvage_locked_disabled_and_entry_blocked() -> void:
	# locked → 入口 disabled +「上鎖中」hint(#22 Rule 20 同款)。
	_put(&"safe", EquipmentEnums.ItemLifecycle.IN_INVENTORY, true)
	_open()
	_sut.open_inspect(&"safe")
	var view: Dictionary = _sut.get_inspect_view()
	assert_false(view["salvage_enabled"])
	assert_eq(view["salvage_hint"], "上鎖中 — 解鎖先可以分解")
	_sut.request_salvage(&"safe")
	assert_eq(_sut.get_modal(), CoordinatorScript.ModalKind.ITEM_INSPECT, "double guard — modal 唔開")
	assert_not_null(_inv.get_item(&"safe"))


func test_ac25c_equipped_salvage_confirm_shows_warning() -> void:
	# equipped 件 salvage confirm → warning(= #22 view)。
	_put(&"worn", EquipmentEnums.ItemLifecycle.EQUIPPED)
	_inv._loadout[EquipmentEnums.EquipSlot.WEAPON] = &"worn"
	_open()
	_sut.open_inspect(&"worn")
	_sut.request_salvage(&"worn")
	assert_eq(_sut.get_salvage_confirm_view()["warning"],
		"現役裝備 — 會自動卸下(如有後備會自動補上)")
