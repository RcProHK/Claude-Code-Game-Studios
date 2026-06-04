## Unit test — GymModeHud Story 009: glance Tier-1 count + alpha invariant (CI-tool logic)
##
## Verifies the same logic the CI tool (tools/ci/check_glance_tier1_count.gd) enforces, plus
## that the tool file exists as the epic deliverable.
##
## Coverage:
##   AC-U-3 — per-state exact count: WORKOUT_ACTIVE==3, COMBAT_ACTIVE==3, BOSS_ENCOUNTER==4
##   AC-U-3 scope — counted states only; matrix rows for exempt states are not exact-gated
##   B7 alpha invariant — deep_dim < threshold < ambient
##
## Deferred (need the HUD .tscn which is not built yet — flagged in Story 009 completion notes):
##   AC-U-3 cluster metadata (glance_group / cluster_icon_cap) · AC-UX-3 0px anchor
extends GutTest

const SUT := preload("res://src/ui/gym_mode_hud/gym_mode_hud.gd")
const CI_TOOL_PATH := "res://tools/ci/check_glance_tier1_count.gd"


func _make_sut() -> SUT:
	var sut: SUT = SUT.new()
	add_child_autofree(sut)
	return sut


# ── AC-U-3: per-state exact count ──

func test_workout_active_glance_count_is_three() -> void:
	var sut := _make_sut()
	assert_eq(sut.get_glance_tier1_count(GameStateMachine.GameState.WORKOUT_ACTIVE), 3,
		"AC-U-3: WORKOUT_ACTIVE glance Tier-1 count == 3 (HP+EXP+PROG; STAT/SKILLS deep-dim excluded)")


func test_combat_active_glance_count_is_three() -> void:
	var sut := _make_sut()
	assert_eq(sut.get_glance_tier1_count(GameStateMachine.GameState.COMBAT_ACTIVE), 3,
		"AC-U-3: COMBAT_ACTIVE glance Tier-1 count == 3 (mirrors WORKOUT_ACTIVE)")


func test_boss_encounter_glance_count_is_four() -> void:
	var sut := _make_sut()
	assert_eq(sut.get_glance_tier1_count(GameStateMachine.GameState.BOSS_ENCOUNTER), 4,
		"AC-U-3: BOSS_ENCOUNTER glance Tier-1 count == 4 (HP+EXP+SKILLS+BOSS; STAT/PROG deep-dim) — R8 B8")


func test_counted_states_within_tier1_max() -> void:
	var sut := _make_sut()
	for state in [
		GameStateMachine.GameState.WORKOUT_ACTIVE,
		GameStateMachine.GameState.COMBAT_ACTIVE,
		GameStateMachine.GameState.BOSS_ENCOUNTER,
	]:
		assert_lte(sut.get_glance_tier1_count(state), sut.GLANCE_TIER1_MAX,
			"AC-U-3: counted state %d within GLANCE_TIER1_MAX (≤5)" % state)


func test_exact_count_catches_stat_promotion_regression() -> void:
	# If a future edit wrongly promoted STAT from ◐ to ○ in WORKOUT_ACTIVE, count would be 4.
	# This test pins the exact value so that regression fails CI (exact, not ≤5).
	var sut := _make_sut()
	var count: int = sut.get_glance_tier1_count(GameStateMachine.GameState.WORKOUT_ACTIVE)
	assert_ne(count, 4,
		"AC-U-3: WORKOUT_ACTIVE must NOT be 4 — STAT/SKILLS staying deep-dim is the contract")
	assert_eq(count, 3, "AC-U-3: exact 3, not merely ≤5")


# ── B7 alpha invariant ──

func test_alpha_invariants_hold() -> void:
	assert_true(SUT.alpha_invariants_hold(),
		"B7: deep_dim(0.22) < threshold(0.35) < ambient(0.55) invariant holds")


# ── CI tool deliverable exists ──

func test_ci_tool_file_exists() -> void:
	assert_true(ResourceLoader.exists(CI_TOOL_PATH) or FileAccess.file_exists(CI_TOOL_PATH),
		"Story 009 deliverable: tools/ci/check_glance_tier1_count.gd exists")
