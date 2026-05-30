## test_inventory_overflow_boundary.gd — Story 007 AC-17
##
## Governing story: production/epics/loot-drop-system/story-007-formula-e1-e2-e4.md
## Governing ADR  : ADR-0005; GDD Pass 2 F-10 (MAX_INVENTORY raised 60→120)
##
## AC-17: inventory_overflow_to_mailbox() uses MAX_INVENTORY=120.
## current_size < 120 → DIRECT_INVENTORY; current_size ≥ 120 → MAILBOX_OVERFLOW.
##
## NOTE: AC-17 text in story says "size=61 → MAILBOX" which was written when
## MAX_INVENTORY=60 (pre-Pass-2 F-10). Implementation Notes correctly say MAX=120.
## Tests follow the Implementation Notes (MAX=120) as the authoritative source.
## This discrepancy is flagged as ADVISORY in story-done.
extends GutTest


# ── AC-17: boundary at MAX_INVENTORY=120 ───────────────────────────────────────

func test_ac17_size_119_returns_direct_inventory() -> void:
	var result := LootItemCalc.inventory_overflow_to_mailbox(119)
	assert_eq(result, LootEnums.OverflowMode.DIRECT_INVENTORY,
		"AC-17: size=119 (< MAX_INVENTORY=120) must return DIRECT_INVENTORY")


func test_ac17_size_120_returns_mailbox_overflow() -> void:
	# Boundary: 120 ≥ MAX_INVENTORY → MAILBOX.
	var result := LootItemCalc.inventory_overflow_to_mailbox(120)
	assert_eq(result, LootEnums.OverflowMode.MAILBOX_OVERFLOW,
		"AC-17: size=120 (= MAX_INVENTORY) must return MAILBOX_OVERFLOW (boundary inclusive)")


func test_ac17_size_60_returns_direct_inventory() -> void:
	# Confirms old MAX=60 behaviour is now DIRECT (not MAILBOX) since MAX=120.
	var result := LootItemCalc.inventory_overflow_to_mailbox(60)
	assert_eq(result, LootEnums.OverflowMode.DIRECT_INVENTORY,
		"size=60 must return DIRECT_INVENTORY (MAX_INVENTORY=120, not 60 — GDD Pass 2 F-10)")


func test_ac17_size_61_returns_direct_inventory() -> void:
	# Story AC-17 text (stale) said 61 → MAILBOX (written when MAX=60).
	# Implementation Notes say MAX=120 → 61 → DIRECT. Implementation Notes win.
	var result := LootItemCalc.inventory_overflow_to_mailbox(61)
	assert_eq(result, LootEnums.OverflowMode.DIRECT_INVENTORY,
		"size=61 must return DIRECT_INVENTORY (MAX=120, AC-17 text was stale at MAX=60)")


# ── Edge cases ────────────────────────────────────────────────────────────────

func test_size_0_returns_direct_inventory() -> void:
	var result := LootItemCalc.inventory_overflow_to_mailbox(0)
	assert_eq(result, LootEnums.OverflowMode.DIRECT_INVENTORY,
		"size=0 (empty inventory) must return DIRECT_INVENTORY")


func test_size_1_returns_direct_inventory() -> void:
	var result := LootItemCalc.inventory_overflow_to_mailbox(1)
	assert_eq(result, LootEnums.OverflowMode.DIRECT_INVENTORY,
		"size=1 must return DIRECT_INVENTORY")


func test_large_size_above_max_returns_mailbox() -> void:
	var result := LootItemCalc.inventory_overflow_to_mailbox(200)
	assert_eq(result, LootEnums.OverflowMode.MAILBOX_OVERFLOW,
		"size=200 (> MAX_INVENTORY) must return MAILBOX_OVERFLOW")


func test_max_inventory_constant_is_120() -> void:
	# Pin the constant — if it changes, this test catches it and forces a review.
	assert_eq(LootItemCalc.MAX_INVENTORY, 120,
		"MAX_INVENTORY must be 120 (GDD Pass 2 F-10 raise from 60)")


func test_direct_inventory_ordinal_is_zero() -> void:
	# ADR-0007 Family A: DIRECT_INVENTORY (ordinal 0) is the safe default.
	assert_eq(LootEnums.OverflowMode.DIRECT_INVENTORY, 0,
		"DIRECT_INVENTORY must be ordinal 0 (Family A safe default)")
