# Telemetry (#28) — Story 007: Formula 2 foreground-ratio + platform_detect visibility hook.
#
# Verifies:
#   AC-1  Formula 2: ratio = t_fg / max(t_total, 1), clamped [0,1]; EC-06 t_total=0 → 1.0.
#   AC-2  ForegroundTracker banks foreground vs total across visible/hidden transitions
#         (injected monotonic clock).
#   AC-3  Non-web platform seam fallback: a live Telemetry instance with no visibility
#         events reports ratio 1.0 (full foreground).
extends GutTest

const F := preload("res://src/telemetry/telemetry_formulas.gd")
const TelemetryScript := preload("res://src/autoload/telemetry.gd")


# --- AC-1: Formula 2 -----------------------------------------------------------

func test_foreground_ratio_formula() -> void:
	assert_almost_eq(F.foreground_ratio(8000, 10000), 0.8, 0.0001, "8s/10s → 0.8")
	assert_eq(F.foreground_ratio(0, 0), 1.0, "EC-06: t_total 0 → 1.0")
	assert_eq(F.foreground_ratio(10000, 10000), 1.0, "all foreground → 1.0")
	assert_eq(F.foreground_ratio(15000, 10000), 1.0, "over-unity clamped to 1.0")
	assert_eq(F.foreground_ratio(-5, 10000), 0.0, "negative clamped to 0.0")


# --- AC-2: ForegroundTracker accumulation -------------------------------------

func test_tracker_banks_visible_and_hidden_spans() -> void:
	var tr := ForegroundTracker.new()
	tr.start(0)
	tr.mark_hidden(1000)   # visible 0..1000 → fg 1000, total 1000
	tr.mark_visible(3000)  # hidden 1000..3000 → total 3000, fg 1000
	var r := tr.ratio(4000)  # visible 3000..4000 → fg 2000, total 4000
	assert_eq(tr.foreground_ms(), 2000, "foreground span banked")
	assert_eq(tr.total_ms(), 4000, "total span banked")
	assert_almost_eq(r, 0.5, 0.0001, "2000/4000 = 0.5")


func test_tracker_all_foreground_is_one() -> void:
	var tr := ForegroundTracker.new()
	tr.start(0)
	assert_eq(tr.ratio(5000), 1.0, "never hidden → ratio 1.0")


func test_tracker_zero_elapsed_is_one() -> void:
	var tr := ForegroundTracker.new()
	tr.start(1000)
	assert_eq(tr.ratio(1000), 1.0, "EC-06: zero elapsed → 1.0 (no div-by-zero)")


func test_tracker_negative_delta_defensive() -> void:
	var tr := ForegroundTracker.new()
	tr.start(5000)
	# Clock appears to go backwards (shouldn't on monotonic) — delta floored to 0.
	var r := tr.ratio(4000)
	assert_eq(tr.total_ms(), 0, "negative delta floored to 0")
	assert_eq(r, 1.0, "no time accrued → 1.0")


# --- AC-3: non-web platform fallback (integration) ----------------------------

func test_telemetry_foreground_ratio_fallback_full_foreground() -> void:
	# Headless (non-web) → PlatformDetect fires no visibility_changed → the tracker stays
	# visible the whole time → ratio 1.0 (AC-3 fallback).
	var t = TelemetryScript.new()
	add_child_autofree(t)
	await get_tree().process_frame
	assert_eq(t.get_foreground_ratio(), 1.0,
		"AC-3: non-web (no visibility events) → full foreground ratio 1.0")


func test_telemetry_subscribes_platform_visibility_seam() -> void:
	# The wiring exists: a live Telemetry resolves PlatformDetect and connects its
	# visibility_changed signal (the seam Story 007 depends on).
	var t = TelemetryScript.new()
	add_child_autofree(t)
	await get_tree().process_frame
	var pd = get_node_or_null("/root/PlatformDetect")
	assert_not_null(pd, "PlatformDetect autoload present")
	if pd != null:
		assert_true(pd.has_signal("visibility_changed"),
			"PlatformDetect exposes the visibility_changed seam (Story 007)")
		assert_true(pd.is_connected("visibility_changed", Callable(t, "_on_visibility_changed")),
			"Telemetry connected its foreground tracker to the visibility seam")
