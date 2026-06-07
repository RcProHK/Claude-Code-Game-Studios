## #22 Character Screen — command surface integration tests
## (stories 014-017:GDD AC-25..34 + 50/51 + AC-19;Group D = 真 #17 + mock GSM)。
## AC-33(iii) 真 #17 誘發(hostile re-entry idiom — test_reentrancy_guard 同款,
## 禁 mock stub return deferred_reentrancy)。
extends GutTest

const CoordinatorScript := preload("res://src/autoload/character_screen_coordinator.gd")
const InventorySystem := preload("res://src/autoload/inventory_system.gd")
const GSMScript := preload("res://src/autoload/game_state_machine.gd")
const TimingConfig := preload("res://src/ui/character_screen/char_screen_timing_config.gd")

const TABLE_PATH: String = "res://assets/data/equipment/stat_assignment_table.tres"
const FIXED_NOW: int = 1764547300


class MockGSM:
	extends Node
	signal state_changed(from_state, to_state, payload)
	var state: int = 2  # IDLE
	func get_current_state() -> int:
		return state
	func connect_for_initial_state(callable: Callable) -> void:
		state_changed.connect(callable)
	func transition(to: int) -> void:
		var from: int = state
		state = to
		state_changed.emit(from, to, null)


class MockStat:
	extends Node
	signal stat_changed(stat_id, old_value, new_value, source, meta)
	func get_stat(_stat_id: StringName) -> float:
		return 10.0
	func connect_for_initial_state(callable: Callable) -> void:
		stat_changed.connect(callable)


## 真 #17 嘅 #11 seam(benign;hostile 版見 AC-33iii)。
class BenignInvStat:
	extends RefCounted
	func is_boot_completed() -> bool:
		return true
	func get_attack_power_excluding_equipment() -> float:
		return 28.0
	func apply_equipment_modifier(_id: StringName, _modifier) -> void:
		pass


## Hostile #11 seam — push window 內 re-enter(AC-33iii 真誘發 vector)。
class HostileInvStat:
	extends RefCounted
	var sut_coordinator = null
	var reentry_item: StringName = &""
	var reentry_slot: int = 0
	var reentry_result: Dictionary = {}
	func is_boot_completed() -> bool:
		return true
	func get_attack_power_excluding_equipment() -> float:
		return 28.0
	func apply_equipment_modifier(_id: StringName, _modifier) -> void:
		if sut_coordinator != null and reentry_item != &"":
			reentry_result = sut_coordinator.equip_item(reentry_item, reentry_slot)
			reentry_item = &""


class MockAudio:
	extends Node
	var sfx_calls: Array = []
	func play_sfx(event_id: StringName) -> void:
		sfx_calls.append(event_id)


var _sut = null
var _inv = null
var _gsm: MockGSM
var _stat: MockStat
var _audio: MockAudio
var _inv_stat


func before_each() -> void:
	_gsm = MockGSM.new()
	add_child_autofree(_gsm)
	_stat = MockStat.new()
	add_child_autofree(_stat)
	_audio = MockAudio.new()
	add_child_autofree(_audio)
	# 真 #17(reentrancy_guard idiom seams)
	_inv_stat = BenignInvStat.new()
	_inv = InventorySystem.new()
	_inv._persistence = MockPersistenceLayer.new()
	_inv._gsm = MockInventoryGSM.new()
	_inv._stat_table = load(TABLE_PATH)
	_inv._stat_system = _inv_stat
	_inv._now_unix_provider = func() -> int: return FIXED_NOW
	add_child_autofree(_inv)
	# coordinator
	_sut = CoordinatorScript.new()
	add_child_autofree(_sut)
	_sut._gsm = _gsm
	_sut._stat_system = _stat
	_sut._inventory = _inv
	_sut._audio = _audio
	_sut._persistence = MockPersistenceLayer.new()
	_sut._date_provider = func() -> String: return "6月7日"


