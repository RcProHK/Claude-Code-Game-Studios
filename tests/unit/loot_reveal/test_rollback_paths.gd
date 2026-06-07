extends GutTest
## Story 012 — rollback paths(pre-S3 cancel+re-query / S3 no-op / queued 零動作).
## Covers AC-30(×3 段 + re-query 雙 branch)/ AC-30b / AC-31 — 並完成 AC-1
## 嘅第四個 cancel path(×4 parametrize 收線)。
##
## GDD: design/gdd/loot-drop-modal.md Rule 11.

const CoordinatorScript := preload("res://src/autoload/loot_reveal_coordinator.gd")

const S := CoordinatorScript.ModalState


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
	signal loot_rollback(drop_id: String)
	var pending: Array = []
	func get_pending_drops() -> Array:
		return pending
	func roll_back(drop_id: String) -> void:
		loot_rollback.emit(drop_id)


var _log: CallLog
var _gsm: MockGsm
var _loot: MockLootSystem
var _cam: FakeCamera
var _inv: FakeInventory
var _dismissed: Array = []


func _drop(id: String, tier_name: String = "LEGENDARY") -> LootDrop:
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


# --- AC-30 ×3: rollback in S0/S1 (ENTRY) and S2 (CEREMONY) ---

func test_rollback_in_entry_cancels_silently_then_requeries_empty_terminal() -> void:
	var c: Node = _make()
	_loot.pending = [_drop("drop_a")]
	_gsm.enter_loot_drop()
	assert_eq(c.get_fsm_state(), S.ENTRY)  # S0/S1 window
	_loot.roll_back("drop_a")
	assert_eq(_dismissed, [{"id": "", "terminal": true}], "queue 空 → terminal emit — GSM 唔 stuck")
	assert_eq(c.get_fsm_state(), S.HIDDEN)
	assert_eq(_inv.calls.size(), 0, "無 terminal frame 無 banking")


func test_rollback_in_ceremony_with_queue_advances_after_gap() -> void:
	var c: Node = _make()
	_loot.pending = [_drop("drop_a"), _drop("drop_b", "RARE")]
	_gsm.enter_loot_drop()
	c._process(0.5)  # CEREMONY (S2)
	_loot.roll_back("drop_a")
	assert_eq(c.get_fsm_state(), S.ENTRY, "table edge CEREMONY→ENTRY (re-query non-empty)")
	assert_eq(_dismissed.size(), 0, "零 modal_dismissed emit(#15 自己處理 queue)")
	c._process(0.6)  # successor gap (prev LEGENDARY → margin 0.6)
	assert_eq(c._content_slots["rarity_badge"], LootEnums.RarityTier.RARE, "下一件 ENTRY")


func test_rollback_during_freeze_releases_exactly_once_completes_ac1_matrix() -> void:
	var c: Node = _make()
	_loot.pending = [_drop("drop_a")]
	_gsm.enter_loot_drop()
	c._process(0.5)
	c._process(0.5)
	_cam.finish_focal()  # freeze active (S2b)
	assert_eq(_log.count("ceremony_freeze"), 1)
	_loot.roll_back("drop_a")
	assert_eq(_log.count("release"), 1, "AC-1 第四 path:rollback → 同一 release 出口 exactly-once(×4 收線)")
	assert_eq(c.get_fsm_state(), S.HIDDEN)


# --- AC-30b: S3 rollback = display no-op ---

func test_s3_rollback_is_display_noop_with_telemetry() -> void:
	var c: Node = _make()
	_loot.pending = [_drop("drop_a", "COMMON")]
	_gsm.enter_loot_drop()
	c._process(0.25)  # STEADY (banked)
	assert_eq(_inv.calls.size(), 1)
	_loot.roll_back("drop_a")
	assert_eq(c.get_fsm_state(), S.STEADY, "modal 照留 STEADY(post-banking — 唔演 show-then-revoke)")
	var late: bool = false
	for entry: Dictionary in c.get_telemetry():
		if entry["event"] == "loot_reveal.late_rollback":
			late = true
	assert_true(late, "telemetry late_rollback")
	c._process(0.3)
	c.handle_tap()
	assert_eq(c.get_fsm_state(), S.EXITING, "可正常 dismiss")


# --- AC-31: queued rollback — 零動作 ---

func test_queued_rollback_does_nothing_to_the_active_reveal() -> void:
	var c: Node = _make()
	_loot.pending = [_drop("drop_a"), _drop("drop_b", "RARE")]
	_gsm.enter_loot_drop()
	c._process(0.5)  # CEREMONY on drop_a
	_loot.roll_back("drop_b")  # 未 reveal 嘅 queued 件
	assert_eq(c.get_fsm_state(), S.CEREMONY, "active reveal 不受影響")
	assert_eq(_dismissed.size(), 0)
	# drop_b 從此唔會出現(pull-model 下次 query 見唔到):
	c._process(0.7)   # → S3 (T_block 1200) ... still ceremony at 1200? advance:
	c._process(0.5)
	assert_eq(c.get_fsm_state(), S.STEADY)
	c._process(0.3)
	c.handle_tap()    # dismiss
	c._process(0.2)   # S4 done — queue excluding rolled drop_b → terminal
	assert_eq(_dismissed[-1]["terminal"], true, "rolled queued 件唔會被 reveal")
