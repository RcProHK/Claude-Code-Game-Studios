extends GutTest
## Story 010 — queue drain intra/terminal + EC-M6/M20 + empty-queue + content source.
## Covers AC-18 / AC-19(#21-side 半)/ AC-32 / AC-34 / AC-57 / AC-70 + AC-60 margin wiring 半.
##
## GDD: design/gdd/loot-drop-modal.md Rule 6 / Rule 13 / EC-M6 / EC-M20.

const CoordinatorScript := preload("res://src/autoload/loot_reveal_coordinator.gd")

const S := CoordinatorScript.ModalState


class MockGsm:
	extends Node
	signal state_changed(from_state, to_state, payload)
	var current_state: int = 7
	var direct_calls: int = 0  # negative spy — #21 must NEVER call GSM
	func get_current_state() -> int:
		return current_state
	func connect_for_initial_state(callable: Callable) -> void:
		state_changed.connect(callable)
	func enter_loot_drop() -> void:
		state_changed.emit(2, 7, null)
	func request_transition(_e) -> void:
		direct_calls += 1


class MockLootSystem:
	extends Node
	signal loot_dropped(drop_id: String, rarity_tier: String, item_type: String, transition_id: String)
	var pending: Array = []
	func get_pending_drops() -> Array:
		return pending
	func fire_doorbell(drop_id: String, rarity: String) -> void:
		loot_dropped.emit(drop_id, rarity, "FAKE_TYPE_FROM_SIGNAL", "t_sig")


var _gsm: MockGsm
var _loot: MockLootSystem
var _dismissed: Array = []


func _drop(id: String, tier_name: String = "COMMON") -> LootDrop:
	var d := LootDrop.new()
	d.drop_id = id
	d.rarity_tier = tier_name
	d.item_type = "WEAPON"
	return d


func _make() -> Node:
	_gsm = MockGsm.new()
	_loot = MockLootSystem.new()
	_dismissed = []
	add_child_autofree(_gsm)
	add_child_autofree(_loot)
	var c: Node = CoordinatorScript.new()
	c._gsm = _gsm
	c._loot_system = _loot
	add_child_autofree(c)
	c.modal_dismissed.connect(func(id: String, terminal: bool) -> void:
		_dismissed.append({"id": id, "terminal": terminal}))
	return c


func _to_steady_common(c: Node) -> void:
	c._process(0.25)  # COMMON entry 150 → CEREMONY; T_block 200 → STEADY
	assert_eq(c.get_fsm_state(), S.STEADY)


# --- AC-18: intra-queue advance, GSM untouched ---

func test_intra_queue_dismiss_emits_nonterminal_then_advances_after_gap() -> void:
	var c: Node = _make()
	_loot.pending = [_drop("drop_a"), _drop("drop_b", "RARE")]
	_gsm.enter_loot_drop()
	_to_steady_common(c)
	c.handle_tap()                  # → EXITING
	assert_eq(_dismissed.size(), 0, "zero emit before the anim completes")
	c._process(0.2)                 # exit anim 0.2s → finish
	assert_eq(_dismissed, [{"id": "drop_a", "terminal": false}], "intra emit (drop_id, false)")
	assert_eq(c.get_fsm_state(), S.EXITING, "gap runs inside EXITING")
	c._process(0.3)                 # gap (prev COMMON → 0.3s)
	assert_eq(c.get_fsm_state(), S.ENTRY, "next reveal opened after the gap")
	assert_eq(c._content_slots["rarity_badge"], LootEnums.RarityTier.RARE, "second drop's content")
	assert_eq(_gsm.direct_calls, 0, "GSM 唔郁 — zero direct calls throughout (negative spy)")


# --- AC-19: terminal ordering — anim completes BEFORE the terminal emit ---

func test_terminal_dismiss_emits_after_anim_then_hides() -> void:
	var c: Node = _make()
	_loot.pending = [_drop("drop_only")]
	_gsm.enter_loot_drop()
	_to_steady_common(c)
	c.handle_tap()
	c._process(0.1)                 # mid-anim
	assert_eq(_dismissed.size(), 0, "anim 中途零 emit")
	c._process(0.1)                 # anim done
	assert_eq(_dismissed, [{"id": "drop_only", "terminal": true}], "terminal emit after S4 完成")
	assert_eq(c.get_fsm_state(), S.HIDDEN)
	assert_eq(_gsm.direct_calls, 0, "exit rides the #15 loot_confirmed chain — zero GSM direct calls")


