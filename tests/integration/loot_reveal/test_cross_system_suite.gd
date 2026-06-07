extends GutTest
## Story 026 — cross-system integration suite(real GSM / #15 / #17 / #6)。
## Covers AC-54(smoke)/ AC-72 / AC-73 / AC-74(G-flag-1 ✅ grep-verified:
## MIN_REVEAL_WINDOW_SECONDS 只有 const 宣告 + knob assert,零 runtime gating
## site — dismiss 完全唔經 window)。AC-71 已喺 018 round-trip 收;AC-78
## BLOCKED-ON #20 Q-OQ6 suppress 接線(#20-side wiring — 唔屬 #21 epic)。

const CoordinatorScript := preload("res://src/autoload/loot_reveal_coordinator.gd")
const LootSystemScript := preload("res://src/autoload/loot_drop_system.gd")
const GSMScript := preload("res://src/autoload/game_state_machine.gd")
const InventoryScript := preload("res://src/autoload/inventory_system.gd")
const ScreenEffectsScript := preload("res://src/autoload/screen_effects.gd")
const TABLE_PATH: String = "res://assets/data/equipment/stat_assignment_table.tres"


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


class FakeCamera:
	extends Node
	signal focal_completed(target_position: Vector2)
	func request_focal(_p: Vector2, _d: float = 0.0, _z: float = 1.0) -> void:
		pass
	func finish_focal() -> void:
		focal_completed.emit(Vector2.ZERO)


func after_each() -> void:
	# Real-PersistenceLayer key hygiene(GSM 用 global autoload)
	PersistenceLayer.delete(GSMScript.KEY_LOOT_REVEAL_PENDING)
	if get_tree().paused:
		get_tree().paused = false


func _make_better_drop() -> LootDrop:
	var d := LootDrop.new()
	d.drop_id = "better_1"
	d.transition_id = "t_better"
	d.rarity_tier = "EPIC"
	d.item_type = "WEAPON"
	d.item_metadata = {"item_id": "better_1"}
	return d


func _grant_full(loot: Node, tid: String, ws: float = 0.6) -> LootDrop:
	loot._process_loot_trigger(tid, LootEnums.SourceEventKind.MINI_BOSS, ws, LootEnums.CeremonyDecision.FULL_CEREMONY)
	return loot._drops_by_transition.get(tid)


# --- AC-73 + AC-74: real GSM full loop ---

func test_gsm_full_loop_reveal_dismiss_confirmed_exit() -> void:
	var gsm: Node = GSMScript.new()
	add_child_autofree(gsm)
	gsm._current_state = GSMScript.GameState.IDLE
	var loot: Node = LootSystemScript.new()
	loot._persistence = MockPersistence.new()
	loot._gsm = gsm  # reverse-wires loot_confirmed → gsm.on_loot_confirmed
	add_child_autofree(loot)
	var c: Node = CoordinatorScript.new()
	c._gsm = gsm
	c._loot_system = loot
	add_child_autofree(c)
	_grant_full(loot, "tid_loop")
	# Entry — 真 transition pipeline(1 event/frame drain):
	var payload := StateTransitionPayload.new()
	payload.source_event = "workout_completed"
	gsm.enqueue_event(payload, GSMScript.GameState.LOOT_DROP, 1)
	gsm._process(0.016)  # 1 event/frame drain — manual deterministic tick
	assert_eq(gsm._current_state, GSMScript.GameState.LOOT_DROP, "real transition 入 LOOT_DROP")
	assert_true(c.is_modal_active(), "real state_changed emit 開 modal")
	# AC-74(G-flag-1):reveal 開咗 ~2s(<15s)tap 即生效:
	for i: int in range(4):
		c._process(0.5)  # 2.0s → S3(任何 tier 都過咗 T_block)
	c._process(0.3)
	c.handle_tap()
	assert_eq(c.get_fsm_state(), CoordinatorScript.ModalState.EXITING,
		"dismiss = completion 非 interruption — 15s window 零 gating(G-flag-1 ✅)")
	c._process(0.2)  # S4 完 → terminal emit → #15 dequeue → loot_confirmed(true)
	assert_eq(loot.get_pending_drops().size(), 0)
	gsm._process(0.016)  # GSM exit enqueue drain
	assert_eq(gsm._current_state, GSMScript.GameState.IDLE,
		"loot_confirmed chain 帶 GSM 返 return state — #21 zero direct call")
	assert_ne(PersistenceLayer.read(GSMScript.KEY_LOOT_REVEAL_PENDING), true,
		"drained terminal → pending flag 清")


