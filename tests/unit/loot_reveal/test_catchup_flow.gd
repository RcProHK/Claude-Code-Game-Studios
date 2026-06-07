extends GutTest
## Story 014 — catch-up prompt + stream + F3 + EC-M13/M18 + phase-gate termination.
## Covers AC-26 / AC-27 / AC-46 / AC-47 / AC-59 / AC-64 / AC-69 + AC-37c ui_cancel 半.
##
## GDD: design/gdd/loot-drop-modal.md Rule 10 / F3 / EC-M8 / EC-M13 / EC-M18.

const CoordinatorScript := preload("res://src/autoload/loot_reveal_coordinator.gd")

const S := CoordinatorScript.ModalState
const T := LootEnums.RarityTier


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
	var drops: Dictionary = {}
	var pending: Array = []
	func get_pending_drops() -> Array:
		return pending
	func get_drop(drop_id: String) -> LootDrop:
		return drops.get(drop_id)
	func add_drop(d: LootDrop) -> void:
		drops[d.drop_id] = d
		pending.append(d)
	func fire_doorbell(drop_id: String, rarity: String) -> void:
		loot_dropped.emit(drop_id, rarity, "WEAPON", "t")


var _gsm: MockGsm
var _loot: MockLootSystem
var _inv: FakeInventory
var _dismissed: Array = []


func _drop(id: String, tier_name: String) -> LootDrop:
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


func _fill(n_common: int, n_uncommon: int, n_rare: int, n_epic: int, n_leg: int) -> void:
	var idx: int = 0
	for spec: Array in [[n_common, "COMMON"], [n_uncommon, "UNCOMMON"], [n_rare, "RARE"], [n_epic, "EPIC"], [n_leg, "LEGENDARY"]]:
		for i: int in range(spec[0]):
			_loot.add_drop(_drop("d_%d" % idx, spec[1]))
			idx += 1


# --- AC-26: threshold boundary ---

func test_depth_4_goes_sequential_depth_5_goes_prompt() -> void:
	var c: Node = _make()
	_fill(4, 0, 0, 0, 0)
	_gsm.go(7)
	assert_eq(c.get_fsm_state(), S.ENTRY, "pending==4 → sequential")
	var c2: Node = _make()
	_fill(5, 0, 0, 0, 0)
	_gsm.go(7)
	assert_eq(c2.get_fsm_state(), S.CATCHUP_PROMPT, "pending==5 == threshold(config 讀)→ prompt")
	assert_eq(c2._prompt_count, 5)


# --- AC-27: prompt defer 零動作 ---

func test_prompt_defer_terminal_emit_zero_commits() -> void:
	var c: Node = _make()
	_fill(6, 0, 0, 0, 0)
	_gsm.go(7)
	c._handle_catchup_exit()  # defer (ui_cancel / 稍後再拆)
	assert_eq(_dismissed, [{"id": "", "terminal": true}], "terminal emit → GSM 推進")
	assert_eq(c.get_fsm_state(), S.HIDDEN)
	assert_eq(_inv.calls.size(), 0, "receive_loot 零 call — pending 不變,零懲罰")


func test_ui_cancel_routes_catchup_exit() -> void:
	var c: Node = _make()
	_fill(5, 0, 0, 0, 0)
	_gsm.go(7)
	var cancel := InputEventAction.new()
	cancel.action = &"ui_cancel"
	cancel.pressed = true
	c._unhandled_input(cancel)
	assert_eq(c.get_fsm_state(), S.HIDDEN, "ui_cancel == 稍後再拆 (AC-37c)")


# --- AC-64: EC-M13 exclusive entry ---

func test_boot_force_reveal_depth_branches_are_exclusive() -> void:
	for spec: Array in [[0, S.HIDDEN], [3, S.ENTRY], [7, S.CATCHUP_PROMPT]]:
		var c: Node = _make()
		_fill(spec[0], 0, 0, 0, 0)
		_gsm.go(7)
		assert_eq(c.get_fsm_state(), spec[1], "depth %d → 正確分支" % spec[0])
		# banner 同 sequential 永不同時:
		var prompt: bool = c.get_fsm_state() == S.CATCHUP_PROMPT
		var sequential: bool = c.get_fsm_state() == S.ENTRY
		assert_false(prompt and sequential, "exclusive assert")


# --- F3 formulas: AC-46 bound + AC-47 regression ---