func _make_item(id: StringName, slot: int, lifecycle: int, mods: Dictionary = {&"attack_power": 10.0}, rarity: int = 2) -> EquipmentItem:
	var item: EquipmentItem = EquipmentItem.new()
	item.item_id = id
	item.item_type = LootEnums.ItemType.WEAPON if slot == EquipmentEnums.EquipSlot.WEAPON else LootEnums.ItemType.COSMETIC
	item.rarity = rarity
	item.stat_modifiers = mods
	item.acquired_at_unix = FIXED_NOW
	item.lifecycle_state = lifecycle
	item.slot_affinity = slot
	item.provenance_text = "拾於 6月3日・腿日"
	_inv._items[id] = item
	return item


func _open() -> void:
	assert_true(_sut.open())
	_sut.advance(TimingConfig.OPEN_ANIM_MS)
	assert_eq(_sut.get_screen_state(), CoordinatorScript.ScreenState.OPEN)


const W := 0  # EquipmentEnums.EquipSlot.WEAPON


## ============ AC-25 — equip ok 同 frame re-read;cosmetic 通道分離 ============

func test_ac25_equip_ok_rereads_same_frame() -> void:
	_make_item(&"sword_a", W, EquipmentEnums.ItemLifecycle.IN_INVENTORY)
	_open()
	var result: Dictionary = _sut.equip_item(&"sword_a", W)
	assert_true(result["ok"])
	assert_eq(_sut.get_loadout_view()[W].get("item_id"), &"sword_a", "同 frame re-read → slot card 更新")


func test_ac25_cosmetic_equip_no_stat_tween() -> void:
	var cos := _make_item(&"hat", EquipmentEnums.EquipSlot.COSMETIC,
		EquipmentEnums.ItemLifecycle.IN_INVENTORY, {})
	cos.is_cosmetic = true
	_open()
	var result: Dictionary = _sut.equip_item(&"hat", EquipmentEnums.EquipSlot.COSMETIC)
	assert_true(result["ok"])
	for id in CoordinatorScript.STAT_IDS:
		assert_eq(_sut.get_stat_arrow(id), 0, "cosmetic 永不餵 #11 → 零 stat tween(Rule 21)")


## ============ AC-26 — 全 5 error + deferred_reentrancy 例外 ============

func test_ac26_error_strings_toast_and_reread() -> void:
	_make_item(&"locked_it", W, EquipmentEnums.ItemLifecycle.IN_INVENTORY)
	_inv._items[&"locked_it"].is_locked = true
	_make_item(&"mailbox_it", W, EquipmentEnums.ItemLifecycle.IN_MAILBOX)
	_open()
	# not_found
	_sut.equip_item(&"ghost", W)
	assert_eq(_sut.get_toast().get("text"), "件物品已唔存在")
	# in_mailbox_claim_first
	_sut.equip_item(&"mailbox_it", W)
	assert_eq(_sut.get_toast().get("text"), "先去信箱領取")
	# slot_type_mismatch(weapon item → cosmetic slot)
	_make_item(&"sword_b", W, EquipmentEnums.ItemLifecycle.IN_INVENTORY)
	_sut.equip_item(&"sword_b", EquipmentEnums.EquipSlot.COSMETIC)
	assert_eq(_sut.get_toast().get("text"), "件裝備唔啱呢個位")
	# slot_empty(unequip 空 slot)
	_sut.unequip_slot(EquipmentEnums.EquipSlot.ARMOR)
	assert_eq(_sut.get_toast().get("text"), "呢個位係空嘅")
	# locked(salvage locked item — 直接 call #17 證 error path;UI 入口已 disabled)
	var r: Dictionary = _inv.salvage(&"locked_it")
	assert_eq(r.get("error"), "locked")


