# BossRegistry spawn selection + effort gate (Story 008:
# AC-02 / AC-03 / AC-04 / AC-10 / AC-13 + EC-22 / EC-03). Pure + deterministic.
extends GutTest

const STRIKE := 0
const CONTROL := 1
const MOBILITY := 2
const UNKNOWN := 3


func _final(cls: int, id: StringName) -> BossTemplate:
	var t := BossTemplate.new()
	t.class_archetype = cls
	t.boss_id = id
	t.tier = BossTemplate.BossTier.FINAL
	return t


func _registry(templates: Array) -> BossRegistry:
	var r := BossRegistry.new()
	r.final_templates.assign(templates)
	return r


# ---------------------------------------------------------------------------
# AC-03 / AC-10 — effort gate (DD#2)
# ---------------------------------------------------------------------------

func test_ac10_low_effort_returns_null_for_mini_path() -> void:
	var r := _registry([_final(STRIKE, &"S1")])
	var sel := r.select_final_template(STRIKE, 0.10, "txn")
	assert_null(sel, "AC-10: effort 0.10 < threshold -> null (#16 skips, #14 mini path)")


func test_ac03_high_effort_spawns_final() -> void:
	var r := _registry([_final(STRIKE, &"S1")])
	var sel := r.select_final_template(STRIKE, 0.50, "txn")
	assert_not_null(sel, "AC-03: effort 0.50 >= threshold -> FINAL template")
	assert_eq(sel.boss_id, &"S1", "selected the STRIKE final template")


func test_ec22_threshold_boundary_spawns_final() -> void:
	var r := _registry([_final(STRIKE, &"S1")])
	var sel := r.select_final_template(STRIKE, BossRegistry.MINI_BOSS_EFFORT_THRESHOLD, "txn")
	assert_not_null(sel, "EC-22: effort == threshold -> FINAL (strict-less-than for mini)")


# ---------------------------------------------------------------------------
# AC-04 / AC-13 — class archetype mapping + UNKNOWN -> STRIKE
# ---------------------------------------------------------------------------

func test_ac04_class_archetype_routing() -> void:
	var r := _registry([_final(STRIKE, &"S1"), _final(CONTROL, &"C1"), _final(MOBILITY, &"M1")])
	assert_eq(r.select_final_template(STRIKE, 0.5, "t").boss_id, &"S1", "STRIKE -> STRIKE template")
	assert_eq(r.select_final_template(CONTROL, 0.5, "t").boss_id, &"C1", "CONTROL -> CONTROL template")
	assert_eq(r.select_final_template(MOBILITY, 0.5, "t").boss_id, &"M1", "MOBILITY -> MOBILITY template")


func test_ac13_unknown_falls_back_to_strike() -> void:
	var r := _registry([_final(STRIKE, &"S1"), _final(CONTROL, &"C1")])
	var sel := r.select_final_template(UNKNOWN, 0.5, "t")
	assert_eq(sel.boss_id, &"S1", "AC-13/Rule 13: UNKNOWN -> STRIKE fallback (never fabricated)")


# ---------------------------------------------------------------------------
# AC-02 — determinism
# ---------------------------------------------------------------------------

func test_ac02_same_inputs_same_template() -> void:
	var r := _registry([_final(STRIKE, &"S1"), _final(STRIKE, &"S2")])
	var a := r.select_final_template(STRIKE, 0.5, "abc123")
	var b := r.select_final_template(STRIKE, 0.5, "abc123")
	assert_eq(a.boss_id, b.boss_id, "AC-02: same (transition_id, class) -> same template")


# ---------------------------------------------------------------------------
# EC-03 — empty registry / missing class
# ---------------------------------------------------------------------------

func test_ec03_missing_class_falls_back_then_null() -> void:
	# Only CONTROL exists; requesting CONTROL with no STRIKE either -> after STRIKE
	# fallback also empty -> null.
	var r := _registry([_final(CONTROL, &"C1")])
	assert_eq(r.select_final_template(CONTROL, 0.5, "t").boss_id, &"C1", "CONTROL present -> returns it")
	# MOBILITY missing -> STRIKE fallback also missing -> null
	assert_null(r.select_final_template(MOBILITY, 0.5, "t"),
		"EC-03: missing class + no STRIKE fallback -> null (#14 handles)")


func test_query_final_filters_by_class() -> void:
	var r := _registry([_final(STRIKE, &"S1"), _final(STRIKE, &"S2"), _final(CONTROL, &"C1")])
	assert_eq(r.query_final(STRIKE).size(), 2, "query_final STRIKE -> 2")
	assert_eq(r.query_final(CONTROL).size(), 1, "query_final CONTROL -> 1")
	assert_eq(r.query_final(MOBILITY).size(), 0, "query_final MOBILITY -> 0")
