# Telemetry (#28) — Story 006: Formula 1 switch-latency glance proxy (bucketed).
#
# Verifies:
#   AC-1 (AC-05)  latency = SET_ACTIVE ts − REST_PERIOD ts → correct bucket index; only the
#                 bucket index is the recorded value (de-id). Boundary cases checked.
#   AC-2          edge (a) REST_PERIOD→WORKOUT_COMPLETE → no event; edge (b) first SET_ACTIVE
#                 with no preceding REST → no event; anchor lifecycle (emit then re-skip).
#   AC-3 (INV-T3) buckets_strictly_ascending predicate.
extends GutTest

const F := preload("res://src/telemetry/telemetry_formulas.gd")


# --- AC-1: latency + bucketing -------------------------------------------------

func test_latency_and_bucket_index() -> void:
	# GDD example: REST @120000, SET_ACTIVE @132000 → 12000ms → bucket 1 (5–15s).
	assert_eq(F.switch_latency_ms(120000, 132000), 12000, "latency = t_a − t_r")
	assert_eq(F.switch_latency_bucket(12000), 1, "12000ms → bucket 1 (5–15s)")


func test_bucket_boundaries() -> void:
	# Boundaries [5000, 15000, 60000, 180000] → 5 buckets, half-open [lo, hi).
	assert_eq(F.switch_latency_bucket(0), 0, "0ms → <5s")
	assert_eq(F.switch_latency_bucket(4999), 0, "4999ms → <5s")
	assert_eq(F.switch_latency_bucket(5000), 1, "5000ms → 5–15s (lower edge inclusive)")
	assert_eq(F.switch_latency_bucket(14999), 1, "14999ms → 5–15s")
	assert_eq(F.switch_latency_bucket(15000), 2, "15000ms → 15–60s")
	assert_eq(F.switch_latency_bucket(59999), 2, "59999ms → 15–60s")
	assert_eq(F.switch_latency_bucket(60000), 3, "60000ms → 60–180s")
	assert_eq(F.switch_latency_bucket(179999), 3, "179999ms → 60–180s")
	assert_eq(F.switch_latency_bucket(180000), 4, "180000ms → >180s")
	assert_eq(F.switch_latency_bucket(181000), 4, "181000ms → >180s")


func test_negative_latency_defensive_bucket_zero() -> void:
	assert_eq(F.switch_latency_bucket(-100), 0, "negative latency → bucket 0 (defensive)")


# --- AC-2: anchor lifecycle + edges (a) and (b) -------------------------------

func test_normal_rest_then_set_active_emits_bucket() -> void:
	var tr := SwitchLatencyTracker.new()
	tr.on_rest_period(120000)
	assert_true(tr.has_anchor(), "anchor set after REST_PERIOD")
	var bucket := tr.on_set_active(132000)
	assert_eq(bucket, 1, "12s latency → bucket 1")
	assert_false(tr.has_anchor(), "anchor cleared after SET_ACTIVE")


func test_edge_a_rest_to_workout_complete_no_event() -> void:
	var tr := SwitchLatencyTracker.new()
	tr.on_rest_period(120000)
	tr.clear_anchor()  # REST_PERIOD → WORKOUT_COMPLETE clears without emit (EC-04)
	assert_false(tr.has_anchor(), "anchor cleared by terminal")
	assert_eq(tr.on_set_active(140000), SwitchLatencyTracker.NO_EVENT, "no anchor → no event")


func test_edge_b_first_set_active_without_rest_no_event() -> void:
	var tr := SwitchLatencyTracker.new()
	# WARM_UP → SET_ACTIVE with no preceding REST_PERIOD.
	assert_eq(tr.on_set_active(50000), SwitchLatencyTracker.NO_EVENT,
		"first SET_ACTIVE, no anchor → no event (edge b)")
	assert_false(tr.has_anchor(), "still no anchor")


func test_anchor_consumed_only_once() -> void:
	var tr := SwitchLatencyTracker.new()
	tr.on_rest_period(100000)
	assert_ne(tr.on_set_active(110000), SwitchLatencyTracker.NO_EVENT, "first SET_ACTIVE emits")
	assert_eq(tr.on_set_active(120000), SwitchLatencyTracker.NO_EVENT,
		"anchor consumed once; second SET_ACTIVE without new REST → no event")


# --- AC-3: INV-T3 -------------------------------------------------------------

func test_inv_t3_buckets_strictly_ascending() -> void:
	assert_true(F.buckets_strictly_ascending([5000, 15000, 60000, 180000]), "default is ascending")
	assert_false(F.buckets_strictly_ascending([5000, 5000, 60000]), "equal adjacent → not strict")
	assert_false(F.buckets_strictly_ascending([15000, 5000]), "descending → false")
	assert_true(F.buckets_strictly_ascending([1]), "single boundary trivially ascending")