# --- AC-32: content source = committed store, never the signal payload ---

func test_display_sources_from_get_pending_record_not_signal_args() -> void:
	var c: Node = _make()
	_gsm.current_state = 7
	_loot.pending = [_drop("drop_real", "EPIC")]
	_loot.fire_doorbell("drop_real", "LEGENDARY")  # signal lies about the tier
	assert_true(c.is_modal_active())
	assert_eq(c._content_slots["rarity_badge"], LootEnums.RarityTier.EPIC, "display == committed record")
	assert_eq(c._content_slots["item_icon"], "WEAPON", "slot from record, not FAKE_TYPE_FROM_SIGNAL")


# --- AC-34: empty-queue LOOT_DROP entry ---

func test_empty_queue_entry_emits_terminal_immediately_and_never_opens() -> void:
	var c: Node = _make()
	_loot.pending = []
	_gsm.enter_loot_drop()
	assert_eq(_dismissed, [{"id": "", "terminal": true}], "即 emit terminal — GSM 唔 stuck")
	assert_false(c.is_modal_active(), "modal 唔開")
	assert_eq(_gsm.direct_calls, 0)


# --- AC-57: EC-M6 dangling/null records ---

func test_null_head_is_skipped_with_critical_telemetry_and_next_opens() -> void:
	var c: Node = _make()
	_loot.pending = [null, _drop("drop_good", "RARE")]
	_gsm.enter_loot_drop()
	assert_true(c.is_modal_active(), "skips the null, opens the good record")
	assert_eq(c._content_slots["rarity_badge"], LootEnums.RarityTier.RARE)
	var critical: bool = false
	for entry: Dictionary in c.get_telemetry():
		if entry["event"] == "loot_reveal.dangling_drop":
			critical = true
	assert_true(critical, "CRITICAL telemetry — never a placeholder modal")


func test_all_null_queue_takes_terminal_exit() -> void:
	var c: Node = _make()
	_loot.pending = [null]
	_gsm.enter_loot_drop()
	assert_false(c.is_modal_active())
	assert_eq(_dismissed, [{"id": "", "terminal": true}], "terminal 件 → terminal dismiss 出口")


# --- AC-70: EC-M20 never mid-exit re-entry; terminal re-eval at S4 end ---

func test_new_drop_during_s4_defers_until_anim_completes_then_continues() -> void:
	var c: Node = _make()
	_loot.pending = [_drop("drop_a")]
	_gsm.enter_loot_drop()
	_to_steady_common(c)
	c.handle_tap()  # → EXITING (queue currently empty after this one)
	# new drop lands mid-S4:
	_loot.pending = [_drop("drop_a"), _drop("drop_new", "EPIC")]
	_loot.fire_doorbell("drop_new", "EPIC")
	assert_eq(c.get_fsm_state(), S.EXITING, "永不 mid-exit 重入 — doorbell deferred")
	c._process(0.2)  # anim done → re-eval finds drop_new
	assert_eq(_dismissed, [{"id": "drop_a", "terminal": false}],
		"terminal 判定重新評估 — 有新件 ⇒ non-terminal, GSM stays")
	c._process(0.3)  # gap
	assert_eq(c.get_fsm_state(), S.ENTRY, "continues with the new drop")
	assert_eq(c._content_slots["rarity_badge"], LootEnums.RarityTier.EPIC)


# --- AC-60 margin wiring half: prev EPIC+ stretches the gap ---

func test_gap_after_epic_uses_focal_exit_margin() -> void:
	var c: Node = _make()
	_loot.pending = [_drop("drop_e", "EPIC"), _drop("drop_f", "EPIC")]
	_gsm.enter_loot_drop()
	for i: int in range(4):
		c._process(0.5)  # EPIC natural T_block 950 → STEADY
	assert_eq(c.get_fsm_state(), S.STEADY)
	c.handle_tap()
	c._process(0.2)      # anim done → intra emit + gap starts
	c._process(0.3)      # 0.3 < margin 0.6 — still waiting
	assert_eq(c.get_fsm_state(), S.EXITING, "EPIC+ successor gap = FOCAL_EXIT_MARGIN (0.6)")
	c._process(0.3)      # 0.6 reached
	assert_eq(c.get_fsm_state(), S.ENTRY, "advance after the margin — EC-M9 deterministic, zero #7 queries")
