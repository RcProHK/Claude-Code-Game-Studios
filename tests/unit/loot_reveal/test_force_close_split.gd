extends GutTest
## Story 011 — force-close D1 pre/post-S3 split + stash-exit F6 + S4 idempotent.
## Covers AC-22 / AC-22b / AC-23 / AC-51 + AC-62(EC-M11 safe→safe)+ AC-1
## pre-S3-force-close path(×4 完成需 012 rollback path)。
##
## GDD: design/gdd/loot-drop-modal.md Rule 8 / Rule 7 D1 / F6 / EC-M11.

const CoordinatorScript := preload("res://src/autoload/loot_reveal_coordinator.gd")

const S := CoordinatorScript.ModalState
const WORKOUT_ACTIVE: int = 3  # 非 safe
const IDLE: int = 2            # safe
const DISCONNECTED: int = 1    # safe
const LOOT_DROP: int = 7
const SUSPENDED: int = 8


class CallLog:
	extends RefCounted
	var entries: Array = []
	func count(call_name: String) -> int:
		var n: int = 0
		for e: Dictionary in entries:
			if e["call"] == call_name:
				n += 1
		return n


class FakeScreenEffects:
	extends Node
	var log: CallLog
	var _next_handle: int = 0
	func ceremony_freeze(duration_sec: float):
		log.entries.append({"call": "ceremony_freeze", "duration": duration_sec})
		_next_handle += 1
		return _next_handle
	func release(handle) -> void:
		log.entries.append({"call": "release", "handle": handle})
	func shake(_i: float, _d: float) -> void:
		pass
	func apply_ceremony_saturation(_d: float, _r: float) -> void:
		pass


class FakeCamera:
	extends Node
	signal focal_completed(target_position: Vector2)
	func request_focal(_p: Vector2, _d: float = 0.0, _z: float = 1.0) -> void:
		pass
	func finish_focal() -> void:
		focal_completed.emit(Vector2.ZERO)


class FakeInventory:
	extends Node
	var calls: Array = []
	func receive_loot(record) -> int:
		calls.append(record)
		return EquipmentEnums.ReceiveResult.OK


class MockGsm:
	extends Node
	signal state_changed(from_state, to_state, payload)
	var current_state: int = LOOT_DROP
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
	var pending: Array = []
	func get_pending_drops() -> Array:
		return pending


var _log: CallLog
var _gsm: MockGsm
var _loot: MockLootSystem
var _cam: FakeCamera
var _inv: FakeInventory
var _dismissed: Array = []


func _drop(id: String, tier_name: String = "COMMON") -> LootDrop:
	var d := LootDrop.new()
	d.drop_id = id
	d.rarity_tier = tier_name
	return d


func _make() -> Node:
	_log = CallLog.new()
	_gsm = MockGsm.new()
	_loot = MockLootSystem.new()
	_cam = FakeCamera.new()
	_inv = FakeInventory.new()
	var fx := FakeScreenEffects.new()
	fx.log = _log
	_dismissed = []
	for n: Node in [_gsm, _loot, _cam, _inv, fx]:
		add_child_autofree(n)
	var c: Node = CoordinatorScript.new()
	c._gsm = _gsm
	c._loot_system = _loot
	c._camera = _cam
	c._inventory = _inv
	c._screen_effects = fx
	add_child_autofree(c)
	c.modal_dismissed.connect(func(id: String, terminal: bool) -> void:
		_dismissed.append({"id": id, "terminal": terminal}))
	return c


# --- AC-22b: pre-S3 force-close = cancel + re-reveal (D1) ---

func test_pre_s3_force_close_cancels_without_emit_and_re_reveals() -> void:
	var c: Node = _make()
	_loot.pending = [_drop("drop_a", "LEGENDARY")]
	_gsm.go(LOOT_DROP)
	c._process(0.5)      # CEREMONY (pre-S3)
	_cam.finish_focal()  # freeze active
	_gsm.go(WORKOUT_ACTIVE)  # rest_ended-class force-close
	assert_eq(c.get_fsm_state(), S.HIDDEN, "≤1 frame cancel")
	assert_eq(_log.count("release"), 1, "INV-M1 release fired (pre-S3 force-close path)")
	assert_eq(_dismissed.size(), 0, "ZERO modal_dismissed emit — item never left the queue")
	assert_eq(_inv.calls.size(), 0, "zero receive_loot — never banked (D1)")
	var re_reveal: bool = false
	for entry: Dictionary in c.get_telemetry():
		if entry["event"] == "re_reveal_count":
			re_reveal = true
	assert_true(re_reveal, "re_reveal_count(tier) telemetry +1")
	# Next safe-state retry — GSM re-enters LOOT_DROP → full ceremony again:
	_gsm.go(LOOT_DROP)
	assert_eq(c.get_fsm_state(), S.ENTRY, "re-reveal opens with the FULL ceremony (item stayed pending)")


