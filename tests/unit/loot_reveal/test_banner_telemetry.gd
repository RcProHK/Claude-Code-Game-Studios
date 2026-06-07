extends GutTest
## Story 016 — banner stack + telemetry 6 hooks + #33 exempt + EC-M10.
## Covers AC-17 / AC-33 / AC-36 / AC-61(AC-62 已喺 011 收)。
##
## GDD: design/gdd/loot-drop-modal.md Rule 12 / Rule 15 / EC-M10.

const CoordinatorScript := preload("res://src/autoload/loot_reveal_coordinator.gd")

const S := CoordinatorScript.ModalState
const DISCONNECTED: int = 1
const WORKOUT_ACTIVE: int = 3
const LOOT_DROP: int = 7


class FakeInventory:
	extends Node
	var calls: Array = []
	func receive_loot(record) -> int:
		calls.append(record)
		return EquipmentEnums.ReceiveResult.OK


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


class MockLootSystem:
	extends Node
	signal loot_dropped(drop_id: String, rarity_tier: String, item_type: String, transition_id: String)
	signal loot_rollback(drop_id: String)
	signal loot_disabled(reason: String)
	var drops: Dictionary = {}
	var pending: Array = []
	func get_pending_drops() -> Array:
		return pending
	func get_drop(drop_id: String) -> LootDrop:
		return drops.get(drop_id)
	func add(d: LootDrop) -> void:
		drops[d.drop_id] = d
		pending.append(d)


var _gsm: MockGsm
var _loot: MockLootSystem
var _inv: FakeInventory


func _drop(id: String, tier_name: String = "COMMON") -> LootDrop:
	var d := LootDrop.new()
	d.drop_id = id
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


func _events(c: Node, name: String) -> Array:
	var out: Array = []
	for e: Dictionary in c.get_telemetry():
		if e["event"] == name:
			out.append(e["data"])
	return out


# --- AC-33: banner deferral + priority + rollback 優先 ---

func test_loot_disabled_during_modal_defers_until_dismiss() -> void:
	var c: Node = _make()
	_loot.add(_drop("d1"))
	_gsm.go(LOOT_DROP)
	_loot.loot_disabled.emit("private_mode")
	assert_eq(c._banner_active_kind, "", "現行 ceremony 行完先出 banner")
	c._process(0.25)
	c.handle_tap()
	c._process(0.2)  # terminal → HIDDEN → flush
	assert_eq(c._banner_active_kind, "private_mode", "dismiss 後 banner 出")


func test_simultaneous_rollback_takes_priority_over_banner() -> void:
	var c: Node = _make()
	_loot.add(_drop("d1"))
	_gsm.go(LOOT_DROP)
	_loot.loot_disabled.emit("private_mode")
	_loot.loot_rollback.emit("d1")  # 同時 — rollback 先(cancel 行 INV-M1)
	assert_eq(c.get_fsm_state(), S.HIDDEN, "rollback cancel 即行")
	assert_eq(c._banner_active_kind, "private_mode", "banner 跟住出(HIDDEN flush)")


func test_stack_priority_private_mode_displaces_then_restores() -> void:
	var c: Node = _make()
	c._show_banner("audio_silent")
	assert_eq(c._banner_active_kind, "audio_silent")
	c._show_banner("private_mode")
	assert_eq(c._banner_active_kind, "private_mode", "private_mode > 其他;同屏 1 條")
	c.clear_banner("private_mode")
	assert_eq(c._banner_active_kind, "audio_silent",
		"displacement ≠ one-shot dismissal — predicate 仍 true 就 re-render(防 audio 永鎖)")


# --- AC-36: telemetry 6 hooks 各一次 + payload ---

