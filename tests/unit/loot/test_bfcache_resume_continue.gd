## test_bfcache_resume_continue.gd — Story 005 AC-12
##
## Governing story: production/epics/loot-drop-system/story-005-formula-3-4-ttl-bfcache.md
## Governing ADR  : ADR-0003 (Accepted 2026-05-30) — bfcache resume handling
##
## AC-12: MID_REVEAL with suspend delta ≤ 30,000ms → CONTINUE_ANIMATION.
## Also: POST_REVEAL_PRE_HANDOFF → always CONTINUE_ANIMATION (finalize handoff).
extends GutTest


func test_ac12_mid_reveal_12s_delta_continues_animation() -> void:
	# Arrange: suspended at 1000ms, resumed at 13000ms → delta = 12,000ms ≤ 30,000.
	var result := LootTtlCalc.bfcache_resume_action(
		LootEnums.DropRevealState.MID_REVEAL, 1000, 13000
	)
	assert_eq(result, LootEnums.ResumeAction.CONTINUE_ANIMATION,
		"MID_REVEAL with 12s delta must return CONTINUE_ANIMATION (AC-12)")


func test_ac12_mid_reveal_exactly_30s_threshold_continues() -> void:
	# Edge case: delta = 30,000ms exactly (≤ threshold) → CONTINUE_ANIMATION.
	var result := LootTtlCalc.bfcache_resume_action(
		LootEnums.DropRevealState.MID_REVEAL, 0, 30000
	)
	assert_eq(result, LootEnums.ResumeAction.CONTINUE_ANIMATION,
		"MID_REVEAL at exactly 30s threshold must CONTINUE (≤ not <)")


func test_mid_reveal_zero_delta_continues() -> void:
	# Instantaneous resume → absolutely continues.
	var result := LootTtlCalc.bfcache_resume_action(
		LootEnums.DropRevealState.MID_REVEAL, 5000, 5000
	)
	assert_eq(result, LootEnums.ResumeAction.CONTINUE_ANIMATION,
		"MID_REVEAL with 0ms delta must CONTINUE_ANIMATION")


func test_post_reveal_pre_handoff_always_continues() -> void:
	# POST_REVEAL_PRE_HANDOFF → always CONTINUE regardless of delta.
	# Test with large delta to confirm it is state-driven, not delta-driven.
	var result := LootTtlCalc.bfcache_resume_action(
		LootEnums.DropRevealState.POST_REVEAL_PRE_HANDOFF, 0, 999999
	)
	assert_eq(result, LootEnums.ResumeAction.CONTINUE_ANIMATION,
		"POST_REVEAL_PRE_HANDOFF must always CONTINUE_ANIMATION (finalize #17 handoff)")


func test_post_reveal_pre_handoff_with_zero_delta_continues() -> void:
	var result := LootTtlCalc.bfcache_resume_action(
		LootEnums.DropRevealState.POST_REVEAL_PRE_HANDOFF, 100, 100
	)
	assert_eq(result, LootEnums.ResumeAction.CONTINUE_ANIMATION,
		"POST_REVEAL_PRE_HANDOFF with 0ms delta must CONTINUE_ANIMATION")


func test_bfcache_continue_threshold_constant() -> void:
	assert_eq(LootTtlCalc.BFCACHE_CONTINUE_THRESHOLD_MS, 30000,
		"BFCACHE_CONTINUE_THRESHOLD_MS must be 30,000 ms (30s per GDD Rule 17)")
