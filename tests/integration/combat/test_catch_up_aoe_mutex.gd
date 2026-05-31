# EnemyDirector — Story 009 Catch-up Queue + AOE Serialization Mutex
#
# Coverage:
#   AC-11    — AOE cast deferred to queue tail while draining; NOT processed in defer frame;
#              processed last (FIFO) after the queue drains.
#   EC-25    — CATCH_UP_QUEUE_HARD_CAP overflow: oldest dropped + CLAMP_TRIGGERED anomaly.
#   EC-24    — drain caps at CATCH_UP_HITS_PER_FRAME_CAP per frame; size monotonic; FIFO.
#
# EnemyDirector is an always-in-tree autoload, so its real _physics_process would drain
# queues between assertions. Tests call set_physics_process(false) and drive drain explicitly.
extends GutTest


## Records drained entries in order so FIFO drain is observable (Story 009 sink seam).
class CatchUpSinkSpy:
	var recorded: Array = []
	func record(entry) -> void:
		recorded.append(entry)


class FakeGSM:
	signal state_changed(from_state: int, to_state: int, payload)
	var _state: int = GameStateMachine.GameState.COMBAT_ACTIVE
	func connect_for_initial_state(callable: Callable) -> void:
		state_changed.connect(callable)
	func get_current_state() -> int:
		return _state
	func acquire_transition_id(_from: int, _to: int) -> String:
		return "TX-mutex-001"


class FakeAbilitySystem:
	signal ability_cast(ability_id: StringName, caster: Node2D, target: Node2D)
	func connect_for_initial_state(callable: Callable) -> void:
		ability_cast.connect(callable)


class FakeStatSystem:
	var call_count: int = 0
	func get_stat(_stat_id: StringName) -> float:
		call_count += 1
		return 10.0


class FakeEnemyRegistry:
	func get_preloaded_pool() -> Dictionary:
		return {&"STRIKE_MOB_T1": null}


const AOE_ID: StringName = &"ABILITY_AOE_1"
const SINGLE_ID: StringName = &"ABILITY_STRIKE_1"

var _fake_gsm: FakeGSM
var _fake_stat: FakeStatSystem
var _sink: CatchUpSinkSpy


func before_each() -> void:
	await get_tree().process_frame
	EnemyDirector.set_physics_process(false)  # control drain explicitly (determinism)
	# Full container reset.
	EnemyDirector.get(&"_catch_up_queue").clear()
	EnemyDirector.get(&"_anomaly_rate_tracker").clear()
	EnemyDirector.get(&"_enemy_state_pool").clear()
	EnemyDirector.get(&"_killed_dedupe_set").clear()
	EnemyDirector.get(&"_spawn_pool").clear()
	EnemyDirector.set(&"_rng_factory", null)
	EnemyDirector.set(&"_active_wave", null)
	EnemyDirector.set(&"_boss_anchor_state", EnemyDirector.BossAnchorState.IDLE)
	EnemyDirector.set(&"_stat_system", null)
	# Inject fakes + Story 009 seams.
	_fake_gsm = FakeGSM.new()
	_fake_stat = FakeStatSystem.new()
	_sink = CatchUpSinkSpy.new()
	EnemyDirector.set(&"_gsm_source", _fake_gsm)
	EnemyDirector.set(&"_ability_source", FakeAbilitySystem.new())
	EnemyDirector.set(&"_stat_system", _fake_stat)
	EnemyDirector.set(&"_enemy_registry", FakeEnemyRegistry.new())
	EnemyDirector.set(&"_aoe_ability_set", {AOE_ID: true})
	EnemyDirector.set(&"_catch_up_sink", _sink)
	EnemyDirector.call("_ready")


func after_each() -> void:
	await get_tree().process_frame
	EnemyDirector.get(&"_catch_up_queue").clear()
	EnemyDirector.set(&"_gsm_source", null)
	EnemyDirector.set(&"_ability_source", null)
	EnemyDirector.set(&"_stat_system", null)
	EnemyDirector.set(&"_enemy_registry", null)
	EnemyDirector.set(&"_aoe_ability_set", null)
	EnemyDirector.set(&"_catch_up_sink", null)
	EnemyDirector.set_physics_process(true)


## Helper: push N opaque catch-up entries (labelled) directly into the queue.
func _seed_queue(count: int, label_prefix: String) -> void:
	var queue: Array = EnemyDirector.get(&"_catch_up_queue")
	for i in count:
		queue.push_back(EnemyDirector.CatchUpEntry.new(StringName("%s%d" % [label_prefix, i]), null, null))


# ---------------------------------------------------------------------------
# AC-11 — AOE deferral during drain
# ---------------------------------------------------------------------------

## AOE cast while draining → appended to queue tail (not processed inline).
func test_ac11_aoe_cast_while_draining_deferred_to_tail() -> void:
	_seed_queue(5, "catchup_")
	var caster := Node2D.new()
	EnemyDirector.call("_on_ability_cast", AOE_ID, caster, null)
	var queue: Array = EnemyDirector.get(&"_catch_up_queue")
	assert_eq(queue.size(), 6, "AC-11: AOE cast must be appended (5 seeded + 1 AOE)")
	var tail = queue[queue.size() - 1]
	assert_eq(tail.ability_id, AOE_ID, "AC-11: AOE entry must be at the queue TAIL (FIFO)")
	caster.free()


