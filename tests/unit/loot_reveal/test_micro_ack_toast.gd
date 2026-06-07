extends GutTest
## Story 013 — micro_ack banking + F4 toast aggregation + flush gate + EC-M17.
## Covers AC-24 / AC-25 / AC-34b(#21-side 半)/ AC-48 / AC-49 / AC-68.
##
## GDD: design/gdd/loot-drop-modal.md Rule 9 / F4 / EC-M17.

const CoordinatorScript := preload("res://src/autoload/loot_reveal_coordinator.gd")

const S := CoordinatorScript.ModalState
const IDLE: int = 2
const WORKOUT_ACTIVE: int = 3
const LOOT_DROP: int = 7


class FakeInventory:
	extends Node
	var result: int = EquipmentEnums.ReceiveResult.OK
	var calls: Array = []
	func receive_loot(record) -> int:
		calls.append(record)
		return result


class MockGsm:
	extends Node
	signal state_changed(from_state, to_state, payload)
	var current_state: int = IDLE
	func get_current_state() -> int:
		return current_state
	func connect_for_initial_state(callable: Callable) -> void:
		state_changed.connect(callable)
	func go(to_state: int) -> void:
		var from: int = current_state
		current_state = to_state
		state_changed.emit(from, to_state, null)


class MockLootSystem:
	extends Node
	signal loot_dropped(drop_id: String, rarity_tier: String, item_type: String, transition_id: String)
	signal loot_micro_ack(drop_id: String)
	var drops: Dictionary = {}
	var pending: Array = []
	var report_calls: Array = []
	func get_pending_drops() -> Array:
		return pending
	func get_drop(drop_id: String) -> LootDrop:
		return drops.get(drop_id)
	func report_receive_failure(drop_id: String) -> void:
		report_calls.append(drop_id)
	func fire_micro_ack(drop_id: String) -> void:
		loot_micro_ack.emit(drop_id)


var _gsm: MockGsm
var _loot: MockLootSystem
var _inv: FakeInventory
var _dismissed: Array = []


func _drop(id: String, tier_name: String = "COMMON") -> LootDrop:
	var d := LootDrop.new()
	d.drop_id = id
	d.rarity_tier = tier_name
	return d


func _make() -> Node:
	_gsm = MockGsm.new()
	_loot = MockLootSystem.new()
	_inv = FakeInventory.new()
	_dismissed = []
	for n: Node in [_gsm, _loot, _inv]:
		add_child_autofree(n)
	var c: Node = CoordinatorScript.new()
	c._gsm = _gsm
	c._loot_system = _loot
	c._inventory = _inv
	add_child_autofree(c)
	c.modal_dismissed.connect(func(id: String, terminal: bool) -> void:
		_dismissed.append({"id": id, "terminal": terminal}))
	return c


func _ack(c: Node, id: String, tier: String = "COMMON") -> void:
	_loot.drops[id] = _drop(id, tier)
	_loot.fire_micro_ack(id)


# --- AC-34b (#21-side): banking + dequeue emit + zero UI + variant ---

func test_micro_ack_banks_instantly_with_zero_ui_and_dequeue_emit() -> void:
	var c: Node = _make()
	_gsm.current_state = WORKOUT_ACTIVE  # mid-workout cap-hit context
	_ack(c, "ack_1", "UNCOMMON")
	assert_eq(_inv.calls.size(), 1, "receive_loot exactly-once — 真係入咗庫")
	assert_eq(_dismissed, [{"id": "ack_1", "terminal": false}], "dequeue emit-back")
	assert_false(c.is_modal_active(), "零 modal/UI 動作")
	assert_false(c._toast_active, "mid-workout — toast held (F4 gate)")
	# 唔漏入 catch-up:
	_loot.pending = [_drop("ack_1", "UNCOMMON")]
	assert_eq(c._queue_depth(), 0, "acked 件唔再出現喺 pull(唔會變 full ceremony)")


func test_micro_ack_failed_rollback_walks_the_report_chain() -> void:
	var c: Node = _make()
	_inv.result = EquipmentEnums.ReceiveResult.FAILED_ROLLBACK
	_ack(c, "ack_bad")
	assert_eq(_loot.report_calls, ["ack_bad"], "report_receive_failure exactly-once(Rule 9 鏈)")


# --- AC-24: toast 結構(safe state、即 flush 後) ---

func test_toast_structure_in_safe_state() -> void:
	var c: Node = _make()
	_gsm.current_state = IDLE
	_ack(c, "ack_1", "RARE")
	c._process(0.15)  # FLUSH_DELAY → toast opens
	assert_true(c._toast_active, "safe state + modal closed → toast")
	assert_eq(c._toast_node.get_parent(), c._toast_container, "anchor 喺 edge container(parent assert)")
	assert_eq(c._toast_n, 1)
	assert_eq(c._toast_tier, LootEnums.RarityTier.RARE, "tier tint = 件 tier")
	assert_eq(c._toast_phase, "entry", "entry beat 行緊")
	var has_text: bool = false
	for child in c._toast_node.get_children():
		if child is Label:
			has_text = true
	assert_false(has_text, "零 text node")
	assert_false(c._toast_node is Control, "無 input handler(non-interactive)")
	c._process(0.15)  # entry == TOAST_ENTRY_SEC
	assert_eq(c._toast_phase, "plateau", "entry 時長 == config")


