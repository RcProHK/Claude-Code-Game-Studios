# Telemetry (#28) — Story 008: #9 workout subscription + Rule 11 session lifecycle.
#
# Verifies:
#   AC-1  each of the 7 WST signals → a corresponding buffered telemetry event.
#   AC-2  session lifecycle: workout_started → session_started; workout_completed → flush
#         hook fired with the right reason + payload.
#   AC-3  EC-09 bfcache TTL: within TTL keeps the session; beyond TTL opens a new one.
#   phase_changed feeds the Formula 1 switch-latency tracker (Story 006 wiring).
extends GutTest

const TelemetryScript := preload("res://src/autoload/telemetry.gd")


## Minimal #9 WorkoutStateTracker stand-in: declares the 7 signals telemetry subscribes.
class MockWST extends Node:
	signal workout_started_forwarded()
	signal workout_completed_forwarded(completed_at_unix: int, transition_id: String)
	signal set_progress_changed(progress: float)
	signal dominant_class_changed(dominant_class: int)
	signal phase_changed(from_phase: int, to_phase: int)
	signal workout_summary_available(summary)
	signal bfcache_resumed(was_mid_workout: bool, restored_phase: int)


class MockClock extends RefCounted:
	var mono: int = 0
	var unix: int = 1000
	func now_monotonic_ms() -> int: return mono
	func now_unix_s() -> int: return unix


func _make_telemetry(wst, clock) -> Node:
	var t = TelemetryScript.new()
	t._workout = wst  # inject #9 seam BEFORE _ready (DI override)
	if clock != null:
		t._clock = clock
	add_child_autofree(t)
	return t


func _event_names(events: Array) -> Array:
	var names := []
	for e in events:
		names.append(e.event_name)
	return names


func _find_event(events: Array, name):
	for e in events:
		if e.event_name == name:
			return e
	return null


func _count_event(events: Array, name) -> int:
	var n := 0
	for e in events:
		if e.event_name == name:
			n += 1
	return n


# --- AC-1: all 7 signals produce events ---------------------------------------

func test_all_seven_signals_produce_events() -> void:
	var wst := MockWST.new()
	add_child_autofree(wst)
	var t = _make_telemetry(wst, null)
	wst.workout_started_forwarded.emit()
	wst.set_progress_changed.emit(0.5)
	wst.dominant_class_changed.emit(1)
	wst.phase_changed.emit(1, 2)
	wst.workout_summary_available.emit(null)
	wst.bfcache_resumed.emit(false, 0)
	wst.workout_completed_forwarded.emit(123456, "txn-7")

	var names := _event_names(t._buffer.get_all())
	assert_true(names.has(&"workout_started"), "workout_started event")
	assert_true(names.has(&"set_progress"), "set_progress event")
	assert_true(names.has(&"dominant_class_changed"), "dominant_class_changed event")
	assert_true(names.has(&"phase_changed"), "phase_changed event")
	assert_true(names.has(&"workout_summary"), "workout_summary event")
	assert_true(names.has(&"bfcache_resumed"), "bfcache_resumed event")
	assert_true(names.has(&"workout_completed"), "workout_completed event")


func test_payloads_carry_no_raw_body_data() -> void:
	var wst := MockWST.new()
	add_child_autofree(wst)
	var t = _make_telemetry(wst, null)
	wst.set_progress_changed.emit(0.42)
	var ev = _find_event(t._buffer.get_all(), &"set_progress")
	assert_not_null(ev, "set_progress buffered")
	assert_almost_eq(ev.payload["progress"], 0.42, 0.0001, "normalized ratio kept")
	assert_false(ev.payload.has("kg"), "no raw kg in payload")


# --- AC-2: session lifecycle + flush ------------------------------------------

func test_workout_started_opens_session() -> void:
	var wst := MockWST.new()
	add_child_autofree(wst)
	var t = _make_telemetry(wst, null)
	wst.workout_started_forwarded.emit()
	var names := _event_names(t._buffer.get_all())
	assert_true(names.has(&"session_started"), "session_started on first workout")
	assert_eq(_count_event(t._buffer.get_all(), &"session_started"), 1, "exactly one session start")


