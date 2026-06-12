# Telemetry (#28) — Story 010: #15 loot subscription + drop-euphoria proxy (Rule 10).
#
# Verifies:
#   AC-1  loot_dropped → STANDARD event, frozen loot_dropped_v1 (EXACTLY 4 payload fields);
#         rarity is the de-id enum string; multiple drops aggregate.
#   AC-2  loot_ceremony_capped → CRITICAL; loot_drop_unbound → STANDARD audit (EC-14).
#   Rule 10  the previous session's max rarity is stamped onto the next session_started.
extends GutTest

const TelemetryScript := preload("res://src/autoload/telemetry.gd")


## Minimal #15 stand-in: the loot signals telemetry subscribes (incl. loot_drop_unbound,
## which #15 does not yet emit but telemetry's handler is ready for — Story 010 erratum).
class MockLoot extends Node:
	signal loot_dropped(drop_id: String, rarity_tier: String, item_type: String, transition_id: String)
	signal loot_ceremony_capped(workout_id: String, capped_kill_count: int)
	signal loot_pending_recovered(drop_id: String, source_event_kind: String)
	signal loot_drop_unbound(transition_id: String, reason: String)


func _make_telemetry(loot) -> Node:
	var t = TelemetryScript.new()
	t._loot = loot  # inject #15 seam before _ready
	add_child_autofree(t)
	return t


func _find(events: Array, name):
	for e in events:
		if e.event_name == name:
			return e
	return null


func _count(events: Array, name) -> int:
	var n := 0
	for e in events:
		if e.event_name == name:
			n += 1
	return n


# --- AC-1: loot_dropped frozen v1 + rarity --------------------------------------

func test_loot_dropped_is_standard_with_four_fields() -> void:
	var loot := MockLoot.new()
	add_child_autofree(loot)
	var t = _make_telemetry(loot)
	await get_tree().process_frame
	loot.loot_dropped.emit("d1", "RARE", "sword", "tx-1")
	var ev = _find(t._buffer.get_all(), &"loot_dropped")
	assert_not_null(ev, "loot_dropped buffered")
	assert_eq(ev.priority, TelemetryEvent.Priority.STANDARD, "loot_dropped is STANDARD")
	assert_eq(ev.payload.size(), 4, "frozen loot_dropped_v1 = exactly 4 fields")
	assert_eq(ev.payload["drop_id"], "d1")
	assert_eq(ev.payload["rarity_tier"], "RARE", "rarity is de-id enum string")
	assert_eq(ev.payload["item_type"], "sword")
	assert_eq(ev.payload["transition_id"], "tx-1")
	assert_eq(ev.schema_version, 1, "schema_version 1 = loot_dropped_v1")


func test_multiple_drops_aggregate() -> void:
	var loot := MockLoot.new()
	add_child_autofree(loot)
	var t = _make_telemetry(loot)
	await get_tree().process_frame
	loot.loot_dropped.emit("d1", "COMMON", "potion", "tx-1")
	loot.loot_dropped.emit("d2", "EPIC", "shield", "tx-2")
	assert_eq(_count(t._buffer.get_all(), &"loot_dropped"), 2, "two drop events recorded")


# --- AC-2: anomaly priorities -------------------------------------------------

func test_ceremony_capped_is_critical() -> void:
	var loot := MockLoot.new()
	add_child_autofree(loot)
	var t = _make_telemetry(loot)
	await get_tree().process_frame
	loot.loot_ceremony_capped.emit("w1", 3)
	var ev = _find(t._buffer.get_all(), &"loot_ceremony_capped")
	assert_not_null(ev, "ceremony_capped buffered")
	assert_eq(ev.priority, TelemetryEvent.Priority.CRITICAL, "loot anomaly is CRITICAL")
	assert_eq(ev.payload["capped_kill_count"], 3, "kill count carried")


func test_pending_recovered_and_drop_unbound_are_standard() -> void:
	var loot := MockLoot.new()
	add_child_autofree(loot)
	var t = _make_telemetry(loot)
	await get_tree().process_frame
	loot.loot_pending_recovered.emit("d9", "boss_kill")
	loot.loot_drop_unbound.emit("tx-7", "no_active_workout")
	var pr = _find(t._buffer.get_all(), &"loot_pending_recovered")
	assert_eq(pr.priority, TelemetryEvent.Priority.STANDARD, "pending_recovered STANDARD")
	var ub = _find(t._buffer.get_all(), &"loot_drop_unbound")
	assert_not_null(ub, "drop_unbound buffered (EC-14 audit)")
	assert_eq(ub.priority, TelemetryEvent.Priority.STANDARD, "drop_unbound STANDARD (not error)")


# --- Rule 10: session max rarity context --------------------------------------

func test_previous_session_max_rarity_stamped_on_new_session() -> void:
	var loot := MockLoot.new()
	add_child_autofree(loot)
	var t = _make_telemetry(loot)
	await get_tree().process_frame
	# Session 1: open + drops up to EPIC (ordinal 3).
	t._ensure_session(false)
	loot.loot_dropped.emit("d1", "COMMON", "x", "tx-1")
	loot.loot_dropped.emit("d2", "EPIC", "y", "tx-2")
	loot.loot_dropped.emit("d3", "RARE", "z", "tx-3")
	# Session 2: forced new → should stamp the prior session max (EPIC=3).
	t._ensure_session(true)
	var sessions: Array = []
	for e in t._buffer.get_all():
		if e.event_name == &"session_started":
			sessions.append(e)
	assert_gte(sessions.size(), 2, "two session_started events")
	var last = sessions[sessions.size() - 1]
	assert_eq(last.payload["last_session_max_rarity"], 3,
		"Rule 10: new session stamps previous session max rarity (EPIC=3)")
