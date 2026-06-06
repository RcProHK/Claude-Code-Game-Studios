extends GutTest
## Stories 002/004/005/006/007 — boot lifecycle + training-day count + unlock
## write-then-emit + rollback + sweep + ceremony queue.
## Covers AC-01/02/03/05/06/10/11/12.

const ZoneSystemScript := preload("res://src/autoload/zone_system.gd")

const DAY1_MS: int = 1765011600000  # 2025-12-06T09:00:00Z ms
const DAY1_LATE_MS: int = 1765065599000  # same UTC date, 23:59:59Z
const DAY2_MS: int = 1765098000000  # next UTC date
const DAY0_MS: int = 1764925200000  # the PREVIOUS date (stale replay vector)


class MockWst:
	extends Node
	signal workout_completed_forwarded(completed_at: int, transition_id: String)


class FlushSpyPersistence:
	extends RefCounted
	var store: Dictionary = {}
	var writes: Array[Dictionary] = []
	var fail_writes: bool = false

	func read(key: String) -> Variant:
		return store.get(key)

	func write(key: String, value: Variant, flush: bool = false) -> bool:
		if fail_writes:
			return false
		store[key] = value
		writes.append({"key": key, "flush": flush})
		return true


func _zone(id: StringName, kind: int, threshold: int) -> ZoneDef:
	var z := ZoneDef.new()
	z.zone_id = id
	var c := ZoneUnlockCondition.new()
	c.kind = kind
	c.threshold = threshold
	z.unlock_condition = c
	return z


func _mvp_plus_locked(threshold: int) -> ZoneRegistryData:
	var r := ZoneRegistryData.new()
	r.zones.append(_zone(&"zone_verdant_forest", ZoneUnlockCondition.Kind.ALWAYS, 0))
	r.zones.append(_zone(&"zone_two", ZoneUnlockCondition.Kind.WORKOUT_COUNT, threshold))
	return r


var _sut: Node
var _wst: MockWst
var _persistence: FlushSpyPersistence
var _unlocks: Array = []


func before_each() -> void:
	_wst = MockWst.new()
	add_child_autofree(_wst)
	_persistence = FlushSpyPersistence.new()
	_unlocks = []


func _boot(registry: ZoneRegistryData) -> void:
	_sut = ZoneSystemScript.new()
	_sut._persistence = _persistence
	_sut._workout_source = _wst
	_sut._registry = registry
	add_child_autofree(_sut)
	_sut.zone_unlocked.connect(func(id: StringName) -> void: _unlocks.append(id))


func _events() -> Array:
	return _sut.get_telemetry().map(func(e: Dictionary) -> String: return e["event"])


# --- AC-01 / AC-12: MVP boot ----------------------------------------------------------

func test_mvp_boot_active_zone_and_derived_always() -> void:
	_boot(_mvp_plus_locked(5))
	assert_true(_sut.is_ready(), "AC-12: READY synchronously by end of _ready")
	assert_false(_wst.workout_completed_forwarded.get_connections().is_empty(),
		"AC-12: #9 signal connected")
	assert_eq(_sut.get_active_zone().zone_id, &"zone_verdant_forest", "AC-01")
	assert_true(_sut.is_zone_unlocked(&"zone_verdant_forest"), "AC-01: ALWAYS derived")
	assert_true(_sut._zone_state.unlocked_zone_ids.is_empty(),
		"AC-01 / Rule 4: ALWAYS is never persisted")


# --- AC-02 / AC-03: unlock write-then-emit + replay idempotency -------------------------

func test_unlock_writes_before_emit_and_replay_is_noop() -> void:
	_boot(_mvp_plus_locked(2))
	_sut._zone_state.workout_count = 1
	# Act — a new training day crosses the threshold.
	_wst.workout_completed_forwarded.emit(DAY2_MS, "txn-B")
	# Assert — AC-02: count 2, one emit, queue holds the id, flush=true write happened.
	assert_eq(_sut._zone_state.workout_count, 2)
	assert_eq(_unlocks, [&"zone_two"])
	assert_true(_sut._zone_state.ceremony_pending.has(&"zone_two"))
	var flushed: int = _persistence.writes.filter(
		func(w: Dictionary) -> bool: return w["flush"]).size()
	assert_eq(flushed, 1, "AC-02: unlock = anchor flush")
	assert_has(_events(), "zone.unlocked")
	# AC-03 — same transition replayed: no count, no second emit, no queue dup.
	_wst.workout_completed_forwarded.emit(DAY2_MS, "txn-B")
	assert_eq(_sut._zone_state.workout_count, 2)
	assert_eq(_unlocks.size(), 1)
	assert_eq(_sut._zone_state.ceremony_pending.count(&"zone_two"), 1)


