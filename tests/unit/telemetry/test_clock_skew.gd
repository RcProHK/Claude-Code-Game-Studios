# Telemetry (#28) — Story 016: EC-07 clock-skew monotonic ordering (AC-16).
#
# Verifies:
#   AC-1  event ordering uses client_ts_monotonic_ms — stable even when wall-clock jumps
#         forward (+3600s NTP) or backward (DST), which only affects client_ts_unix.
#   AC-2  the EC-03 duplicate window is keyed on monotonic time, so a massive wall-clock
#         jump does not break duplicate detection within the monotonic window.
#
# The injected MockClock drives both stamps independently so the test can move wall time
# without moving monotonic time and vice-versa.
extends GutTest

const TelemetryScript := preload("res://src/autoload/telemetry.gd")
const PRIO := TelemetryEvent.Priority


class MockClock extends RefCounted:
	var mono: int = 0
	var unix: int = 1000
	func now_monotonic_ms() -> int: return mono
	func now_unix_s() -> int: return unix


func _make_telemetry(clock) -> Node:
	var t = TelemetryScript.new()
	t._clock = clock   # inject clock seam BEFORE _ready (DI override)
	add_child_autofree(t)
	return t


func _count_event(events: Array, name) -> int:
	var n := 0
	for e in events:
		if e.event_name == name:
			n += 1
	return n


# --- AC-1: monotonic ordering survives wall-clock jumps -----------------------

func test_ordering_uses_monotonic_despite_wall_jump() -> void:
	var clock := MockClock.new()
	var t := _make_telemetry(clock)

	clock.mono = 100
	clock.unix = 1000
	t._record(&"e1", {}, PRIO.STANDARD)

	# Wall clock jumps +3600s (NTP correction); monotonic advances normally.
	clock.mono = 200
	clock.unix = 1000 + 3600
	t._record(&"e2", {}, PRIO.STANDARD)

	# Wall clock jumps BACKWARD (DST roll-back); monotonic still advances.
	clock.mono = 300
	clock.unix = 1000 + 3600 - 7200
	t._record(&"e3", {}, PRIO.STANDARD)

	var events: Array = t._buffer.get_all()
	assert_eq(events.size(), 3, "three STANDARD events buffered in record order")

	var monos: Array = [
		events[0].client_ts_monotonic_ms,
		events[1].client_ts_monotonic_ms,
		events[2].client_ts_monotonic_ms,
	]
	assert_eq(monos, [100, 200, 300], "AC-16: monotonic stamps strictly increase with record order")

	var sorted_monos: Array = monos.duplicate()
	sorted_monos.sort()
	assert_eq(monos, sorted_monos, "AC-16: monotonic ordering is stable")

	# The wall stamp reflects the jumps (it is NOT a stable ordering key).
	assert_eq(events[1].client_ts_unix, 1000 + 3600, "unix stamp follows the forward jump")
	assert_lt(events[2].client_ts_unix, events[1].client_ts_unix, "unix stamp jumped backward (DST) — proves it is not the ordering key")


# --- AC-2: duplicate window is monotonic, not wall-clock ----------------------

func test_dup_window_keyed_on_monotonic() -> void:
	var clock := MockClock.new()
	var t := _make_telemetry(clock)
	t._dup_window_ms = 5000  # explicit window (decoupled from config default, Story 017)

	clock.mono = 1000
	clock.unix = 5000
	t._record_dedup(&"loot_dropped", "tid-1", {
		"drop_id": "d1", "rarity_tier": "RARE", "item_type": "sword", "transition_id": "tid-1",
	}, PRIO.STANDARD, 1)

	# Monotonic only +2000ms (well within DUP_WINDOW_MS=5000), but wall clock leaps +999999s.
	clock.mono = 1000 + 2000
	clock.unix = 5000 + 999999
	t._record_dedup(&"loot_dropped", "tid-1", {
		"drop_id": "d1", "rarity_tier": "RARE", "item_type": "sword", "transition_id": "tid-1",
	}, PRIO.STANDARD, 1)

	assert_eq(_count_event(t._buffer.get_all(), &"duplicate_transition_observed"), 1,
		"AC-16: dup detection keyed on monotonic — a huge wall jump does not hide the duplicate")


func test_dup_window_monotonic_expiry() -> void:
	var clock := MockClock.new()
	var t := _make_telemetry(clock)
	t._dup_window_ms = 5000  # explicit window (decoupled from config default, Story 017)

	clock.mono = 1000
	clock.unix = 5000
	t._record_dedup(&"loot_dropped", "tid-2", {
		"drop_id": "d2", "rarity_tier": "EPIC", "item_type": "ring", "transition_id": "tid-2",
	}, PRIO.STANDARD, 1)

	# Monotonic +6000ms > DUP_WINDOW_MS(5000) → outside the window → NOT a duplicate,
	# even though the wall clock barely moved.
	clock.mono = 1000 + 6000
	clock.unix = 5001
	t._record_dedup(&"loot_dropped", "tid-2", {
		"drop_id": "d2", "rarity_tier": "EPIC", "item_type": "ring", "transition_id": "tid-2",
	}, PRIO.STANDARD, 1)

	assert_eq(_count_event(t._buffer.get_all(), &"duplicate_transition_observed"), 0,
		"AC-16: outside the monotonic window → no duplicate flagged (wall clock irrelevant)")
