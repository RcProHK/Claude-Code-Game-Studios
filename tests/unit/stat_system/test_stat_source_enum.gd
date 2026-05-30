# StatSystem — AC-04 StatSource enum 5-value completeness (Rule 3) Unit Tests
#
# Scope: verifies the StatSource enum has exactly 5 members in the canonical
# declaration order, and that the INITIAL_STATE sentinel is rejected by the
# mutation API (apply_stat_delta returns false; _base unchanged).
#
# Framework: GUT (Godot Unit Testing) v9.x
# Driving GDD: design/gdd/stat-system.md §H AC-04 (Rule 3); FR-1 (Section B)
extends GutTest


var _stat: Node = null


func before_each() -> void:
	# Fresh un-parented instance — _ready() never runs, so _base holds defaults.
	_stat = preload("res://src/autoload/stat_system.gd").new()
	watch_signals(_stat)


func after_each() -> void:
	_stat.free()
	_stat = null


## AC-04: StatSource.values() returns exactly 5 elements.
func test_stat_source_enum_has_exactly_five_members() -> void:
	# Arrange
	var StatSystem = preload("res://src/autoload/stat_system.gd")

	# Act
	var values: Array = StatSystem.StatSource.values()

	# Assert
	assert_eq(values.size(), 5,
		"AC-04: StatSource must have exactly 5 members (FR-1 exhaustive)")


## AC-04: the 5 members are exactly the canonical names (no RNG/time sources).
func test_stat_source_enum_has_canonical_member_names() -> void:
	# Arrange
	var StatSystem = preload("res://src/autoload/stat_system.gd")
	const EXPECTED_NAMES: Array[String] = [
		"PR_BREAKTHROUGH",
		"VOLUME_TICK",
		"EQUIPMENT",
		"DEBUG_OVERRIDE",
		"INITIAL_STATE",
	]

	# Act
	var keys: Array = StatSystem.StatSource.keys()

	# Assert — count then membership (FR-1: no LOOT_RANDOM / LEVEL_UP_BONUS / etc.)
	assert_eq(keys.size(), 5, "AC-04: exactly 5 enum keys")
	for member_name: String in EXPECTED_NAMES:
		assert_true(StatSystem.StatSource.has(member_name),
			"AC-04: StatSource must contain member '%s'" % member_name)


## AC-04: declaration order is load-bearing (ordinal inspection).
func test_stat_source_enum_ordinal_order_is_canonical() -> void:
	# Arrange
	var StatSystem = preload("res://src/autoload/stat_system.gd")

	# Assert — ordinals fixed so serialization/telemetry stays stable.
	assert_eq(int(StatSystem.StatSource.PR_BREAKTHROUGH), 0, "AC-04: PR_BREAKTHROUGH ordinal 0")
	assert_eq(int(StatSystem.StatSource.VOLUME_TICK), 1, "AC-04: VOLUME_TICK ordinal 1")
	assert_eq(int(StatSystem.StatSource.EQUIPMENT), 2, "AC-04: EQUIPMENT ordinal 2")
	assert_eq(int(StatSystem.StatSource.DEBUG_OVERRIDE), 3, "AC-04: DEBUG_OVERRIDE ordinal 3")
	assert_eq(int(StatSystem.StatSource.INITIAL_STATE), 4, "AC-04: INITIAL_STATE ordinal 4")


## AC-04: INITIAL_STATE sentinel is rejected by the mutation API.
func test_stat_source_initial_state_sentinel_rejected_by_mutation_api() -> void:
	# Arrange
	var StatSystem = preload("res://src/autoload/stat_system.gd")
	var StatId = StatSystem.StatId
	var str_before: float = _stat.get_stat(StatId.STR)

	# Act
	var result: bool = _stat.apply_stat_delta(
		StatId.STR, StatSystem.StatSource.INITIAL_STATE, 1.0)

	# Assert — rejected, STR unchanged, telemetry fires with "invalid_source" (AC-04).
	assert_false(result,
		"AC-04: apply_stat_delta with INITIAL_STATE sentinel must return false")
	assert_eq(_stat.get_stat(StatId.STR), str_before,
		"AC-04: sentinel reject must leave STR unchanged")
	assert_signal_emit_count(_stat, "stat_mutation_rejected", 1,
		"AC-04: stat_mutation_rejected must fire once for INITIAL_STATE sentinel")
	var params: Array = get_signal_parameters(_stat, "stat_mutation_rejected", 0)
	assert_eq(params[3], "invalid_source",
		"AC-04: INITIAL_STATE rejection reason must be 'invalid_source'")
