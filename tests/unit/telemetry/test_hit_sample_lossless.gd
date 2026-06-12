# Telemetry (#28) — Story 005: Formula 3 hit-sample + Formula 4 lossless aggregate.
#
# Verifies:
#   AC-1  hit_sample_keep keeps stride positions + any force_keep; k<=0 / k=1 → full keep.
#   AC-2  CombatAggregate is lossless: total_hits == real hit count regardless of stride;
#         crit_count == real crit count; Σtier_counts == total_hits.
#   AC-3  determinism: same input sequence → identical output, twice.
#   AC-4  crit override at a non-stride position (i=7, force_keep) → keep.
extends GutTest

const F := preload("res://src/telemetry/telemetry_formulas.gd")


# --- AC-1 / AC-4: Formula 3 sampling ------------------------------------------

func test_sample_keeps_stride_positions() -> void:
	assert_true(F.hit_sample_keep(0, 10, false), "i=0 is a stride position")
	assert_true(F.hit_sample_keep(10, 10, false), "i=10 is a stride position")
	assert_true(F.hit_sample_keep(20, 10, false), "i=20 is a stride position")
	assert_false(F.hit_sample_keep(7, 10, false), "i=7 not a stride position, no force")
	assert_false(F.hit_sample_keep(13, 10, false), "i=13 not a stride position")


func test_force_keep_overrides_at_non_stride_position() -> void:
	# AC-4 / AC-06: a crit (force_keep) at i=7 (non-stride) is still kept.
	assert_true(F.hit_sample_keep(7, 10, true), "force_keep overrides non-stride position")
	assert_true(F.hit_sample_keep(3, 100, true), "force_keep always wins")


func test_stride_zero_or_one_means_full_keep() -> void:
	# k<=0 guard → treated as 1 → every hit kept (mod-0 guard).
	assert_true(F.hit_sample_keep(5, 0, false), "k=0 → full keep (no mod-0 crash)")
	assert_true(F.hit_sample_keep(5, -3, false), "k<0 → full keep")
	assert_true(F.hit_sample_keep(0, 1, false), "k=1 → every hit kept")
	assert_true(F.hit_sample_keep(999, 1, false), "k=1 → every hit kept")


# --- AC-2: Formula 4 lossless aggregate ---------------------------------------

func test_aggregate_is_lossless_regardless_of_stride() -> void:
	# 100 hits, stride 10, every 3rd is a crit. total_hits MUST be 100, never ~10.
	var agg := CombatAggregate.new()
	var stride := 10
	var kept := 0
	var real_crits := 0
	for i in range(100):
		var is_crit := (i % 3 == 0)
		var tier := i % 4  # 4 distinct damage tiers
		# sampling decides individual-event buffering...
		if F.hit_sample_keep(i, stride, is_crit):
			kept += 1
		# ...but the accumulator updates for EVERY hit (lossless).
		agg.accumulate(10 + i, is_crit, tier)
		if is_crit:
			real_crits += 1

	assert_eq(agg.total_hits, 100, "AC-07: total_hits == real hit count (not sampled)")
	assert_eq(agg.crit_count, real_crits, "crit_count == real crit count")
	assert_eq(agg.tier_total(), 100, "Σtier_counts == total_hits (lossless)")
	assert_lt(kept, 100, "sampling DID drop some individual events (proves decoupling)")
	assert_gt(kept, 0, "sampling kept some")


func test_aggregate_tiers_and_damage_sum() -> void:
	var agg := CombatAggregate.new()
	agg.accumulate(100, false, 0)
	agg.accumulate(200, true, 1)
	agg.accumulate(50, false, 0)
	assert_eq(agg.total_hits, 3, "3 hits")
	assert_eq(agg.total_damage, 350, "100+200+50")
	assert_eq(agg.crit_count, 1, "one crit")
	assert_eq(agg.tier_counts[0], 2, "tier 0 hit twice")
	assert_eq(agg.tier_counts[1], 1, "tier 1 hit once")
	assert_eq(agg.tier_total(), 3, "tier sum == total_hits")


func test_aggregate_reset_clears_all() -> void:
	var agg := CombatAggregate.new()
	agg.accumulate(100, true, 2)
	agg.reset()
	assert_eq(agg.total_hits, 0, "reset clears total_hits")
	assert_eq(agg.total_damage, 0, "reset clears total_damage")
	assert_eq(agg.crit_count, 0, "reset clears crit_count")
	assert_eq(agg.tier_total(), 0, "reset clears tier_counts")


# --- AC-3: determinism --------------------------------------------------------

func test_determinism_same_input_same_output() -> void:
	var seq := [[0, false, 0], [7, true, 1], [10, false, 2], [13, true, 0], [20, false, 3]]
	var d1 := _run_sequence(seq)
	var d2 := _run_sequence(seq)
	assert_eq(d1, d2, "AC-3: identical input sequence → identical aggregate output")


func _run_sequence(seq: Array) -> Dictionary:
	var agg := CombatAggregate.new()
	var keeps: Array = []
	for entry in seq:
		var i: int = entry[0]
		var is_crit: bool = entry[1]
		var tier: int = entry[2]
		keeps.append(F.hit_sample_keep(i, 10, is_crit))
		agg.accumulate(10, is_crit, tier)
	var out := agg.to_dict()
	out["keeps"] = keeps
	return out
