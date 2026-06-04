## Unit test — GymModeHud Story 003: tween circuit-breaker + handle-map (spike-grounded)
##
## Mirrors prototypes/tween-spike/ PART B assertions, rewritten against the production
## GymModeHud implementation (not the throwaway HudTweenManager inner class).
##
## Coverage:
##   AC-EC-F4b(1) — snap-index off-by-one: snap fires on (MAX_TWEEN_RESTART_COUNT+1)-th event
##   AC-EC-F4b(2) — snap-path counter to 0; invariant count == _active_tweens.size()
##   AC-EC-F4b(3) — empty/stale-handle _on_tween_finished → no-op (identity guard)
##   AC-EC-F4b(4) — reset-then-resume via logical seam (no frame-timing dependency)
##   AC-EC-R2     — same-stat kill-restart (one live tween, no accumulation)
##   AC-CR-2 zero-floor — reduce_motion never increments; count never negative
##   EC-R6        — DEEP_DIM emphasis → set value, skip tween (no increment)
extends GutTest

const SUT := preload("res://src/ui/gym_mode_hud/gym_mode_hud.gd")


func _make_sut() -> SUT:
	var sut: SUT = SUT.new()
	add_child_autofree(sut)
	sut._reduce_motion = false
	return sut


func _assert_invariant(sut: SUT, ctx: String) -> void:
	assert_eq(sut.get_active_tween_count(), sut._active_tweens.size(),
		"INVARIANT count == _active_tweens.size() (%s)" % ctx)


# ── AC-EC-F4b(1): snap-index off-by-one (spike B4) ──

func test_snap_fires_on_max_restart_plus_one_th_event() -> void:
	var sut := _make_sut()
	# MAX_TWEEN_RESTART_COUNT = 5. Events: e1=create(rc0), e2..e6 = kill-restart.
	# e6 is the (MAX+1)-th event → restart_count hits 5 → snap.
	var snap_event_index: int = -1
	for i in 8:
		sut._set_exp_fill(float(i + 1) / 10.0)
		# Detect the snap: after snap, restart_count resets to 0 AND no live tween.
		if sut._get_restart_count_for_test(&"exp") == 0 and sut.get_active_tween_count() == 0 and snap_event_index == -1 and i >= 1:
			snap_event_index = i + 1
	assert_eq(snap_event_index, sut.MAX_TWEEN_RESTART_COUNT + 1,
		"AC-EC-F4b(1)/B4: snap fires on the (MAX_TWEEN_RESTART_COUNT+1)=6th event")


func test_snap_value_reaches_latest_target() -> void:
	var sut := _make_sut()
	for i in 6:
		sut._set_exp_fill(float(i + 1) / 10.0)
	# 6th event target = 6/10 = 0.6, snapped instantly.
	assert_almost_eq(sut.get_exp_bar_value(), 0.6, 0.0001,
		"AC-EC-F4b(1): snap sets bar to latest target instantly")
	assert_eq(sut._get_restart_count_for_test(&"exp"), 0,
		"AC-EC-F4b(1): restart_count resets to 0 at snap")


# ── AC-EC-F4b(2): snap-path counter to 0 (spike B3) ──

func test_snap_path_returns_count_to_zero() -> void:
	var sut := _make_sut()
	for i in 6:
		sut._set_exp_fill(float(i + 1) / 10.0)
	assert_eq(sut.get_active_tween_count(), 0,
		"AC-EC-F4b(2)/B3: snap = kill(--) + set_immediate(no ++) → count back to 0")
	_assert_invariant(sut, "after snap")


# ── AC-EC-F4b(3): empty/stale-handle no-op (spike B5/B6) ──

func test_on_tween_finished_empty_handle_is_noop() -> void:
	var sut := _make_sut()
	for i in 6:
		sut._set_exp_fill(float(i + 1) / 10.0)  # snap → entry erased
	var count_before: int = sut.get_active_tween_count()
	sut._on_tween_finished(&"exp", null)  # stale residual on empty handle
	assert_eq(sut.get_active_tween_count(), count_before,
		"AC-EC-F4b(3)/B5: _on_tween_finished on empty handle → identity guard returns, no change")
	_assert_invariant(sut, "after stale finished on empty handle")


