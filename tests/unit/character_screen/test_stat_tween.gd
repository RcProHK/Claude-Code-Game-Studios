## #22 F1 stat tween core — unit suite (story 004; GDD AC-01..04).
## Golden vector 紀律:.5 boundary 只准 binary-exact 值(GDD AC header)。
extends GutTest

const StatTween := preload("res://src/ui/character_screen/stat_tween.gd")


static func _fmt_int(v: float) -> String:
	return str(roundi(v))


func _make(initial: float, tween_ms: float = 300.0):
	var t = StatTween.new(Callable(StatTween, "_noop") if false else func(v: float) -> String: return _fmt_int(v), tween_ms)
	t.reset(initial)
	return t


## --- AC-01: golden vector + overshoot clamp (sd B-1) ---

func test_ac01_golden_vector_t150_is_89_25() -> void:
	var t = _make(84.0)
	t.retarget(90.0)
	t.advance(150.0)
	assert_almost_eq(t.current_raw(), 89.25, 0.0001, "ease(0.5)=0.875 → 84+6×0.875")
	assert_eq(t.display(), "89")
	assert_eq(t.arrow(), 1, "↑ arrow")


func test_ac01_overshoot_single_step_clamps_at_target() -> void:
	var t = _make(84.0)
	t.retarget(90.0)
	t.advance(500.0)  # browser throttle class — u 必須 clamp
	assert_eq(t.display(), "90", "永不超過 target(clamp u — Pillar 1)")
	assert_almost_eq(t.current_raw(), 90.0, 0.0001)
	assert_false(t.is_active(), "natural settle")


func test_ac01_massive_step_never_explodes() -> void:
	var t = _make(84.0)
	t.retarget(90.0)
	t.advance(1000.0)  # 冇 clamp 嘅 cubic 會出 166
	assert_eq(t.display(), "90")


## --- AC-02: retarget mid-tween,永不 queue,收斂最後 target ---

func test_ac02_retarget_restarts_from_interpolated() -> void:
	var t = _make(84.0)
	t.retarget(90.0)
	t.advance(150.0)  # 89.25
	t.retarget(95.0)
	assert_almost_eq(t._v_from, 89.25, 0.0001, "v_from := 當前 interpolated 值")
	assert_almost_eq(t._elapsed_ms, 0.0, 0.0001, "clock 歸零")
	t.advance(300.0)
	assert_eq(t.display(), "95", "行足新 tween 收斂新 target")


func test_ac02_n_retargets_converge_to_last() -> void:
	var t = _make(10.0)
	for target in [20.0, 30.0, 40.0, 55.0]:
		t.retarget(target)
		t.advance(50.0)  # 每次未完就再 retarget — 永不 queue
	t.advance(300.0)
	assert_eq(t.display(), "55", "signal 停 → 最後一條收斂")
	assert_false(t.is_active())


## --- AC-03: zero-delta formatter guard + settle := v_target (sd B-3) ---

func test_ac03_sub_display_unit_no_tween_no_arrow() -> void:
	# crit_chance class:0.071→0.074 sub-display-unit — 用 pct formatter.
	var fmt_pct := func(v: float) -> String: return "%d%%" % roundi(v * 100.0)
	var t = StatTween.new(fmt_pct, 300.0)
	t.reset(0.071)
	t.retarget(0.074)
	assert_false(t.is_active(), "fmt 相等 → 無 tween")
	assert_eq(t.arrow(), 0, "無 arrow")
	assert_almost_eq(t.current_raw(), 0.074, 0.000001, "settle 喺 v_target(真值)")


func test_ac03_midtween_zero_delta_kills_and_settles_at_v_target() -> void:
	var t = _make(84.0)
	t.retarget(85.0)
	t.advance(120.0)  # display 仲係 84.x
	var display_before: String = t.display()
	assert_eq(display_before, "85" if t.current_raw() >= 84.5 else "84")
	# 收 target 同 display 同 bucket → guard fire
	var same_bucket_target: float = t.current_raw() - 0.05
	t.retarget(same_bucket_target)
	assert_false(t.is_active(), "kill 進行中 tween")
	assert_almost_eq(t.current_raw(), same_bucket_target, 0.0001, "settle := v_target pin(sd B-3)")
	assert_eq(t.arrow(), 0)


