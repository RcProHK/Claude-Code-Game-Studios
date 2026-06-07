extends GutTest
## Story 015 — catch-up ceremonies + grid + commit 語意 + EC-M7/M16 + C-1/C-2.
## Covers AC-28(#21-side)/ AC-29(#21-side)/ AC-58(#21-side)/ AC-67。
## Gated 半邊:aggregated cue id 註冊(G-LM-8 → 023)/ batch seam real(G-LM-10
## → 024)/ #15 dequeue(G-LM-4 → 018)— 本檔全部以 fake seam 斷言 call shape。
##
## GDD: design/gdd/loot-drop-modal.md Rule 10 / Rule 7 / EC-M7 / EC-M16 / C-1 / C-2.

const CoordinatorScript := preload("res://src/autoload/loot_reveal_coordinator.gd")

const S := CoordinatorScript.ModalState
const T := LootEnums.RarityTier
const WORKOUT_ACTIVE: int = 3


class BatchSpyInventory:
	extends Node
	var calls: Array = []          # receive_loot records, in order
	var batch_events: Array = []   # "begin"/"end" markers interleaved
	var persist_count: int = 0     # simulated: +1 per call OUTSIDE batch; +1 per batch
	var _in_batch: bool = false
	func begin_receive_batch() -> void:
		batch_events.append("begin")
		_in_batch = true
	func end_receive_batch() -> void:
		batch_events.append("end")
		_in_batch = false
		persist_count += 1
	func receive_loot(record) -> int:
		calls.append(record)
		batch_events.append("receive")
		if not _in_batch:
			persist_count += 1
		return EquipmentEnums.ReceiveResult.OK


class FakeAudio:
	extends Node
	var sfx_calls: Array = []
	func play_sfx(event_id: StringName) -> void:
		sfx_calls.append(event_id)


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
var _inv: BatchSpyInventory
var _audio: FakeAudio
var _dismissed: Array = []


func _drop(id: String, tier_name: String) -> LootDrop:
	var d := LootDrop.new()
	d.drop_id = id
	d.rarity_tier = tier_name
	return d


func _make() -> Node:
	_gsm = MockGsm.new()
	_loot = MockLootSystem.new()
	_inv = BatchSpyInventory.new()
	_audio = FakeAudio.new()
	_dismissed = []
	for n: Node in [_gsm, _loot, _inv, _audio]:
		add_child_autofree(n)
	var c: Node = CoordinatorScript.new()
	c._gsm = _gsm
	c._loot_system = _loot
	c._inventory = _inv
	c._audio = _audio
	add_child_autofree(c)
	c.modal_dismissed.connect(func(id: String, terminal: bool) -> void:
		_dismissed.append({"id": id, "terminal": terminal}))
	return c


func _fill_f3_fixture() -> void:
	# 14C + 10U + 4R + 1E + 1L (AC-28 嘅 F3 fixture)
	var idx: int = 0
	for spec: Array in [[14, "COMMON"], [10, "UNCOMMON"], [4, "RARE"], [1, "EPIC"], [1, "LEGENDARY"]]:
		for i: int in range(spec[0]):
			_loot.add(_drop("d_%02d" % idx, spec[1]))
			idx += 1


## 精確行完 24-beat stream:banner 0.3 + 24×0.15 — 停喺 stream-end 嗰 frame
## (batch 已 fire,首個 ceremony ENTRY 啱啱開,clock=0)。
func _run_stream(c: Node) -> void:
	c._process(0.3)  # banner
	for i: int in range(24):
		c._process(0.15)


# --- AC-28: catch-up 結構(F3 fixture 全鏈) ---

func test_f3_fixture_stream_ceremonies_grid_structure() -> void:
	var c: Node = _make()
	_fill_f3_fixture()
	_gsm.go(7)
	c.handle_tap()  # reveal-all
	assert_eq(c.get_fsm_state(), S.CATCHUP_STREAM)
	assert_eq(c._catchup_stream.size(), 24, "sub-RARE 24 件 stream")
	assert_eq(c._catchup_ceremonies.size(), 5, "top-K=5(L+E+3R)")
	assert_eq(c._catchup_grid_items.size(), 1, "第 4 件 R 折入 grid(C-1 own cell)")
	# D4 negative spy: stream 期間零 fanfare:
	_run_stream(c)
	var fanfare_count: int = 0
	var aggregate_count: int = 0
	for ev: StringName in _audio.sfx_calls:
		if String(ev).begins_with("loot_fanfare"):
			fanfare_count += 1
		if ev == &"loot_stream_aggregate":
			aggregate_count += 1
	assert_eq(fanfare_count, 1, "stream 期間零 fanfare — 唯一 fanfare 屬第一個 ceremony(R)@stream 完")
	assert_eq(aggregate_count, 1, "aggregated cue exactly-once(單一 duck handle #4-side)")
	# stream-end 單一 frame batch(seam 包裹):
	assert_eq(_inv.batch_events.slice(0, 1), ["begin"], "batch seam begin 先行")
	assert_eq(_inv.batch_events[_inv.batch_events.find("end")], "end", "end 收尾")
	assert_eq(_inv.persist_count, 1, "24 件 stream → persist 一次(G-LM-10 語意 over fake)")
	assert_eq(c.get_fsm_state(), S.ENTRY, "RARE+ ceremonies 接力(ascending — 首件 R)")
	assert_eq(c._current_tier, T.RARE, "reveal ascending 由 R 起")