func test_ac26_toast_expires_on_injected_clock() -> void:
	_open()
	_sut.equip_item(&"ghost", W)
	assert_false(_sut.get_toast().is_empty())
	_sut.advance(TimingConfig.ERROR_TOAST_DURATION_MS)
	assert_true(_sut.get_toast().is_empty(), "toast 經 injected clock 過期")


## ============ AC-27 — unconditional nudge + inline [鎖定] ============

func test_ac27_nudge_appears_and_inline_lock() -> void:
	_make_item(&"sword_a", W, EquipmentEnums.ItemLifecycle.IN_INVENTORY)
	_open()
	_sut.equip_item(&"sword_a", W)
	var nudge: Dictionary = _sut.get_nudge(W)
	assert_false(nudge.is_empty(), "未 lock manual equip → unconditional nudge")
	assert_false(nudge["confirmed"])
	# inline [鎖定] one-tap(gd F-6 pin)
	_sut.nudge_lock_tap(W)
	assert_true(_inv.get_item(&"sword_a").is_locked, "tap → set_lock(true)")
	assert_true(_sut.get_nudge(W)["confirmed"], "nudge 變「已鎖定」確認態")


func test_ac27_nudge_expires_and_locked_equip_no_nudge() -> void:
	_make_item(&"sword_a", W, EquipmentEnums.ItemLifecycle.IN_INVENTORY)
	_open()
	_sut.equip_item(&"sword_a", W)
	_sut.advance(TimingConfig.LOCK_NUDGE_DURATION_MS)
	assert_true(_sut.get_nudge(W).is_empty(), "LOCK_NUDGE_DURATION_MS 後消失")
	# 已 lock item re-equip → 無 nudge
	_inv.set_lock(&"sword_a", true)
	_inv.unequip(W)
	_sut.equip_item(&"sword_a", W)
	assert_true(_sut.get_nudge(W).is_empty(), "已 lock → 無 nudge")


## ============ AC-28 — salvage 兩步 friction + modal view ============

func test_ac28_salvage_confirm_view_complete() -> void:
	var item := _make_item(&"sword_a", W, EquipmentEnums.ItemLifecycle.IN_INVENTORY,
		{&"attack_power": 10.0}, 4)  # LEGENDARY
	var receipt := SourceReceipt.new()
	receipt.signature_text = "於 6月3日腿日,以 120kg 之軀鍛成"
	item.source_receipt = receipt
	_open()
	_sut.equip_item(&"sword_a", W)  # equipped → warning 行
	_sut.open_inspect(&"sword_a")
	_sut.request_salvage(&"sword_a")
	assert_eq(_sut.get_modal(), CoordinatorScript.ModalKind.SALVAGE_CONFIRM)
	var view: Dictionary = _sut.get_salvage_confirm_view()
	assert_eq(view["yield"], _inv.salvage_yield(4), "static yield preview")
	assert_eq(view["provenance"], "拾於 6月3日・腿日")
	assert_eq(view["warning"], "現役裝備 — 會自動卸下(如有後備會自動補上)")
	assert_eq(view["signature_text"], "於 6月3日腿日,以 120kg 之軀鍛成", "LEGENDARY signature")


func test_ac28_no_single_tap_destruction_path() -> void:
	_make_item(&"sword_a", W, EquipmentEnums.ItemLifecycle.IN_INVENTORY)
	_open()
	_sut.request_salvage(&"sword_a")  # 第一步只開 modal
	assert_eq(_inv.get_item(&"sword_a").lifecycle_state,
		EquipmentEnums.ItemLifecycle.IN_INVENTORY, "request 唔執行 salvage")
	# confirm 冇 modal context → no-op
	_sut.cancel_modal()
	var r: Dictionary = _sut.confirm_salvage()
	assert_false(r.get("ok", false), "無 confirm context → 永無單 tap 毀件")


## ============ AC-29 — locked salvage 入口灰掉 ============

