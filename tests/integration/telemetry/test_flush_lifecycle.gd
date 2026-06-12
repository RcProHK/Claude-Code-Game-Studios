# Telemetry (#28) — Story 011: flush model async batch POST (ADR-0012). AC-09.
#
# Verifies (with an injected mock transport — the real HTTPRequest is VS-tier-gated):
#   - remove-on-ACK: a 200 clears exactly the in-flight batch (EC-12 by-id).
#   - single in-flight: a second flush is skipped while one is in-flight (events stay).
#   - 401 keeps the buffer and does NOT force-boot (the key divergence from #2).
#   - 5xx / dispatch-failure keep the buffer + arm Formula 5 backoff.
#   - 429 honours Retry-After.
#   - pre-session (no token) and opt-out keep events buffered, dispatch nothing.
#   - X-Session-Token header + relative endpoint on the wire.
extends GutTest

const TelemetryScript := preload("res://src/autoload/telemetry.gd")
const PRIO := TelemetryEvent.Priority


## Records dispatches; responds either immediately (auto_code >= 0) or on demand.
class MockTransport:
	var calls: Array = []
	var dispatch_returns: bool = true
	var auto_code: int = -1   # -1 = manual (call respond_last); >=0 = respond inline

	func dispatch(url: String, headers: PackedStringArray, body: String, on_response: Callable) -> bool:
		calls.append({"url": url, "headers": headers, "body": body, "cb": on_response})
		if not dispatch_returns:
			return false
		if auto_code >= 0:
			on_response.call(auto_code, 0)
		return true

	func respond_last(code: int, retry_after: int = 0) -> void:
		(calls[-1]["cb"] as Callable).call(code, retry_after)


func _make(token: String = "tok-1") -> Node:
	var t = TelemetryScript.new()
	add_child_autofree(t)
	t.set_session_token(token)
	return t


func _seed(t, n: int, prio: int = PRIO.STANDARD) -> void:
	for i in range(n):
		t._record(&"evt", {}, prio)


# --- remove-on-ACK + wire format ----------------------------------------------

func test_200_removes_in_flight_batch() -> void:
	var S := TelemetryScript.State
	var tx := MockTransport.new()
	var t := _make()
	t.set_flush_transport(tx)
	_seed(t, 3)
	assert_eq(t.get_buffered_count(), 3, "3 events buffered")
	assert_true(t._flush_now(&"test"), "flush dispatched")
	assert_eq(tx.calls.size(), 1, "one dispatch")
	assert_eq(t.get_state(), S.FLUSHING, "in-flight → FLUSHING (manual transport)")
	# wire format: relative endpoint + X-Session-Token header
	assert_eq(tx.calls[0]["url"], "/api/game/telemetry", "relative main endpoint")
	var has_token := false
	for h in tx.calls[0]["headers"]:
		if h == "X-Session-Token: tok-1":
			has_token = true
	assert_true(has_token, "X-Session-Token header present")
	tx.respond_last(200)
	assert_eq(t.get_buffered_count(), 0, "AC-09: 200 ACK removes the in-flight batch")
	assert_eq(t.get_state(), S.ACTIVE, "FLUSHING → ACTIVE after ACK")


func test_single_in_flight_skips_second_flush() -> void:
	var tx := MockTransport.new()
	var t := _make()
	t.set_flush_transport(tx)
	_seed(t, 3)
	assert_true(t._flush_now(&"first"), "first flush dispatched")
	_seed(t, 1)   # a new event arrives mid-flight
	assert_false(t._flush_now(&"second"), "second flush skipped while in-flight")
	assert_eq(tx.calls.size(), 1, "still only one dispatch")
	tx.respond_last(200)
	assert_eq(t.get_buffered_count(), 1, "the mid-flight event survives (not in the acked batch)")


# --- 401: keep buffer, NO force-boot (the key divergence) ---------------------

