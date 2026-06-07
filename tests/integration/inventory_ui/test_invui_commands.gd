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


## ============ story 014: AC-26 — 6+1 error codes 真誘發 ============

func test_ac26_six_codes_real_induction_toast_map() -> void:
	# Arrange
	_put(&"mb_item", EquipmentEnums.ItemLifecycle.IN_MAILBOX)
	_put(&"sword", EquipmentEnums.ItemLifecycle.IN_INVENTORY)
	_open()
	# ① not_found(equip ghost — L656)。
	_sut.equip_item(&"ghost")
	assert_eq(_sut.get_toast()["text"], "件物品已唔存在")
	# ② in_mailbox_claim_first(equip mailbox 件 — L658)。
	_sut.equip_item(&"mb_item")
	assert_eq(_sut.get_toast()["text"], "先去信箱領取")
	# ③ slot_type_mismatch(explicit 錯 slot — L661)。
	_sut.equip_item(&"sword", EquipmentEnums.EquipSlot.ARMOR)
	assert_eq(_sut.get_toast()["text"], "件裝備唔啱呢個位")
	# ④ slot_empty(unequip 空 slot — L677)。
	_sut.unequip_slot(EquipmentEnums.EquipSlot.ACCESSORY)
	assert_eq(_sut.get_toast()["text"], "呢個位係空嘅")
	# ⑤ locked(confirm 期間外部 lock — salvage L556 真誘發)。
	_sut.open_inspect(&"sword")
	_sut.request_salvage(&"sword")
	_inv.set_lock(&"sword", true)  # confirm 開緊期間 stale lock
	_sut.confirm_salvage()
	assert_eq(_sut.get_toast()["text"], "上鎖中 — 解鎖先可以操作")
	assert_not_null(_inv.get_item(&"sword"), "locked — #17 refuse,件未毀")
	# ⑥ not_in_mailbox(claim ghost — L722;專屬文案)。
	_sut.claim_item(&"vanished")
	assert_eq(_sut.get_toast()["text"], "件物品已唔喺信箱(可能已自動分解)")


func test_ac26_deferred_no_toast_next_frame_harvest() -> void:
	# deferred_reentrancy → 唔 toast,下 frame 收割(= #22 EC-23)。
	_put(&"sword", EquipmentEnums.ItemLifecycle.IN_INVENTORY)
	_open()
	_inv._mutating = true
	var result: Dictionary = _sut.equip_item(&"sword")
	assert_eq(String(result["error"]), "deferred_reentrancy")
	assert_true(_sut.get_toast().is_empty(), "deferred 唔 toast")
	# 還原 _mutating → 等 replay(#17 process_frame one-shot — frame N+1;
	# coordinator 嘅 call_deferred re-read 行先過 replay,所以「收割」由
	# **下一個 re-read trigger** 完成 — EC-16 design-accept 呢個 class)。
	_inv._mutating = false
	await get_tree().process_frame
	await get_tree().process_frame
	assert_eq(_inv.get_item(&"sword").lifecycle_state,
		EquipmentEnums.ItemLifecycle.EQUIPPED, "replay 成功(#17 機器)")
	# 下個 re-read trigger(section visibility re-read — Rule 23)收割。
	_sut.set_active_section(CoordinatorScript.SectionKind.MAILBOX)
	_sut.set_active_section(CoordinatorScript.SectionKind.INVENTORY)
	assert_true(bool(_view_for(_sut.get_inventory_view(), "sword")["equipped"]),
		"下個 re-read 收割 — view 追上 replay 結果")


func test_ac26_shortfall_takes_make_room_not_toast_path() -> void:
	# dispatch ①②③:shortfall return 冇 error key — 必須行 MAKE_ROOM 唔行 toast。
	for i in 120:
		_put(StringName("f%d" % i), EquipmentEnums.ItemLifecycle.IN_INVENTORY)
	_put(&"wanted", EquipmentEnums.ItemLifecycle.IN_MAILBOX)
	_open()
	_sut.claim_item(&"wanted")
	assert_eq(_sut.get_modal(), CoordinatorScript.ModalKind.MAKE_ROOM)
	assert_true(_sut.get_toast().is_empty(), "shortfall ≠ error — 零 toast(dispatch ②)")


func test_ac26_boundary_second_error_replaces_toast() -> void:
	# 同屏最多 1 條 toast — 新取代舊。
	_open()
	_sut.equip_item(&"ghost_a")
	assert_eq(_sut.get_toast()["text"], "件物品已唔存在")
	_sut.claim_item(&"ghost_b")
	assert_eq(_sut.get_toast()["text"], "件物品已唔喺信箱(可能已自動分解)", "新取代舊")


## ============ story 014: AC-27 — DISCONNECTED 全功能 suite ============

func test_ac27_disconnected_all_commands_behave_as_idle() -> void:
	# Arrange: DISCONNECTED(ADR-0003 — local 全功能,唯一 delta = banner)。
	_gsm.state = GSMScript.GameState.DISCONNECTED
	_put(&"to_equip", EquipmentEnums.ItemLifecycle.IN_INVENTORY, false, {&"max_hp": 5.0})
	_put(&"to_lock", EquipmentEnums.ItemLifecycle.IN_INVENTORY)
	_put(&"to_salvage", EquipmentEnums.ItemLifecycle.IN_INVENTORY)
	_put(&"to_claim", EquipmentEnums.ItemLifecycle.IN_MAILBOX)
	_put(&"to_bulk", EquipmentEnums.ItemLifecycle.IN_INVENTORY)
	_open()
	assert_true(_sut.is_offline_banner_visible(), "唯一 delta = banner")
	# claim ✓
	assert_true(_sut.claim_item(&"to_claim")["ok"], "claim offline 照行")
	# equip ✓
	assert_true(_sut.equip_item(&"to_equip")["ok"], "equip offline 照行")
	# unequip ✓
	assert_true(_sut.unequip_slot(EquipmentEnums.EquipSlot.WEAPON)["ok"], "unequip offline 照行")
	# lock ✓
	assert_true(_sut.toggle_lock(&"to_lock", true)["ok"], "lock offline 照行")
	# 單件 salvage ✓
	_sut.open_inspect(&"to_salvage")
	_sut.request_salvage(&"to_salvage")
	assert_true(_sut.confirm_salvage()["ok"], "salvage offline 照行")
	# bulk ✓(to_bulk + to_claim 已 claim 入倉 — unlocked rarity 0)
	_sut.open_bulk_select()
	assert_true(_sut.bulk_row_tap(0)["opened"])
	assert_true(_sut.confirm_bulk_salvage()["ok"], "bulk offline 照行")