func test_ac29_locked_item_salvage_disabled_in_inspect() -> void:
	_make_item(&"sword_a", W, EquipmentEnums.ItemLifecycle.IN_INVENTORY)
	_inv.set_lock(&"sword_a", true)
	_open()
	_sut.open_inspect(&"sword_a")
	assert_false(_sut.get_inspect_view()["salvage_enabled"], "locked → 入口 disabled")
	_sut.request_salvage(&"sword_a")
	assert_eq(_sut.get_modal(), CoordinatorScript.ModalKind.ITEM_INSPECT,
		"double guard:locked request_salvage 唔開 modal")


## ============ AC-30 — salvage 現役兩 outcome(EC-13 backfill split)============

func test_ac30a_salvage_equipped_with_candidate_backfills() -> void:
	_make_item(&"sword_a", W, EquipmentEnums.ItemLifecycle.IN_INVENTORY, {&"attack_power": 20.0})
	_make_item(&"sword_b", W, EquipmentEnums.ItemLifecycle.IN_INVENTORY, {&"attack_power": 10.0})
	_open()
	_sut.equip_item(&"sword_a", W)
	_sut.request_salvage(&"sword_a")
	var shards_before: int = _inv.get_forge_shards()
	_sut.confirm_salvage()
	var card: Dictionary = _sut.get_loadout_view()[W]
	assert_eq(card.get("item_id"), &"sword_b", "(a) 有 candidate → backfill item render")
	assert_false(_sut.get_backfill_note(W).is_empty(), "「自動補上」ledger note")
	assert_gt(_inv.get_forge_shards(), shards_before, "shards snap 更新")


func test_ac30b_salvage_equipped_no_candidate_empty_slot() -> void:
	_make_item(&"sword_a", W, EquipmentEnums.ItemLifecycle.IN_INVENTORY)
	_open()
	_sut.equip_item(&"sword_a", W)
	_sut.request_salvage(&"sword_a")
	_sut.confirm_salvage()
	assert_true(_sut.get_loadout_view()[W].is_empty(), "(b) 無 candidate → empty slot")
	assert_true(_sut.get_backfill_note(W).is_empty(), "無 backfill note")


## ============ AC-31 — picker(F3 sort / empty 照開 / stale rebuild)============

func test_ac31_picker_sorted_and_filtered() -> void:
	_make_item(&"sword_a", W, EquipmentEnums.ItemLifecycle.IN_INVENTORY, {&"attack_power": 5.0}, 3)
	_make_item(&"axe_b", W, EquipmentEnums.ItemLifecycle.IN_INVENTORY, {&"attack_power": 5.0}, 3)
	_make_item(&"bow_c", W, EquipmentEnums.ItemLifecycle.IN_INVENTORY, {&"attack_power": 5.0}, 2)
	_open()
	_sut.open_picker(W)
	assert_eq(_sut.get_modal(), CoordinatorScript.ModalKind.SLOT_PICKER)
	assert_eq(_sut.get_picker_view()["item_ids"], [&"axe_b", &"sword_a", &"bow_c"] as Array,
		"F3:rarity desc → 同秒 id asc")


func test_ac31_empty_picker_still_opens() -> void:
	_open()
	_sut.open_picker(W)
	assert_eq(_sut.get_modal(), CoordinatorScript.ModalKind.SLOT_PICKER, "0 件照開 sheet(EC-20)")
	assert_eq((_sut.get_picker_view()["item_ids"] as Array).size(), 0)


func test_ac31_stale_row_toast_and_inplace_rebuild() -> void:
	_make_item(&"sword_a", W, EquipmentEnums.ItemLifecycle.IN_INVENTORY)
	_make_item(&"sword_b", W, EquipmentEnums.ItemLifecycle.IN_INVENTORY)
	_open()
	_sut.open_picker(W)
	# cross-surface 消滅(#23 bulk class)— picker 仲顯示 sword_a
	_inv.salvage(&"sword_a")
	var r: Dictionary = _sut.picker_tap(&"sword_a")
	assert_eq(r.get("error"), "not_found")
	assert_eq(_sut.get_modal(), CoordinatorScript.ModalKind.SLOT_PICKER, "唔 close picker")
	assert_eq(_sut.get_picker_view()["item_ids"], [&"sword_b"] as Array, "原地 rebuild")


