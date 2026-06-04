## Unit test — GymModeHud Story 011 (logic portion): min visual floors + REST cockpit caps
##
## Covers ONLY the self-contained logic AC. The visual/playtest AC (AC-V-1 tachistoscope,
## AC-UX-6/V-5 colorblind, AC-V-2/CR-1 shake readability) are headless-unverifiable and require
## a built HUD .tscn + external human playtest — DEFERRED, tracked in Story 011 completion notes.
##
## Coverage:
##   AC-UX-5     — EXP bar height = max(round(hp×0.5×dpr), min_bar_height)
##   AC-U-6      — effective font = max(base × text_scale, min_font); text_scale 0.8 holds the floor
##   AC-UX-10/U-2 — REST cockpit SKILLS list bounded at REST_SKILLS_LIST_CAP; STAT block cap
##   AC-UX-8     — banner touch target floor const (44 CSS px)
extends GutTest

const SUT := preload("res://src/ui/gym_mode_hud/gym_mode_hud.gd")


func _make_sut() -> SUT:
	var sut: SUT = SUT.new()
	add_child_autofree(sut)
	return sut


# ── AC-UX-5: EXP bar height floor ──

func test_exp_bar_height_floor_active_at_low_dpr() -> void:
	# hp=6, dpr=1 → round(3.0)=3 < 4 → floored to MIN_BAR_HEIGHT_PX (4)
	assert_eq(SUT.compute_exp_bar_height(6.0, 1.0, 4.0), 4.0,
		"AC-UX-5: EXP height floors at min_bar_height (4) when half-HP×dpr is below it")


func test_exp_bar_height_scales_with_dpr() -> void:
	# hp=6, dpr=2 → round(6.0)=6 > 4 → no floor
	assert_eq(SUT.compute_exp_bar_height(6.0, 2.0, 4.0), 6.0,
		"AC-UX-5: EXP height = round(hp×0.5×dpr) when above floor")


# ── AC-U-6: font floor ──

func test_font_size_normal_scale() -> void:
	assert_eq(SUT.compute_effective_font_size(10.0, 1.0, 7.0), 10.0,
		"AC-U-6: font = base when text_scale 1.0")


func test_font_size_floor_holds_at_small_scale() -> void:
	# base=8, scale=0.8 → 6.4 < 7 → floored to 7
	assert_eq(SUT.compute_effective_font_size(8.0, 0.8, 7.0), 7.0,
		"AC-U-6: text_scale 0.8 must not push font below the hard floor (7)")


func test_font_size_scales_when_above_floor() -> void:
	# base=10, scale=0.8 → 8.0 > 7 → no floor
	assert_eq(SUT.compute_effective_font_size(10.0, 0.8, 7.0), 8.0,
		"AC-U-6: font scales down to 8.0 (still above floor)")


# ── AC-UX-10 / AC-U-2: REST cockpit bound ──

func test_rest_skills_list_bounded() -> void:
	var sut := _make_sut()
	# All 9 canonical abilities unlocked → REST list shows at most REST_SKILLS_LIST_CAP (8) + scroll.
	var all_nine: Array = [
		&"strike_tier_1_jab", &"strike_tier_2_hook", &"strike_tier_3_overhand",
		&"control_tier_1_parry", &"control_tier_2_hook_pull", &"control_tier_3_grapple",
		&"mobility_tier_1_dash", &"mobility_tier_2_leap", &"mobility_tier_3_ground_pound",
	]
	var rest_list: Array = sut.get_rest_skills_display(all_nine)
	assert_eq(rest_list.size(), sut.REST_SKILLS_LIST_CAP,
		"AC-UX-10/U-2: REST SKILLS list bounded at REST_SKILLS_LIST_CAP (8), not infinite")


func test_rest_skills_list_larger_than_boss_glance_cap() -> void:
	var sut := _make_sut()
	# REST focus-layer cap (8) is distinct from (and larger than) the BOSS glance cap (4).
	assert_gt(sut.REST_SKILLS_LIST_CAP, sut.SKILL_CLUSTER_DISPLAY_CAP,
		"AC-UX-10: REST focus-layer list cap (8) > BOSS glance cap (4) — different contexts")


func test_rest_stat_block_cap() -> void:
	var sut := _make_sut()
	assert_eq(sut.REST_STAT_BLOCK_CAP, 3,
		"AC-U-2: REST STAT block capped at 3")


# ── AC-UX-8: touch target floor ──

func test_banner_touch_target_floor() -> void:
	var sut := _make_sut()
	assert_gte(sut.BANNER_TOUCH_TARGET_PX, 44.0,
		"AC-UX-8: banner touch target ≥ 44×44 CSS px")