## AOE cast while draining → NOT processed in the defer frame.
func test_ac11_aoe_cast_not_processed_in_defer_frame() -> void:
	_seed_queue(5, "catchup_")
	var caster := Node2D.new()
	EnemyDirector.call("_on_ability_cast", AOE_ID, caster, null)
	assert_eq(_sink.recorded.size(), 0,
		"AC-11: no entry may be processed during the defer call (defer != drain)")
	assert_eq(_fake_stat.call_count, 0,
		"AC-11: deferred AOE must not build a stat snapshot in the defer frame")
	caster.free()


## After deferral, draining processes all entries FIFO with the AOE last.
func test_ac11_deferred_aoe_processed_last_after_drain() -> void:
	_seed_queue(5, "catchup_")
	var caster := Node2D.new()
	EnemyDirector.call("_on_ability_cast", AOE_ID, caster, null)
	# Drain all 6 (under the 12/frame cap → single drain empties the queue).
	EnemyDirector.call("_drain_catch_up_queue")
	assert_eq(_sink.recorded.size(), 6, "AC-11: all 6 entries drained")
	var last = _sink.recorded[_sink.recorded.size() - 1]
	assert_eq(last.ability_id, AOE_ID, "AC-11: deferred AOE must be processed LAST (FIFO)")
	# First 5 are the seeded entries in order.
	assert_eq(_sink.recorded[0].ability_id, &"catchup_0", "AC-11: FIFO order preserved at head")
	caster.free()


## Two AOE casts deferred during drain preserve their relative FIFO order.
func test_ac11_multiple_deferred_aoe_preserve_relative_fifo() -> void:
	_seed_queue(3, "catchup_")
	EnemyDirector.set(&"_aoe_ability_set", {&"AOE_A": true, &"AOE_B": true})
	var caster := Node2D.new()
	EnemyDirector.call("_on_ability_cast", &"AOE_A", caster, null)
	EnemyDirector.call("_on_ability_cast", &"AOE_B", caster, null)
	EnemyDirector.call("_drain_catch_up_queue")  # 3 seeded + 2 AOE = 5, under cap
	assert_eq(_sink.recorded.size(), 5, "AC-11: all 5 entries drained")
	assert_eq(_sink.recorded[3].ability_id, &"AOE_A", "AC-11: first-deferred AOE_A drains before AOE_B")
	assert_eq(_sink.recorded[4].ability_id, &"AOE_B", "AC-11: second-deferred AOE_B drains last (relative FIFO)")
	caster.free()


## _is_aoe_cast with a null seam returns false (no defer before Story 018 wiring).
func test_ac11_null_aoe_set_never_defers() -> void:
	EnemyDirector.set(&"_aoe_ability_set", null)
	_seed_queue(5, "catchup_")
	var caster := Node2D.new()
	EnemyDirector.call("_on_ability_cast", AOE_ID, caster, null)
	assert_eq((EnemyDirector.get(&"_catch_up_queue") as Array).size(), 5,
		"AC-11: with a null AOE set, nothing is classified AOE → no defer")
	caster.free()


## Non-AOE cast while draining proceeds normally (NOT deferred).
func test_ac11_non_aoe_cast_while_draining_not_deferred() -> void:
	_seed_queue(5, "catchup_")
	var caster := Node2D.new()
	EnemyDirector.call("_on_ability_cast", SINGLE_ID, caster, null)
	var queue: Array = EnemyDirector.get(&"_catch_up_queue")
	assert_eq(queue.size(), 5, "AC-11: non-AOE cast must NOT be enqueued (queue unchanged)")
	assert_eq(_fake_stat.call_count, 2,
		"AC-11: non-AOE cast proceeds through the pipeline (snapshot built)")
	caster.free()


## With an empty queue, even an AOE cast proceeds normally (no drain in progress).
func test_ac11_aoe_cast_with_empty_queue_not_deferred() -> void:
	var caster := Node2D.new()
	EnemyDirector.call("_on_ability_cast", AOE_ID, caster, null)
	var queue: Array = EnemyDirector.get(&"_catch_up_queue")
	assert_eq(queue.size(), 0, "AC-11: AOE cast with empty queue must NOT defer")
	assert_eq(_fake_stat.call_count, 2, "AC-11: AOE cast with empty queue proceeds normally")
	caster.free()


# ---------------------------------------------------------------------------
# EC-25 — Hard-cap overflow → CLAMP_TRIGGERED
# ---------------------------------------------------------------------------

