# Telemetry (#28) — Story 009 (AC-12): Rule 15 recursion guard + combat handler logic.
#
# Verifies:
#   AC-12  combat_metric_anomaly → ONE CRITICAL event; a re-entrant anomaly is suppressed
#          into the diagnostic channel (telemetry_self_error LOW), NEVER re-emitting
#          combat_metric_anomaly (no recursion, #13 EC-49); telemetry has no anomaly signal.
#   hit_resolved → lossless Formula 4 aggregate (every hit) + Formula 3 sampling (stride);
#          crit force-kept at a non-stride index (AC-06).
#
# Unit-style: direct handler calls on a non-added Telemetry with manually-built buffer /
# aggregate (no tree needed — pure sink logic).
extends GutTest

const TelemetryScript := preload("res://src/autoload/telemetry.gd")


class MockHit extends RefCounted:
	var damage_dealt: int = 0
	var is_crit: bool = false
	var damage_tier: int = 0


class MockAnomaly extends RefCounted:
	var reason: StringName = &""
	var aggregate: bool = false


func _make_bare_telemetry() -> Node:
	var t = TelemetryScript.new()
	t._buffer = TelemetryBuffer.new(1000, 100)
	t._combat_aggregate = CombatAggregate.new()
	return t


func _count(events: Array, name) -> int:
	var n := 0
	for e in events:
		if e.event_name == name:
			n += 1
	return n


# --- AC-12: recursion guard ---------------------------------------------------

func test_anomaly_records_one_critical_event() -> void:
	var t = _make_bare_telemetry()
	var anom := MockAnomaly.new()
	anom.reason = &"impossible_damage"
	t._on_combat_metric_anomaly(anom)
	var events: Array = t._buffer.get_all()
	assert_eq(_count(events, &"combat_metric_anomaly"), 1, "one anomaly event")
	var ev = events[0]
	assert_eq(ev.priority, TelemetryEvent.Priority.CRITICAL, "anomaly is CRITICAL")
	assert_eq(ev.payload["reason"], &"impossible_damage", "reason carried")
	t.free()


func test_telemetry_has_no_anomaly_signal_to_re_emit() -> void:
	# G-TEL-2 structural guarantee: telemetry declares no combat_metric_anomaly signal, so
	# it physically cannot recurse back into #14.
	var t = TelemetryScript.new()
	assert_false(t.has_signal("combat_metric_anomaly"),
		"telemetry has no combat_metric_anomaly signal (cannot recurse)")
	t.free()


func test_reentrant_anomaly_suppressed_to_diagnostic() -> void:
	var t = _make_bare_telemetry()
	t._in_anomaly_handler = true  # simulate being mid-anomaly (re-entrancy)
	var anom := MockAnomaly.new()
	anom.reason = &"nested"
	t._on_combat_metric_anomaly(anom)
	var events: Array = t._buffer.get_all()
	assert_eq(_count(events, &"combat_metric_anomaly"), 0, "re-entrant anomaly suppressed")
	assert_eq(_count(events, &"telemetry_self_error"), 1, "self-error to diagnostic channel")
	t.free()


func test_self_error_is_low_diagnostic() -> void:
	var t = _make_bare_telemetry()
	t._record_self_error("serialize failed")
	var events: Array = t._buffer.get_all()
	assert_eq(events.size(), 1, "one diagnostic event")
	assert_eq(events[0].event_name, &"telemetry_self_error", "diagnostic channel")
	assert_eq(events[0].priority, TelemetryEvent.Priority.LOW, "self_error is LOW meta")
	assert_eq(events[0].payload["context"], "serialize failed", "context carried")
	t.free()


# --- hit_resolved sampling + lossless aggregate --------------------------------

func test_hit_aggregate_lossless_and_sampled() -> void:
	var t = _make_bare_telemetry()
	for i in range(25):
		var h := MockHit.new()
		h.damage_dealt = 10
		h.is_crit = false
		h.damage_tier = 1
		t._on_hit_resolved(h)
	var agg: Dictionary = t.get_combat_aggregate_dict()
	assert_eq(agg["total_hits"], 25, "AC-07: all 25 hits aggregated (lossless)")
	assert_eq(agg["total_damage"], 250, "total damage summed")
	# stride 10 → individual events at index 0, 10, 20 → 3 kept.
	var events: Array = t._buffer.get_all()
	assert_eq(_count(events, &"hit_resolved"), 3, "stride 10 → 3 individual events")
	t.free()


func test_crit_hit_force_kept_at_non_stride_index() -> void:
	var t = _make_bare_telemetry()
	# indices 0..4 non-crit (index 0 sampled by stride); index 5 crit (force-kept).
	for i in range(5):
		var h := MockHit.new()
		h.damage_dealt = 5
		h.is_crit = false
		h.damage_tier = 1
		t._on_hit_resolved(h)
	var crit := MockHit.new()
	crit.damage_dealt = 99
	crit.is_crit = true
	crit.damage_tier = 4
	t._on_hit_resolved(crit)
	var events: Array = t._buffer.get_all()
	assert_eq(_count(events, &"hit_resolved"), 2,
		"AC-06: index 0 (stride) + index 5 (crit force-kept) = 2 individual events")
	t.free()
