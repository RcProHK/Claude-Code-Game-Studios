# Telemetry (#28) — Story 004: 3-tier priority ring buffer + Rule 7 overflow.
#
# Verifies (AC-03 GDD binding — must-not-regress):
#   AC-1  CRITICAL is never evicted by ordinary overflow; the main ring evicts the OLDEST
#         LOW first, then the OLDEST STANDARD. CRITICAL reserve overflow → spool hook
#         called; unwired spool → counted, wired-success spool → NOT counted (EC-05).
#   AC-2  dropped_count == number of evictions (exact); 0 when no overflow; the
#         dropped_count meta-event priority is CRITICAL.
#   AC-3  INV-T1 (CRITICAL_RESERVED < BUFFER_MAX) via the pure validate_config predicate.
#
# INV-T1 is probed through the predicate (not the constructor) so the test never trips
# the .gutconfig engine-error gate that the fallback push_error would otherwise raise.
extends GutTest

const PRIO := TelemetryEvent.Priority


func _ev(prio: int, id: int = 0) -> TelemetryEvent:
	var e := TelemetryEvent.new()
	e.priority = prio
	e.client_event_id = id
	e.event_name = &"test"
	return e


# --- AC-1: CRITICAL never evicted; LOW-first then STANDARD --------------------

func test_critical_never_evicted_and_low_evicted_before_standard() -> void:
	# buffer_max 10, reserved 3 → main capacity 7.
	var buf := TelemetryBuffer.new(10, 3)
	# Seed one CRITICAL to prove it survives the whole overflow storm.
	buf.push(_ev(PRIO.CRITICAL, 900))
	# Fill the main ring: 4 LOW (ids 0-3) + 3 STANDARD (ids 100-102) = 7.
	for i in range(4):
		buf.push(_ev(PRIO.LOW, i))
	for i in range(3):
		buf.push(_ev(PRIO.STANDARD, 100 + i))
	assert_eq(buf.main_size(), 7, "main full at capacity")
	assert_eq(buf.get_dropped_count(), 0, "no drop while filling")

	# One more STANDARD → must evict the OLDEST LOW (not a STANDARD).
	buf.push(_ev(PRIO.STANDARD, 200))
	assert_eq(buf.get_dropped_count(), 1, "one eviction")
	assert_eq(buf.count_priority(PRIO.LOW), 3, "oldest LOW evicted first (4→3)")
	assert_eq(buf.count_priority(PRIO.STANDARD), 4, "STANDARD untouched (3→4)")

	# Drain the rest of the LOW tier (3 more pushes evict the 3 remaining LOW).
	buf.push(_ev(PRIO.STANDARD, 201))
	buf.push(_ev(PRIO.STANDARD, 202))
	buf.push(_ev(PRIO.STANDARD, 203))
	assert_eq(buf.count_priority(PRIO.LOW), 0, "all LOW drained before any STANDARD evict")

	# Now LOW is exhausted → next push evicts the OLDEST STANDARD.
	var std_before := buf.count_priority(PRIO.STANDARD)
	buf.push(_ev(PRIO.STANDARD, 204))
	assert_eq(buf.count_priority(PRIO.STANDARD), std_before, "STANDARD evicted+added (net same)")
	assert_eq(buf.get_dropped_count(), 5, "5 total evictions (1 + 3 LOW + 1 STANDARD)")

	# CRITICAL survived the entire storm.
	assert_eq(buf.critical_size(), 1, "CRITICAL never evicted by main overflow")


func test_critical_overflow_unwired_spool_drops_and_counts() -> void:
	var buf := TelemetryBuffer.new(10, 3)  # reserved 3
	for i in range(3):
		buf.push(_ev(PRIO.CRITICAL, i))
	assert_eq(buf.critical_size(), 3, "reserve full")
	# 4th CRITICAL — reserve full, NO spool hook wired → oldest is at-risk → drop + count.
	buf.push(_ev(PRIO.CRITICAL, 3))
	assert_eq(buf.critical_size(), 3, "reserve stays at cap")
	assert_eq(buf.get_dropped_count(), 1, "unwired spool → overflow CRITICAL counted (EC-05)")


func test_critical_overflow_with_successful_spool_not_counted() -> void:
	var spooled: Array = []
	var buf := TelemetryBuffer.new(10, 3)
	buf.set_spool_hook(func(events: Array) -> bool:
		spooled.append_array(events)
		return true)
	for i in range(5):  # 2 over the reserve of 3
		buf.push(_ev(PRIO.CRITICAL, i))
	assert_eq(buf.critical_size(), 3, "reserve at cap")
	assert_eq(spooled.size(), 2, "2 overflow CRITICAL handed to spool hook")
	assert_eq(buf.get_dropped_count(), 0, "successful spool → NOT a drop (EC-05)")


# --- AC-2: dropped_count --------------------------------------------------------

func test_dropped_count_equals_overflow_count_exactly() -> void:
	var buf := TelemetryBuffer.new(5, 1)  # main capacity 4
	for i in range(4):
		buf.push(_ev(PRIO.LOW, i))
	for i in range(6):  # 6 evictions
		buf.push(_ev(PRIO.LOW, 100 + i))
	assert_eq(buf.get_dropped_count(), 6, "dropped_count == overflow count (exact)")


func test_no_overflow_means_zero_dropped() -> void:
	var buf := TelemetryBuffer.new(100, 10)
	buf.push(_ev(PRIO.LOW, 0))
	buf.push(_ev(PRIO.STANDARD, 1))
	buf.push(_ev(PRIO.CRITICAL, 2))
	assert_eq(buf.get_dropped_count(), 0, "no overflow → dropped_count 0")
	assert_eq(buf.size(), 3, "all retained")


func test_dropped_count_meta_event_priority_is_critical() -> void:
	assert_eq(TelemetryBuffer.DROPPED_COUNT_EVENT_PRIORITY, PRIO.CRITICAL,
		"AC-2: dropped_count meta-event is CRITICAL (survives Rule 7)")


# --- AC-3: INV-T1 (pure predicate) --------------------------------------------

func test_inv_t1_validate_config_predicate() -> void:
	assert_eq(TelemetryBuffer.validate_config(2000, 256), "", "valid default config passes")
	assert_ne(TelemetryBuffer.validate_config(100, 200), "",
		"INV-T1: reserved (200) >= max (100) rejected")
	assert_ne(TelemetryBuffer.validate_config(100, 100), "",
		"INV-T1: reserved == max rejected")
	assert_ne(TelemetryBuffer.validate_config(0, 0), "", "buffer_max <= 0 rejected")
	assert_ne(TelemetryBuffer.validate_config(10, -1), "", "negative reserved rejected")
