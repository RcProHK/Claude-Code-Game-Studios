# Telemetry (#28) — Story 016: EC-17 master opt-out (AC-15).
#
# Verifies:
#   AC-1  telemetry_enabled=false → zero flush (nothing leaves the device).
#   AC-2  under opt-out, capture drops to in-memory CRITICAL only (non-CRITICAL dropped).
#   AC-3  toggling the switch mid-session takes effect immediately and consistently.
extends GutTest

const TelemetryScript := preload("res://src/autoload/telemetry.gd")
const PRIO := TelemetryEvent.Priority


func _make_telemetry() -> Node:
	var t = TelemetryScript.new()
	add_child_autofree(t)
	return t


# --- AC-1: disabled → never flushes -------------------------------------------

func test_opt_out_blocks_flush() -> void:
	var t := _make_telemetry()
	var flushes: Array = []
	t._flush_hook = func(reason): flushes.append(reason)

	t.set_telemetry_enabled(false)
	t._request_flush(&"workout_completed")
	assert_eq(flushes.size(), 0, "AC-15: disabled telemetry never flushes (nothing leaves device)")

	t.set_telemetry_enabled(true)
	t._request_flush(&"workout_completed")
	assert_eq(flushes.size(), 1, "re-enabled telemetry flushes again")


# --- AC-2: disabled → only in-memory CRITICAL retained ------------------------

func test_opt_out_keeps_only_critical_in_memory() -> void:
	var t := _make_telemetry()
	t.set_telemetry_enabled(false)

	t._record(&"set_progress", {"progress": 0.5}, PRIO.STANDARD)
	t._record(&"hit_resolved", {}, PRIO.LOW)
	assert_eq(t.get_buffered_count(), 0, "AC-15: non-CRITICAL is not retained under opt-out")

	t._record(&"telemetry_self_error", {"context": "x"}, PRIO.CRITICAL)
	assert_eq(t.get_buffered_count(), 1, "AC-15: in-memory CRITICAL kept for local crash diagnostics")


func test_opt_out_is_enabled_by_default() -> void:
	var t := _make_telemetry()
	assert_true(t.is_telemetry_enabled(), "default is enabled (first-party premium single-player)")
	t._record(&"e", {}, PRIO.STANDARD)
	assert_eq(t.get_buffered_count(), 1, "enabled telemetry buffers a STANDARD event")


# --- AC-3: mid-session toggle is consistent -----------------------------------

func test_opt_out_toggle_mid_session_consistent() -> void:
	var t := _make_telemetry()

	t._record(&"a", {}, PRIO.STANDARD)            # enabled → buffered
	assert_eq(t.get_buffered_count(), 1, "enabled: buffered")

	t.set_telemetry_enabled(false)
	t._record(&"b", {}, PRIO.STANDARD)            # disabled → dropped
	assert_eq(t.get_buffered_count(), 1, "disabled: STANDARD blocked")

	t.set_telemetry_enabled(true)
	t._record(&"c", {}, PRIO.STANDARD)            # re-enabled → buffered
	assert_eq(t.get_buffered_count(), 2, "re-enabled: buffered again (toggle is consistent)")
