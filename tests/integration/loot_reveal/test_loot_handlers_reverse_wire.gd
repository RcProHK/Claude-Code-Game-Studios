extends GutTest
## Story 018 (G-LM-4b) — real #15 + real #21 reverse-wire integration.
## 解封 AC-19 / AC-34b / AC-65 嘅 #15 半邊 + AC-71 ordering case 全鏈。
##
## GDD: design/gdd/loot-drop-modal.md G-LM-4 ③④⑤ / Rule 6/7/13.

const CoordinatorScript := preload("res://src/autoload/loot_reveal_coordinator.gd")
const LootSystemScript := preload("res://src/autoload/loot_drop_system.gd")

const S := CoordinatorScript.ModalState


class MockPersistence:
	extends RefCounted
	var store: Dictionary = {}
	func read(key: String) -> Variant:
		return store.get(key)
	func write(key: String, value: Variant, _flush: bool = false) -> bool:
		store[key] = value
		return true
	func delete(key: String) -> bool:
		store.erase(key)
		return true
	func list_keys(prefix: String) -> Array:
		var out: Array = []
		for k: String in store.keys():
			if k.begins_with(prefix):
				out.append(k)
		return out
	func is_private_mode() -> bool:
		return false


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
	var current_state: int = 2
	func get_current_state() -> int:
		return current_state
	func connect_for_initial_state(callable: Callable) -> void:
		state_changed.connect(callable)
	func go(to_state: int) -> void:
		var from: int = current_state
		current_state = to_state
		state_changed.emit(from, to_state, null)


var _persist: MockPersistence
var _gsm: MockGsm
var _loot: Node
var _inv: FakeInventory
var _confirmed: int = 0


func _make() -> Node:
	_persist = MockPersistence.new()
	_gsm = MockGsm.new()
	_inv = FakeInventory.new()
	_confirmed = 0
	_loot = LootSystemScript.new()
	_loot._persistence = _persist
	add_child_autofree(_gsm)
	add_child_autofree(_inv)
	add_child_autofree(_loot)
	_loot.loot_confirmed.connect(func(_queue_drained: bool) -> void: _confirmed += 1)
	var c: Node = CoordinatorScript.new()
	c._gsm = _gsm
	c._loot_system = _loot
	c._inventory = _inv
	add_child_autofree(c)  # _ready reverse-wires modal_dismissed → on_modal_dismissed
	return c


func _grant_full(tid: String, ws: float = 0.6) -> LootDrop:
	_loot._process_loot_trigger(tid, LootEnums.SourceEventKind.MINI_BOSS, ws, LootEnums.CeremonyDecision.FULL_CEREMONY)
	return _loot._drops_by_transition.get(tid)


# --- AC-19 full: terminal dismiss → #15 dequeue → loot_confirmed ---

func test_terminal_dismiss_drains_queue_and_emits_loot_confirmed() -> void:
	var c: Node = _make()
	var drop: LootDrop = _grant_full("tid_a")
	_gsm.go(7)  # LOOT_DROP → modal opens
	assert_true(c.is_modal_active())
	for i: int in range(4):
		c._process(0.5)  # natural S3 (any tier)
	c._process(0.3)
	c.handle_tap()       # dismiss
	c._process(0.2)      # S4 done → terminal emit → handler dequeues
	assert_eq(_loot.get_pending_drops().size(), 0, "#15 以 drop_id dequeue")
	assert_eq(_confirmed, 1, "queue 空 + terminal → loot_confirmed exactly-once(GSM exit chain)")
	assert_true(drop.revealed, "revealed flag set — reboot 永不 re-reveal banked 件")
	var on_disk: Dictionary = _persist.store.get("loot.pending." + drop.drop_id, {})
	assert_true(bool(on_disk.get("revealed", false)), "pending snapshot 已刷新")


func test_intra_queue_dismiss_dequeues_without_confirming() -> void:
	var c: Node = _make()
	_grant_full("tid_1")
	_grant_full("tid_2")
	_gsm.go(7)
	for i: int in range(4):
		c._process(0.5)
	c._process(0.3)
	c.handle_tap()
	c._process(0.2)  # S4 → intra emit → dequeue 第 1 件
	assert_eq(_loot.get_pending_drops().size(), 1, "dequeue by drop_id — 第 2 件仍喺 queue")
	assert_eq(_confirmed, 0, "非 terminal — 零 loot_confirmed")


func test_double_dismiss_is_a_silent_noop() -> void:
	var c: Node = _make()
	var drop: LootDrop = _grant_full("tid_dd")
	_loot.on_modal_dismissed(drop.drop_id, false)
	assert_eq(_loot.get_pending_drops().size(), 0)
	_loot.on_modal_dismissed(drop.drop_id, false)  # EC-29 — replay
	assert_eq(_loot.get_pending_drops().size(), 0, "double-dismiss no-op,無 error")


# --- AC-71 ordering case 全鏈: ACK 先到、reveal 後到 ---

func test_ack_first_reveal_later_full_round_trip() -> void:
	var c: Node = _make()
	var drop: LootDrop = _grant_full("tid_order")
	_loot._on_backend_ack({"drop_id": drop.drop_id, "canonical_id": "canon_x"})
	assert_eq(_loot.get_pending_drops().size(), 1, "件仍喺 reveal queue")
	_gsm.go(7)  # 照 reveal
	assert_true(c.is_modal_active(), "ACK 後照 reveal")
	for i: int in range(4):
		c._process(0.5)
	c._process(0.3)
	c.handle_tap()
	c._process(0.2)
	assert_eq(_loot.get_pending_drops().size(), 0, "dequeue 唔 skip — queue 清")
	assert_true(_persist.store.has("loot.committed.canon_x"), "commit rename 完好(雙語意分離)")
	assert_eq(_confirmed, 1)


# --- AC-65 report 半邊: recovery 鏈 + dedupe ---

func test_failed_rollback_records_recovery_entry_once() -> void:
	var c: Node = _make()
	_inv.result = EquipmentEnums.ReceiveResult.FAILED_ROLLBACK
	var drop: LootDrop = _grant_full("tid_fail")
	_gsm.go(7)
	for i: int in range(4):
		c._process(0.5)  # S3 → receive FAILED → report chain
	var key: String = "loot.pending.recovery." + drop.drop_id
	assert_true(_persist.store.has(key), "loot.pending.recovery 寫入(#17 EC-1 boot-drain 鏈保全)")
	var snapshot = _persist.store[key]
	_loot.report_receive_failure(drop.drop_id)  # defer-path 假報
	assert_eq(_persist.store[key], snapshot, "dedupe — 重複 report 係 no-op")


# --- AC-34b dequeue 半邊: micro_ack 經 emit-back 清走 ---

func test_micro_ack_banking_dequeues_via_the_same_handler() -> void:
	var c: Node = _make()
	_loot._process_loot_trigger("tid_micro", LootEnums.SourceEventKind.WORKOUT_DAILY, 0.2, LootEnums.CeremonyDecision.MICRO_ACK)
	# micro 件唔喺 reveal queue;#21 嘅 micro_ack handler 已 bank + emit-back:
	assert_eq(_loot.get_pending_drops().size(), 0)
	assert_eq(_inv.calls.size(), 1, "Rule 9 banking 即時(optimistic emit 觸發 #21 handler)")
	var micro: LootDrop = _loot._drops_by_transition["tid_micro"]
	assert_true(micro.revealed, "emit-back 經同一 handler 標 revealed")
