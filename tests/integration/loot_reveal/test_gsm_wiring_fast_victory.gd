extends GutTest
## Story 019 (G-LM-4c) — GSM deferred-reveal wiring + retry-suppression +
## fast-victory marker ⑧。Covers AC-37b + G-flag-3 殘餘收線。
##
## GDD: design/gdd/loot-drop-modal.md G-LM-4 ⑥⑧ / Rule 13b / GSM Rule 13 L123.

const CoordinatorScript := preload("res://src/autoload/loot_reveal_coordinator.gd")
const LootSystemScript := preload("res://src/autoload/loot_drop_system.gd")
const GSMScript := preload("res://src/autoload/game_state_machine.gd")


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


class StubGsm:
	## 輕量 GSM stub 帶 G-LM-4c 行為 — 用 real GSM 嘅 hook 邏輯做 oracle 太重
	## (real-GSM 全鏈喺 test_cross_system_suite/026);呢度針對 #15↔GSM 接縫。
	extends Node
	signal state_changed(from_state, to_state, payload)
	var current_state: int = 2
	var confirmed_calls: Array = []
	func get_current_state() -> int:
		return current_state
	func connect_for_initial_state(callable: Callable) -> void:
		state_changed.connect(callable)
	func on_loot_confirmed(queue_drained: bool) -> void:
		confirmed_calls.append(queue_drained)
	func emit_with_payload(from_s: int, to_s: int, payload) -> void:
		current_state = to_s
		state_changed.emit(from_s, to_s, payload)


class BossLikePayload:
	extends RefCounted
	var source_event: String = "workout_completed"
	var data: Dictionary = {}


var _persist: MockPersistence
var _gsm: StubGsm
var _loot: Node


func _make_loot_with_stub_gsm() -> Node:
	_persist = MockPersistence.new()
	_gsm = StubGsm.new()
	add_child_autofree(_gsm)
	_loot = LootSystemScript.new()
	_loot._persistence = _persist
	_loot._gsm = _gsm
	add_child_autofree(_loot)  # _ready: connect_for_initial_state + reverse-wire confirmed
	return _loot


# --- ⑧ fast-victory marker(兩個 order 都兜) ---

func test_marker_before_grant_stamps_the_record() -> void:
	_make_loot_with_stub_gsm()
	var payload := BossLikePayload.new()
	payload.data = {"workout_id": "w_fast", "boss": {"outcome": "INTERRUPTED_WITH_CREDIT"}}
	_gsm.emit_with_payload(6, 7, payload)  # BOSS_ENCOUNTER → LOOT_DROP
	_loot._process_loot_trigger("w_fast", LootEnums.SourceEventKind.WORKOUT_DAILY, 0.6, LootEnums.CeremonyDecision.FULL_CEREMONY)
	var drop: LootDrop = _loot._drops_by_transition["w_fast"]
	assert_true(bool(drop.item_metadata.get("fast_victory", false)), "marker-before-grant stamp")
	var on_disk: Dictionary = _persist.store["loot.pending." + drop.drop_id]
	assert_true(bool((on_disk["item_metadata"] as Dictionary).get("fast_victory", false)),
		"durable carrier — deferred reveal 攞得返 outcome")


func test_marker_after_grant_patches_the_record() -> void:
	_make_loot_with_stub_gsm()
	_loot._process_loot_trigger("w_late", LootEnums.SourceEventKind.WORKOUT_DAILY, 0.6, LootEnums.CeremonyDecision.FULL_CEREMONY)
	var payload := BossLikePayload.new()
	payload.data = {"workout_id": "w_late", "boss": {"outcome": "INTERRUPTED_WITH_CREDIT"}}
	_gsm.emit_with_payload(6, 7, payload)
	var drop: LootDrop = _loot._drops_by_transition["w_late"]
	assert_true(bool(drop.item_metadata.get("fast_victory", false)), "late marker patches")


func test_normal_outcome_never_marks() -> void:
	_make_loot_with_stub_gsm()
	var payload := BossLikePayload.new()
	payload.data = {"workout_id": "w_norm", "boss": {"outcome": "DEFEATED"}}
	_gsm.emit_with_payload(6, 7, payload)
	_loot._process_loot_trigger("w_norm", LootEnums.SourceEventKind.WORKOUT_DAILY, 0.6, LootEnums.CeremonyDecision.FULL_CEREMONY)
	var drop: LootDrop = _loot._drops_by_transition["w_norm"]
	assert_false(bool(drop.item_metadata.get("fast_victory", false)))


# --- AC-37b: #21 attribution slot 用「快勝」variant,ceremony 照 tier ---

func test_fast_victory_record_renders_quick_win_attribution() -> void:
	_make_loot_with_stub_gsm()
	var d := LootDrop.new()
	d.drop_id = "fv_1"
	d.rarity_tier = "EPIC"
	d.item_metadata = {"fast_victory": true}
	var loot_stub := MockLootHolder.new()
	loot_stub.pending = [d]
	add_child_autofree(loot_stub)
	var c: Node = CoordinatorScript.new()
	c._gsm = _gsm
	c._loot_system = loot_stub
	add_child_autofree(c)
	_gsm.emit_with_payload(2, 7, null)
	assert_eq(c._content_slots["source_attribution"], "快勝", "fast-victory copy variant")
	assert_eq(c._current_tier, LootEnums.RarityTier.EPIC, "ceremony ladder 照 tier 不變(layout variant only)")


class MockLootHolder:
	extends Node
	signal loot_dropped(drop_id: String, rarity_tier: String, item_type: String, transition_id: String)
	var pending: Array = []
	func get_pending_drops() -> Array:
		return pending


# --- ④/⑥ loot_confirmed 接線 + drained 語意(real #15 → stub GSM handler) ---

func test_terminal_drained_vs_defer_semantics() -> void:
	_make_loot_with_stub_gsm()
	_loot._process_loot_trigger("w_a", LootEnums.SourceEventKind.WORKOUT_DAILY, 0.6, LootEnums.CeremonyDecision.FULL_CEREMONY)
	# defer-style terminal(queue 非空):
	_loot.on_modal_dismissed("", true)
	assert_eq(_gsm.confirmed_calls, [false], "defer → confirmed(false) — GSM 推進但 flag 保留")
	# drain terminal:
	var drop: LootDrop = _loot._drops_by_transition["w_a"]
	_loot.on_modal_dismissed(drop.drop_id, true)
	assert_eq(_gsm.confirmed_calls, [false, true], "queue 清 → confirmed(true) — flag 清得")