## At hard cap, enqueue drops oldest + emits CLAMP_TRIGGERED; size stays at cap.
func test_ec25_hard_cap_overflow_drops_oldest_and_emits_anomaly() -> void:
	_seed_queue(EnemyDirector.CATCH_UP_QUEUE_HARD_CAP, "old_")
	watch_signals(EnemyDirector)
	EnemyDirector.call("_enqueue_catch_up", EnemyDirector.CatchUpEntry.new(&"new_entry", null, null))
	var queue: Array = EnemyDirector.get(&"_catch_up_queue")
	assert_eq(queue.size(), EnemyDirector.CATCH_UP_QUEUE_HARD_CAP,
		"EC-25: size must stay at hard cap (oldest dropped, new pushed)")
	assert_signal_emitted(EnemyDirector, "combat_metric_anomaly",
		"EC-25: CLAMP_TRIGGERED anomaly must be emitted on overflow")
	var params: Array = get_signal_parameters(EnemyDirector, "combat_metric_anomaly")
	var payload = params[0]
	assert_eq(payload.reason, EnemyDirector.REASON_CLAMP_TRIGGERED,
		"EC-25: anomaly reason must be CLAMP_TRIGGERED")
	assert_true(payload.context_dump.get("queue_overflow", false),
		"EC-25: context_dump.queue_overflow must be true")


## Overflow drops the OLDEST entry (FIFO eviction), new entry lands at tail.
func test_ec25_overflow_evicts_front_entry() -> void:
	_seed_queue(EnemyDirector.CATCH_UP_QUEUE_HARD_CAP, "old_")
	EnemyDirector.call("_enqueue_catch_up", EnemyDirector.CatchUpEntry.new(&"new_entry", null, null))
	var queue: Array = EnemyDirector.get(&"_catch_up_queue")
	assert_eq(queue[0].ability_id, &"old_1",
		"EC-25: front (old_0) must be evicted; old_1 is the new head")
	assert_eq(queue[queue.size() - 1].ability_id, &"new_entry",
		"EC-25: new entry must be at the tail")


## Below hard cap, enqueue does NOT emit an anomaly.
func test_ec25_below_cap_no_anomaly() -> void:
	_seed_queue(10, "old_")
	watch_signals(EnemyDirector)
	EnemyDirector.call("_enqueue_catch_up", EnemyDirector.CatchUpEntry.new(&"new_entry", null, null))
	assert_eq(get_signal_emit_count(EnemyDirector, "combat_metric_anomaly"), 0,
		"EC-25: no anomaly below the hard cap")
	assert_eq((EnemyDirector.get(&"_catch_up_queue") as Array).size(), 11,
		"EC-25: below cap, entry is simply appended")


# ---------------------------------------------------------------------------
# EC-24 — Per-frame drain cap + monotonic FIFO drain
# ---------------------------------------------------------------------------

## Each drain processes at most CATCH_UP_HITS_PER_FRAME_CAP entries.
func test_ec24_single_drain_caps_at_per_frame_limit() -> void:
	_seed_queue(50, "burst_")
	EnemyDirector.call("_drain_catch_up_queue")
	var cap: int = EnemyDirector.CATCH_UP_HITS_PER_FRAME_CAP
	assert_eq(_sink.recorded.size(), cap,
		"EC-24: a single drain must process exactly CATCH_UP_HITS_PER_FRAME_CAP entries")
	assert_eq((EnemyDirector.get(&"_catch_up_queue") as Array).size(), 50 - cap,
		"EC-24: queue must shrink by exactly the per-frame cap")


## 50-entry backlog drains monotonically over 5 frames to 0 (12,12,12,12,2).
func test_ec24_burst_drains_monotonically_to_zero() -> void:
	_seed_queue(50, "burst_")
	var queue: Array = EnemyDirector.get(&"_catch_up_queue")
	var sizes: Array[int] = []
	for tick in 5:
		EnemyDirector.call("_physics_process", 0.016)
		sizes.append(queue.size())
	assert_eq(sizes, [38, 26, 14, 2, 0] as Array[int],
		"EC-24: queue size after each frame must be 38,26,14,2,0 (12/frame cap)")
	# Strictly monotonic decrease.
	for i in range(1, sizes.size()):
		assert_lt(sizes[i], sizes[i - 1], "EC-24: queue size must strictly decrease each frame")


## Drain preserves FIFO order across multiple frames.
func test_ec24_drain_preserves_fifo_across_frames() -> void:
	_seed_queue(20, "fifo_")
	EnemyDirector.call("_drain_catch_up_queue")  # processes fifo_0..fifo_11
	EnemyDirector.call("_drain_catch_up_queue")  # processes fifo_12..fifo_19
	assert_eq(_sink.recorded.size(), 20, "EC-24: all 20 entries drained over 2 frames")
	assert_eq(_sink.recorded[0].ability_id, &"fifo_0", "EC-24: first drained is fifo_0")
	assert_eq(_sink.recorded[12].ability_id, &"fifo_12", "EC-24: frame-2 head is fifo_12")
	assert_eq(_sink.recorded[19].ability_id, &"fifo_19", "EC-24: last drained is fifo_19")


## Empty queue drain is a safe no-op.
func test_ec24_empty_queue_drain_is_noop() -> void:
	EnemyDirector.call("_drain_catch_up_queue")
	assert_eq(_sink.recorded.size(), 0, "EC-24: draining an empty queue records nothing")
