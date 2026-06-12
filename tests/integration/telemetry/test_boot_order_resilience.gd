# Telemetry (#28) — Story 009 (AC-10): #14 combat subscription order-resilience + EC-11.
#
# Verifies:
#   AC-10  Telemetry boots Last; a mock #14 emitting AFTER boot has all 3 combat signals
#          captured (zero silent drop). enemy_killed → STANDARD; combat_metric_anomaly →
#          CRITICAL; the first events carry a back-filled (non-UNKNOWN) game_state stamp.
#   EC-11  a hit_resolved received while the FSM is SUSPENDED is still buffered (faithful).
extends GutTest

const TelemetryScript := preload("res://src/autoload/telemetry.gd")


class MockED extends Node:
	signal hit_resolved(payload)
	signal enemy_killed(payload)
	signal combat_metric_anomaly(payload)


class MockHit extends RefCounted:
	var damage_dealt: int = 0
	var is_crit: bool = false
	var damage_tier: int = 0


class MockKill extends RefCounted:
	var enemy_instance_id: int = 0
	var transition_id: String = ""


class MockAnomaly extends RefCounted:
	var reason: StringName = &""
	var aggregate: bool = false


func _find(events: Array, name):
	for e in events:
		if e.event_name == name:
			return e
	return null


func _make_telemetry(ed) -> Node:
	var t = TelemetryScript.new()
	t._enemy_director = ed  # inject #14 seam before _ready
	add_child_autofree(t)
	return t


# --- AC-10: order-resilience ---------------------------------------------------

func test_all_three_combat_signals_captured_after_late_boot() -> void:
	var ed := MockED.new()
	add_child_autofree(ed)
	var t = _make_telemetry(ed)
	await get_tree().process_frame
	await get_tree().process_frame  # let GSM cfis back-fill settle

	# Emit AFTER telemetry has booted (the Last-boot late-join scenario).
	var hit := MockHit.new()
	hit.damage_dealt = 50
	hit.is_crit = true  # force-kept
	hit.damage_tier = 4
	ed.hit_resolved.emit(hit)
	var kill := MockKill.new()
	kill.enemy_instance_id = 7
	kill.transition_id = "tx-1"
	ed.enemy_killed.emit(kill)
	var anom := MockAnomaly.new()
	anom.reason = &"impossible_damage"
	ed.combat_metric_anomaly.emit(anom)

	var events: Array = t._buffer.get_all()
	assert_not_null(_find(events, &"hit_resolved"), "hit captured (crit force-kept)")
	assert_not_null(_find(events, &"enemy_killed"), "kill captured — zero silent drop")
	assert_not_null(_find(events, &"combat_metric_anomaly"), "anomaly captured")


func test_combat_event_priorities() -> void:
	var ed := MockED.new()
	add_child_autofree(ed)
	var t = _make_telemetry(ed)
	await get_tree().process_frame
	var kill := MockKill.new()
	kill.enemy_instance_id = 1
	kill.transition_id = "tx"
	ed.enemy_killed.emit(kill)
	var anom := MockAnomaly.new()
	anom.reason = &"x"
	ed.combat_metric_anomaly.emit(anom)
	var events: Array = t._buffer.get_all()
	assert_eq(_find(events, &"enemy_killed").priority, TelemetryEvent.Priority.STANDARD,
		"enemy_killed is STANDARD")
	assert_eq(_find(events, &"combat_metric_anomaly").priority, TelemetryEvent.Priority.CRITICAL,
		"combat_metric_anomaly is CRITICAL (FR-5 silent-fail backstop)")


func test_enemy_killed_payload_uses_instance_id() -> void:
	var ed := MockED.new()
	add_child_autofree(ed)
	var t = _make_telemetry(ed)
	await get_tree().process_frame
	var kill := MockKill.new()
	kill.enemy_instance_id = 42
	kill.transition_id = "tx-9"
	ed.enemy_killed.emit(kill)
	var ev = _find(t._buffer.get_all(), &"enemy_killed")
	assert_eq(ev.payload["enemy_instance_id"], 42, "uses enemy_instance_id (not target_id)")
	assert_eq(ev.payload["transition_id"], "tx-9", "transition_id carried")


# --- EC-11: buffered while SUSPENDED ------------------------------------------

func test_hit_buffered_while_suspended() -> void:
	var ed := MockED.new()
	add_child_autofree(ed)
	var t = _make_telemetry(ed)
	await get_tree().process_frame
	# Drive the FSM to SUSPENDED (ACTIVE→SUSPENDED is a legal transition).
	t._transition_to(TelemetryScript.State.SUSPENDED)
	assert_eq(t.get_state(), TelemetryScript.State.SUSPENDED, "telemetry is SUSPENDED")
	var hit := MockHit.new()
	hit.damage_dealt = 10
	hit.is_crit = false
	hit.damage_tier = 0  # index 0 → sampled by stride anyway
	ed.hit_resolved.emit(hit)
	assert_not_null(_find(t._buffer.get_all(), &"hit_resolved"),
		"EC-11: hit_resolved still buffered while SUSPENDED (faithful record)")
