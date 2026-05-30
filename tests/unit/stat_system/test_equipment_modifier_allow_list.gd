# Unit tests — StatSystem Equipment Modifier Layer (Story 003).
# Covers AC-06 (apply emits stat_changed for affected derived stats only, source=EQUIPMENT,
# is_base_change=false) and AC-08 (same equipment_id overwrites prior modifier).
# Also exercises EC-18 (remove unknown id is a no-op) and removal-reverts-baseline.
#
# Each test uses a FRESH un-parented StatSystem instance (no autoload coupling) and
# watch_signals so signal-emission assertions are isolated per test.
extends GutTest

const StatSystem := preload("res://src/autoload/stat_system.gd")

var _sut


func before_each() -> void:
	_sut = StatSystem.new()
	watch_signals(_sut)


func after_each() -> void:
	_sut.free()
	_sut = null


# --- AC-06 ----------------------------------------------------------------------------

func test_apply_modifier_emits_stat_changed_for_max_hp() -> void:
	var modifier = _sut.StatModifier.new({ _sut.StatId.MAX_HP: 50.0 })

	_sut.apply_equipment_modifier(&"helm_of_might", modifier)

	assert_signal_emitted(_sut, "stat_changed",
		"apply_equipment_modifier should emit stat_changed for MAX_HP")
	var params: Array = get_signal_parameters(_sut, "stat_changed", 0)
	assert_eq(params[0], _sut.StatId.MAX_HP, "stat_id should be MAX_HP")
	# Story 010: derived baseline is now the real F3 value (160 at VIT=10), not 0.0.
	assert_eq(params[1], 160.0, "old_value should be the F3 MAX_HP baseline (160)")
	assert_eq(params[2], 210.0, "new_value should be 160 + the +50 equipment delta")
	assert_eq(params[3], _sut.StatSource.EQUIPMENT, "source should be EQUIPMENT")
	assert_false(params[4], "is_base_change should be false for an equipment recompute")


func test_apply_modifier_emits_stat_changed_for_crit_chance() -> void:
	var modifier = _sut.StatModifier.new({ _sut.StatId.CRIT_CHANCE: 0.15 })

	_sut.apply_equipment_modifier(&"lucky_charm", modifier)

	assert_signal_emitted(_sut, "stat_changed",
		"apply_equipment_modifier should emit stat_changed for CRIT_CHANCE")
	var params: Array = get_signal_parameters(_sut, "stat_changed", 0)
	assert_eq(params[0], _sut.StatId.CRIT_CHANCE, "stat_id should be CRIT_CHANCE")
	# Story 010: F6 baseline is 0.015 (DEX=10); +0.15 → 0.165, still under the 0.50 cap.
	assert_almost_eq(params[1], 0.015, 0.0001, "old_value should be the F6 CRIT baseline (0.015)")
	assert_almost_eq(params[2], 0.165, 0.0001, "new_value should be 0.015 + the +0.15 delta")
	assert_eq(params[3], _sut.StatSource.EQUIPMENT, "source should be EQUIPMENT")
	assert_false(params[4], "is_base_change should be false")


func test_apply_modifier_does_not_emit_for_unaffected_stats() -> void:
	# Modifier touches MAX_HP only — STR/VIT (base stats) must NOT emit stat_changed.
	var modifier = _sut.StatModifier.new({ _sut.StatId.MAX_HP: 25.0 })

	_sut.apply_equipment_modifier(&"sturdy_vest", modifier)

	# Exactly one emission, and it is for MAX_HP — no STR/VIT emissions.
	assert_signal_emit_count(_sut, "stat_changed", 1,
		"only the affected derived stat (MAX_HP) should emit")
	var params: Array = get_signal_parameters(_sut, "stat_changed", 0)
	assert_eq(params[0], _sut.StatId.MAX_HP, "the single emission must be MAX_HP, not STR/VIT")