func test_ac31_picker_tap_equips_and_closes() -> void:
	_make_item(&"sword_a", W, EquipmentEnums.ItemLifecycle.IN_INVENTORY)
	_open()
	_sut.open_picker(W)
	var r: Dictionary = _sut.picker_tap(&"sword_a")
	assert_true(r["ok"])
	assert_eq(_sut.get_modal(), CoordinatorScript.ModalKind.NONE, "成功 → close sheet")


## ============ AC-32 — confirm 時 item 已死(EC-18)============

func test_ac32_confirm_on_dead_item() -> void:
	_make_item(&"sword_a", W, EquipmentEnums.ItemLifecycle.IN_INVENTORY)
	_open()
	_sut.request_salvage(&"sword_a")
	var shards_before: int = _inv.get_forge_shards()
	_inv.salvage(&"sword_a")  # 另一路徑消滅(TTL/bulk class)— credit 已俾 #17 做
	var shards_after_external: int = _inv.get_forge_shards()
	var r: Dictionary = _sut.confirm_salvage()
	assert_eq(r.get("error"), "not_found")
	assert_eq(_sut.get_modal(), CoordinatorScript.ModalKind.NONE, "modal close")
	assert_eq(_sut.get_toast().get("text"), "件物品已唔存在")
	assert_eq(_inv.get_forge_shards(), shards_after_external, "#22 零自行 shards 變動")
	assert_gt(shards_after_external, shards_before, "credit 係外部消滅嗰下已做")


## ============ AC-33 — EC-04 三 orderings ============

func test_ac33_i_equip_then_force_close_result_stands_toast_dropped() -> void:
	_make_item(&"sword_a", W, EquipmentEnums.ItemLifecycle.IN_INVENTORY)
	_open()
	_sut.equip_item(&"ghost", W)  # 製造 pending toast
	var result: Dictionary = _sut.equip_item(&"sword_a", W)
	assert_true(result["ok"], "command 結果成立(#17 已 mutate)")
	_gsm.transition(GSMScript.GameState.WORKOUT_ACTIVE)  # 同 frame force-close
	_sut.advance(TimingConfig.FORCE_CLOSE_MAX_MS)
	assert_eq(_inv.get_item(&"sword_a").lifecycle_state,
		EquipmentEnums.ItemLifecycle.EQUIPPED, "(i) #17 state 成立 — close 永不 cancel write")
	assert_true(_sut.get_toast().is_empty(), "(i) pending toast drop")


func test_ac33_ii_force_close_first_input_ignored() -> void:
	_make_item(&"sword_a", W, EquipmentEnums.ItemLifecycle.IN_INVENTORY)
	_open()
	_gsm.transition(GSMScript.GameState.WORKOUT_ACTIVE)  # FORCE_CLOSING
	var r: Dictionary = _sut.equip_item(&"sword_a", W)
	assert_eq(r.get("error"), "screen_not_open", "(ii) FORCE_CLOSING input ignore")
	assert_eq(_inv.get_item(&"sword_a").lifecycle_state,
		EquipmentEnums.ItemLifecycle.IN_INVENTORY, "#17 untouched")


