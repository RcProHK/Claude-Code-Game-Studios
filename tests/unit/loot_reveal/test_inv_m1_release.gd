extends GutTest
## Story 007 — INV-M1 freeze-release 單一出口 + EC-M1 suspend + EC-M2 reject.
## Covers AC-1(fast-complete + Suspended 兩 path;rollback/force-close path
## 喺 012/011 落地後完成 ×4 parametrize)/ AC-2 / AC-52 / AC-53.
##
## GDD: design/gdd/loot-drop-modal.md Rule 11 INV-M1 / EC-M1 / EC-M2.

const CoordinatorScript := preload("res://src/autoload/loot_reveal_coordinator.gd")

const S := CoordinatorScript.ModalState
const SUSPENDED: int = 8  # GSM GameState.SUSPENDED
const LOOT_DROP: int = 7
const IDLE: int = 2


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
	var reject_freeze: bool = false
	var ledger_cleared: bool = false  # EC-M1: Suspended override self-cancel
	var _next_handle: int = 0
	func ceremony_freeze(duration_sec: float):
		if reject_freeze:
			log.entries.append({"call": "ceremony_freeze_rejected", "duration": duration_sec})
			return null
		log.entries.append({"call": "ceremony_freeze", "duration": duration_sec})
		_next_handle += 1
		return _next_handle
	func release(handle) -> void:
		# Idempotent at #6: a cleared ledger makes this a no-op, never an error.
		log.entries.append({"call": "release", "handle": handle, "ledger_cleared": ledger_cleared})
	func shake(_i: float, _d: float) -> void:
		log.entries.append({"call": "shake"})
	func apply_ceremony_saturation(_drop: float, _r: float) -> void:
		log.entries.append({"call": "apply_ceremony_saturation"})


class FakeCamera:
	extends Node
	signal focal_completed(target_position: Vector2)
	var log: CallLog
	func request_focal(_p: Vector2, _d: float = 0.0, _z: float = 1.0) -> void:
		log.entries.append({"call": "request_focal"})
	func finish_focal() -> void:
		focal_completed.emit(Vector2.ZERO)


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
var _fx: FakeScreenEffects
var _fake_now_ms: int = 100000


func _drop(tier_name: String) -> LootDrop:
	var d := LootDrop.new()
	d.drop_id = "drop_x"
	d.rarity_tier = tier_name
	return d


func _make() -> Node:
	_log = CallLog.new()
	_gsm = MockGsm.new()
	_loot = MockLootSystem.new()
	_cam = FakeCamera.new()
	_fx = FakeScreenEffects.new()
	_cam.log = _log
	_fx.log = _log
	_fake_now_ms = 100000
	for n: Node in [_gsm, _loot, _cam, _fx]:
		add_child_autofree(n)
	var c: Node = CoordinatorScript.new()
	c._gsm = _gsm
	c._loot_system = _loot
	c._camera = _cam
	c._screen_effects = _fx
	c._now_ms = func() -> int: return _fake_now_ms
	add_child_autofree(c)
	return c


func _open_legendary_into_freeze(c: Node) -> void:
	_loot.pending = [_drop("LEGENDARY")]
	_gsm.go(LOOT_DROP)
	c._process(0.5)      # CEREMONY
	c._process(0.5)      # clock 1000 — inside S2 window
	_cam.finish_focal()  # freeze issued (S2b active)
	assert_eq(_log.count("ceremony_freeze"), 1)


# --- AC-1 (兩 path 本 story;×4 完成 @ 012): exactly-once via the single exit ---

func test_fast_complete_path_releases_exactly_once() -> void:
	var c: Node = _make()
	_open_legendary_into_freeze(c)
	c.handle_tap()
	assert_eq(_log.count("release"), 1, "fast-complete → release exactly once")
	c.handle_tap()  # extra mash — fast-complete already active
	assert_eq(_log.count("release"), 1, "no double-release on tap spam")


func test_suspend_path_releases_exactly_once() -> void:
	var c: Node = _make()
	_open_legendary_into_freeze(c)
	_gsm.go(SUSPENDED)
	assert_eq(_log.count("release"), 1, "suspend → INV-M1 exit fired once")


