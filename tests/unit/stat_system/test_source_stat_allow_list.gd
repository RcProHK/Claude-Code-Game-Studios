# StatSystem — AC-05 Source/stat allow-list: PR_BREAKTHROUGH base-only (Rule 4)
#
# Scope: verifies the source→stat_id allow-list. PR_BREAKTHROUGH on a base stat
# (STR) succeeds and lands the delta (10→11); PR_BREAKTHROUGH on a derived stat
# (MAX_HP) is rejected, fires stat_mutation_rejected with reason
# "source_stat_mismatch", and leaves the target unchanged.
#
# Framework: GUT (Godot Unit Testing) v9.x
# Driving GDD: design/gdd/stat-system.md §H AC-05 (Rule 4); EC-09
extends GutTest


var _stat: Node = null


func before_each() -> void:
	# Fresh un-parented instance — _ready() never runs, so STR holds default 10.0
	# (the AC-05 GIVEN precondition "STR=10").
	_stat = preload("res://src/autoload/stat_system.gd").new()
	watch_signals(_stat)


func after_each() -> void:
	_stat.free()
	_stat = null


## AC-05 (allowed): PR_BREAKTHROUGH on STR succeeds, STR rises 10 → 11.
func test_source_stat_allow_list_pr_breakthrough_on_str_succeeds() -> void:
	# Arrange
	var StatSystem = preload("res://src/autoload/stat_system.gd")
	var StatId = StatSystem.StatId
	assert_eq(_stat.get_stat(StatId.STR), 10.0, "Precondition: STR=10")

	# Act
	var result: bool = _stat.apply_stat_delta(
		StatId.STR, StatSystem.StatSource.PR_BREAKTHROUGH, 1.0)

	# Assert
	assert_true(result, "AC-05: PR_BREAKTHROUGH on base stat STR must return true")
	assert_eq(_stat.get_stat(StatId.STR), 11.0, "AC-05: STR must rise 10 → 11")


## AC-05 (allowed): no rejection signal fires on the legal path.
func test_source_stat_allow_list_legal_path_emits_no_rejection() -> void:
	# Arrange
	var StatSystem = preload("res://src/autoload/stat_system.gd")
	var StatId = StatSystem.StatId

	# Act
	_stat.apply_stat_delta(StatId.STR, StatSystem.StatSource.PR_BREAKTHROUGH, 1.0)

	# Assert
	assert_signal_not_emitted(_stat, "stat_mutation_rejected",
		"AC-05: a legal mutation must not fire stat_mutation_rejected")


## AC-05 (disallowed): PR_BREAKTHROUGH on MAX_HP is rejected + telemetry fires.
func test_source_stat_allow_list_pr_breakthrough_on_max_hp_rejected() -> void:
	# Arrange
	var StatSystem = preload("res://src/autoload/stat_system.gd")
	var StatId = StatSystem.StatId
	var hp_before: float = _stat.get_stat(StatId.MAX_HP)

	# Act
	var result: bool = _stat.apply_stat_delta(
		StatId.MAX_HP, StatSystem.StatSource.PR_BREAKTHROUGH, 50.0)

	# Assert — rejected + unchanged.
	assert_false(result, "AC-05: PR_BREAKTHROUGH on derived MAX_HP must return false")
	assert_eq(_stat.get_stat(StatId.MAX_HP), hp_before,
		"AC-05: rejected mutation must leave MAX_HP unchanged")


## AC-05 (disallowed): rejection payload matches the EC-09 contract.
func test_source_stat_allow_list_rejection_payload_is_source_stat_mismatch() -> void:
	# Arrange
	var StatSystem = preload("res://src/autoload/stat_system.gd")
	var StatId = StatSystem.StatId

	# Act
	_stat.apply_stat_delta(StatId.MAX_HP, StatSystem.StatSource.PR_BREAKTHROUGH, 50.0)

	# Assert — exactly one rejection, with the canonical payload shape.
	assert_signal_emit_count(_stat, "stat_mutation_rejected", 1,
		"AC-05: exactly one stat_mutation_rejected on the disallowed path")
	var params: Array = get_signal_parameters(_stat, "stat_mutation_rejected", 0)
	assert_eq(params[0], StatId.MAX_HP, "AC-05: reject param 0 = stat_id (MAX_HP)")
	assert_eq(params[1], StatSystem.StatSource.PR_BREAKTHROUGH,
		"AC-05: reject param 1 = source (PR_BREAKTHROUGH)")
	assert_eq(params[2], 50.0, "AC-05: reject param 2 = delta (50.0)")
	assert_eq(params[3], "source_stat_mismatch",
		"AC-05 / EC-09: reject reason must be 'source_stat_mismatch'")
