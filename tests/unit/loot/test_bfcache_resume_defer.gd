## test_bfcache_resume_defer.gd — Story 005 AC-13
##
## Governing story: production/epics/loot-drop-system/story-005-formula-3-4-ttl-bfcache.md
## Governing ADR  : ADR-0003 (Accepted 2026-05-30) — bfcache resume handling
##
## AC-13: MID_REVEAL with suspend delta > 30,000ms → DEFER_TO_NEXT_BOOT.
## Also: PRE_REVEAL → always NO_ACTION (plays on next user gesture, any delta).
extends GutTest


func test_ac13_mid_reveal_45s_delta_defers_to_next_boot() -> void:
	# Arrange: delta = 45,000ms > 30,000 → DEFER_TO_NEXT_BOOT.
	var result := LootTtlCalc.bfcache_resume_action(
		LootEnums.DropRevealState.MID_REVEAL, 0, 45000
	)
	assert_eq(result, LootEnums.ResumeAction.DEFER_TO_NEXT_BOOT,
		"MID_REVEAL with 45s delta must return DEFER_TO_NEXT_BOOT (AC-13)")


func test_ac13_mid_reveal_30001ms_defers() -> void:
	# Edge case: delta = 30,001ms (one ms over threshold) → DEFER.
	var result := LootTtlCalc.bfcache_resume_action(
		LootEnums.DropRevealState.MID_REVEAL, 0, 30001
	)
	assert_eq(result, LootEnums.ResumeAction.DEFER_TO_NEXT_BOOT,
		"MID_REVEAL at 30,001ms must DEFER (> threshold, not ≤)")


func test_mid_reveal_very_long_suspension_defers() -> void:
	# 10 minutes backgrounded → definitely defer.
	var result := LootTtlCalc.bfcache_resume_action(
		LootEnums.DropRevealState.MID_REVEAL, 1000, 601000
	)
	assert_eq(result, LootEnums.ResumeAction.DEFER_TO_NEXT_BOOT,
		"MID_REVEAL with 10-minute suspension must DEFER_TO_NEXT_BOOT")


func test_pre_reveal_any_delta_no_action() -> void:
	# PRE_REVEAL → NO_ACTION regardless of delta (ceremony plays on next gesture).
	var result := LootTtlCalc.bfcache_resume_action(
		LootEnums.DropRevealState.PRE_REVEAL, 0, 1
	)
	assert_eq(result, LootEnums.ResumeAction.NO_ACTION,
		"PRE_REVEAL must always return NO_ACTION")


func test_pre_reveal_large_delta_still_no_action() -> void:
	var result := LootTtlCalc.bfcache_resume_action(
		LootEnums.DropRevealState.PRE_REVEAL, 0, 9999999
	)
	assert_eq(result, LootEnums.ResumeAction.NO_ACTION,
		"PRE_REVEAL with very large delta must still return NO_ACTION")


func test_pre_reveal_zero_delta_no_action() -> void:
	var result := LootTtlCalc.bfcache_resume_action(
		LootEnums.DropRevealState.PRE_REVEAL, 500, 500
	)
	assert_eq(result, LootEnums.ResumeAction.NO_ACTION,
		"PRE_REVEAL with 0ms delta must return NO_ACTION")


func test_unknown_drop_state_returns_no_action_fallback() -> void:
	# Unrecognised state (e.g. future enum member) → defensive fallback NO_ACTION.
	var result := LootTtlCalc.bfcache_resume_action(99, 0, 1000)
	assert_eq(result, LootEnums.ResumeAction.NO_ACTION,
		"Unrecognised drop_state must fall through to NO_ACTION (defensive fallback)")
