# Telemetry (#28) — Story 012: page-hide best-effort beacon (ADR-0012 §4). AC-13 / EC-18.
#
# Verifies (with a mock platform_detect — real sendBeacon is VS-tier-gated):
#   - visibilitychange→hidden triggers ONE best-effort beacon to the beacon endpoint with
#     the token IN BODY (sendBeacon cannot set headers), and steps ACTIVE → SUSPENDED.
#   - EC-18: send_beacon false (unavailable / non-Web) → synchronous XHR fallback.
#   - returning to visible resumes SUSPENDED → ACTIVE.
extends GutTest

const TelemetryScript := preload("res://src/autoload/telemetry.gd")
const PRIO := TelemetryEvent.Priority


## platform_detect stand-in: the visibility signal + the two page-hide flush seams.
class MockPlatform extends Node:
	signal visibility_changed(is_visible: bool)
	var beacon_calls: Array = []
	var xhr_calls: Array = []
	var beacon_returns: bool = true

	func send_beacon(url: String, body: String) -> bool:
		beacon_calls.append({"url": url, "body": body})
		return beacon_returns

	func send_sync_xhr(url: String, body: String) -> bool:
		xhr_calls.append({"url": url, "body": body})
		return true

	func is_page_visible() -> bool:
		return true


func _make(platform) -> Node:
	var t = TelemetryScript.new()
	t._platform = platform   # inject BEFORE _ready so _subscribe_upstream connects the signal
	add_child_autofree(t)
	t.set_session_token("tok-9")
	return t


func _seed(t, n: int) -> void:
	for i in range(n):
		t._record(&"evt", {}, PRIO.STANDARD)


# --- AC-13: hidden → beacon (token-in-body) + SUSPENDED -----------------------

func test_hidden_triggers_beacon_token_in_body() -> void:
	var S := TelemetryScript.State
	var p := MockPlatform.new()
	add_child_autofree(p)
	var t := _make(p)
	_seed(t, 2)
	p.visibility_changed.emit(false)
	assert_eq(p.beacon_calls.size(), 1, "AC-13: hidden fires one best-effort beacon")
	assert_eq(p.beacon_calls[0]["url"], "/api/game/telemetry/beacon", "separate beacon endpoint")
	var parsed: Dictionary = JSON.parse_string(p.beacon_calls[0]["body"])
	assert_eq(parsed.get("session_token"), "tok-9", "token-in-body (sendBeacon has no headers)")
	assert_eq((parsed.get("events") as Array).size(), 2, "the buffered events are in the beacon batch")
	assert_eq(t.get_state(), S.SUSPENDED, "page-hide steps ACTIVE → SUSPENDED")


func test_send_beacon_false_falls_back_to_xhr() -> void:
	var p := MockPlatform.new()
	p.beacon_returns = false   # sendBeacon unavailable
	add_child_autofree(p)
	var t := _make(p)
	_seed(t, 1)
	p.visibility_changed.emit(false)
	assert_eq(p.beacon_calls.size(), 1, "beacon attempted")
	assert_eq(p.xhr_calls.size(), 1, "EC-18: false → synchronous XHR fallback")
	assert_eq(p.xhr_calls[0]["url"], "/api/game/telemetry/beacon", "fallback hits the same beacon endpoint")


func test_visible_resumes_active() -> void:
	var S := TelemetryScript.State
	var p := MockPlatform.new()
	add_child_autofree(p)
	var t := _make(p)
	_seed(t, 1)
	p.visibility_changed.emit(false)
	assert_eq(t.get_state(), S.SUSPENDED, "hidden → SUSPENDED")
	p.visibility_changed.emit(true)
	assert_eq(t.get_state(), S.ACTIVE, "visible → ACTIVE (resume)")


func test_hidden_empty_buffer_no_beacon_still_suspends() -> void:
	var S := TelemetryScript.State
	var p := MockPlatform.new()
	add_child_autofree(p)
	var t := _make(p)
	# no events buffered
	p.visibility_changed.emit(false)
	assert_eq(p.beacon_calls.size(), 0, "empty buffer → nothing to beacon")
	assert_eq(t.get_state(), S.SUSPENDED, "page-hide suspends regardless of buffer contents")


func test_opt_out_suppresses_beacon() -> void:
	var p := MockPlatform.new()
	add_child_autofree(p)
	var t := _make(p)
	t.set_telemetry_enabled(false)
	t._record(&"crit", {}, PRIO.CRITICAL)
	p.visibility_changed.emit(false)
	assert_eq(p.beacon_calls.size(), 0, "opt-out → no beacon (zero bytes leave the device)")
	assert_eq(p.xhr_calls.size(), 0, "opt-out → no XHR fallback either")