func test_ceremonies_advance_ascending_then_grid_commits_overflow() -> void:
	var c: Node = _make()
	_fill_f3_fixture()
	_gsm.go(7)
	c.handle_tap()
	_run_stream(c)
	var seen_tiers: Array = []
	# 行晒 5 個 ceremonies(natural + tap dismiss):
	for i: int in range(5):
		seen_tiers.append(c._current_tier)
		for j: int in range(4):
			c._process(0.5)   # natural S3(最長 LEG 1.2s)
		c._process(0.3)
		c.handle_tap()        # dismiss
		c._process(0.2)       # S4
		c._process(0.6)       # gap(EPIC+ margin 都夠)
	assert_eq(seen_tiers, [T.RARE, T.RARE, T.RARE, T.EPIC, T.LEGENDARY], "ascending,peak-end")
	assert_eq(c.get_fsm_state(), S.CATCHUP_GRID, "ceremonies 完 → contact-sheet grid")
	# C-2: overflow 件喺 grid entry frame batch commit:
	assert_eq(_inv.calls.size(), 24 + 5 + 1, "stream 24 + ceremonies 5 + grid overflow 1 全 committed")
	assert_eq(_inv.persist_count, 1 + 5 + 1, "stream batch 1 + per-item 5 + grid batch 1")
	c.handle_tap()  # grid close
	assert_eq(_dismissed[-1], {"id": "", "terminal": true}, "grid terminal emit — GSM deadlock fix")
	assert_eq(c.get_fsm_state(), S.HIDDEN)


# --- AC-29: mid-ceremonies「稍後再拆」零懲罰 ---

func test_mid_ceremony_exit_commits_current_keeps_rest_pending() -> void:
	var c: Node = _make()
	_fill_f3_fixture()
	_gsm.go(7)
	c.handle_tap()
	_run_stream(c)  # stream committed(24)
	# 第 1 個 ceremony(R)行到 S2:
	c._process(0.35)
	assert_eq(c.get_fsm_state(), S.CEREMONY)
	c._handle_catchup_exit()  # 稍後再拆
	c._process(0.2)   # snap → S3(commit)→ stash collapse 開始
	c._process(0.2)   # collapse 完 → emit + terminal → HIDDEN
	assert_eq(c.get_fsm_state(), S.HIDDEN)
	assert_eq(_inv.calls.size(), 25, "stream 24 + 當前件 1 — exit 永遠唔丟件;剩餘 4 ceremonies 永不 commit(留 pending)")
	assert_eq(_dismissed[-1], {"id": "", "terminal": true}, "terminal — GSM 推進")


# --- AC-58: EC-M7 per-phase force-close commit points ---

func test_force_close_in_prompt_zero_commit() -> void:
	var c: Node = _make()
	_fill_f3_fixture()
	_gsm.go(7)
	assert_eq(c.get_fsm_state(), S.CATCHUP_PROMPT)
	_gsm.go(WORKOUT_ACTIVE)
	assert_eq(_inv.calls.size(), 0, "PROMPT force-close → 零 commit 全留 pending")
	assert_eq(_dismissed[-1], {"id": "", "terminal": true})
	assert_eq(c.get_fsm_state(), S.HIDDEN)


func test_force_close_mid_stream_batch_commits_displayed_only() -> void:
	var c: Node = _make()
	_fill_f3_fixture()
	_gsm.go(7)
	c.handle_tap()
	c._process(0.3)   # banner
	c._process(0.6)   # 4 beats displayed
	assert_eq(c._catchup_stream_displayed.size(), 4)
	_gsm.go(WORKOUT_ACTIVE)  # force-close 嗰刻 = batch commit point
	assert_eq(_inv.calls.size(), 4, "已 display 4 件單 frame 連發 commit;未 display 留 pending")
	assert_eq(_inv.persist_count, 1, "seam 包裹 — persist 一次")
	assert_eq(c.get_fsm_state(), S.HIDDEN)


func test_force_close_in_grid_zero_data_effect() -> void:
	var c: Node = _make()
	_fill_f3_fixture()
	_gsm.go(7)
	c.handle_tap()
	_run_stream(c)
	for i: int in range(5):
		for j: int in range(4):
			c._process(0.5)
		c._process(0.3)
		c.handle_tap()
		c._process(0.2)
		c._process(0.6)
	assert_eq(c.get_fsm_state(), S.CATCHUP_GRID)
	var commits_before: int = _inv.calls.size()
	_gsm.go(WORKOUT_ACTIVE)
	assert_eq(_inv.calls.size(), commits_before, "grid 係 post-commit summary — 零 data 影響")
	assert_eq(c.get_fsm_state(), S.HIDDEN)


# --- AC-67: EC-M16 rollback 打中 stream ---

func test_rollback_hits_displayed_uncommitted_beat() -> void:
	var c: Node = _make()
	_fill_f3_fixture()
	_gsm.go(7)
	c.handle_tap()
	c._process(0.3)
	c._process(0.45)  # 3 beats displayed: d_00 d_01 d_02
	_loot.loot_rollback.emit("d_01")  # displayed 但 batch 未 fire
	assert_eq(c._catchup_stream_displayed.size(), 2, "aggregate −1,該件唔入 batch")
	_run_stream(c)  # stream 完 → batch
	var committed_ids: Array = []
	for record in _inv.calls:
		committed_ids.append(str(record.drop_id))
	assert_false("d_01" in committed_ids, "rolled beat 永不 commit")
	# 未 display 件 rollback:
	assert_true("d_02" in committed_ids, "其他 beats 照 commit")