# --- AC-25: modal active 時 defer + 單一 aggregated flush ---

func test_acks_during_modal_defer_then_flush_as_single_aggregate() -> void:
	var c: Node = _make()
	_gsm.current_state = IDLE
	_loot.pending = [_drop("reveal_1", "COMMON")]
	_gsm.go(LOOT_DROP)
	assert_true(c.is_modal_active())
	for i: int in range(3):
		_ack(c, "ack_%d" % i, ["COMMON", "EPIC", "UNCOMMON"][i])
	assert_false(c._toast_active, "modal active — 零 toast 即出")
	c._process(0.25)  # natural S3
	c._process(0.3)
	c.handle_tap()    # dismiss
	c._process(0.2)   # S4 done → terminal → HIDDEN(GSM 仍 LOOT_DROP — mock 唔轉)
	_gsm.current_state = IDLE  # #15 chain 會帶 GSM 返 safe;mock 手動
	c._process(0.15)  # FLUSH_DELAY
	assert_true(c._toast_active, "close 後 flush")
	assert_eq(c._toast_n, 3, "單一「×3」toast")
	assert_eq(c._toast_tier, LootEnums.RarityTier.EPIC, "tint == 最高 tier")


# --- AC-48: F4 display 規則 ---

func test_f4_display_aggregation_counts() -> void:
	var c: Node = _make()
	_gsm.current_state = IDLE
	for i: int in range(150):
		c._enqueue_ack(LootEnums.RarityTier.COMMON)
	c._process(0.15)
	assert_eq(c._toast_n, 150, "internal count 150 — 「×99+」display cap 係 UI 層格式(027)")


# --- AC-49: merge 邊界 + 守恆 ---

func test_merge_extends_within_cap_and_overflow_goes_to_carryover() -> void:
	var c: Node = _make()
	_gsm.current_state = IDLE
	c._enqueue_ack(LootEnums.RarityTier.COMMON)
	c._process(0.15)  # toast opens (age 0.15, entry)
	assert_true(c._toast_active)
	# Sustained ack stream — each merge tops the plateau up to MERGE_MIN_REMAIN,
	# keeping the instance alive toward the lifetime cap:
	var tiers: Array = [LootEnums.RarityTier.RARE, LootEnums.RarityTier.COMMON,
		LootEnums.RarityTier.COMMON, LootEnums.RarityTier.COMMON]
	for tier: int in tiers:
		c._process(0.5)
		c._enqueue_ack(tier)
	# ages at ack: 0.65/1.15/1.65/2.15 — remaining-to-cap ≥ 0.6 ⇒ all merged.
	assert_eq(c._toast_n, 5, "merges accumulated (N=5)")
	assert_eq(c._toast_tier, LootEnums.RarityTier.RARE, "tint 升到最高 tier")
	c._process(0.5)  # age 2.65
	c._enqueue_ack(LootEnums.RarityTier.COMMON)  # remaining-to-cap 0.35 < 0.6
	assert_eq(c._toast_n, 5, "remaining-to-cap < MERGE_MIN_REMAIN → 唔 merge")
	assert_eq(c._carryover_acks.size(), 1, "直入 carryover bucket")
	# plateau 耗盡 → fade → close → carryover 開新 toast:
	for i: int in range(4):
		c._process(0.2)
	assert_true(c._toast_active, "carryover N 開新 toast")
	assert_eq(c._toast_n, 1)
	var conserved: int = c._displayed_acks_total + c._toast_n + c._carryover_acks.size()
	assert_eq(conserved, 6, "守恆:Σ displayed(5) + active(1) + carryover(0) == total acks(6)")
	assert_eq(c._total_acks, 6, "audit input matches")


# --- AC-68: EC-M17 toast interrupt 守恆 ---

func test_modal_opening_folds_visible_toast_back_into_deferred() -> void:
	var c: Node = _make()
	_gsm.current_state = IDLE
	c._enqueue_ack(LootEnums.RarityTier.COMMON)
	c._enqueue_ack(LootEnums.RarityTier.COMMON)
	c._process(0.15)
	assert_true(c._toast_active)
	assert_eq(c._toast_n, 2)
	_loot.pending = [_drop("reveal_x", "RARE")]
	_gsm.go(LOOT_DROP)  # modal opens over the toast
	assert_false(c._toast_active, "即時 interrupt(fade 係 skin)")
	assert_true(c.is_modal_active())
	assert_eq(c._deferred_acks.size(), 1, "count fold 入 deferred")
	assert_eq(int(c._deferred_acks[0]["n"]), 2, "N=2 完整保留 — count 唔可以蒸發")
	# close 後 flush 包齊:
	c._process(0.5)
	for i: int in range(3):
		c._process(0.5)
	c.handle_tap()
	c._process(0.3)
	c.handle_tap()
	c._process(0.2)
	_gsm.current_state = IDLE
	c._process(0.15)
	assert_true(c._toast_active)
	assert_eq(c._toast_n, 2, "重新 flush 總數守恆")