func test_stale_tween_finished_does_not_corrupt_new_entry() -> void:
	var sut := _make_sut()
	# e1: create tween A
	sut._set_exp_fill(0.1)
	var tween_a: Tween = sut._active_tweens[&"exp"]
	# e2: kill A, create tween B
	sut._set_exp_fill(0.2)
	var tween_b: Tween = sut._active_tweens[&"exp"]
	assert_ne(tween_a, tween_b, "precondition: restart produced a new tween object")
	var count_before: int = sut.get_active_tween_count()
	# Stale residual finished from killed A arrives
	sut._on_tween_finished(&"exp", tween_a)
	assert_eq(sut.get_active_tween_count(), count_before,
		"AC-EC-F4b(3)/B6: stale A finished → identity guard (live==B≠A) returns, B not erased")
	assert_true(sut._active_tweens.has(&"exp"),
		"AC-EC-F4b(3)/B6: new tween B entry intact after stale A residual")
	_assert_invariant(sut, "after stale A residual")


# ── AC-EC-F4b(4): reset-then-resume via logical seam (spike resume test) ──

func test_resume_after_natural_finish_no_frame_timing() -> void:
	var sut := _make_sut()
	sut._set_exp_fill(0.3)  # e1 create
	var t: Tween = sut._active_tweens[&"exp"]
	# Simulate natural completion via the seam (no await — deterministic, logical-epoch).
	sut._on_tween_finished(&"exp", t)
	assert_eq(sut.get_active_tween_count(), 0,
		"AC-EC-F4b(4): natural finish → count 0")
	assert_eq(sut._get_restart_count_for_test(&"exp"), 0,
		"AC-EC-F4b(4): lifecycle ③ — natural finish resets restart_count")
	# New event after natural finish → normal restart (not snap-mode)
	sut._set_exp_fill(0.5)
	assert_eq(sut.get_active_tween_count(), 1,
		"AC-EC-F4b(4): resume — new event restarts a normal tween (increment, not snap)")
	_assert_invariant(sut, "resume")


# ── AC-EC-R2: same-stat kill-restart (one live tween) ──

func test_same_stat_restart_keeps_single_live_tween() -> void:
	var sut := _make_sut()
	sut._set_exp_fill(0.1)  # create
	sut._set_exp_fill(0.2)  # kill-restart
	sut._set_exp_fill(0.3)  # kill-restart
	assert_eq(sut.get_active_tween_count(), 1,
		"AC-EC-R2: same-stat repeated events → exactly one live tween (kill-restart, no accumulation)")
	assert_lte(sut.get_active_tween_count(), sut.MAX_CONCURRENT_TWEENS,
		"AC-EC-R2: kill-restart peak never exceeds MAX_CONCURRENT_TWEENS")
	_assert_invariant(sut, "same-stat restart")


# ── AC-CR-2 zero-floor (spike F2/B9) ──

func test_reduce_motion_never_increments_count() -> void:
	var sut := _make_sut()
	sut._reduce_motion = true
	for i in 5:
		sut._set_exp_fill(float(i) / 5.0)
	assert_eq(sut.get_active_tween_count(), 0,
		"AC-CR-2 zero-floor: reduce_motion instant set never creates a tween")
	assert_gte(sut.get_active_tween_count(), 0,
		"AC-CR-2 zero-floor: count never negative")
	_assert_invariant(sut, "reduce_motion")


# ── EC-R6: DEEP_DIM emphasis → skip tween ──

func test_deep_dim_emphasis_skips_tween() -> void:
	var sut := _make_sut()
	# WORKOUT_ACTIVE matrix → STAT/SKILLS deep-dim, but EXP is EMPHASIS. To exercise
	# EC-R6 on the EXP element directly, force its emphasis to DEEP_DIM.
	sut._element_emphasis[&"exp"] = sut.Emphasis.DEEP_DIM
	sut._set_exp_fill(0.42)
	assert_eq(sut.get_active_tween_count(), 0,
		"EC-R6: deep-dim element → value set, tween skipped (no increment)")
	assert_almost_eq(sut.get_exp_bar_value(), 0.42, 0.0001,
		"EC-R6: deep-dim still updates the underlying value (set, no animation)")
	_assert_invariant(sut, "deep-dim skip")


# ── multi-stat cap interaction (cross-stat distinct from circuit breaker) ──

func test_invariant_held_across_mixed_operations() -> void:
	var sut := _make_sut()
	_assert_invariant(sut, "initial")
	sut._set_exp_fill(0.1)
	_assert_invariant(sut, "e1 create")
	sut._set_exp_fill(0.2)
	_assert_invariant(sut, "e2 restart")
	var t: Tween = sut._active_tweens[&"exp"]
	sut._on_tween_finished(&"exp", t)
	_assert_invariant(sut, "natural finish")
	assert_eq(sut.get_active_tween_count(), 0, "after natural finish, no live tween")
