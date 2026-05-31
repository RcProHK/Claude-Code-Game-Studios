# Test helper — synthesize EnemyRegistry + WaveDescriptor resources in-memory (Story 020).
# Avoids file I/O so AC-17 / Story 011 tests don't depend on assets/data/EnemyRegistry.tres.
extends RefCounted

## Baseline defaults per archetype (mirrors the shipped EnemyRegistry.tres values).
const _DEFAULTS: Dictionary = {
	&"STRIKE": {"mult": 1.0, "speed": 120.0, "hp": [80, 220, 540], "defense": [8, 18, 32], "color": Color(1, 0, 0, 1)},
	&"CONTROL": {"mult": 1.25, "speed": 90.0, "hp": [35, 95, 230], "defense": [2, 5, 10], "color": Color(0, 0, 1, 1)},
	&"MOBILITY": {"mult": 0.75, "speed": 280.0, "hp": [55, 145, 360], "defense": [4, 10, 20], "color": Color(0, 1, 0, 1)},
}


## Build an EnemyRegistry with one WaveDescriptor per requested archetype key.
static func make_registry(archetypes: Array) -> EnemyRegistry:
	var reg := EnemyRegistry.new()
	for key in archetypes:
		reg.archetypes[key] = make_descriptor(key)
	return reg


## Build a single WaveDescriptor for an archetype (defaults applied; STRIKE fallback).
static func make_descriptor(archetype: StringName) -> WaveDescriptor:
	var d: Dictionary = _DEFAULTS.get(archetype, _DEFAULTS[&"STRIKE"])
	var wd := WaveDescriptor.new()
	wd.enemy_templates = [StringName("%s_MOB_T1" % archetype)] as Array[StringName]
	wd.spawn_cadence_sec = 2.0
	wd.archetype_cadence_mult = d["mult"]
	wd.spawn_count_per_set = 3
	wd.primary_outline_color = d["color"]
	wd.faction = 1
	var hp: Array[int] = []
	hp.assign(d["hp"])  # convert untyped → Array[int] (typed property)
	wd.max_hp = hp
	var defense: Array[int] = []
	defense.assign(d["defense"])
	wd.defense = defense
	wd._template_move_speed = d["speed"]
	return wd


## Self-check (Story 020 QA).
static func _static_check() -> bool:
	var reg := make_registry([&"STRIKE"] as Array)
	assert(reg.archetypes.size() == 1, "factory: 1 archetype")
	assert(reg.archetypes.has(&"STRIKE"), "factory: STRIKE present")
	assert((reg.archetypes[&"STRIKE"] as WaveDescriptor)._template_move_speed > 0.0,
		"factory: move_speed > 0")
	return true