func test_gsm_state_unmoved_during_intra_queue() -> void:
	var gsm: Node = GSMScript.new()
	add_child_autofree(gsm)
	gsm._current_state = GSMScript.GameState.IDLE
	var loot: Node = LootSystemScript.new()
	loot._persistence = MockPersistence.new()
	loot._gsm = gsm
	add_child_autofree(loot)
	var c: Node = CoordinatorScript.new()
	c._gsm = gsm
	c._loot_system = loot
	add_child_autofree(c)
	_grant_full(loot, "tid_q1")
	_grant_full(loot, "tid_q2")
	var payload := StateTransitionPayload.new()
	payload.source_event = "workout_completed"
	gsm.enqueue_event(payload, GSMScript.GameState.LOOT_DROP, 1)
	gsm._process(0.016)
	for i: int in range(4):
		c._process(0.5)
	c._process(0.3)
	c.handle_tap()   # 第 1 件 dismiss(non-terminal)
	c._process(0.2)
	gsm._process(0.016)
	assert_eq(gsm._current_state, GSMScript.GameState.LOOT_DROP,
		"intra-queue 期間 GSM state 全程不變(Rule 6)")


# --- AC-72: real #17 full handoff + batch persist-once ---

func test_real_inventory_handoff_and_catchup_batch_persist_once() -> void:
	var state_writes: Array[int] = [0]  # array container — GDScript lambda 對 primitive 係 capture-by-value
	var persist := MockInventoryPersistWrapper.new()
	persist.on_state_write = func() -> void: state_writes[0] += 1
	var inv: Node = InventoryScript.new()
	inv._persistence = persist
	inv._gsm = MockInventoryGSM.new()
	inv._stat_table = load(TABLE_PATH)
	inv._stat_system = MockInventoryStat.new()
	inv._now_unix_provider = func() -> int: return 1764547300
	add_child_autofree(inv)
	var gsm := MockSimpleGsm.new()
	var loot: Node = LootSystemScript.new()
	loot._persistence = MockPersistence.new()
	add_child_autofree(gsm)
	add_child_autofree(loot)
	var c: Node = CoordinatorScript.new()
	c._gsm = gsm
	c._loot_system = loot
	c._inventory = inv
	add_child_autofree(c)
	# 單件 full reveal → S3 → 入庫 + auto-equip:
	_grant_full(loot, "tid_inv")
	gsm.go(7)
	c._process(0.25)
	for i: int in range(4):
		c._process(0.5)
	assert_eq(c.get_fsm_state(), CoordinatorScript.ModalState.STEADY)
	assert_gt(inv._items.size(), 0, "S3 → inventory 含 item(real #17 grant 鏈全通)")
	# auto-equip-if-better 唔被阻:path 行咗(零 mods fixture score 唔升 →
	# 唔 equip 係 if-better 正確行為;equip 決策本身由 #17 suite 全 cover)。
	assert_eq(int(inv.receive_loot(_make_better_drop())), int(EquipmentEnums.ReceiveResult.OK),
		"second grant 經同一 path — 鏈未被 #21 handoff 阻斷")
	# Catch-up batch:stream 6 件 → persist per batch 一次:
	c.handle_tap()
	c._process(0.3)
	c.handle_tap()
	c._process(0.2)
	gsm.current_state = 2
	for i: int in range(6):
		_grant_full(loot, "tid_b%d" % i, 0.0)  # ws=0 ⇒ Formula 1 forces COMMON(全 stream,deterministic)
	var writes_before: int = state_writes[0]
	gsm.go(7)
	c.handle_tap()  # reveal-all
	c._process(0.3)
	for i: int in range(7):
		c._process(0.15)  # stream 完 → batch
	assert_eq(state_writes[0], writes_before + 1,
		"stream batch 經 begin/end seam → real #17 persist 一次(G-LM-10 兌現)")


class MockSimpleGsm:
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


class MockInventoryPersistWrapper:
	extends RefCounted
	var store: Dictionary = {}
	var on_state_write: Callable = Callable()
	func read(key: String) -> Variant:
		return store.get(key)
	func write(key: String, value: Variant, _flush: bool = false) -> bool:
		store[key] = value
		if key == "inventory.state" and on_state_write.is_valid():
			on_state_write.call()
		return true
	func delete(key: String) -> bool:
		store.erase(key)
		return true
	func is_private_mode() -> bool:
		return false


# --- AC-54 smoke: real #6 over the #21 freeze path(主測 @ 021 #6-side) ---

func test_ec_m3_smoke_real_screen_effects() -> void:
	var fx: Node = ScreenEffectsScript.new()
	fx._shader_sink = func(_u: StringName, _v: Variant) -> void: pass
	add_child_autofree(fx)
	fx._lifecycle_state = ScreenEffectsScript.LifecycleState.ACTIVE
	var h1: int = fx.ceremony_freeze(0.1)
	var h2: int = fx.ceremony_freeze(0.4)  # max-remaining 效果
	assert_true(get_tree().paused)
	fx.release(h1)  # 只清自己 entry
	assert_true(get_tree().paused, "另一 entry 仍 hold")
	fx.release(h2)
	assert_false(get_tree().paused)