func test_ac33_iii_deferred_reentrancy_real_17_replay() -> void:
	# 真 #17 誘發:hostile #11 seam 喺 push window 內 re-enter(禁 mock stub)
	var hostile := HostileInvStat.new()
	_inv._stat_system = hostile
	_make_item(&"outer", W, EquipmentEnums.ItemLifecycle.IN_INVENTORY, {&"attack_power": 22.0})
	_make_item(&"inner", EquipmentEnums.EquipSlot.ARMOR,
		EquipmentEnums.ItemLifecycle.IN_INVENTORY, {&"attack_power": 6.0})
	_inv._items[&"inner"].item_type = LootEnums.ItemType.ARMOR
	_open()
	hostile.sut_coordinator = _sut
	hostile.reentry_item = &"inner"
	hostile.reentry_slot = EquipmentEnums.EquipSlot.ARMOR
	var outer_result: Dictionary = _sut.equip_item(&"outer", W)
	assert_true(outer_result["ok"], "outer command 成功")
	assert_eq(hostile.reentry_result.get("error"), "deferred_reentrancy", "inner 收 deferred")
	assert_true(_sut.get_toast().is_empty(), "(iii) deferred_reentrancy 唔 toast(EC-23)")
	# #17 下一 frame 真 replay → 收割
	await get_tree().process_frame
	await get_tree().process_frame  # replay + #22 call_deferred re-read
	assert_eq(_inv.get_item(&"inner").lifecycle_state,
		EquipmentEnums.ItemLifecycle.EQUIPPED, "(iii) #17 replay 照行")


## ============ AC-34 — inspect view ============

func test_ac34_inspect_view_via_card_body_tap() -> void:
	var item := _make_item(&"sword_a", W, EquipmentEnums.ItemLifecycle.IN_INVENTORY,
		{&"attack_power": 10.0}, 4)
	var receipt := SourceReceipt.new()
	receipt.signature_text = "簽名收據"
	item.source_receipt = receipt
	_open()
	_sut.open_inspect(&"sword_a")
	var view: Dictionary = _sut.get_inspect_view()
	assert_eq(view["provenance"], "拾於 6月3日・腿日", "provenance 全 tier 顯示")
	assert_eq(view["signature_text"], "簽名收據")
	assert_true(view["salvage_enabled"], "salvage 入口住 inspect 內")
	assert_eq(view["stat_modifiers"], {&"attack_power": 10.0}, "原始 stat_modifiers — 禁 predicted final")


## ============ AC-50 — DISCONNECTED 全功能(EC-30)============

func test_ac50_disconnected_commands_identical() -> void:
	_gsm.state = GSMScript.GameState.DISCONNECTED
	_make_item(&"sword_a", W, EquipmentEnums.ItemLifecycle.IN_INVENTORY)
	_open()
	assert_true(_sut.is_offline_banner_visible(), "唯一 delta = banner")
	assert_true(_sut.equip_item(&"sword_a", W)["ok"], "equip 照行")
	assert_true(_sut.toggle_lock(&"sword_a", true)["ok"], "set_lock 照行")
	_inv.set_lock(&"sword_a", false)
	_sut.request_salvage(&"sword_a")
	assert_true(_sut.confirm_salvage()["ok"], "salvage confirm 照行")


## ============ AC-51 / AC-19 — modal dismiss routing(EC-07)============

func test_ac51_scrim_esc_first_dismiss_is_cancel() -> void:
	_make_item(&"sword_a", W, EquipmentEnums.ItemLifecycle.IN_INVENTORY)
	_open()
	_sut.request_salvage(&"sword_a")
	var consumed: bool = _sut.handle_escape()  # ESC 第一下 / scrim tap 等效
	assert_true(consumed, "第一下俾 modal 食咗")
	assert_eq(_sut.get_modal(), CoordinatorScript.ModalKind.NONE, "dismiss = cancel")
	assert_eq(_inv.get_item(&"sword_a").lifecycle_state,
		EquipmentEnums.ItemLifecycle.IN_INVENTORY, "item 不變(destructive-safe)")
	# 第二下先 close screen
	_sut.handle_escape()
	assert_eq(_sut.get_screen_state(), CoordinatorScript.ScreenState.CLOSING, "AC-19 第二下 close")
