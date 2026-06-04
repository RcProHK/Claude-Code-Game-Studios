## Unit test — GymModeHud Story 008: dim states + DIM_PRODUCT_FLOOR + emphasis alpha + EC-R6
##
## Coverage:
##   AC-KNOB-B   — effective_dim = max(base × state_mult, FLOOR): LOOT 0.30 (clamp),
##                 SUSPENDED 0.35 (at-product), DISCONNECTED 0.50 (no-clamp)
##   emphasis αx3 — ◉/▷ full, ○ 0.55, ◐ 0.22; invariant 0.22 < 0.35 < 0.55
##   EC-R6       — ◐ stat_changed → value set, no tween; ◐→○ → emphasis alpha rises
##   AC-EC-S3    — LOOT_DROP defer: HP/EXP ○dim, PROG ▽ (alpha 0), no loot text rendered by HUD
extends GutTest

const SUT := preload("res://src/ui/gym_mode_hud/gym_mode_hud.gd")


class _StubStatSystem:
	extends RefCounted
	signal stat_changed(stat_id: StringName, old_value: float, new_value: float, source: int, is_initial: bool)
	func connect_for_initial_state(callable: Callable) -> void:
		stat_changed.connect(callable)
	func emit_stat_changed(stat_id: StringName, new_val: float) -> void:
		stat_changed.emit(stat_id, 0.0, new_val, 0, false)


func _make_sut() -> SUT:
	var sut: SUT = SUT.new()
	sut._stat_system = _StubStatSystem.new()
	add_child_autofree(sut)
	return sut


# ── AC-KNOB-B: dim product floor (3 cases) ──

func test_effective_dim_loot_clamps_to_floor() -> void:
	var sut := _make_sut()
	# max(0.5 × 0.4, 0.30) = max(0.20, 0.30) = 0.30 — clamp active
	assert_almost_eq(sut.get_effective_dim_for_state(GameStateMachine.GameState.LOOT_DROP), 0.30, 0.0001,
		"AC-KNOB-B: LOOT_DROP effective_dim clamps to DIM_PRODUCT_FLOOR (0.30)")


func test_effective_dim_suspended_at_product() -> void:
	var sut := _make_sut()
	# max(0.5 × 0.7, 0.30) = max(0.35, 0.30) = 0.35 — at-product, no clamp
	assert_almost_eq(sut.get_effective_dim_for_state(GameStateMachine.GameState.SUSPENDED), 0.35, 0.0001,
		"AC-KNOB-B: SUSPENDED effective_dim == 0.35 (at product, no clamp)")


func test_effective_dim_disconnected_no_clamp() -> void:
	var sut := _make_sut()
	# max(0.5 × 1.0, 0.30) = max(0.50, 0.30) = 0.50 — no clamp
	assert_almost_eq(sut.get_effective_dim_for_state(GameStateMachine.GameState.DISCONNECTED), 0.50, 0.0001,
		"AC-KNOB-B: DISCONNECTED effective_dim == 0.50 (no clamp)")


func test_compute_effective_dim_pure_static() -> void:
	# clamp on FINAL product (KNOB-A) — never back-solved into knobs
	assert_almost_eq(SUT.compute_effective_dim(0.5, 0.4, 0.30), 0.30, 0.0001,
		"AC-KNOB-B: static compute clamps final product")
	assert_almost_eq(SUT.compute_effective_dim(0.5, 1.0, 0.30), 0.50, 0.0001,
		"AC-KNOB-B: static compute no-clamp case")


# ── emphasis alpha 3-axis ──

func test_emphasis_alpha_three_axis() -> void:
	var sut := _make_sut()
	assert_gte(sut.get_emphasis_alpha(sut.Emphasis.EMPHASIS), sut.AMBIENT_ALPHA,
		"◉ emphasis alpha ≥ ambient (0.55) — fully visible")
	assert_almost_eq(sut.get_emphasis_alpha(sut.Emphasis.AMBIENT), 0.55, 0.0001,
		"○ ambient alpha == 0.55 (glance-readable)")
	assert_almost_eq(sut.get_emphasis_alpha(sut.Emphasis.DEEP_DIM), 0.22, 0.0001,
		"◐ deep-dim alpha == 0.22 (exits glance band)")


func test_emphasis_alpha_invariant_ordering() -> void:
	var sut := _make_sut()
	# Invariant: 0.22 < 0.35 < 0.55
	assert_true(sut.DEEP_DIM_ELEMENT_ALPHA < sut.DEEP_DIM_ALPHA_THRESHOLD,
		"invariant: deep_dim_element_alpha (0.22) < threshold (0.35)")
	assert_true(sut.DEEP_DIM_ALPHA_THRESHOLD < sut.AMBIENT_ALPHA,
		"invariant: threshold (0.35) < ambient_alpha (0.55)")


func test_hidden_and_defer_alpha_zero() -> void:
	var sut := _make_sut()
	assert_eq(sut.get_emphasis_alpha(sut.Emphasis.HIDDEN), 0.0,
		"— hidden → alpha 0 (not rendered)")
	assert_eq(sut.get_emphasis_alpha(sut.Emphasis.DEFER), 0.0,
		"▽ defer → alpha 0 (HUD yields, draws nothing)")


# ── EC-R6: deep-dim skip-tween + emphasis rise ──

func test_deep_dim_skips_tween_then_rises_on_emphasis() -> void:
	var sut := _make_sut()
	# Force EXP element to deep-dim, then a stat_changed must NOT create a tween (Story 003 mechanism).
	sut._element_emphasis[&"exp"] = sut.Emphasis.DEEP_DIM
	var stub := sut._stat_system as _StubStatSystem
	stub.emit_stat_changed(&"exp", 200.0)  # _current_exp set; _exp_to_next default 1.0 → fill clamps 1.0
	assert_eq(sut.get_active_tween_count(), 0,
		"EC-R6: deep-dim element stat_changed → value set, no tween")
	# Now raise emphasis ◐ → ○; effective alpha must rise from 0.22 to 0.55.
	var dim_alpha: float = sut.get_emphasis_alpha(sut.Emphasis.DEEP_DIM)
	sut._element_emphasis[&"exp"] = sut.Emphasis.AMBIENT
	var ambient_alpha: float = sut.get_emphasis_alpha(sut.get_element_emphasis(&"exp"))
	assert_gt(ambient_alpha, dim_alpha,
		"EC-R6: ◐→○ raises effective alpha (0.22 → 0.55), value already current (no replay)")


# ── AC-EC-S3: LOOT defer fallback ──

func test_loot_defer_alpha_and_no_loot_text() -> void:
	var sut := _make_sut()
	sut._apply_state_matrix(GameStateMachine.GameState.LOOT_DROP)
	# HP/EXP ○dim → ambient alpha; PROG ▽ → alpha 0 (defers to #21)
	assert_almost_eq(sut.get_emphasis_alpha(sut.get_element_emphasis(&"hp")), 0.55, 0.0001,
		"AC-EC-S3: LOOT_DROP HP ○dim → ambient alpha")
	assert_eq(sut.get_emphasis_alpha(sut.get_element_emphasis(&"prog")), 0.0,
		"AC-EC-S3: LOOT_DROP PROG ▽ defer → alpha 0 (HUD draws no loot)")
	# HUD owns no loot-text node — boss/stat/skills all hidden in LOOT_DROP.
	assert_eq(sut.get_element_emphasis(&"boss"), sut.Emphasis.HIDDEN,
		"AC-EC-S3: HUD never fabricates loot text (boss hidden, #21 owns ceremony)")