# --- AC-22: post-S3 stash-exit + deferred-ack ---

func test_post_s3_force_close_stashes_emits_and_defers_ack() -> void:
	var c: Node = _make()
	_loot.pending = [_drop("drop_a")]
	_gsm.go(LOOT_DROP)
	c._process(0.25)  # STEADY — banked
	assert_eq(_inv.calls.size(), 1)
	_gsm.go(WORKOUT_ACTIVE)
	assert_eq(c.get_fsm_state(), S.EXITING, "stash collapse running (no input needed)")
	c._process(0.2)   # STASH_COLLAPSE_SEC
	assert_eq(_dismissed.size(), 1, "modal_dismissed emitted — item was banked at S3")
	assert_eq(c.get_fsm_state(), S.HIDDEN)
	assert_eq(c._deferred_acks.size(), 1, "deferred-ack +1 → aggregated「+N」at next safe state (F4)")
	assert_eq(c._deferred_acks[0]["reason"], "stash")


func test_stash_total_within_f6_budget() -> void:
	var c: Node = _make()
	_loot.pending = [_drop("drop_a")]
	_gsm.go(LOOT_DROP)
	c._process(0.25)
	_gsm.go(WORKOUT_ACTIVE)
	c._process(0.15)
	assert_eq(c.get_fsm_state(), S.EXITING, "collapse mid-flight at 150ms")
	c._process(0.1)  # 250ms total — within the 0.3s budget incl. jitter margin
	assert_eq(c.get_fsm_state(), S.HIDDEN, "F6: release same-frame + collapse ≤0.3s total")


# --- AC-23: S4 idempotent under force-close ---

func test_force_close_mid_s4_single_emit_no_advance() -> void:
	var c: Node = _make()
	_loot.pending = [_drop("drop_a"), _drop("drop_b")]
	_gsm.go(LOOT_DROP)
	c._process(0.25)
	c.handle_tap()           # → EXITING (normal dismiss)
	c._process(0.1)          # mid-anim
	_gsm.go(WORKOUT_ACTIVE)  # force-close lands mid-S4
	c._process(0.1)          # anim completes
	assert_eq(_dismissed.size(), 1, "modal_dismissed emit count == 1 (idempotent)")
	assert_eq(c.get_fsm_state(), S.HIDDEN, "no gap-advance — GSM has left; drop_b stays pending")


# --- SUSPENDED-triggered (Rule 8): zero frames — instant branch ---

func test_suspend_in_steady_emits_instantly_without_anim() -> void:
	var c: Node = _make()
	_loot.pending = [_drop("drop_a")]
	_gsm.go(LOOT_DROP)
	c._process(0.25)  # STEADY
	_gsm.go(SUSPENDED)
	assert_eq(_dismissed.size(), 1, "SUSPENDED post-S3 → 即 emit (zero anim — AC-51)")
	assert_eq(c.get_fsm_state(), S.HIDDEN)
	assert_eq(c._deferred_acks.size(), 1, "stash deferred-ack recorded")


# --- AC-62: EC-M11 safe→safe continues ---

func test_safe_to_safe_transition_keeps_the_modal_open() -> void:
	var c: Node = _make()
	_loot.pending = [_drop("drop_a", "EPIC")]
	_gsm.go(LOOT_DROP)
	c._process(0.5)  # mid-ceremony
	_gsm.go(IDLE)    # safe → safe (entry-time set only)
	assert_eq(c.get_fsm_state(), S.CEREMONY, "safe→safe 繼續 — 無 stash-exit 無 cancel")
	_gsm.go(DISCONNECTED)
	assert_eq(c.get_fsm_state(), S.CEREMONY, "DISCONNECTED 都係 safe")
	_gsm.go(WORKOUT_ACTIVE)
	assert_eq(c.get_fsm_state(), S.HIDDEN, "轉出 safe set 先觸發 (pre-S3 → cancel)")
