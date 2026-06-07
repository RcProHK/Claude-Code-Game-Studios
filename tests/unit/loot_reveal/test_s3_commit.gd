extends GutTest
## Story 009 — INV-M3 S3 commit + EC-M14 五 variant + EC-M5 同源 cross-pin.
## Covers AC-20 / AC-56(unit 半 — real-#17 equality @ 026)/ AC-65(#21-side
## 半 — report handler real 半 @ 018)。AC-21 = CI lint(check_receive_loot_callers)。
##
## GDD: design/gdd/loot-drop-modal.md Rule 7 / EC-M14 / EC-M5.

const CoordinatorScript := preload("res://src/autoload/loot_reveal_coordinator.gd")

const S := CoordinatorScript.ModalState
const RR := EquipmentEnums.ReceiveResult


class FakeInventory:
	extends Node
	var result: int = RR.OK
	var calls: Array = []  # captured records
	func receive_loot(record) -> int:
		calls.append(record)
		return result


class MockGsm:
	extends Node
	signal state_changed(from_state, to_state, payload)
	var current_state: int = 7
	func get_current_state() -> int:
		return current_state
	func connect_for_initial_state(callable: Callable) -> void:
		state_changed.connect(callable)
	func enter_loot_drop() -> void:
		state_changed.emit(2, 7, null)


class MockLootSystem:
	extends Node
	signal loot_dropped(drop_id: String, rarity_tier: String, item_type: String, transition_id: String)
	var pending: Array = []
	var report_calls: Array = []
	func get_pending_drops() -> Array:
		return pending
	func report_receive_failure(drop_id: String) -> void:
		report_calls.append(drop_id)


var _gsm: MockGsm
var _loot: MockLootSystem
var _inv: FakeInventory


func _drop(tier_name: String) -> LootDrop:
	var d := LootDrop.new()
	d.drop_id = "drop_s3"
	d.rarity_tier = tier_name
	return d


func _make() -> Node:
	_gsm = MockGsm.new()
	_loot = MockLootSystem.new()
	_inv = FakeInventory.new()
	for n: Node in [_gsm, _loot, _inv]:
		add_child_autofree(n)
	var c: Node = CoordinatorScript.new()
	c._gsm = _gsm
	c._loot_system = _loot
	c._inventory = _inv
	add_child_autofree(c)
	return c


func _open_to_s3(c: Node, tier_name: String = "COMMON") -> void:
	_loot.pending = [_drop(tier_name)]
	_gsm.enter_loot_drop()
	c._process(0.25)  # COMMON: entry 150 → CEREMONY; T_block 200 → STEADY
	if tier_name != "COMMON":
		for i: int in range(4):
			c._process(0.5)
	assert_eq(c.get_fsm_state(), S.STEADY)


# --- AC-20: exactly-once @ S3 entry; tap adds nothing; banked before any exit ---

func test_receive_loot_fires_exactly_once_at_s3_entry_without_tap() -> void:
	var c: Node = _make()
	_open_to_s3(c)
	assert_eq(_inv.calls.size(), 1, "banking at S3 ENTRY — no tap required (INV-M3)")
	c._process(1.0)
	assert_eq(_inv.calls.size(), 1, "parking in S3 never re-banks")


func test_tap_dismiss_never_double_banks() -> void:
	var c: Node = _make()
	_open_to_s3(c)
	c._process(0.3)  # past any debounce concerns (natural S3 anyway)
	c.handle_tap()   # dismiss → EXITING
	assert_eq(c.get_fsm_state(), S.EXITING)
	assert_eq(_inv.calls.size(), 1, "tap is ceremonial — zero second receive_loot")


func test_fast_complete_path_banks_once() -> void:
	var c: Node = _make()
	_loot.pending = [_drop("LEGENDARY")]
	_gsm.enter_loot_drop()
	c._process(0.5)  # CEREMONY
	c.handle_tap()   # fast-complete → snap
	c._process(0.1)  # S3
	assert_eq(c.get_fsm_state(), S.STEADY)
	assert_eq(_inv.calls.size(), 1, "fast-completed S3 banks exactly once")


# --- AC-65 (#21-side, ×5 ReceiveResult over fake #17) ---

func test_ok_is_silent_success() -> void:
	var c: Node = _make()
	_inv.result = RR.OK
	_open_to_s3(c)
	assert_eq(c.get_telemetry().size(), 0, "OK → zero telemetry, zero UI delta")


func test_failed_rollback_zero_visible_delta_plus_report_chain() -> void:
	var c: Node = _make()
	_inv.result = RR.FAILED_ROLLBACK
	_open_to_s3(c)
	assert_eq(c.get_fsm_state(), S.STEADY, "modal proceeds — dismissable as normal (EC-M14)")
	var critical: bool = false
	for entry: Dictionary in c.get_telemetry():
		if entry["event"] == "loot_reveal.receive_failed":
			critical = true
	assert_true(critical, "CRITICAL telemetry recorded")
	assert_eq(_loot.report_calls, ["drop_s3"], "report_receive_failure exactly once — EC-1 recovery chain alive")


func test_queued_suspended_is_success_with_stash_exit_flag() -> void:
	var c: Node = _make()
	_inv.result = RR.QUEUED_SUSPENDED
	_open_to_s3(c)
	assert_true(c._pending_stash_exit, "durably parked == success → stash-exit path (011 consumes)")
	assert_eq(_loot.report_calls.size(), 0, "no failure report — this is a success variant")


func test_duplicate_noop_counts_and_emits_no_second_ack() -> void:
	var c: Node = _make()
	_inv.result = RR.DUPLICATE_NOOP
	_open_to_s3(c)
	var counted: bool = false
	for entry: Dictionary in c.get_telemetry():
		if entry["event"] == "loot_reveal.duplicate_noop":
			counted = true
	assert_true(counted, "telemetry counter")
	assert_eq(c._deferred_acks.size(), 0, "no second micro_ack of any kind")


func test_converted_dupe_joins_deferred_ack_aggregate() -> void:
	var c: Node = _make()
	_inv.result = RR.CONVERTED_DUPE
	_open_to_s3(c)
	assert_eq(c._deferred_acks.size(), 1, "shard ack queued into the F4 deferred aggregate")
	assert_eq(c._deferred_acks[0]["reason"], "converted_dupe")


# --- AC-56 (unit 半): coercion 同源 — forwarded record unchanged ---

func test_unknown_tier_displays_common_but_forwards_record_untouched() -> void:
	var c: Node = _make()
	_loot.pending = [_drop("MYTHIC")]
	_gsm.enter_loot_drop()
	c._process(0.25)  # COMMON ladder (coerced) → STEADY
	assert_eq(c.get_fsm_state(), S.STEADY)
	assert_eq(c._current_tier, LootEnums.RarityTier.COMMON, "顯示 tier = COMMON (coerced before ladder)")
	assert_eq(str(_inv.calls[0].rarity_tier), "MYTHIC",
		"record forwarded RAW — #17 runs the SAME RarityTier.get coercion (同源 ⇒ 入庫 tier == 顯示 tier; real-#17 equality @ 026)")
