## Unit test — GymModeHud Story 002: EXP bar Formula 1/2 + tween core + reduce_motion
##
## Coverage:
##   AC-F1 — compute_exp_fill: 340/500=0.68, 500/500=1.0, exp_to_next=0→1.0 (EC-F1),
##           current_exp=-5→0.0 (EC-F3), NaN/INF→0.0 (EC-F4)
##   AC-F2 — compute_tween_duration: reduce_motion false→0.3, true→0.0
##   AC-CR-2 — counter seam: idle settle → _active_tween_count==0 + value stable;
##             burst → _active_tween_count ≤ MAX_CONCURRENT_TWEENS (config const)
extends GutTest

const SUT := preload("res://src/ui/gym_mode_hud/gym_mode_hud.gd")


# ── AC-F1: Formula 1 (pure static — no node needed) ──

func test_compute_exp_fill_normal_ratio() -> void:
	assert_almost_eq(SUT.compute_exp_fill(340.0, 500.0), 0.68, 0.0001,
		"AC-F1: 340/500 == 0.68")


func test_compute_exp_fill_full_bar() -> void:
	assert_eq(SUT.compute_exp_fill(500.0, 500.0), 1.0,
		"AC-F1: 500/500 == 1.0")


func test_compute_exp_fill_zero_to_next_div_guard() -> void:
	# EC-F1: exp_to_next=0 → max(.,1)=1 denominator, no NaN, clamps to 1.0
	var result: float = SUT.compute_exp_fill(340.0, 0.0)
	assert_eq(result, 1.0,
		"AC-F1/EC-F1: exp_to_next=0 → div-guard max(.,1), 340/1 clamped to 1.0")
	assert_false(is_nan(result), "AC-F1/EC-F1: no NaN with zero denominator")


func test_compute_exp_fill_negative_current_sanitised() -> void:
	# EC-F3: current_exp=-5 → max(.,0)=0 → 0/500 == 0.0
	assert_eq(SUT.compute_exp_fill(-5.0, 500.0), 0.0,
		"AC-F1/EC-F3: negative current_exp sanitised to 0.0")


func test_compute_exp_fill_both_inputs_sanitised() -> void:
	# EC-F3: both inputs negative → 0/1 == 0.0, no NaN
	var result: float = SUT.compute_exp_fill(-10.0, -20.0)
	assert_eq(result, 0.0,
		"AC-F1/EC-F3: both negative inputs sanitised → 0.0")
	assert_false(is_nan(result), "AC-F1/EC-F3: no NaN with both inputs sanitised")


func test_compute_exp_fill_overflow_clamps_to_one() -> void:
	# current >> to_next (e.g. just leveled, stale) → clamp ceiling 1.0
	assert_eq(SUT.compute_exp_fill(900.0, 500.0), 1.0,
		"AC-F1: current > to_next clamps to 1.0 (no overflow)")


func test_compute_exp_fill_nan_input_returns_zero() -> void:
	# EC-F4: NaN ratio → 0.0 fallback
	assert_eq(SUT.compute_exp_fill(NAN, 500.0), 0.0,
		"AC-F1/EC-F4: NaN current_exp → 0.0 fallback")


func test_compute_exp_fill_inf_input_returns_zero() -> void:
	# EC-F4: INF ratio → 0.0 fallback
	assert_eq(SUT.compute_exp_fill(INF, 500.0), 0.0,
		"AC-F1/EC-F4: INF current_exp → 0.0 fallback")


# ── AC-F2: Formula 2 (pure static) ──

func test_compute_tween_duration_motion_on() -> void:
	assert_eq(SUT.compute_tween_duration(false, 0.3), 0.3,
		"AC-F2: reduce_motion=false → base 0.3")


func test_compute_tween_duration_reduce_motion() -> void:
	assert_eq(SUT.compute_tween_duration(true, 0.3), 0.0,
		"AC-F2: reduce_motion=true → 0.0 (instant set)")


func test_compute_tween_duration_base_out_of_range_clamped() -> void:
	assert_eq(SUT.compute_tween_duration(false, 99.0), 0.5,
		"AC-F2: base above safe range clamps to 0.5")
	assert_eq(SUT.compute_tween_duration(false, 0.01), 0.2,
		"AC-F2: base below safe range clamps to 0.2")


# ── AC-CR-2: tween counter seam (needs node in tree) ──

func _make_sut() -> SUT:
	var sut: SUT = SUT.new()
	# Inject nulls so _ready() skips signal wiring (no autoloads needed for tween test).
	add_child_autofree(sut)
	return sut


func test_reduce_motion_snaps_without_tween() -> void:
	var sut := _make_sut()
	sut._reduce_motion = true
	sut._set_exp_fill(0.68)
	assert_eq(sut.get_active_tween_count(), 0,
		"AC-CR-2/F2: reduce_motion → instant set, no tween created")
	assert_almost_eq(sut.get_exp_bar_value(), 0.68, 0.0001,
		"AC-CR-2/F2: reduce_motion snaps value immediately")


func test_tween_increments_active_count() -> void:
	var sut := _make_sut()
	sut._reduce_motion = false
	sut._set_exp_fill(0.5)
	assert_eq(sut.get_active_tween_count(), 1,
		"AC-CR-2: starting a tween increments _active_tween_count")


func test_tween_settle_returns_count_to_zero_and_value_stable() -> void:
	var sut := _make_sut()
	sut._reduce_motion = false
	sut._set_exp_fill(0.42)
	assert_eq(sut.get_active_tween_count(), 1, "AC-CR-2: tween in flight")
	# Wait for the tween to finish (event-driven await, not a wall-clock assertion).
	await get_tree().create_timer(BASE_DURATION + 0.1).timeout
	assert_eq(sut.get_active_tween_count(), 0,
		"AC-CR-2: settle → _active_tween_count back to 0 (idle-0-cost)")
	assert_almost_eq(sut.get_exp_bar_value(), 0.42, 0.001,
		"AC-CR-2: settled bar value reaches target")
	# Value stability: a further idle window must not move the value.
	var settled: float = sut.get_exp_bar_value()
	await get_tree().create_timer(0.2).timeout
	assert_almost_eq(sut.get_exp_bar_value(), settled, 0.0001,
		"AC-CR-2: idle 200ms after settle → value delta == 0")


func test_burst_caps_active_tween_count_at_max() -> void:
	var sut := _make_sut()
	sut._reduce_motion = false
	# Same-frame burst of MAX_CONCURRENT_TWEENS + 2 motion requests.
	var burst: int = sut.MAX_CONCURRENT_TWEENS + 2
	for i in burst:
		sut._set_exp_fill(float(i) / float(burst))
	assert_lte(sut.get_active_tween_count(), sut.MAX_CONCURRENT_TWEENS,
		"AC-CR-2: burst of MAX+2 → _active_tween_count ≤ MAX_CONCURRENT_TWEENS (config const, excess degrades to instant set)")


const BASE_DURATION: float = 0.3
