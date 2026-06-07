extends GutTest
## Story 004 — F1 timeline budget + unified timing model + motion_reduction.
## Covers AC-38 / AC-39 / AC-40 / AC-41 (AC-55 EC-M4 full matrix moved to
## story 006 — its assert targets are the ladder calls that land there).
##
## GDD: design/gdd/loot-drop-modal.md F1 + 統一 timing model.

const CoordinatorScript := preload("res://src/autoload/loot_reveal_coordinator.gd")

const S := CoordinatorScript.ModalState
const LEGENDARY: int = LootEnums.RarityTier.LEGENDARY

## Pinned F1 golden table (GDD per-tier timeline — sum column).
const T_BLOCK_DEFAULT: Array[int] = [200, 350, 650, 950, 1200]
const T_BLOCK_MOTION_REDUCTION: Array[int] = [200, 350, 500, 650, 800]


func _default_config() -> LootRevealTimingConfig:
	return LootRevealTimingConfig.new()


# --- AC-38: golden table + ceiling assert is `<=` (LEGENDARY equality passes) ---

func test_default_config_t_block_matches_golden_table() -> void:
	var config := _default_config()
	for tier: int in range(5):
		assert_eq(
			LootRevealFormulas.t_block_ms(config, tier),
			T_BLOCK_DEFAULT[tier],
			"T_block tier %d == %dms (F1 golden)" % [tier, T_BLOCK_DEFAULT[tier]])


func test_default_config_passes_validation_legendary_touches_ceiling() -> void:
	var config := _default_config()
	assert_eq(config.validate(), Array([], TYPE_STRING, &"", null), "defaults valid — 1200 == 1200 ceiling passes (<=)")
	assert_eq(LootRevealFormulas.t_block_ms(config, LEGENDARY), 1200, "equality reachable")


func test_ceiling_overrun_fails_validation() -> void:
	var config := _default_config()
	config.timestop_ms[LEGENDARY] = 401  # 800 + 401 = 1201 > 1200
	var errors: Array[String] = config.validate()
	assert_false(errors.is_empty(), "T_block 1201 must fail the <= ceiling")


# --- AC-39: C1-violating config fails data-load; NO runtime clamp anywhere ---

func test_c1_violation_fails_validation_and_is_never_clamped() -> void:
	var config := _default_config()
	config.entry_ms[LEGENDARY] = 1300  # > hold 800 + timestop 400 = 1200
	var errors: Array[String] = config.validate()
	assert_false(errors.is_empty(), "C1 violation must fail validation")
	var joined: String = " | ".join(errors)
	assert_string_contains(joined, "C1", "error names the violated constraint")
	# No clamp: the formula reports the raw (illegal) value — flattening the
	# ladder silently is the failure mode F1 forbids.
	assert_eq(LootRevealFormulas.t_block_ms(config, LEGENDARY), 1300, "no runtime clamp (raw max reported)")


func test_coordinator_refuses_reveal_on_invalid_config() -> void:
	var bad := _default_config()
	bad.entry_ms[LEGENDARY] = 1300
	var c: Node = CoordinatorScript.new()
	c._timing_config = bad
	add_child_autofree(c)
	c._state = S.HIDDEN
	c._open_reveal_flow()
	assert_eq(c.get_fsm_state(), S.HIDDEN, "invalid config → reveal refused (fail loud, no clamp)")


# --- AC-40: non-additive — three tracks share T=0; LEGENDARY T_block == 1200 ---

func test_legendary_timeline_is_concurrent_not_additive() -> void:
	var c: Node = CoordinatorScript.new()
	add_child_autofree(c)
	c._state = S.HIDDEN
	c._in_catchup = false
	assert_true(c._transition(S.ENTRY))
	c._begin_reveal(LEGENDARY)
	# Exact dyadic deltas — no float drift across the boundary checks.
	c._process(0.5)   # clock 500ms ≥ entry 450 → CEREMONY (S1 done, S2 running)
	assert_eq(c.get_fsm_state(), S.CEREMONY, "content final @ 450ms — entry overlaps S2 from T=0")
	c._process(0.5)   # clock 1000ms — still inside S2 (< 1200)
	assert_eq(c.get_fsm_state(), S.CEREMONY, "1000ms < T_block 1200 — still ceremony")
	c._process(0.25)  # clock 1250ms ≥ 1200 → STEADY
	assert_eq(c.get_fsm_state(), S.STEADY,
		"S3 reached at 1200ms, NOT 1650ms — additive reading would still be mid-ceremony at 1250ms")


func test_clock_only_accumulates_during_entry_and_ceremony() -> void:
	var c: Node = CoordinatorScript.new()
	add_child_autofree(c)
	c._process(1.0)
	assert_eq(c.get_reveal_clock_ms(), 0.0, "HIDDEN — clock parked")
	c._state = S.STEADY
	c._process(1.0)
	assert_eq(c.get_reveal_clock_ms(), 0.0, "STEADY — clock parked (S3 is tap-paced, unbounded)")


# --- AC-41: motion_reduction variant — timestop 0, ladder monotonic ---

func test_motion_reduction_t_block_table_and_monotonicity() -> void:
	var config := _default_config()
	var prev: int = -1
	for tier: int in range(5):
		var t: int = LootRevealFormulas.t_block_ms(config, tier, true)
		assert_eq(t, T_BLOCK_MOTION_REDUCTION[tier],
			"motion_reduction T_block tier %d == %dms" % [tier, T_BLOCK_MOTION_REDUCTION[tier]])
		assert_gt(t, prev, "ladder monotonicity preserved under motion_reduction")
		prev = t


func test_motion_reduction_drives_coordinator_timeline() -> void:
	var c: Node = CoordinatorScript.new()
	c._motion_reduction = true
	add_child_autofree(c)
	c._state = S.HIDDEN
	assert_true(c._transition(S.ENTRY))
	c._begin_reveal(LEGENDARY)
	c._process(0.5)   # 500ms ≥ entry 450 → CEREMONY
	c._process(0.25)  # 750ms < 800
	assert_eq(c.get_fsm_state(), S.CEREMONY, "750ms < motion_reduction T_block 800")
	c._process(0.0625)  # 812.5ms ≥ 800 → STEADY
	assert_eq(c.get_fsm_state(), S.STEADY, "motion_reduction LEGENDARY blocks only 800ms")


# --- Tuning Knobs flash budget (data-load assert) ---

func test_flash_budget_violation_fails_validation() -> void:
	var config := _default_config()
	config.exit_anim_sec = 0.1
	config.inter_reveal_gap_sec = 0.2  # cycle = 0.2 + 0.1 + 0.2 = 0.5s → 4 flash/s
	var errors: Array[String] = config.validate()
	assert_false(errors.is_empty(), "2 transients / 0.5s cycle = 4/s > 3/s must fail")
	assert_string_contains(" | ".join(errors), "flash budget")
