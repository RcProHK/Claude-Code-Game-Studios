# StatSystem — Story 006 Persistence flush policy (AC-09) Integration Tests.
#
# Scope: apply_stat_delta persists base-stat mutations and chooses the flush flag
# per source (flush_for_source):
#   PR_BREAKTHROUGH → flush = true   (high-stakes; survive a crash)
#   DEBUG_OVERRIDE  → flush = true
#   VOLUME_TICK     → flush = false  (high-frequency; batched)
#
# MockPersistenceLayer's write spy only forwards {key, value}, so this test uses a
# FlushSpyPersistence that records the flush flag explicitly.
#
# Framework: GUT (Godot Unit Testing) v9.x
# Driving GDD: design/gdd/stat-system.md §H AC-09 (Rule 7)
# Story: production/epics/stat-system/story-006-persistence-atomic-write.md
extends GutTest

const StatSystem := preload("res://src/autoload/stat_system.gd")


class MockGSM extends RefCounted:
	func connect_for_initial_state(_callable: Callable) -> void:
		pass


## Persistence spy recording each write's (key, value, flush). Duck-typed against
## the production PersistenceLayer surface used by StatSystem (read / write).
class FlushSpyPersistence extends RefCounted:
	signal critical_save_failed(error_code: String, key: String)
	var writes: Array = []

	func read(_key: String) -> Variant:
		return null  # first-boot defaults so _base[STR] starts at 10.0

	func write(key: String, value: Variant, flush: bool = false) -> bool:
		writes.append({"key": key, "value": value, "flush": flush})
		return true


var _sut
var _persistence: FlushSpyPersistence


func before_each() -> void:
	_persistence = FlushSpyPersistence.new()
	_sut = StatSystem.new()
	_sut._persistence = _persistence
	_sut._gsm = MockGSM.new()
	add_child_autofree(_sut)  # boot to READY


func after_each() -> void:
	_sut = null
	_persistence = null


func test_pr_breakthrough_persists_with_flush_true() -> void:
	# Act
	var ok: bool = _sut.apply_stat_delta(_sut.StatId.STR, _sut.StatSource.PR_BREAKTHROUGH, 1.0)

	# Assert: AC-09 — a PR breakthrough flushes immediately.
	assert_true(ok, "the mutation must succeed")
	assert_eq(_persistence.writes.size(), 1, "exactly one write must be issued")
	assert_eq(_persistence.writes[0]["key"], "stat.str", "write key must be stat.str")
	assert_eq(_persistence.writes[0]["value"], 11.0, "persisted value must be the new target (11.0)")
	assert_true(_persistence.writes[0]["flush"], "AC-09: PR_BREAKTHROUGH must persist with flush = true")


func test_debug_override_persists_with_flush_true() -> void:
	# Act
	_sut.apply_stat_delta(_sut.StatId.STR, _sut.StatSource.DEBUG_OVERRIDE, 2.0)

	# Assert: AC-09 — DEBUG_OVERRIDE also flushes immediately.
	assert_eq(_persistence.writes.size(), 1, "exactly one write must be issued")
	assert_true(_persistence.writes[0]["flush"], "AC-09: DEBUG_OVERRIDE must persist with flush = true")


func test_volume_tick_persists_with_flush_false() -> void:
	# Act
	_sut.apply_stat_delta(_sut.StatId.STR, _sut.StatSource.VOLUME_TICK, 1.0)

	# Assert: AC-09 — a high-frequency volume tick defers the flush.
	assert_eq(_persistence.writes.size(), 1, "exactly one write must be issued")
	assert_false(_persistence.writes[0]["flush"], "AC-09: VOLUME_TICK must persist with flush = false")


func test_flush_for_source_policy_direct() -> void:
	# Act / Assert: exercise the policy helper directly for full coverage.
	assert_true(_sut.flush_for_source(_sut.StatSource.PR_BREAKTHROUGH),
		"AC-09: PR_BREAKTHROUGH → flush true")
	assert_true(_sut.flush_for_source(_sut.StatSource.DEBUG_OVERRIDE),
		"AC-09: DEBUG_OVERRIDE → flush true")
	assert_false(_sut.flush_for_source(_sut.StatSource.VOLUME_TICK),
		"AC-09: VOLUME_TICK → flush false")
	assert_false(_sut.flush_for_source(_sut.StatSource.EQUIPMENT),
		"AC-09: EQUIPMENT → flush false (and never reaches apply_stat_delta)")