## --- AC-04: A→B→A 反悔 + arrow operand pin ---

func test_ac04_reversal_clears_arrow_settles_v_target() -> void:
	var t = _make(84.0)
	t.retarget(85.0)
	assert_eq(t.arrow(), 1)
	t.advance(40.0)  # u=0.1333 → ease≈0.349 → raw≈84.35,display「84」bucket
	assert_eq(t.display(), "84", "fixture sanity:仲喺「84」bucket")
	t.retarget(84.2)  # fmt(84.2)=「84」== fmt(display)→ guard fire
	assert_false(t.is_active())
	assert_eq(t.arrow(), 0, "arrow 清走(EC-10)")
	assert_almost_eq(t.current_raw(), 84.2, 0.0001, "settle 喺 v_target")


func test_ac04_arrow_operand_is_raw_interpolated() -> void:
	var t = _make(84.0)
	t.retarget(90.0)
	t.advance(150.0)  # raw = 89.25,display「89」
	t.retarget(89.0)  # fmt(89.0)=「89」== fmt(89.25)=「89」→ guard(無 arrow)
	assert_eq(t.arrow(), 0)
	# 重起:operand 用 raw 89.25 — target 89.5 fmt「90」≠「89」→ tween,
	# sign(89.5 − 89.25) = +1(如果用 formatted 89 vs 89.5 sign 都係 +1 —
	# roundi monotonic ⇒ sign 一致,但 golden pin 用 raw operand)
	var t2 = _make(84.0)
	t2.retarget(90.0)
	t2.advance(150.0)  # raw 89.25
	t2.retarget(89.5)  # fmt「90」≠「89」
	assert_true(t2.is_active())
	assert_eq(t2.arrow(), 1, "sign(89.5−89.25)=+1,operand = raw interpolated")
	assert_almost_eq(t2._v_from, 89.25, 0.0001)


func test_ac04_retarget_can_reverse_arrow() -> void:
	var t = _make(84.0)
	t.retarget(90.0)
	t.advance(150.0)  # raw 89.25 ↑
	t.retarget(85.0)  # fmt(85)=「85」≠「89」→ tween,sign(85−89.25)=−1
	assert_eq(t.arrow(), -1, "retarget 可令 arrow 反轉")


## --- edges: boundaries + snap (sd B-4 非 EQUIPMENT path) ---

func test_edge_t0_and_full_duration() -> void:
	var t = _make(84.0)
	t.retarget(90.0)
	assert_eq(t.display(), "84", "t=0 顯示 v_from")
	t.advance(300.0)
	assert_eq(t.display(), "90", "t=duration 顯示 v_target")
	assert_false(t.is_active())


func test_edge_negative_delta_unequip() -> void:
	var t = _make(90.0)
	t.retarget(84.0)
	assert_eq(t.arrow(), -1)
	t.advance(150.0)
	assert_almost_eq(t.current_raw(), 90.0 - 6.0 * 0.875, 0.0001, "負 delta 對稱")


func test_edge_band_endpoints_200_and_400() -> void:
	for ms in [200.0, 400.0]:
		var t = _make(0.0, ms)
		t.retarget(10.0)
		t.advance(ms)
		assert_eq(t.display(), "10", "band 端點 %sms well-defined" % ms)


func test_edge_retarget_at_t0() -> void:
	var t = _make(84.0)
	t.retarget(90.0)
	t.retarget(95.0)  # t=0 即 retarget — v_from = current = 84
	assert_almost_eq(t._v_from, 84.0, 0.0001)
	assert_true(t.is_active())


func test_snap_kills_tween_and_clears_arrow() -> void:
	var t = _make(84.0)
	t.retarget(90.0)
	t.advance(100.0)
	t.snap(87.0)  # 非 EQUIPMENT reconciliation(sd B-4)
	assert_false(t.is_active(), "kill")
	assert_eq(t.arrow(), 0, "清 arrow")
	assert_eq(t.display(), "87", "snap 到 v_target")


func test_advance_returns_true_exactly_on_settle_tick() -> void:
	var t = _make(84.0)
	t.retarget(90.0)
	assert_false(t.advance(150.0), "未 settle")
	assert_true(t.advance(150.0), "settle 嗰一 tick 回 true(story 019 SFX coalesce 用)")
	assert_false(t.advance(16.0), "settle 後唔再 fire")