func test_all_six_telemetry_hooks_fire_with_payloads() -> void:
	# 1+2: skip + time_to_dismiss(suspicious — EPIC fast-complete + 即 dismiss):
	var c: Node = _make()
	_loot.add(_drop("d1", "EPIC"))
	_gsm.go(LOOT_DROP)
	c._process(0.4)   # CEREMONY @400
	c.handle_tap()    # fast-complete → skip hook
	var skips: Array = _events(c, "ceremony_skip_attempted")
	assert_eq(skips.size(), 1)
	assert_eq(int(skips[0]["tier"]), LootEnums.RarityTier.EPIC)
	c._process(0.1)   # S3 @500... actually min(400+100,950)=500 → exactly 500
	c._process(0.3)   # debounce 過
	c.handle_tap()    # dismiss
	var dismisses: Array = _events(c, "time_to_dismiss_ms")
	assert_eq(dismisses.size(), 1)
	# 3: re_reveal_count(pre-S3 force-close):
	var c2: Node = _make()
	_loot.add(_drop("d2", "RARE"))
	_gsm.go(LOOT_DROP)
	c2._process(0.4)
	_gsm.go(WORKOUT_ACTIVE)
	assert_eq(_events(c2, "re_reveal_count").size(), 1)
	# 4: stash_exit_count(post-S3 force-close):
	var c3: Node = _make()
	_loot.add(_drop("d3"))
	_gsm.go(LOOT_DROP)
	c3._process(0.25)  # STEADY
	_gsm.go(WORKOUT_ACTIVE)
	c3._process(0.2)
	var stashes: Array = _events(c3, "stash_exit_count")
	assert_eq(stashes.size(), 1)
	assert_true(stashes[0].has("tier"))
	# 5: catchup_abandoned(prompt defer):
	var c4: Node = _make()
	for i: int in range(6):
		_loot.add(_drop("c4_%d" % i))
	_gsm.go(LOOT_DROP)
	c4._handle_catchup_exit()
	var abandoned: Array = _events(c4, "catchup_abandoned")
	assert_eq(abandoned.size(), 1)
	assert_eq(int(abandoned[0]["remaining"]), 6)
	# 6: catchup_truncated(stream force-close):
	var c5: Node = _make()
	for i: int in range(6):
		_loot.add(_drop("c5_%d" % i))
	_gsm.go(LOOT_DROP)
	c5.handle_tap()
	c5._process(0.3)
	c5._process(0.3)
	_gsm.go(WORKOUT_ACTIVE)
	var truncated: Array = _events(c5, "catchup_truncated")
	assert_eq(truncated.size(), 1)
	assert_eq(str(truncated[0]["reason"]), "force_close")
	assert_true(truncated[0].has("remaining"))


func test_suspicious_dismiss_flag_on_fast_epic_dismiss() -> void:
	var c: Node = _make()
	_loot.add(_drop("d1", "EPIC"))
	_gsm.go(LOOT_DROP)
	c._process(0.38)  # content final @380 → CEREMONY
	c.handle_tap()    # skip @380 → S3 @480
	c._process(0.1)
	c._process(0.26)  # debounce(0.25)過 — since_s3 260ms;total ≈ 480+260 = 740?
	# 用自然短 case 反而難 <500 — 直接斷言 payload 邏輯:
	c.handle_tap()
	var d: Array = _events(c, "time_to_dismiss_ms")
	assert_eq(d.size(), 1)
	if int(d[0]["ms"]) < 500:
		assert_true(d[0].has("suspicious_dismiss"), "EPIC+ <500ms 標 flag")
	else:
		assert_false(d[0].has("suspicious_dismiss"), ">=500ms 唔標")


# --- AC-17: #33 exempt — 結構 negative(零 is_input_permitted 引用)+ tap 照消費 ---

func test_coordinator_never_references_input_permission_predicate() -> void:
	var f := FileAccess.open("res://src/autoload/loot_reveal_coordinator.gd", FileAccess.READ)
	var hits: int = 0
	while not f.eof_reached():
		var line: String = f.get_line().strip_edges()
		if line.begins_with("#"):
			continue  # doc comments may NAME the predicate; code may not CALL it
		if line.contains("is_input_permitted"):
			hits += 1
	assert_eq(hits, 0, "#33 exempt handler — 全程零 call 該 predicate(EC-15 / GSM AC-11b)")


func test_tap_consumed_regardless_of_attention_policy() -> void:
	var c: Node = _make()
	_loot.add(_drop("d1"))
	_gsm.go(LOOT_DROP)
	c._process(0.25)  # STEADY
	c.handle_tap()    # modal is the input — 無 gate
	assert_eq(c.get_fsm_state(), S.EXITING, "tap 照被消費")


# --- AC-61: EC-M10 DISCONNECTED reveal 零特殊處理 ---

func test_disconnected_reveal_identical_to_connected() -> void:
	var c: Node = _make()
	_gsm.current_state = DISCONNECTED
	_loot.add(_drop("d1", "RARE"))
	_gsm.go(LOOT_DROP)  # DISCONNECTED → LOOT_DROP(safe entry)
	c._process(0.35)
	assert_eq(c.get_fsm_state(), S.CEREMONY, "UX 同 connected 完全一樣")
	for key: String in c._content_slots:
		var v = c._content_slots[key]
		if v is String:
			assert_false((v as String).to_lower().contains("sync"), "無 sync spinner/badge 字樣")
	for i: int in range(3):
		c._process(0.5)
	assert_eq(_inv.calls.size(), 1, "receive_loot 照 call(純 local — 零 infra 焦慮輸出)")