# --- AC-06: per-day cap + monotone stale guard -------------------------------------------

func test_training_day_count_cap_stale_and_next_day() -> void:
	_boot(_mvp_plus_locked(5))
	_sut._zone_state.workout_count = 3
	# Day 1 first workout counts.
	_wst.workout_completed_forwarded.emit(DAY1_MS, "txn-1")
	assert_eq(_sut._zone_state.workout_count, 4)
	# (a) same UTC day, new transition → per-day cap (UTC boundary fixture pair).
	_wst.workout_completed_forwarded.emit(DAY1_LATE_MS, "txn-C")
	assert_eq(_sut._zone_state.workout_count, 4, "AC-06a: same-day cap")
	# (b) STALE date (epoch full-resync replay) → monotone guard.
	_wst.workout_completed_forwarded.emit(DAY0_MS, "txn-E")
	assert_eq(_sut._zone_state.workout_count, 4, "AC-06b: stale-date no-op")
	# (c) next UTC date → counts (the 00:00:00Z edge of the fixture pair).
	_wst.workout_completed_forwarded.emit(DAY2_MS, "txn-D")
	assert_eq(_sut._zone_state.workout_count, 5, "AC-06c: new day counts")


# --- AC-05: retroactive sweep -------------------------------------------------------------

func test_boot_sweep_unlocks_already_earned_zone() -> void:
	var pre := ZoneState.new()
	pre.workout_count = 25
	_persistence.store["zone.state"] = pre.to_dict()
	_boot(_mvp_plus_locked(20))
	assert_true(_sut.is_zone_unlocked(&"zone_two"), "AC-05: sweep retro-credits at boot")
	assert_true(_sut._zone_state.ceremony_pending.has(&"zone_two"),
		"AC-05: ceremony queued (drained later by the presentation consumer)")


func test_sweep_is_idempotent_and_silent_when_nothing_earned() -> void:
	_boot(_mvp_plus_locked(5))
	assert_true(_sut._zone_state.ceremony_pending.is_empty())
	assert_eq(_unlocks.size(), 0)


# --- AC-10: persist-fail rollback (both appends; count keeps) -------------------------------

func test_persist_fail_rolls_back_unlock_and_ceremony_keeps_count() -> void:
	_boot(_mvp_plus_locked(2))
	_sut._zone_state.workout_count = 1
	_persistence.fail_writes = true
	_wst.workout_completed_forwarded.emit(DAY2_MS, "txn-B")
	assert_eq(_unlocks.size(), 0, "AC-10: zero emit on write failure")
	assert_false(_sut._zone_state.unlocked_zone_ids.has(&"zone_two"), "unlock rolled back")
	assert_false(_sut._zone_state.ceremony_pending.has(&"zone_two"), "queue rolled back")
	assert_eq(_sut._zone_state.workout_count, 2, "count deliberately keeps")
	assert_has(_events(), "zone.persist_failed")
	# Recovery — next boot sweep re-credits from the in-memory-carried count.
	_persistence.fail_writes = false
	_sut._retroactive_sweep()
	assert_true(_sut._zone_state.unlocked_zone_ids.has(&"zone_two"), "sweep self-heals")
	assert_eq(_sut._zone_state.ceremony_pending.count(&"zone_two"), 1, "zero duplicate")


# --- AC-11: ceremony queue drain ----------------------------------------------------------

func test_drain_returns_all_and_clears() -> void:
	var pre := ZoneState.new()
	pre.workout_count = 99
	_persistence.store["zone.state"] = pre.to_dict()
	var r := ZoneRegistryData.new()
	r.zones.append(_zone(&"zone_verdant_forest", ZoneUnlockCondition.Kind.ALWAYS, 0))
	for i: int in 3:
		r.zones.append(_zone(StringName("zone_%d" % i), ZoneUnlockCondition.Kind.WORKOUT_COUNT, 10 + i))
	_boot(r)
	# Sweep unlocked 3 zones at once.
	var drained: Array[StringName] = _sut.drain_ceremony_queue()
	assert_eq(drained.size(), 3, "AC-11: one drain returns ALL (aggregated reveal)")
	assert_true(_sut._zone_state.ceremony_pending.is_empty(), "AC-11: cleared")
	assert_eq(_sut.drain_ceremony_queue().size(), 0, "second drain is empty")
