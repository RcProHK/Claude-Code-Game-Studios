# Integration tests — StatSystem Equipment Modifier Layer is transient (Story 003).
# Covers AC-07: equipment modifiers are NEVER persisted and NEVER mutate base stats.
#
# Story 004 wires real PersistenceLayer boot/replay; until then this story proves
# transience structurally — fresh instances start with an empty modifier table, and a
# second instance never inherits a first instance's modifiers (simulating reload isolation).
# No real PL is injected here (apply_equipment_modifier must not call PL.write at all).
extends GutTest

const StatSystem := preload("res://src/autoload/stat_system.gd")

var _sut


func before_each() -> void:
	_sut = StatSystem.new()


func after_each() -> void:
	_sut.free()
	_sut = null


func test_fresh_instance_has_empty_equipment_modifiers() -> void:
	# A freshly constructed StatSystem boots with no equipment modifiers (#17 replays later).
	assert_eq(_sut._equipment_modifiers.size(), 0,
		"a fresh StatSystem instance must start with an empty equipment modifier table")


func test_modifier_does_not_change_base_stat() -> void:
	# A base-stat (STR) delta carried on an equipment modifier must NOT mutate _base —
	# base stats change only through apply_stat_delta (Rule 2 / AC-07).
	_sut.apply_equipment_modifier(&"gauntlets", _sut.StatModifier.new({ _sut.StatId.STR: 10.0 }))

	assert_eq(_sut._base[_sut.StatId.STR], 10.0,
		"_base[STR] must stay at the 10.0 baseline — equipment must not write base stats")
	assert_eq(_sut.get_stat(_sut.StatId.STR), 10.0,
		"get_stat(STR) reads _base directly and must ignore the equipment delta")


func test_fresh_instance_after_modifier_has_empty_table() -> void:
	# Instance A receives a modifier; a brand-new instance B must NOT inherit it.
	# This simulates reload isolation — transient state does not survive re-construction.
	_sut.apply_equipment_modifier(&"helm", _sut.StatModifier.new({ _sut.StatId.MAX_HP: 50.0 }))
	assert_eq(_sut._equipment_modifiers.size(), 1, "precondition: instance A has 1 modifier")

	var instance_b = StatSystem.new()
	assert_eq(instance_b._equipment_modifiers.size(), 0,
		"a second instance must start empty — equipment modifiers are not persisted/shared")
	assert_eq(instance_b.get_stat(instance_b.StatId.MAX_HP), 0.0,
		"instance B MAX_HP must be the 0.0 baseline, unaffected by instance A's modifier")
	instance_b.free()


func test_modifier_affects_derived_not_base() -> void:
	# Applying a MAX_HP (derived) modifier changes get_stat(MAX_HP) but leaves _base untouched.
	var base_snapshot: Dictionary = _sut._base.duplicate(true)

	_sut.apply_equipment_modifier(&"vest", _sut.StatModifier.new({ _sut.StatId.MAX_HP: 50.0 }))

	assert_eq(_sut._base, base_snapshot,
		"_base must be byte-identical before and after an equipment modifier (no base write)")
	assert_eq(_sut.get_stat(_sut.StatId.MAX_HP), 50.0,
		"get_stat(MAX_HP) must reflect the +50 equipment delta via the derived path")
