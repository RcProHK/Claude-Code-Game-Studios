## test_ceremony_cap_per_workout_isolation.gd
## Story 004 AC-07: per-workout counter isolation + housekeeping LRU eviction.
##
## Governing story: production/epics/loot-drop-system/story-004-formula-2-ceremony-cap.md
## Governing ADRs : ADR-0005 (primary). CF-5 per-workout isolation.
## Coverage       : AC-07 (per-workout isolation) + housekeeping + final overflow.
extends GutTest

## Autoload script preloaded as a const (shadows the LootDropSystem autoload
## global so tests can call .new() / access enums + constants on the class).
const LootDropSystem := preload("res://src/autoload/loot_drop_system.gd")

var _sut: LootDropSystem


func before_each() -> void:
	_sut = LootDropSystem.new()
	add_child_autofree(_sut)
	await get_tree().process_frame


func after_each() -> void:
	_sut = null


# ─── AC-07: per-workout isolation ────────────────────────────────────────────

func test_ac07_five_mini_boss_calls_return_full_ceremony() -> void:
	# Arrange — fresh workout W-99, no prior entry.
	# Act / Assert — calls 1..5 all under cap → FULL_CEREMONY.
	for i: int in range(5):
		var decision: int = _sut._ceremony_cap_check(LootEnums.SourceEventKind.MINI_BOSS, "W-99")
		assert_eq(decision, LootEnums.CeremonyDecision.FULL_CEREMONY,
			"W-99 mini-boss call #%d (under cap) returns FULL_CEREMONY" % [i + 1])


func test_ac07_sixth_mini_boss_call_returns_micro_ack() -> void:
	# Arrange — exhaust the cap with 5 prior calls.
	for i: int in range(5):
		_sut._ceremony_cap_check(LootEnums.SourceEventKind.MINI_BOSS, "W-99")
	# Act
	var decision: int = _sut._ceremony_cap_check(LootEnums.SourceEventKind.MINI_BOSS, "W-99")
	# Assert
	assert_eq(decision, LootEnums.CeremonyDecision.MICRO_ACK,
		"W-99 6th mini-boss call returns MICRO_ACK")


func test_ac07_counter_increments_correctly() -> void:
	# Arrange / Act — 5 calls.
	for i: int in range(5):
		_sut._ceremony_cap_check(LootEnums.SourceEventKind.MINI_BOSS, "W-99")
	# Assert
	assert_eq(int(_sut._emit_counter_mini.get("W-99", 0)), 5,
		"emit_counter_mini['W-99'] == 5 after 5 FULL_CEREMONY calls")


func test_ac07_w42_counter_unaffected_by_w99() -> void:
	# Arrange — seed W-42 at 3, then hammer W-99.
	_sut._emit_counter_mini["W-42"] = 3
	# Act
	for i: int in range(6):
		_sut._ceremony_cap_check(LootEnums.SourceEventKind.MINI_BOSS, "W-99")
	# Assert — W-42 is untouched (per-workout isolation, CF-5).
	assert_eq(int(_sut._emit_counter_mini.get("W-42", 0)), 3,
		"W-42 counter unaffected by W-99 operations (per-workout isolation)")


func test_ac07_workout_daily_counts_in_mini_pool() -> void:
	# WORKOUT_DAILY shares the mini pool — it is NOT an independent pool.
	# Arrange
	# Act — one MINI_BOSS then one WORKOUT_DAILY for the same workout.
	_sut._ceremony_cap_check(LootEnums.SourceEventKind.MINI_BOSS, "W-77")
	_sut._ceremony_cap_check(LootEnums.SourceEventKind.WORKOUT_DAILY, "W-77")
	# Assert — both incremented the same mini-pool counter.
	assert_eq(int(_sut._emit_counter_mini.get("W-77", 0)), 2,
		"WORKOUT_DAILY counts in the mini pool alongside MINI_BOSS (shared, not independent)")
	assert_false(_sut._emit_counter_final.has("W-77"),
		"WORKOUT_DAILY never touches the final pool")


# ─── Housekeeping LRU eviction ───────────────────────────────────────────────

func test_housekeeping_evicts_when_over_500() -> void:
	# Arrange — fill the mini pool with 501 entries (over MINI_POOL_MAX_ENTRIES).
	for i: int in range(501):
		_sut._emit_counter_mini["W-%d" % i] = 1
	# Act
	_sut._housekeeping_sweep_counters()
	# Assert — first inserted key ("W-0") is evicted; size drops to 500.
	assert_false(_sut._emit_counter_mini.has("W-0"),
		"oldest key (W-0, first inserted) is evicted")
	assert_eq(_sut._emit_counter_mini.size(), 500,
		"mini pool size drops to 500 after one emergency eviction")
	var events: Array[Dictionary] = _sut.get_telemetry("loot_counter_emergency_evict")
	assert_eq(events.size(), 1, "loot_counter_emergency_evict telemetry emitted once")
	assert_eq(events[0].get("data", {}).get("evicted_key"), "W-0",
		"evicted_key telemetry names the oldest key")


func test_housekeeping_evicts_only_one_entry_per_call() -> void:
	# Arrange — 502 entries (2 over ceiling).
	for i: int in range(502):
		_sut._emit_counter_mini["W-%d" % i] = 1
	# Act — single sweep call.
	_sut._housekeeping_sweep_counters()
	# Assert — exactly one entry removed per call (501 remain, still over ceiling).
	assert_eq(_sut._emit_counter_mini.size(), 501,
		"a single sweep call evicts exactly 1 entry (502→501)")


# ─── FINAL_BOSS overflow safety ──────────────────────────────────────────────

func test_final_boss_overflow_does_not_crash() -> void:
	# Arrange — first FINAL_BOSS fills the reserved pool (0→1).
	var first: int = _sut._ceremony_cap_check(LootEnums.SourceEventKind.FINAL_BOSS, "W-55")
	assert_eq(first, LootEnums.CeremonyDecision.FULL_CEREMONY,
		"first FINAL_BOSS returns FULL_CEREMONY (reserved pool 0→1)")
	# Act — second FINAL_BOSS is an overflow (should never happen if rules honored).
	var second: int = _sut._ceremony_cap_check(LootEnums.SourceEventKind.FINAL_BOSS, "W-55")
	# Assert — overflow must not crash and still returns FULL_CEREMONY.
	assert_eq(second, LootEnums.CeremonyDecision.FULL_CEREMONY,
		"overflow FINAL_BOSS still returns FULL_CEREMONY without crashing")
	var events: Array[Dictionary] = _sut.get_telemetry("loot_final_boss_ceremony_overflow")
	assert_eq(events.size(), 1,
		"overflow emits loot_final_boss_ceremony_overflow telemetry once")
