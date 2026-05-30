## test_catchup_sequential.gd — Story 006 AC-19
##
## Governing story: production/epics/loot-drop-system/story-006-formula-5-6-reconcile-catchup.md
## Governing ADR  : ADR-0003 (Accepted 2026-05-30)
##
## AC-19: catch_up_threshold_compression(count < 5) returns SEQUENTIAL_REVEAL.
## Simulates a player returning after 1-2 missed days with few pending drops;
## each drop gets its own full ceremony in trigger-timestamp ASC order.
##
## NOTE: Formula 6 is a pure static function — these tests call it directly.
## "Integration" label reflects the scenario context (catch-up reveal session)
## rather than a dependency on the live autoload.
extends GutTest


func test_ac19_three_pending_returns_sequential_reveal() -> void:
	# AC-19: 3 pending drops (< 5) → sequential reveal mode.
	var result := LootReconcileCalc.catch_up_threshold_compression(3)
	assert_eq(result, LootEnums.CatchUpMode.SEQUENTIAL_REVEAL,
		"3 pending drops must return SEQUENTIAL_REVEAL (AC-19)")


func test_ac19_boundary_four_pending_returns_sequential_reveal() -> void:
	# Edge case: 4 pending → SEQUENTIAL_REVEAL (4 < 5).
	var result := LootReconcileCalc.catch_up_threshold_compression(4)
	assert_eq(result, LootEnums.CatchUpMode.SEQUENTIAL_REVEAL,
		"4 pending drops must return SEQUENTIAL_REVEAL (one below threshold)")


func test_ac19_zero_pending_returns_sequential_reveal() -> void:
	# Player just logged in — no missed drops.
	var result := LootReconcileCalc.catch_up_threshold_compression(0)
	assert_eq(result, LootEnums.CatchUpMode.SEQUENTIAL_REVEAL,
		"0 pending drops must return SEQUENTIAL_REVEAL")


func test_ac19_one_pending_returns_sequential_reveal() -> void:
	var result := LootReconcileCalc.catch_up_threshold_compression(1)
	assert_eq(result, LootEnums.CatchUpMode.SEQUENTIAL_REVEAL,
		"1 pending drop must return SEQUENTIAL_REVEAL")


func test_ac19_two_pending_returns_sequential_reveal() -> void:
	var result := LootReconcileCalc.catch_up_threshold_compression(2)
	assert_eq(result, LootEnums.CatchUpMode.SEQUENTIAL_REVEAL,
		"2 pending drops must return SEQUENTIAL_REVEAL")


func test_ac19_sequential_reveal_ordinal_is_zero() -> void:
	# ADR-0007 Family A: SEQUENTIAL_REVEAL (ordinal 0) is the safe default.
	assert_eq(LootEnums.CatchUpMode.SEQUENTIAL_REVEAL, 0,
		"SEQUENTIAL_REVEAL must be ordinal 0 (Family A safe default)")


func test_ac19_summary_banner_ordinal_is_one() -> void:
	assert_eq(LootEnums.CatchUpMode.SUMMARY_BANNER_THEN_BURST, 1,
		"SUMMARY_BANNER_THEN_BURST must be ordinal 1")
