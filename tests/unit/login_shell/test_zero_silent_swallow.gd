extends GutTest
## Story 010 — zero-silent-swallow: the 4-system error consumer wiring. Covers
## AC-26 (each emit → +1 entry, correct dedupe_key + severity) + AC-52 (UNMAPPED
## default-deny). NON-tautological: wrong severity / wrong key / empty banner all fail.
##
## GDD: Rule 5 (source-first dispatch, #24 = sole UI consumer of #3/#8/#11/#12).

const CoordinatorScript := preload("res://src/autoload/login_shell_coordinator.gd")
const ESM := preload("res://src/ui/login_shell/error_severity_map.gd")


class MockGsm:
	extends Node
	signal state_changed(from_state, to_state, payload)
	var current_state: int = 2
	func get_current_state() -> int: return current_state
	func connect_for_initial_state(callable: Callable) -> void:
		state_changed.connect(callable)


class MockPersistence:
	extends Node
	signal critical_save_failed(error_code: String, key: String)


class MockStreak:
	extends Node
	signal streak_persistence_failed(error_code: String, key: String)


class MockStat:
	extends Node
	signal stat_critical_save_failed(stat_id: StringName)


class MockAbility:
	extends Node
	signal ability_unlock_save_failed(ability_id: StringName)


var _persistence: MockPersistence
var _streak: MockStreak
var _stat: MockStat
var _ability: MockAbility
var _stack


func _make() -> Node:
	var gsm := MockGsm.new()
	_persistence = MockPersistence.new()
	_streak = MockStreak.new()
	_stat = MockStat.new()
	_ability = MockAbility.new()
	add_child_autofree(gsm)
	add_child_autofree(_persistence)
	add_child_autofree(_streak)
	add_child_autofree(_stat)
	add_child_autofree(_ability)
	var c: Node = CoordinatorScript.new()
	c._gsm = gsm
	c._persistence = _persistence
	c._streak = _streak
	c._stat = _stat
	c._ability = _ability
	add_child_autofree(c)  # _ready wires the 4 error signals into the BannerStack
	_stack = c.get_banner_stack()
	return c


# --- AC-26: each emit → exactly +1 entry, correct dedupe_key + severity ---

func test_ac26_persistence_ongoing_enqueues_with_correct_key_and_severity() -> void:
	_make()
	assert_eq(_stack.count(), 0, "empty stack at boot")
	_persistence.critical_save_failed.emit("QUOTA_EXHAUSTED", "save_a")
	assert_eq(_stack.count(), 1, "exactly +1 entry")
	var e: Dictionary = _stack.entries()[0]
	assert_eq(e["severity"], ESM.Severity.ONGOING, "QUOTA_EXHAUSTED → ONGOING (non-tautological)")
	assert_eq(e["dedupe_key"], "0|QUOTA_EXHAUSTED|save_a", "dedupe_key = (PERSISTENCE, code, key)")


func test_ac26_streak_is_feature_degraded_by_source_not_code() -> void:
	_make()
	# FLUSH_FAILED is a #3 WIPE code — but from the #8 SOURCE it must be FEATURE_DEGRADED
	# (source-first, never code-classified — the collision-guard core of Rule 5).
	_streak.streak_persistence_failed.emit("FLUSH_FAILED", "streak")
	assert_eq(_stack.count(), 1, "+1 entry")
	var e: Dictionary = _stack.entries()[0]
	assert_eq(e["severity"], ESM.Severity.FEATURE_DEGRADED,
		"#8 FLUSH_FAILED → FEATURE_DEGRADED by SOURCE (NOT WIPE — collision guard)")
	assert_eq(e["dedupe_key"], "1|FLUSH_FAILED|streak", "dedupe_key (STREAK, code, key)")


func test_ac26_stat_and_ability_single_arg_feature_degraded() -> void:
	_make()
	_stat.stat_critical_save_failed.emit(&"strength")
	_ability.ability_unlock_save_failed.emit(&"fireball")
	assert_eq(_stack.count(), 2, "two more entries (+1 each)")
	assert_eq(_stack.entries()[0]["severity"], ESM.Severity.FEATURE_DEGRADED, "#11 → FEATURE_DEGRADED")
	assert_eq(_stack.entries()[0]["dedupe_key"], "2||strength", "#11 dedupe (STAT, '', stat_id)")
	assert_eq(_stack.entries()[1]["severity"], ESM.Severity.FEATURE_DEGRADED, "#12 → FEATURE_DEGRADED")
	assert_eq(_stack.entries()[1]["dedupe_key"], "3||fireball", "#12 dedupe (ABILITY, '', ability_id)")


func test_ac26_all_four_sources_each_produce_a_visible_entry() -> void:
	_make()
	_persistence.critical_save_failed.emit("READ_ONLY_FILESYSTEM", "p")
	_streak.streak_persistence_failed.emit("X", "s")
	_stat.stat_critical_save_failed.emit(&"agility")
	_ability.ability_unlock_save_failed.emit(&"dash")
	assert_eq(_stack.count(), 4, "all 4 error edges terminate in a visible entry (zero silent-swallow)")


# --- AC-52: UNMAPPED default-deny ---

func test_ac52_unmapped_code_produces_ongoing_weight_banner() -> void:
	_make()
	_persistence.critical_save_failed.emit("FUTURE_CODE_13", "x")
	assert_eq(_stack.count(), 1, "unmapped code is NOT silently dropped (+1 entry)")
	var e: Dictionary = _stack.entries()[0]
	assert_eq(e["severity"], ESM.Severity.UNMAPPED, "AC-52: unmapped #3 code → UNMAPPED")
	assert_eq(
		ESM.priority_weight(e["severity"]), ESM.priority_weight(ESM.Severity.ONGOING),
		"UNMAPPED carries ONGOING-weight (default-deny, highest-safe)")