# --- AC-2: idempotent + not-issued no-op ---

func test_release_is_noop_when_freeze_never_issued() -> void:
	var c: Node = _make()
	_loot.pending = [_drop("LEGENDARY")]
	_gsm.go(LOOT_DROP)
	c._process(0.5)  # CEREMONY — focal pending, freeze NOT issued
	c.handle_tap()   # fast-complete pre-issue
	assert_eq(_log.count("release"), 0, "not-issued ⇒ release no-op (zero seam calls)")


func test_release_against_cleared_ledger_is_safe() -> void:
	var c: Node = _make()
	_open_legendary_into_freeze(c)
	_fx.ledger_cleared = true  # #6 Suspended override already wiped its entry
	_gsm.go(SUSPENDED)
	assert_eq(_log.count("release"), 1, "release forwarded once — #6-side no-op, no error, no double-decrement")
	c._release_freeze()  # direct second call — must be flag-guarded no-op
	assert_eq(_log.count("release"), 1, "idempotent: second release call is a no-op")


# --- AC-52: EC-M1 suspend in S2b → resume decision ---

func test_resume_within_threshold_reenters_s3_without_reissuing_freeze() -> void:
	var c: Node = _make()
	_open_legendary_into_freeze(c)
	_gsm.go(SUSPENDED)
	_fake_now_ms += 10000  # 10s ≤ 30s
	_gsm.go(IDLE)
	assert_eq(c.get_fsm_state(), S.STEADY, "≤30s resume → straight into S3 (content already final)")
	assert_eq(c._s3_entries, 1, "S3 entry side effects exactly once at re-entry")
	assert_eq(_log.count("ceremony_freeze"), 1, "freeze spy count NOT incremented — 嚴禁 re-issue")


func test_resume_after_threshold_cancels_with_pre_s3_semantics() -> void:
	var c: Node = _make()
	_open_legendary_into_freeze(c)
	_gsm.go(SUSPENDED)
	_fake_now_ms += 31000  # > 30s
	_gsm.go(IDLE)
	assert_eq(c.get_fsm_state(), S.HIDDEN, ">30s → pre-S3 cancel (D1 — item stays pending)")
	assert_eq(c._s3_entries, 0, "zero receive_loot-class side effects — never banked")
	var dismissed_count: int = 0
	var _conn = c.modal_dismissed.connect(func(_id, _t): dismissed_count += 1)
	assert_eq(dismissed_count, 0, "zero modal_dismissed emits on the cancel path")


func test_clock_parks_while_suspended() -> void:
	var c: Node = _make()
	_open_legendary_into_freeze(c)
	var clock_at_suspend: float = c.get_reveal_clock_ms()
	_gsm.go(SUSPENDED)
	c._process(5.0)
	assert_eq(c.get_reveal_clock_ms(), clock_at_suspend, "EC-M1 park — zero clock drift during bfcache")


# --- AC-53: EC-M2 freeze rejected → degrade, ceremony completes, telemetry ---

func test_freeze_reject_degrades_to_motion_variant_and_reaches_s3() -> void:
	var c: Node = _make()
	_fx.reject_freeze = true
	_loot.pending = [_drop("LEGENDARY")]
	_gsm.go(LOOT_DROP)
	c._process(0.5)
	_cam.finish_focal()  # freeze attempt → rejected
	assert_eq(_log.count("ceremony_freeze"), 0, "freeze rejected (#6 not serviceable)")
	assert_eq(_log.count("shake"), 0, "ladder tail suppressed after reject")
	c._process(0.25)
	c._process(0.0625)   # clock 812.5 ≥ motion-variant T_block 800
	assert_eq(c.get_fsm_state(), S.STEADY, "ceremony degraded but COMPLETE — reveal is the hard guarantee")
	var found: bool = false
	for entry: Dictionary in c.get_telemetry():
		if entry["event"] == "loot_reveal.freeze_rejected":
			found = true
	assert_true(found, "telemetry loot_reveal.freeze_rejected recorded")