func test_workout_completed_triggers_flush() -> void:
	var wst := MockWST.new()
	add_child_autofree(wst)
	var t = _make_telemetry(wst, null)
	var flush_reasons: Array = []
	t._flush_hook = func(reason): flush_reasons.append(reason)
	wst.workout_completed_forwarded.emit(123456, "txn-7")
	assert_eq(flush_reasons.size(), 1, "Rule 6(c): workout_completed triggers flush")
	assert_eq(flush_reasons[0], &"workout_completed", "flush reason is workout_completed")
	var ev = _find_event(t._buffer.get_all(), &"workout_completed")
	assert_eq(ev.payload["completed_at_unix"], 123456, "completed_at passed through")
	assert_eq(ev.payload["transition_id"], "txn-7", "transition_id (String) passed through")


# --- AC-3: EC-09 bfcache TTL --------------------------------------------------

func test_bfcache_within_ttl_keeps_session() -> void:
	var clock := MockClock.new()
	clock.mono = 1000
	var wst := MockWST.new()
	add_child_autofree(wst)
	var t = _make_telemetry(wst, clock)
	wst.workout_started_forwarded.emit()  # activity at mono=1000
	clock.mono = 1000 + 5000  # +5s, well within 30-min TTL
	wst.bfcache_resumed.emit(true, 2)
	var ev = _find_event(t._buffer.get_all(), &"bfcache_resumed")
	assert_eq(ev.payload["session_continued"], true, "within TTL → same session")
	assert_eq(_count_event(t._buffer.get_all(), &"session_started"), 1, "no new session start")


func test_bfcache_beyond_ttl_opens_new_session() -> void:
	var clock := MockClock.new()
	clock.mono = 1000
	var wst := MockWST.new()
	add_child_autofree(wst)
	var t = _make_telemetry(wst, clock)
	wst.workout_started_forwarded.emit()
	clock.mono = 1000 + t.SESSION_RESUME_TTL_MS + 1  # just past TTL
	wst.bfcache_resumed.emit(true, 2)
	var events: Array = t._buffer.get_all()
	var bf = _find_event(events, &"bfcache_resumed")
	assert_eq(bf.payload["session_continued"], false, "beyond TTL → new session")
	assert_eq(_count_event(events, &"session_started"), 2, "new session_started on TTL expiry")


# --- phase_changed → Formula 1 switch-latency ---------------------------------

func test_phase_changed_feeds_switch_latency_tracker() -> void:
	var clock := MockClock.new()
	clock.mono = 100000
	var wst := MockWST.new()
	add_child_autofree(wst)
	var t = _make_telemetry(wst, clock)
	wst.phase_changed.emit(2, 3)  # SET_ACTIVE → REST_PERIOD (sets anchor)
	clock.mono = 112000           # +12s
	wst.phase_changed.emit(3, 2)  # REST_PERIOD → SET_ACTIVE (computes latency)
	var ev = _find_event(t._buffer.get_all(), &"switch_latency")
	assert_not_null(ev, "switch_latency emitted on REST→SET_ACTIVE")
	assert_eq(ev.payload["bucket"], 1, "12s → bucket 1 (5–15s)")


func test_phase_workout_complete_clears_anchor_no_latency() -> void:
	var clock := MockClock.new()
	clock.mono = 100000
	var wst := MockWST.new()
	add_child_autofree(wst)
	var t = _make_telemetry(wst, clock)
	wst.phase_changed.emit(2, 3)  # REST anchor
	wst.phase_changed.emit(3, 4)  # REST_PERIOD → WORKOUT_COMPLETE (edge a: clear, no latency)
	clock.mono = 120000
	wst.phase_changed.emit(4, 2)  # WORKOUT_COMPLETE → SET_ACTIVE: no anchor → no latency
	var ev = _find_event(t._buffer.get_all(), &"switch_latency")
	assert_null(ev, "edge a cleared anchor → no switch_latency event")
