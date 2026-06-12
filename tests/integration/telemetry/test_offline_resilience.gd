# Telemetry (#28) — Story 011: offline resilience (AC-20). Backend down the whole session →
# gameplay zero impact; CRITICAL preserved; reconnect auto-recovers the flush.
#
# Uses a MockClock so the test can advance past each Formula 5 backoff window and prove the
# backoff grows (BASE × 2^(n−1), capped) while the buffer is never lost.
extends GutTest

const TelemetryScript := preload("res://src/autoload/telemetry.gd")
const PRIO := TelemetryEvent.Priority


class MockClock:
	var mono: int = 0
	var unix: int = 1000
	func now_monotonic_ms() -> int: return mono
	func now_unix_s() -> int: return unix


class MockTransport:
	var calls: int = 0
	var next_code: int = 503   # backend down
	func dispatch(_url: String, _headers: PackedStringArray, _body: String, on_response: Callable) -> bool:
		calls += 1
		on_response.call(next_code, 0)
		return true


func _make() -> Array:
	var clock := MockClock.new()
	var tx := MockTransport.new()
	var t = TelemetryScript.new()
	t._clock = clock
	add_child_autofree(t)
	t.set_session_token("tok-1")
	t.set_flush_transport(tx)
	return [t, tx, clock]


func test_backend_down_whole_session_keeps_buffer_and_grows_backoff() -> void:
	var S := TelemetryScript.State
	var bundle := _make()
	var t = bundle[0]
	var tx: MockTransport = bundle[1]
	var clock: MockClock = bundle[2]

	# Seed a mix incl. a CRITICAL anomaly (must never be lost).
	t._record(&"hit", {}, PRIO.LOW)
	t._record(&"anomaly", {}, PRIO.CRITICAL)
	t._record(&"phase", {}, PRIO.STANDARD)
	var seeded: int = t.get_buffered_count()
	assert_eq(seeded, 3, "3 events buffered before any flush")

	# Attempt 1 (fails 503).
	clock.mono = 1000
	assert_true(t._flush_now(&"a1"), "flush attempt dispatched")
	assert_eq(t.get_buffered_count(), 3, "AC-20: buffer retained after 503")
	assert_eq(t.get_state(), S.ACTIVE, "never stuck in FLUSHING")
	assert_eq(t._flush_failure_count, 1, "failure 1")
	var backoff1: int = t._backoff_until_ms - clock.mono

	# Still inside backoff → suppressed.
	clock.mono = 1000 + backoff1 - 1
	assert_false(t._flush_now(&"too-soon"), "retry inside backoff window suppressed")
	assert_eq(tx.calls, 1, "no extra dispatch inside the window")

	# Advance past backoff → attempt 2 (fails again), backoff grows.
	clock.mono = 1000 + backoff1 + 1
	assert_true(t._flush_now(&"a2"), "attempt 2 dispatched after backoff window")
	assert_eq(t._flush_failure_count, 2, "failure 2")
	var backoff2: int = t._backoff_until_ms - clock.mono
	assert_gt(backoff2, backoff1, "Formula 5: backoff grows on consecutive failures")
	assert_eq(t.get_buffered_count(), 3, "buffer still intact through repeated failures")

	# CRITICAL is still present (never sampled / dropped).
	var has_critical := false
	for ev in t._buffer.get_all():
		if ev.priority == PRIO.CRITICAL:
			has_critical = true
	assert_true(has_critical, "AC-20: CRITICAL anomaly preserved through the outage")

	# Reconnect: next flush returns 200 → buffer clears, backoff resets.
	clock.mono = 1000 + backoff1 + backoff2 + 100000   # well past any window
	tx.next_code = 200
	assert_true(t._flush_now(&"recovered"), "flush dispatches after the window")
	assert_eq(t.get_buffered_count(), 0, "AC-20: reconnect auto-recovers — buffer flushed")
	assert_eq(t._flush_failure_count, 0, "backoff reset on success")
	assert_eq(t.get_state(), S.ACTIVE, "back to ACTIVE")
