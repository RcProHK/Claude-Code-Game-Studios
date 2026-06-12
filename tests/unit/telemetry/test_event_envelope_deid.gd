# Telemetry (#28) — Story 003: event envelope schema + de-identification.
#
# Verifies:
#   AC-1  _make_event stamps all 8 envelope fields; client_event_id is per-session
#         strictly-monotonic (+1 each call, no reuse); to_dict serializes 8 fields and
#         EXCLUDES priority (buffer metadata).
#   AC-2  de-id: TelemetryDeId.pr_magnitude clamps to [0, 2.0] (non-finite → MIN); a PR
#         event payload carries pr_magnitude + a volume COUNT and NO raw kg / 1RM / bodyweight.
#   AC-3  monotonic (ordering) vs wall (absolute) stamps are independent — a +3600s wall
#         jump does not perturb the monotonic delta (EC-07 foundation).
#   Drift guard: _GAME_STATE_NAMES mirrors GSM `enum GameState` exactly (size + per-ordinal).
extends GutTest

const TelemetryScript := preload("res://src/autoload/telemetry.gd")
const GSMScript := preload("res://src/autoload/game_state_machine.gd")

const COMBAT_ACTIVE: int = 5  # GSM GameState ordinal


## Controllable clock seam: now_unix_s + now_monotonic_ms (envelope timestamps).
class MockClock extends RefCounted:
	var unix_s: int = 1000
	var mono_ms: int = 5000
	func now_unix_s() -> int: return unix_s
	func now_monotonic_ms() -> int: return mono_ms


# --- AC-1: envelope fields + monotonic id -------------------------------------

func test_envelope_has_eight_fields_and_monotonic_event_id() -> void:
	var t = TelemetryScript.new()
	t.set_session_id("sess-abc")
	t._clock = MockClock.new()

	var ev1 = t._make_event(&"hit_resolved", {"damage_tier": 2}, TelemetryEvent.Priority.LOW)
	var ev2 = t._make_event(&"enemy_killed", {}, TelemetryEvent.Priority.STANDARD)

	assert_eq(ev1.event_name, &"hit_resolved", "event_name stamped")
	assert_eq(ev1.schema_version, 1, "default schema_version")
	assert_eq(ev1.client_event_id, 1, "first client_event_id is 1")
	assert_eq(ev1.session_id, "sess-abc", "session_id from set_session_id")
	assert_eq(ev1.client_ts_unix, 1000, "wall stamp from clock")
	assert_eq(ev1.client_ts_monotonic_ms, 5000, "monotonic stamp from clock")
	assert_eq(ev1.payload, {"damage_tier": 2}, "payload passed through")
	assert_eq(ev2.client_event_id, 2, "client_event_id strictly +1, no reuse")
	t.free()


func test_client_event_id_strictly_increasing_over_n() -> void:
	var t = TelemetryScript.new()
	var seen := {}
	var last := 0
	for i in range(50):
		var ev = t._make_event(&"e", {}, TelemetryEvent.Priority.LOW)
		assert_eq(ev.client_event_id, last + 1, "id strictly +1 at step %d" % i)
		assert_false(seen.has(ev.client_event_id), "no duplicate id")
		seen[ev.client_event_id] = true
		last = ev.client_event_id
	t.free()


func test_to_dict_has_eight_keys_priority_excluded() -> void:
	var t = TelemetryScript.new()
	var ev = t._make_event(&"z", {"a": 1}, TelemetryEvent.Priority.CRITICAL)
	var d = ev.to_dict()
	var expected := ["event_name", "schema_version", "client_event_id", "session_id",
		"client_ts_unix", "client_ts_monotonic_ms", "game_state", "payload"]
	assert_eq(d.size(), 8, "on-wire envelope has exactly 8 fields")
	for k in expected:
		assert_true(d.has(k), "to_dict has '%s'" % k)
	assert_false(d.has("priority"), "priority is buffer metadata — NOT serialized on-wire")
	t.free()


# --- AC-2: de-identification ---------------------------------------------------

