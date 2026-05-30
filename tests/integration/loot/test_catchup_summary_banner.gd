## test_catchup_summary_banner.gd — Story 006 AC-18
##
## Governing story: production/epics/loot-drop-system/story-006-formula-5-6-reconcile-catchup.md
## Governing ADR  : ADR-0003 (Accepted 2026-05-30)
##
## AC-18: catch_up_threshold_compression(count ≥ 5) returns SUMMARY_BANNER_THEN_BURST.
## Simulates a player returning after several missed days with many pending drops.
##
## NOTE: Formula 6 is a pure static function — these tests call it directly.
## "Integration" label reflects the scenario context (multi-day catch-up state)
## rather than a dependency on the live autoload.
extends GutTest


func test_ac18_eight_pending_returns_summary_banner() -> void:
	# AC-18: 8 pending unrevealed drops (> CATCH_UP_THRESHOLD=5) → summary mode.
	var result := LootReconcileCalc.catch_up_threshold_compression(8)
	assert_eq(result, LootEnums.CatchUpMode.SUMMARY_BANNER_THEN_BURST,
		"8 pending drops must return SUMMARY_BANNER_THEN_BURST (AC-18)")


func test_ac18_boundary_exactly_five_returns_summary_banner() -> void:
	# Edge case: exactly 5 → SUMMARY_BANNER_THEN_BURST (≥ 5, not > 5).
	var result := LootReconcileCalc.catch_up_threshold_compression(5)
	assert_eq(result, LootEnums.CatchUpMode.SUMMARY_BANNER_THEN_BURST,
		"Exactly 5 pending must return SUMMARY_BANNER_THEN_BURST (boundary inclusive)")


func test_ac18_large_pending_count_returns_summary_banner() -> void:
	# Player missed 2 weeks → many drops accumulated.
	var result := LootReconcileCalc.catch_up_threshold_compression(14)
	assert_eq(result, LootEnums.CatchUpMode.SUMMARY_BANNER_THEN_BURST,
		"14 pending drops must return SUMMARY_BANNER_THEN_BURST")


func test_ac18_six_pending_returns_summary_banner() -> void:
	var result := LootReconcileCalc.catch_up_threshold_compression(6)
	assert_eq(result, LootEnums.CatchUpMode.SUMMARY_BANNER_THEN_BURST,
		"6 pending drops must return SUMMARY_BANNER_THEN_BURST")
