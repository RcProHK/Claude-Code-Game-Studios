# EnemyRegistry.tres — Story 010 schema + baseline value load test (AC-17).
#
# Loads the real data file and asserts the WaveDescriptor baseline values per the
# GDD Wave Archetype Spec. Complements the static CI lints (schema + move cap) with
# a typed-load verification that the .tres actually deserializes into the schema.
extends GutTest

const REGISTRY_PATH: String = "res://assets/data/EnemyRegistry.tres"

const ENEMY_MOVE_CAP: float = 420.0

var _registry: EnemyRegistry


func before_each() -> void:
	_registry = load(REGISTRY_PATH) as EnemyRegistry


# ---------------------------------------------------------------------------
# AC-17 — structure
# ---------------------------------------------------------------------------

func test_ac17_registry_loads_as_enemy_registry() -> void:
	assert_not_null(_registry, "AC-17: EnemyRegistry.tres must load as EnemyRegistry")


func test_ac17_three_archetypes_present() -> void:
	assert_eq(_registry.archetypes.size(), 3, "AC-17: exactly 3 archetypes")
	assert_true(_registry.archetypes.has(&"STRIKE"), "AC-17: STRIKE archetype present")
	assert_true(_registry.archetypes.has(&"CONTROL"), "AC-17: CONTROL archetype present")
	assert_true(_registry.archetypes.has(&"MOBILITY"), "AC-17: MOBILITY archetype present")


func test_ac17_each_archetype_is_wave_descriptor_with_enemy_faction() -> void:
	for key: StringName in _registry.archetypes:
		var wd: WaveDescriptor = _registry.archetypes[key]
		assert_not_null(wd, "AC-17: %s maps to a WaveDescriptor" % key)
		assert_eq(wd.faction, 1, "AC-17: %s faction must be 1 (ENEMY)" % key)
		assert_gt(wd.spawn_cadence_sec, 0.0, "AC-17: %s spawn_cadence_sec > 0" % key)
		assert_gt(wd.enemy_templates.size(), 0, "AC-17: %s has ≥1 enemy_template" % key)


func test_ac17_outline_colors_per_archetype() -> void:
	assert_eq((_registry.archetypes[&"STRIKE"] as WaveDescriptor).primary_outline_color,
		Color(1, 0, 0, 1), "AC-17: STRIKE outline RED")
	assert_eq((_registry.archetypes[&"CONTROL"] as WaveDescriptor).primary_outline_color,
		Color(0, 0, 1, 1), "AC-17: CONTROL outline BLUE")
	assert_eq((_registry.archetypes[&"MOBILITY"] as WaveDescriptor).primary_outline_color,
		Color(0, 1, 0, 1), "AC-17: MOBILITY outline GREEN")


# ---------------------------------------------------------------------------
# Baseline values (GDD Wave Archetype Spec)
# ---------------------------------------------------------------------------

func test_baseline_strike_values() -> void:
	var wd: WaveDescriptor = _registry.archetypes[&"STRIKE"]
	assert_eq(wd.max_hp, [80, 220, 540] as Array[int], "STRIKE max_hp tiers")
	assert_eq(wd.defense, [8, 18, 32] as Array[int], "STRIKE defense tiers")
	assert_almost_eq(wd._template_move_speed, 120.0, 0.001, "STRIKE move_speed")
	assert_almost_eq(wd.archetype_cadence_mult, 1.0, 0.001, "STRIKE cadence_mult")


func test_baseline_control_values() -> void:
	var wd: WaveDescriptor = _registry.archetypes[&"CONTROL"]
	assert_eq(wd.max_hp, [35, 95, 230] as Array[int], "CONTROL max_hp tiers")
	assert_eq(wd.defense, [2, 5, 10] as Array[int], "CONTROL defense tiers")
	assert_almost_eq(wd._template_move_speed, 90.0, 0.001, "CONTROL move_speed")
	assert_almost_eq(wd.archetype_cadence_mult, 1.25, 0.001, "CONTROL cadence_mult")


func test_baseline_mobility_values() -> void:
	var wd: WaveDescriptor = _registry.archetypes[&"MOBILITY"]
	assert_eq(wd.max_hp, [55, 145, 360] as Array[int], "MOBILITY max_hp tiers")
	assert_eq(wd.defense, [4, 10, 20] as Array[int], "MOBILITY defense tiers")
	assert_almost_eq(wd._template_move_speed, 280.0, 0.001, "MOBILITY move_speed")
	assert_almost_eq(wd.archetype_cadence_mult, 0.75, 0.001, "MOBILITY cadence_mult")


## INV-7: every archetype move speed ≤ 420 px/s.
func test_inv7_all_move_speeds_within_cap() -> void:
	for key: StringName in _registry.archetypes:
		var wd: WaveDescriptor = _registry.archetypes[key]
		assert_lte(wd._template_move_speed, ENEMY_MOVE_CAP,
			"INV-7: %s move_speed ≤ %d" % [key, int(ENEMY_MOVE_CAP)])