func test_401_keeps_buffer_no_force_boot() -> void:
	var S := TelemetryScript.State
	var tx := MockTransport.new()
	var t := _make()
	t.set_flush_transport(tx)
	_seed(t, 3)
	t._flush_now(&"test")
	tx.respond_last(401)
	assert_eq(t.get_buffered_count(), 3, "ADR-0012 §3: 401 keeps the buffer")
	assert_eq(t.get_state(), S.ACTIVE, "401 returns to ACTIVE — telemetry never force-boots gameplay")
	assert_eq(t._flush_failure_count, 0, "401 does not escalate Formula 5 backoff (transient auth)")


# --- 5xx / dispatch failure: keep buffer + backoff ----------------------------

func test_5xx_keeps_buffer_and_arms_backoff() -> void:
	var tx := MockTransport.new()
	var t := _make()
	t.set_flush_transport(tx)
	_seed(t, 3)
	t._flush_now(&"test")
	tx.respond_last(503)
	assert_eq(t.get_buffered_count(), 3, "AC-09: 5xx keeps the buffer")
	assert_eq(t._flush_failure_count, 1, "failure counted")
	assert_gt(t._backoff_until_ms, 0, "Formula 5 backoff armed")
	assert_false(t._flush_now(&"retry"), "a retry inside the backoff window is suppressed")


func test_429_honours_retry_after() -> void:
	var tx := MockTransport.new()
	var t := _make()
	t.set_flush_transport(tx)
	_seed(t, 2)
	var before: int = t._now_monotonic_ms()
	t._flush_now(&"test")
	tx.respond_last(429, 5)   # Retry-After: 5s
	assert_eq(t.get_buffered_count(), 2, "429 keeps the buffer")
	assert_almost_eq(t._backoff_until_ms - before, 5000, 50, "429 backoff ≈ Retry-After (5s)")


func test_dispatch_failure_keeps_buffer_and_backoff() -> void:
	var S := TelemetryScript.State
	var tx := MockTransport.new()
	tx.dispatch_returns = false
	var t := _make()
	t.set_flush_transport(tx)
	_seed(t, 3)
	assert_false(t._flush_now(&"test"), "dispatch could not start → false")
	assert_eq(t.get_buffered_count(), 3, "buffer kept on dispatch failure")
	assert_eq(t.get_state(), S.ACTIVE, "returns to ACTIVE (never stuck in FLUSHING)")
	assert_eq(t._flush_failure_count, 1, "dispatch failure counted for backoff")


# --- EC-12: late ACK for an already-evicted batch is a no-op ------------------

func test_ec12_late_ack_for_evicted_batch_is_noop() -> void:
	var tx := MockTransport.new()
	var t := _make()
	t.set_flush_transport(tx)
	_seed(t, 3)
	t._flush_now(&"test")
	# Simulate overflow eviction of the in-flight events before the ACK arrives.
	t._buffer.remove_by_event_ids(t._in_flight_ids.duplicate())
	assert_eq(t.get_buffered_count(), 0, "events evicted while in-flight")
	tx.respond_last(200)   # late ACK → remove_by_event_ids finds nothing
	assert_eq(t.get_buffered_count(), 0, "EC-12: late ACK is a no-op, no corruption")


# --- pre-session + opt-out gates ----------------------------------------------

func test_pre_session_no_token_keeps_buffered() -> void:
	var tx := MockTransport.new()
	var t := _make("")   # no session token yet
	t.set_flush_transport(tx)
	_seed(t, 3)
	assert_false(t._flush_now(&"test"), "no token → flush skipped (pre-session)")
	assert_eq(tx.calls.size(), 0, "nothing dispatched without a token")
	assert_eq(t.get_buffered_count(), 3, "events stay buffered until a token arrives")
	t.set_session_token("tok-late")
	assert_true(t._flush_now(&"test"), "flush dispatches once the token is available")


func test_opt_out_blocks_flush_dispatch() -> void:
	var tx := MockTransport.new()
	var t := _make()
	t.set_flush_transport(tx)
	t.set_telemetry_enabled(false)
	t._record(&"crit", {}, PRIO.CRITICAL)   # only CRITICAL is retained under opt-out
	assert_false(t._flush_now(&"test"), "opt-out → no flush")
	assert_eq(tx.calls.size(), 0, "opt-out dispatches nothing (zero bytes leave the device)")
