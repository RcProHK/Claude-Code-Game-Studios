# GymSysBackendClient — Autoload position 4 (#2)
#
# Driving GDD: design/gdd/gymsys-backend-client.md (Approved 2026-05-26)
# Governing ADRs: ADR-0002 GymSys Integration Protocol, ADR-0004 CORS Topology
#
# Option B (post-workout reaction) client — polls GYM's read-only `/api/game/feed?since=<cursor>`
# (added 2026-06-13, GYM main.py) and REPLAYS each newly-saved completed workout as the locked
# ADR-0002 signal stream that WorkoutStateTracker (#9) consumes:
#   workout_started → set_logged(exercise_id, reps, weight) ×N → workout_completed(saved_at)
# (rest_started/rest_ended are not present in a completed-workout feed — Option B; live per-set
# events are the Phase-2 Option-A path, see docs/gymsys-integration-plan.md.)
#
# Transport is configured-then-polls: production boots IDLE (no base_url) so it never reaches a
# non-existent backend — `configure()` starts polling once GYM is reachable. The empirical HTTP +
# auth + CORS round-trip stays VS-tier-gated (ADR-0002/0004); the feed→signal translation core
# (`_process_feed`) is pure and unit-tested.
extends Node

# ── ADR-0002 locked signals (must match WST._connect_gym_sys_signals) ──────────
signal workout_started()
signal set_logged(exercise_id: StringName, reps: int, weight: float)
signal rest_started(duration_seconds: int)
signal rest_ended()
signal workout_completed(completed_at: int)
signal poll_failed(category: StringName)
signal poll_recovered()

const FEED_PATH: String = "/api/game/feed"
const DEFAULT_POLL_SEC: float = 5.0
const JITTER_SEC: float = 0.5            ## ADR-0002 5s ±0.5s

var _cursor: int = 0                      ## differential cursor = max workout _savedAt (ms) seen
var _base_url: String = ""                ## e.g. "https://host:port" (relative when same-origin web)
var _session_cookie: String = ""          ## GYM session cookie (auth); empty = none
var _http: HTTPRequest = null
var _poll_timer: Timer = null
var _was_failing: bool = false
var _polling: bool = false


func _ready() -> void:
	# IDLE until configure() — production has no live backend yet (ADR-0002 VS-tier).
	pass


## Wire the client to a reachable GYM and start polling. Until called, the client is inert.
func configure(base_url: String, session_cookie: String = "", poll_interval: float = DEFAULT_POLL_SEC) -> void:
	_base_url = base_url.rstrip("/")
	_session_cookie = session_cookie
	if _http == null:
		_http = HTTPRequest.new()
		add_child(_http)
		_http.request_completed.connect(_on_request_completed)
	if _poll_timer == null:
		_poll_timer = Timer.new()
		_poll_timer.one_shot = false
		add_child(_poll_timer)
		_poll_timer.timeout.connect(_poll)
	_poll_timer.wait_time = poll_interval + randf_range(-JITTER_SEC, JITTER_SEC)
	_poll_timer.start()
	_polling = true
	_poll()


func get_cursor() -> int:
	return _cursor


# ── Polling (real HTTP — VS-tier transport) ───────────────────────────────────
func _poll() -> void:
	if not _polling or _http == null or _base_url.is_empty():
		return
	var headers: PackedStringArray = []
	if not _session_cookie.is_empty():
		headers.append("Cookie: " + _session_cookie)
	var url: String = "%s%s?since=%d" % [_base_url, FEED_PATH, _cursor]
	var err: int = _http.request(url, headers)
	if err != OK:
		_register_poll_failure(&"request_error")


func _on_request_completed(result: int, code: int, _headers: PackedStringArray, body: PackedByteArray) -> void:
	if result != HTTPRequest.RESULT_SUCCESS or code != 200:
		_register_poll_failure(&"http_%d" % code if result == HTTPRequest.RESULT_SUCCESS else &"transport")
		return
	var parsed: Variant = JSON.parse_string(body.get_string_from_utf8())
	if typeof(parsed) != TYPE_DICTIONARY:
		_register_poll_failure(&"bad_payload")
		return
	if _was_failing:
		_was_failing = false
		poll_recovered.emit()
	_process_feed(parsed)


func _register_poll_failure(category: StringName) -> void:
	if not _was_failing:
		_was_failing = true
		poll_failed.emit(category)


# ── Feed → signal translation (pure core — unit tested) ────────────────────────
## Replays each completed workout in `feed.workouts` (server-sorted ascending by saved_at)
## as workout_started → set_logged×N → workout_completed, then advances the cursor.
## Idempotent across polls: GYM excludes workouts with _savedAt <= since, so a workout is
## replayed at most once.
func _process_feed(feed: Dictionary) -> void:
	var workouts: Array = feed.get("workouts", [])
	for w: Variant in workouts:
		if typeof(w) != TYPE_DICTIONARY:
			continue
		workout_started.emit()
		for ex: Variant in (w as Dictionary).get("exercises", []):
			if typeof(ex) != TYPE_DICTIONARY:
				continue
			var eid := StringName((ex as Dictionary).get("exercise_id", ""))
			for s: Variant in (ex as Dictionary).get("sets", []):
				if typeof(s) != TYPE_DICTIONARY:
					continue
				var sd := s as Dictionary
				set_logged.emit(eid, int(sd.get("reps", 0)), float(sd.get("weight", 0.0)))
		workout_completed.emit(int((w as Dictionary).get("saved_at", 0)))
	# advance cursor to the server-reported high-water mark (falls back to current)
	_cursor = int(feed.get("cursor", _cursor))
