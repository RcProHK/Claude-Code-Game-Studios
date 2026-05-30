# StatSystem — Story 004 Boot Reconciliation, partial persisted keys (AC-11) Unit Tests.
#
# Scope: a returning player has SOME but not all stat.* keys persisted. Boot must
# use the persisted values verbatim and default the missing ones to 10.0, without
# crashing. Mixed present/absent keys exercise per-key independence.
#
# Framework: GUT (Godot Unit Testing) v9.x
# Driving GDD: design/gdd/stat-system.md §H AC-11
# Story: production/epics/stat-system/story-004-boot-reconciliation.md
extends GutTest

const StatSystem := preload("res://src/autoload/stat_system.gd")


class MockGSM extends RefCounted:
	func connect_for_initial_state(_callable: Callable) -> void:
		pass


var _sut
var _mock_persistence: MockPersistenceLayer
var _mock_gsm: MockGSM


func before_each() -> void:
	_mock_persistence = MockPersistenceLayer.new()
	_mock_gsm = MockGSM.new()
	_sut = StatSystem.new()
	_sut._persistence = _mock_persistence
	_sut._gsm = _mock_gsm


func after_each() -> void:
	_sut.free()
	_sut = null
	_mock_persistence = null
	_mock_gsm = null


func test_boot_partial_keys_uses_persisted_and_defaults_missing() -> void:
	# Arrange: str + vit persisted, dex absent (AC-11). Values stored as floats so
	# typeof() == TYPE_FLOAT in reconciliation.
	_mock_persistence.write("stat.str", 25.0)
	_mock_persistence.write("stat.vit", 15.0)
	# stat.dex deliberately left unset.

	# Act
	add_child_autofree(_sut)
	await get_tree().process_frame  # _ready() already ran synchronously in add_child; settle one frame (awaiting _sut.ready would hang — it already fired)

	# Assert: AC-11 — persisted values verbatim, missing key defaulted.
	assert_eq(_sut.get_stat(_sut.StatId.STR), 25.0, "AC-11: persisted STR must be used as-is")
	assert_eq(_sut.get_stat(_sut.StatId.DEX), 10.0, "AC-11: absent DEX must default to 10.0")
	assert_eq(_sut.get_stat(_sut.StatId.VIT), 15.0, "AC-11: persisted VIT must be used as-is")


func test_boot_partial_keys_reaches_ready() -> void:
	# Arrange
	_mock_persistence.write("stat.str", 25.0)
	_mock_persistence.write("stat.vit", 15.0)

	# Act
	add_child_autofree(_sut)
	await get_tree().process_frame  # _ready() already ran synchronously in add_child; settle one frame (awaiting _sut.ready would hang — it already fired)

	# Assert: a partial-key boot still completes cleanly.
	assert_eq(_sut._substate, StatSystem.Substate.READY,
		"AC-11: partial-key boot must reach READY")


func test_boot_partial_keys_no_critical_failure() -> void:
	# Arrange
	_mock_persistence.write("stat.str", 25.0)
	_mock_persistence.write("stat.vit", 15.0)
	watch_signals(_sut)

	# Act
	add_child_autofree(_sut)
	await get_tree().process_frame  # _ready() already ran synchronously in add_child; settle one frame (awaiting _sut.ready would hang — it already fired)

	# Assert: a merely-absent key is a warning path, NOT a critical-save failure.
	assert_signal_emit_count(_sut, "stat_critical_save_failed", 0,
		"AC-11: an absent key must not raise stat_critical_save_failed (warning path only)")
