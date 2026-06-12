# Telemetry (#28) — Story 010 (EC-03): duplicate-transition detection.
#
# Verifies:
#   EC-03  the same (event_name, transition_id) within DUP_WINDOW_MS records BOTH originals
#          (faithful — never suppressed) PLUS one duplicate_transition_observed (CRITICAL).
#          Beyond the window → no duplicate marker. A different transition_id → no marker.
extends GutTest

const TelemetryScript := preload("res://src/autoload/telemetry.gd")


class MockClock extends RefCounted:
	var mono: int = 0
	func now_monotonic_ms() -> int: return mono
	func now_unix_s() -> int: return 1000


func _make_bare(clock) -> Node:
	var t = TelemetryScript.new()
	t._buffer = TelemetryBuffer.new(1000, 100)
	t._clock = clock
	t._dup_window_ms = 5000  # explicit test window (decoupled from the config default, Story 017)
	return t


func _count(events: Array, name) -> int:
	var n := 0
	for e in events:
		if e.event_name == name:
			n += 1
	return n


func test_duplicate_within_window_emits_marker_and_keeps_both() -> void:
	var clock := MockClock.new()
	clock.mono = 1000
	var t = _make_bare(clock)
	t._record_dedup(&"loot_dropped", "tx-1", {"a": 1}, TelemetryEvent.Priority.STANDARD)
	clock.mono = 1000 + 2000  # +2s, within the 5s window
	t._record_dedup(&"loot_dropped", "tx-1", {"a": 1}, TelemetryEvent.Priority.STANDARD)
	var events: Array = t._buffer.get_all()
	assert_eq(_count(events, &"loot_dropped"), 2, "EC-03: both originals recorded (faithful)")
	assert_eq(_count(events, &"duplicate_transition_observed"), 1, "one duplicate marker")
	# the marker is CRITICAL
	for e in events:
		if e.event_name == &"duplicate_transition_observed":
			assert_eq(e.priority, TelemetryEvent.Priority.CRITICAL, "duplicate marker is CRITICAL")
	t.free()


func test_beyond_window_no_duplicate_marker() -> void:
	var clock := MockClock.new()
	clock.mono = 1000
	var t = _make_bare(clock)
	t._record_dedup(&"loot_dropped", "tx-1", {}, TelemetryEvent.Priority.STANDARD)
	clock.mono = 1000 + 6000  # +6s, past the 5s window
	t._record_dedup(&"loot_dropped", "tx-1", {}, TelemetryEvent.Priority.STANDARD)
	var events: Array = t._buffer.get_all()
	assert_eq(_count(events, &"loot_dropped"), 2, "both recorded")
	assert_eq(_count(events, &"duplicate_transition_observed"), 0,
		"beyond window → not treated as a duplicate")
	t.free()


func test_different_transition_id_no_marker() -> void:
	var clock := MockClock.new()
	clock.mono = 1000
	var t = _make_bare(clock)
	t._record_dedup(&"loot_dropped", "tx-1", {}, TelemetryEvent.Priority.STANDARD)
	clock.mono = 1100
	t._record_dedup(&"loot_dropped", "tx-2", {}, TelemetryEvent.Priority.STANDARD)
	var events: Array = t._buffer.get_all()
	assert_eq(_count(events, &"duplicate_transition_observed"), 0,
		"different transition_id is not a duplicate")
	t.free()


func test_different_event_name_same_tid_no_marker() -> void:
	var clock := MockClock.new()
	clock.mono = 1000
	var t = _make_bare(clock)
	t._record_dedup(&"loot_dropped", "tx-1", {}, TelemetryEvent.Priority.STANDARD)
	clock.mono = 1100
	t._record_dedup(&"enemy_killed", "tx-1", {}, TelemetryEvent.Priority.STANDARD)
	var events: Array = t._buffer.get_all()
	assert_eq(_count(events, &"duplicate_transition_observed"), 0,
		"same transition_id but different event_name is not a duplicate")
	t.free()
