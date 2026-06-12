# Telemetry (#28) — Story 016: EC-08 DEGRADED Private Mode (AC-21).
#
# Verifies:
#   AC-1  boot Private Mode → DEGRADED; capture continues in-memory; no user:// spool.
#   AC-2  mid-session private_mode_detected → ACTIVE → DEGRADED.
#   AC-3  the user:// emergency spool is suppressed under Private Mode (and opt-out),
#         but writes normally when ACTIVE / non-private / enabled.
#   AC-4  rare recovery: notify_private_mode_cleared → DEGRADED → ACTIVE.
#
# PersistenceLayer is a SOFT dependency whose live build may not expose the Private Mode
# API; this MockPersistence supplies the full contract (is_private_mode + the signal) to
# exercise the gate. The defensive has_method/has_signal guards are covered by the other
# telemetry tests, which inject no persistence and never crash.
extends GutTest

const TelemetryScript := preload("res://src/autoload/telemetry.gd")
const PRIO := TelemetryEvent.Priority


## #3 PersistenceLayer stand-in exposing the Private Mode contract (ADR-0003).
class MockPersistence extends Node:
	signal private_mode_detected()
	var private: bool = false
	func is_private_mode() -> bool:
		return private


func _make_telemetry(persistence) -> Node:
	var t = TelemetryScript.new()
	if persistence != null:
		t._persistence = persistence   # inject #3 seam BEFORE _ready (DI override)
	add_child_autofree(t)
	return t


func _ev(prio: int) -> TelemetryEvent:
	var e := TelemetryEvent.new()
	e.priority = prio
	return e


func _count_event(events: Array, name) -> int:
	var n := 0
	for e in events:
		if e.event_name == name:
			n += 1
	return n


# --- AC-1: boot Private Mode → DEGRADED, capture continues --------------------

func test_boot_private_mode_enters_degraded() -> void:
	var S := TelemetryScript.State
	var p := MockPersistence.new()
	p.private = true
	add_child_autofree(p)
	var t := _make_telemetry(p)
	assert_eq(t.get_state(), S.DEGRADED, "AC-21: boot Private Mode → DEGRADED")


func test_degraded_still_captures_in_memory() -> void:
	var p := MockPersistence.new()
	p.private = true
	add_child_autofree(p)
	var t := _make_telemetry(p)
	t._record(&"set_progress", {"progress": 0.5}, PRIO.STANDARD)
	assert_eq(t.get_buffered_count(), 1, "AC-21: DEGRADED keeps capturing in-memory (not a capture stop)")


func test_non_private_boots_active() -> void:
	var S := TelemetryScript.State
	var p := MockPersistence.new()
	p.private = false
	add_child_autofree(p)
	var t := _make_telemetry(p)
	assert_eq(t.get_state(), S.ACTIVE, "non-private persistence → ACTIVE")


# --- AC-2: mid-session detection ----------------------------------------------

func test_midsession_private_detected_active_to_degraded() -> void:
	var S := TelemetryScript.State
	var p := MockPersistence.new()
	p.private = false
	add_child_autofree(p)
	var t := _make_telemetry(p)
	assert_eq(t.get_state(), S.ACTIVE, "boots ACTIVE (non-private)")
	p.private_mode_detected.emit()
	assert_eq(t.get_state(), S.DEGRADED, "AC-21: mid-session private_mode_detected → DEGRADED")


# --- AC-3: spool gate ---------------------------------------------------------

func test_degraded_suppresses_user_spool() -> void:
	var p := MockPersistence.new()
	p.private = true
	add_child_autofree(p)
	var t := _make_telemetry(p)
	var spooled: Array = []
	t.set_spool_writer(func(events): spooled.append(events); return true)
	var wrote: bool = t._spool_to_user([_ev(PRIO.CRITICAL)])
	assert_false(wrote, "AC-21: DEGRADED/Private Mode → no user:// spool")
	assert_eq(spooled.size(), 0, "the writer is never invoked under Private Mode")


func test_active_nonprivate_spools_via_writer() -> void:
	var t := _make_telemetry(null)   # no persistence → non-private, ACTIVE
	var spooled: Array = []
	t.set_spool_writer(func(events): spooled.append(events); return true)
	var wrote: bool = t._spool_to_user([_ev(PRIO.CRITICAL)])
	assert_true(wrote, "ACTIVE + non-private + enabled → emergency spool writes")
	assert_eq(spooled.size(), 1, "the writer is invoked exactly once")


func test_opt_out_also_suppresses_spool() -> void:
	var t := _make_telemetry(null)
	t.set_telemetry_enabled(false)
	var spooled: Array = []
	t.set_spool_writer(func(events): spooled.append(events); return true)
	assert_false(t._spool_to_user([_ev(PRIO.CRITICAL)]), "opt-out → nothing leaves the device, incl. user:// spool")
	assert_eq(spooled.size(), 0, "writer not invoked under opt-out")


# --- AC-4: rare recovery ------------------------------------------------------

func test_private_cleared_recovers_to_active() -> void:
	var S := TelemetryScript.State
	var p := MockPersistence.new()
	p.private = false   # the method reports non-private; the signal latches private
	add_child_autofree(p)
	var t := _make_telemetry(p)
	p.private_mode_detected.emit()
	assert_eq(t.get_state(), S.DEGRADED, "latched into DEGRADED")
	var recovered: bool = t.notify_private_mode_cleared()
	assert_true(recovered, "DEGRADED → ACTIVE recovery succeeds")
	assert_eq(t.get_state(), S.ACTIVE, "AC-21 edge: Private Mode lifted → ACTIVE")
	# Recovery clears the latch → spool is allowed again.
	var spooled: Array = []
	t.set_spool_writer(func(events): spooled.append(events); return true)
	assert_true(t._spool_to_user([_ev(PRIO.CRITICAL)]), "post-recovery spool re-enabled")