func test_pr_magnitude_clamps_to_unit_range() -> void:
	assert_almost_eq(TelemetryDeId.pr_magnitude(1.5), 1.5, 0.0001, "in-range passthrough")
	assert_eq(TelemetryDeId.pr_magnitude(3.0), 2.0, "clamped to MAX 2.0")
	assert_eq(TelemetryDeId.pr_magnitude(-1.0), 0.0, "clamped to MIN 0.0")
	assert_eq(TelemetryDeId.pr_magnitude(INF), 0.0, "non-finite → MIN (defensive)")
	assert_eq(TelemetryDeId.pr_magnitude(NAN), 0.0, "NaN → MIN (defensive)")


func test_volume_recorded_as_exercise_count_not_kg() -> void:
	assert_eq(TelemetryDeId.volume_exercise_count(8), 8, "count passthrough")
	assert_eq(TelemetryDeId.volume_exercise_count(-3), 0, "negative floored to 0")


func test_pr_event_payload_carries_no_raw_body_data() -> void:
	var t = TelemetryScript.new()
	var payload := {
		"pr_magnitude": TelemetryDeId.pr_magnitude(1.2),
		"volume": TelemetryDeId.volume_exercise_count(8),
	}
	var ev = t._make_event(&"pr_achieved", payload, TelemetryEvent.Priority.STANDARD)
	assert_true(ev.payload["pr_magnitude"] >= 0.0 and ev.payload["pr_magnitude"] <= 2.0,
		"AC-2: pr_magnitude ∈ [0, 2.0]")
	assert_almost_eq(ev.payload["pr_magnitude"], 1.2, 0.0001, "normalized magnitude kept")
	assert_eq(ev.payload["volume"], 8, "volume is a count")
	assert_false(ev.payload.has("kg"), "AC-2: no raw kg")
	assert_false(ev.payload.has("weight_kg"), "AC-2: no absolute weight")
	assert_false(ev.payload.has("one_rep_max_kg"), "AC-2: no absolute 1RM")
	assert_false(ev.payload.has("bodyweight"), "AC-2: no bodyweight")
	t.free()


# --- AC-3: monotonic vs wall-clock stamps -------------------------------------

func test_monotonic_and_wall_stamps_are_independent() -> void:
	var t = TelemetryScript.new()
	var clock = MockClock.new()
	t._clock = clock
	clock.unix_s = 1000
	clock.mono_ms = 5000
	var ev1 = t._make_event(&"a", {}, TelemetryEvent.Priority.LOW)
	# Wall-clock jumps +3600s (NTP correction / device sleep); monotonic advances 50ms.
	clock.unix_s = 1000 + 3600
	clock.mono_ms = 5050
	var ev2 = t._make_event(&"b", {}, TelemetryEvent.Priority.LOW)
	assert_gt(ev2.client_ts_monotonic_ms, ev1.client_ts_monotonic_ms, "monotonic strictly increases")
	assert_eq(ev2.client_ts_monotonic_ms - ev1.client_ts_monotonic_ms, 50,
		"AC-3: monotonic delta independent of the wall jump")
	assert_eq(ev2.client_ts_unix - ev1.client_ts_unix, 3600, "AC-3: wall reflects the +3600s jump")
	t.free()


# --- game_state stamping + GSM enum drift guard -------------------------------

func test_envelope_stamps_game_state_name() -> void:
	var t = TelemetryScript.new()
	var ev0 = t._make_event(&"x", {}, TelemetryEvent.Priority.LOW)
	assert_eq(ev0.game_state, &"UNKNOWN", "sentinel (no back-fill) → UNKNOWN")
	t._current_game_state = COMBAT_ACTIVE
	var ev1 = t._make_event(&"y", {}, TelemetryEvent.Priority.LOW)
	assert_eq(ev1.game_state, &"COMBAT_ACTIVE", "back-filled ordinal → enum name")
	t.free()


func test_game_state_names_mirror_gsm_enum() -> void:
	# Drift guard: a GSM GameState renumber/rename must fail HERE rather than silently
	# mis-stamping the envelope.
	var gsm_keys = GSMScript.GameState.keys()
	var tel_names = TelemetryScript._GAME_STATE_NAMES
	assert_eq(tel_names.size(), gsm_keys.size(),
		"_GAME_STATE_NAMES must mirror GSM GameState enum size")
	for i in range(gsm_keys.size()):
		assert_eq(String(tel_names[i]), String(gsm_keys[i]),
			"ordinal %d: telemetry name must equal GSM enum key '%s'" % [i, gsm_keys[i]])
