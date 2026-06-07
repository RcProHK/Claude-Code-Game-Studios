extends GutTest
## Story 024 (G-LM-10) — #17 public batch seam(begin/end_receive_batch)。
## 解封 AC-72 batch 半邊 / AC-28+58 seam call 半邊嘅 real-#17 基礎。
##
## GDD: design/gdd/loot-drop-modal.md G-LM-10 / Rule 7 catch-up batch.

const InventoryScript := preload("res://src/autoload/inventory_system.gd")
const TABLE_PATH: String = "res://assets/data/equipment/stat_assignment_table.tres"

var _persist: MockPersistenceLayer
var _inv: Node
var _state_writes: int = 0  # inventory.state persist counter(Contract 14 spy)


func _drop(id: String) -> LootDrop:
	var d := LootDrop.new()
	d.drop_id = id
	d.transition_id = "t_" + id
	d.rarity_tier = "COMMON"
	d.item_type = "WEAPON"
	d.item_metadata = {"item_id": id}
	return d


func _make() -> Node:
	_persist = MockPersistenceLayer.new()
	_state_writes = 0
	_persist.attach_write_spy(func(entry: Dictionary) -> void:
		if str(entry.get("key", "")) == "inventory.state":
			_state_writes += 1)
	_inv = InventoryScript.new()
	_inv._persistence = _persist
	_inv._gsm = MockInventoryGSM.new()
	_inv._stat_table = load(TABLE_PATH)
	_inv._stat_system = MockInventoryStat.new()
	_inv._now_unix_provider = func() -> int: return 1764547300
	add_child_autofree(_inv)
	return _inv


func test_batched_receives_persist_exactly_once() -> void:
	_make()
	var baseline: int = _state_writes
	_inv.begin_receive_batch()
	for i: int in range(5):
		_inv.receive_loot(_drop("b_%d" % i))
	assert_eq(_state_writes, baseline, "batch 內零 persist(coalesced)")
	_inv.end_receive_batch()
	assert_eq(_state_writes, baseline + 1, "end → persist 一次(5 件 1 write — G-LM-10)")


func test_unbatched_external_calls_persist_per_call() -> void:
	_make()
	var baseline: int = _state_writes
	_inv.receive_loot(_drop("u_1"))
	_inv.receive_loot(_drop("u_2"))
	assert_eq(_state_writes, baseline + 2,
		"shipped 行為不變:無 seam = 逐 call persist(:389-393 gate)— seam 係 opt-in")


func test_nested_batches_drain_on_the_outermost_end() -> void:
	_make()
	var baseline: int = _state_writes
	_inv.begin_receive_batch()
	_inv.begin_receive_batch()
	_inv.receive_loot(_drop("n_1"))
	_inv.end_receive_batch()
	assert_eq(_state_writes, baseline, "inner end 唔 drain")
	_inv.end_receive_batch()
	assert_eq(_state_writes, baseline + 1, "outermost end 先 drain")


func test_unbalanced_end_is_a_warned_noop() -> void:
	_make()
	var baseline: int = _state_writes
	_inv.end_receive_batch()  # 無 begin
	assert_eq(_state_writes, baseline, "no-op — depth 唔會變負")
	_inv.begin_receive_batch()
	_inv.receive_loot(_drop("h_1"))
	_inv.end_receive_batch()
	assert_eq(_state_writes, baseline + 1, "後續 balanced pair 正常(self-heal)")