func test_f3_worst_case_bound_15_8s() -> void:
	var config := LootRevealTimingConfig.new()
	# 全 EPIC+ ceremonies ×5(LEGENDARY)+ 滿 stream:
	var worst: float = LootRevealFormulas.catchup_machine_time_sec(
		config, 999, [T.LEGENDARY, T.LEGENDARY, T.LEGENDARY, T.LEGENDARY, T.LEGENDARY])
	assert_lte(worst, 15.8, "T_machine ≤ 15.8s provable bound(GDD 上界用全 0.6 gap;首 gap 實際 0.3 → 15.5)")
	assert_almost_eq(worst, 15.5, 0.001, "exact regression:0.3 + 6.0 + (0.3+1.2) + 4×(0.6+1.2) + 0.5")
	# 120 sub-RARE → 40 beats(6.0s)+ 80 折 grid:
	var partition: Dictionary = LootRevealFormulas.catchup_partition(
		_tier_array(120, 0, 0, 0, 0), config)
	assert_eq((partition["stream"] as Array).size(), 40, "stream cap 40")
	assert_eq((partition["grid_overflow"] as Array).size(), 80, "80 折入 grid")


func test_f3_regression_30_item_fixture_10_3s() -> void:
	var config := LootRevealTimingConfig.new()
	var tiers: Array = _tier_array(14, 10, 4, 1, 1)
	var partition: Dictionary = LootRevealFormulas.catchup_partition(tiers, config)
	var ceremonies: Array = partition["ceremonies"]
	assert_eq(ceremonies.size(), 5, "top-K=5(L+E+3R)")
	var ceremony_tiers: Array = []
	for i: int in ceremonies:
		ceremony_tiers.append(tiers[i])
	assert_eq(ceremony_tiers, [T.RARE, T.RARE, T.RARE, T.EPIC, T.LEGENDARY], "reveal ascending")
	assert_eq((partition["grid_overflow"] as Array).size(), 1, "第 4 件 R 折入 grid(C-1 own cell)")
	var t: float = LootRevealFormulas.catchup_machine_time_sec(config, 24, ceremony_tiers)
	assert_almost_eq(t, 10.3, 0.001, "F3 worked example == 10.3s")


func _tier_array(n_c: int, n_u: int, n_r: int, n_e: int, n_l: int) -> Array:
	var out: Array = []
	for spec: Array in [[n_c, T.COMMON], [n_u, T.UNCOMMON], [n_r, T.RARE], [n_e, T.EPIC], [n_l, T.LEGENDARY]]:
		for i: int in range(spec[0]):
			out.append(spec[1])
	return out


# --- Stream cadence + EC-M8 phase-gate + termination (AC-59) ---

func test_stream_displays_beats_at_cadence_and_appends_phase_gated() -> void:
	var c: Node = _make()
	_fill(6, 0, 1, 0, 0)
	_gsm.go(7)
	c.handle_tap()  # reveal-all
	assert_eq(c.get_fsm_state(), S.CATCHUP_STREAM)
	c._process(0.3)   # banner beat
	c._process(0.45)  # 3 beats
	assert_eq(c._catchup_stream_displayed.size(), 3, "0.15s/件 cadence")
	# EC-M8: sub-RARE append 未完 phase:
	var late := _drop("late_sub", "COMMON")
	_loot.add_drop(late)
	_loot.fire_doorbell("late_sub", "COMMON")
	assert_eq(c._catchup_stream.size(), 7, "stream 未完 → append 尾")
	# RARE+ mid-stream → ascending insert 入 ceremonies(cap 未滿):
	var late_epic := _drop("late_epic", "EPIC")
	_loot.add_drop(late_epic)
	_loot.fire_doorbell("late_epic", "EPIC")
	assert_eq(c._catchup_ceremonies.size(), 2, "RARE+ 插入 ceremonies 殘餘")
	# 持續注入仍 terminate(cap enforced):
	for i: int in range(50):
		var d := _drop("flood_%d" % i, "COMMON")
		_loot.add_drop(d)
		_loot.fire_doorbell(d.drop_id, "COMMON")
	assert_lte(c._catchup_stream.size(), 40, "MAX_STREAM_BEATS cap — 收斂保證")
	for i: int in range(45):
		c._process(0.15)
	assert_ne(c.get_fsm_state(), S.CATCHUP_STREAM, "stream terminates → ceremonies(phase 唔回頭)")


# --- AC-69: EC-M18 prompt count in-place ---

func test_prompt_count_updates_in_place_on_new_drop() -> void:
	var c: Node = _make()
	_fill(5, 0, 0, 0, 0)
	_gsm.go(7)
	assert_eq(c._prompt_count, 5)
	var d := _drop("new_one", "COMMON")
	_loot.add_drop(d)
	_loot.fire_doorbell("new_one", "COMMON")
	assert_eq(c._prompt_count, 6, "count→6 in-place")
	assert_eq(c.get_fsm_state(), S.CATCHUP_PROMPT, "零新 entrance(state 不變)")
