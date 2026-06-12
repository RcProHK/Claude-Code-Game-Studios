# Telemetry (#28) — Story 018: Pre-MVP gate data-completeness (AC-22). ADVISORY mission gate.
#
# Drives a representative session through the real telemetry handlers and asserts the
# resulting metric set is sufficient to evaluate BOTH halves of the Pre-MVP PIVOT/KILL
# hypothesis (systems-index L331 "players glance + drop excitement"):
#   upper "glance"          → switch_latency bucket + foreground_ratio + visibility transitions
#   lower "drop excitement" → loot rarity distribution + last_session_max_rarity session stamp
# Also confirms Pillar 2 (telemetry emits zero gameplay signals) and de-id holds (no raw
# body fields in any payload). This is the concrete evidence behind
# production/qa/evidence/telemetry-premvp-data-completeness.md.
extends GutTest

const TelemetryScript := preload("res://src/autoload/telemetry.gd")
const PRIO := TelemetryEvent.Priority

# WorkoutPhase ordinals (workout_state_tracker.gd enum WorkoutPhase) — mirror of the
# telemetry handler's private consts.
const PHASE_SET_ACTIVE := 2
const PHASE_REST_PERIOD := 3
const PHASE_WORKOUT_COMPLETE := 4

# Raw body-data field denylist (mirror of check_telemetry_no_pii.gd) — used to grep the
# captured payloads end-to-end.
const FORBIDDEN_FIELDS: Array[String] = [
	"weight_kg", "bodyweight", "body_weight", "body_mass", "one_rep_max",
	"raw_weight", "absolute_weight", "absolute_1rm", "raw_1rm", "set_weight",
	"kg_lifted", "lbs_lifted", "lift_kg",
]


class MockClock:
	var mono: int = 0
	var unix: int = 1_700_000_000
	func now_monotonic_ms() -> int: return mono
	func now_unix_s() -> int: return unix


class MockPlatform extends Node:
	signal visibility_changed(is_visible: bool)
	func send_beacon(_url: String, _body: String) -> bool: return true
	func is_page_visible() -> bool: return true


## No-op transport so the workout_completed flush trigger does not hit the real HTTPRequest
## (the relative URL is the web-export fetch path — VS-tier-gated; native headless can't
## parse it). This story is about DATA CAPTURE, not transport.
class NoopTransport:
	func dispatch(_url: String, _headers: PackedStringArray, _body: String, _on_response: Callable) -> bool:
		return true   # accepted, never responds → buffer stays intact for inspection


class HitPayload:
	var damage_dealt: int
	var is_crit: bool
	var damage_tier: int
	func _init(d: int, c: bool, t: int) -> void:
		damage_dealt = d; is_crit = c; damage_tier = t


func _names(events: Array) -> Array:
	var out: Array = []
	for e in events:
		out.append(e.event_name)
	return out


func _find(events: Array, name):
	for e in events:
		if e.event_name == name:
			return e
	return null


func test_full_session_covers_both_hypothesis_halves() -> void:
	var clock := MockClock.new()
	var platform := MockPlatform.new()
	add_child_autofree(platform)
	var t = TelemetryScript.new()
	t._clock = clock
	t._platform = platform
	add_child_autofree(t)
	t.set_session_token("tok-session-1")
	t.set_flush_transport(NoopTransport.new())   # don't hit the real HTTPRequest (web-only path)

	# --- representative session -------------------------------------------------
	clock.mono = 1000
	t._on_workout_started()                                  # session_started + workout_started

	# glance: a REST→SET_ACTIVE switch produces a switch_latency bucket event.
	t._on_phase_changed(PHASE_SET_ACTIVE, PHASE_REST_PERIOD) # set the rest anchor
	clock.mono = 1000 + 12000                                # 12s rest → bucket "5–15s"
	t._on_phase_changed(PHASE_REST_PERIOD, PHASE_SET_ACTIVE) # emit switch_latency

	# glance: a visibility round-trip feeds the foreground ratio + transition counting.
	clock.mono += 3000
	platform.visibility_changed.emit(false)                 # hidden (banks foreground span)
	clock.mono += 2000
	platform.visibility_changed.emit(true)                  # visible again

	# combat: a few hits incl. a crit (force-kept individual + lossless aggregate).
	t._on_hit_resolved(HitPayload.new(40, false, 2))
	t._on_hit_resolved(HitPayload.new(90, true, 4))

	# drop excitement: an EPIC loot drop.
	t._on_loot_dropped("drop-1", "EPIC", "sword", "txn-loot-1")

	clock.mono += 1000
	t._on_workout_completed(clock.unix, "txn-workout-1")     # workout_completed (+ flush trigger)

	var events: Array = t._buffer.get_all()
	var names: Array = _names(events)

	# --- UPPER HALF: glance -----------------------------------------------------
	assert_true(names.has(&"switch_latency"), "glance: switch_latency bucket captured")
	var sw = _find(events, &"switch_latency")
	assert_eq(sw.payload["bucket"], 1, "glance: 12s rest → bucket index 1 (5–15s)")
	var ratio: float = t.get_foreground_ratio()
	assert_between(ratio, 0.0, 1.0, "glance: foreground_ratio is a usable [0,1] proxy")
	assert_gt(t._foreground_tracker.total_ms(), 0, "glance: visibility transitions accumulated total time")

	# --- LOWER HALF: drop excitement -------------------------------------------
	assert_true(names.has(&"loot_dropped"), "drop: loot_dropped captured (rarity distribution source)")
	var loot = _find(events, &"loot_dropped")
	assert_eq(loot.payload["rarity_tier"], "EPIC", "drop: rarity tier recorded")
	assert_eq(t._session_max_rarity_ordinal, 3, "drop: session max rarity tracked (EPIC=3)")
	# the session-open stamp: a forced new session carries last_session_max_rarity.
	t._ensure_session(true)
	var sessions: Array = []
	for e in t._buffer.get_all():
		if e.event_name == &"session_started":
			sessions.append(e)
	assert_eq(sessions.size(), 2, "two session_started events (original + forced new)")
	assert_eq(sessions[1].payload["last_session_max_rarity"], 3,
		"drop: last_session_max_rarity session-open stamp = previous session EPIC")

	# --- Pillar 2 + de-id (no PII) end-to-end ----------------------------------
	for e in t._buffer.get_all():
		var blob: String = JSON.stringify(e.payload).to_lower()
		for field: String in FORBIDDEN_FIELDS:
			assert_false(blob.contains(field),
				"de-id: payload of '%s' carries no raw body field '%s'" % [e.event_name, field])
