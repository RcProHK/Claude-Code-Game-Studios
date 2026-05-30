# StatSystem — Story 008 DEBUG_OVERRIDE release-build runtime guard Unit Tests.
#
# Scope (FR-3 Pillar 1 hard guarantee — runtime defense layer):
#   AC-13  — release-build context (_debug_build_override = false): a DEBUG_OVERRIDE
#            mutation is rejected — returns false, stat_mutation_rejected(...,
#            "debug_override_release_blocked") emits, stat is unchanged.
#   AC-13b — debug-build context (_debug_build_override = true): the release guard
#            does NOT fire; a DEBUG_OVERRIDE mutation proceeds through normal
#            validation and mutates the stat.
#   AC-13c — default (_debug_build_override = null): _get_is_debug() falls through to
#            OS.is_debug_build() (typically true under the GUT runner), so the seam
#            transparently defers to the engine API when no override is set.
#
# The guard MUST use the injectable seam (not raw OS.is_debug_build()) — a real
# release export is impractical in the CI GUT gate.
#
# Framework: GUT (Godot Unit Testing) v9.x
# Driving GDD: design/gdd/stat-system.md §H AC-13 (Rule 10 / FR-3)
# Story: production/epics/stat-system/story-008-debug-override-release-guard.md
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
	add_child_autofree(_sut)  # boot to READY (STR == 10.0)


func after_each() -> void:
	# Reset the seam to the production default so no test leaks state to the next.
	if _sut != null:
		_sut._debug_build_override = null
	_sut = null
	_mock_persistence = null
	_mock_gsm = null


# --- AC-13: release-build context blocks DEBUG_OVERRIDE -----------------------

func test_release_build_blocks_debug_override_returns_false() -> void:
	# Arrange: simulate a release export.
	_sut._debug_build_override = false

	# Act
	var ok: bool = _sut.apply_stat_delta(_sut.StatId.STR, _sut.StatSource.DEBUG_OVERRIDE, 100.0)

	# Assert: AC-13 — DEBUG_OVERRIDE must never silently succeed in release.
	assert_false(ok, "AC-13: DEBUG_OVERRIDE must be rejected in a release build")


func test_release_build_blocks_debug_override_leaves_stat_unchanged() -> void:
	# Arrange
	_sut._debug_build_override = false
	var before: float = _sut.get_stat(_sut.StatId.STR)

	# Act
	_sut.apply_stat_delta(_sut.StatId.STR, _sut.StatSource.DEBUG_OVERRIDE, 100.0)

	# Assert: AC-13 — the blocked mutation must not move the stat.
	assert_eq(_sut.get_stat(_sut.StatId.STR), before,
		"AC-13: a release-blocked DEBUG_OVERRIDE must leave STR unchanged (10.0)")


func test_release_build_blocks_debug_override_emits_rejection() -> void:
	# Arrange
	_sut._debug_build_override = false
	watch_signals(_sut)

	# Act
	_sut.apply_stat_delta(_sut.StatId.STR, _sut.StatSource.DEBUG_OVERRIDE, 100.0)

	# Assert: AC-13 — the reject carries the canonical reason for #28 routing.
	assert_signal_emit_count(_sut, "stat_mutation_rejected", 1,
		"AC-13: a release-blocked DEBUG_OVERRIDE must emit stat_mutation_rejected once")
	var params: Array = get_signal_parameters(_sut, "stat_mutation_rejected")
	assert_eq(params[0], _sut.StatId.STR, "AC-13: rejected stat_id must be STR")
	assert_eq(params[1], _sut.StatSource.DEBUG_OVERRIDE, "AC-13: rejected source must be DEBUG_OVERRIDE")
	assert_eq(params[2], 100.0, "AC-13: rejected delta must be 100.0")
	assert_eq(params[3], "debug_override_release_blocked", "AC-13: reason must be 'debug_override_release_blocked'")


# --- AC-13b: debug-build context permits DEBUG_OVERRIDE -----------------------

func test_debug_build_permits_debug_override() -> void:
	# Arrange: force the debug path explicitly.
	_sut._debug_build_override = true
	var before: float = _sut.get_stat(_sut.StatId.STR)

	# Act
	var ok: bool = _sut.apply_stat_delta(_sut.StatId.STR, _sut.StatSource.DEBUG_OVERRIDE, 5.0)

	# Assert: AC-13b — debug builds legitimately permit DEBUG_OVERRIDE.
	assert_true(ok, "AC-13b: a debug-build DEBUG_OVERRIDE must succeed")
	assert_eq(_sut.get_stat(_sut.StatId.STR), before + 5.0,
		"AC-13b: the DEBUG_OVERRIDE mutation applies normally in a debug build")


# --- AC-13c: null seam defers to OS.is_debug_build() --------------------------

func test_null_override_defers_to_engine_api() -> void:
	# Arrange: production default — no override.
	_sut._debug_build_override = null

	# Assert: AC-13c — the seam returns exactly OS.is_debug_build() when unset.
	assert_eq(_sut._get_is_debug(), OS.is_debug_build(),
		"AC-13c: with no override, _get_is_debug() must equal OS.is_debug_build()")


func test_null_override_permits_debug_override_under_gut() -> void:
	# Under the GUT runner OS.is_debug_build() is typically true, so the default
	# (null) seam should permit DEBUG_OVERRIDE. Guard the assertion on the actual
	# engine value so this stays correct even if run in an unusual context.
	_sut._debug_build_override = null

	# Act
	var ok: bool = _sut.apply_stat_delta(_sut.StatId.STR, _sut.StatSource.DEBUG_OVERRIDE, 1.0)

	# Assert
	if OS.is_debug_build():
		assert_true(ok, "AC-13c: with null seam in a debug context, DEBUG_OVERRIDE succeeds")
	else:
		assert_false(ok, "AC-13c: with null seam in a release context, DEBUG_OVERRIDE is blocked")