func test_apply_modifier_ignores_unknown_stat_id() -> void:
	# EC-19 — unknown stat_id keys are silently ignored (no emit, no error).
	var modifier = _sut.StatModifier.new({
		&"bogus_stat": 999.0,
		_sut.StatId.MOVE_SPEED: 10.0,
	})

	_sut.apply_equipment_modifier(&"weird_boots", modifier)

	# Only MOVE_SPEED (a known derived stat) emits; the bogus key is dropped.
	assert_signal_emit_count(_sut, "stat_changed", 1,
		"unknown stat_id must be ignored — only MOVE_SPEED emits")
	var params: Array = get_signal_parameters(_sut, "stat_changed", 0)
	assert_eq(params[0], _sut.StatId.MOVE_SPEED, "the lone emission must be MOVE_SPEED")


# --- AC-08 ----------------------------------------------------------------------------

func test_apply_modifier_same_id_overwrites() -> void:
	# First modifier: +50 MAX_HP. Second (same id): +20 MAX_HP. Result must be +20, not +70.
	_sut.apply_equipment_modifier(&"ring_a", _sut.StatModifier.new({ _sut.StatId.MAX_HP: 50.0 }))
	_sut.apply_equipment_modifier(&"ring_a", _sut.StatModifier.new({ _sut.StatId.MAX_HP: 20.0 }))

	# Story 010: derived value is the F3 baseline (160) PLUS the equipment delta.
	assert_eq(_sut.get_stat(_sut.StatId.MAX_HP), 180.0,
		"same equipment_id must overwrite (not stack): 160 baseline + 20 = 180")

	# Second apply: old=160+50=210 (prior table), new=160+20=180.
	var params: Array = get_signal_parameters(_sut, "stat_changed", 1)
	assert_eq(params[1], 210.0, "second apply old_value should be 160 + the prior 50")
	assert_eq(params[2], 180.0, "second apply new_value should be 160 + the overwritten 20")


func test_apply_modifier_distinct_ids_stack() -> void:
	# Sanity: distinct equipment_ids accumulate (proves overwrite is keyed by id, not global).
	_sut.apply_equipment_modifier(&"ring_a", _sut.StatModifier.new({ _sut.StatId.MAX_HP: 50.0 }))
	_sut.apply_equipment_modifier(&"ring_b", _sut.StatModifier.new({ _sut.StatId.MAX_HP: 20.0 }))

	# Story 010: F3 baseline (160) + 50 + 20 = 230.
	assert_eq(_sut.get_stat(_sut.StatId.MAX_HP), 230.0,
		"distinct equipment_ids should sum on top of the 160 baseline: 160 + 50 + 20 = 230")


# --- Removal (EC-18 + revert) ---------------------------------------------------------

func test_remove_modifier_unknown_id_is_noop() -> void:
	# EC-18 — removing an id that was never applied emits nothing and raises no error.
	_sut.remove_equipment_modifier(&"never_equipped")

	assert_signal_emit_count(_sut, "stat_changed", 0,
		"removing an unknown equipment_id must not emit stat_changed")


func test_remove_modifier_reverts_derived_stat() -> void:
	_sut.apply_equipment_modifier(&"helm", _sut.StatModifier.new({ _sut.StatId.MAX_HP: 50.0 }))
	# Story 010: F3 baseline (160) + 50 = 210.
	assert_eq(_sut.get_stat(_sut.StatId.MAX_HP), 210.0, "precondition: MAX_HP is 160 + 50 = 210")

	_sut.remove_equipment_modifier(&"helm")

	assert_eq(_sut.get_stat(_sut.StatId.MAX_HP), 160.0,
		"removing the modifier should revert MAX_HP to the F3 baseline (160)")
	# Last emission (index 1) is the revert: old=210, new=160.
	var params: Array = get_signal_parameters(_sut, "stat_changed", 1)
	assert_eq(params[0], _sut.StatId.MAX_HP, "revert emission stat_id should be MAX_HP")
	assert_eq(params[1], 210.0, "revert old_value should be 210 (160 baseline + 50)")
	assert_eq(params[2], 160.0, "revert new_value should be the 160 baseline")
	assert_eq(params[3], _sut.StatSource.EQUIPMENT, "revert source should be EQUIPMENT")
	assert_false(params[4], "revert is_base_change should be false")
