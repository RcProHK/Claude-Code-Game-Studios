# AbilitySystem — Story 007 Boot Reconciliation (AC-14 / AC-14b / AC-14c) Integration Tests.
#
# Scope (TR-ability-011 / ADR-0006 Contract 4): _ready() is synchronous (NO await). It replays
# every persisted "ability.unlocked.<id>" key into _unlocked_abilities via the defensive
# _load_unlock_from_key reader, clears the transient cooldown table, subscribes the Stat + GSM
# handlers via connect_for_initial_state, flips to READY, and emits boot_completed exactly once.
# NO ability_unlocked fires during _ready() (subscribers connect after boot — AC-14c).
#
# PersistenceLayer has NO list_keys_matching; boot walks the 9 known AbilityId keys and reads each
# directly. MockPersistenceLayer (read/write) is preloaded with the keys under test.
#
# Test pattern: add_child_autofree(sut) then `await get_tree().process_frame` — NOT `await
# _sut.ready` (the ready signal already fired inside add_child in Godot 4.6; awaiting it HANGS).
#
# Framework: GUT (Godot Unit Testing) v9.x
# Driving GDD: design/gdd/ability-system.md Rule 10 + EC-01/02/03/04
# Story: production/epics/ability-system/story-007-boot-reconciliation.md
extends GutTest

const AbilitySystem := preload("res://src/autoload/ability_system.gd")


## MockGSM — captures connect_for_initial_state so the boot subscription can be asserted. No
## state_changed signal: if production used a direct .connect() this mock would runtime-error
## (ADR-0006 Contract 6 protection, same pattern as the StatSystem boot test).
class MockGSM extends RefCounted:
	var connect_for_initial_state_call_count: int = 0
	var registered_callable: Callable = Callable()

	func connect_for_initial_state(callable: Callable) -> void:
		connect_for_initial_state_call_count += 1
		registered_callable = callable


## MockStatSystem — captures connect_for_initial_state. Does NOT deliver an initial burst (the
## boot subscription assertion does not need a delivery; AC-14c separately verifies no unlock fires
## even if the burst did run, because _on_stat_changed returns early during INITIALISING).
class MockStatSystem extends RefCounted:
	var connect_for_initial_state_call_count: int = 0
	var registered_callable: Callable = Callable()

	func connect_for_initial_state(callable: Callable) -> void:
		connect_for_initial_state_call_count += 1
		registered_callable = callable

	func get_stat(_stat_id: StringName) -> float:
		return 0.0


var _sut
var _mock_persistence: MockPersistenceLayer
var _mock_gsm: MockGSM
var _mock_stat: MockStatSystem


func before_each() -> void:
	_mock_persistence = MockPersistenceLayer.new()
	_mock_gsm = MockGSM.new()
	_mock_stat = MockStatSystem.new()
	_sut = AbilitySystem.new()
	_sut._persistence = _mock_persistence
	_sut._gsm = _mock_gsm
	_sut._stat_system = _mock_stat


func after_each() -> void:
	_sut = null
	_mock_persistence = null
	_mock_gsm = null
	_mock_stat = null


## Build a valid persisted UnlockRecord dict for a given source ordinal + timestamp.
func _record_dict(source_ordinal: int, ts: int = 1_700_000_000) -> Dictionary:
	var record := AbilitySystem.UnlockRecord.new()
	record.first_unlocked_at_unix = ts
	record.source = source_ordinal
	return record.to_dict()


# --- AC-14: normal boot with pre-existing keys ------------------------------------------------

func test_boot_loads_two_persisted_keys() -> void:
	# Arrange — two persisted unlock keys (STRIKE T1 via PR, CONTROL T1 via STAT_THRESHOLD).
	_mock_persistence.write(
		"ability.unlocked." + String(_sut.AbilityId.STRIKE_TIER_1_JAB),
		_record_dict(0),  # PR_BREAKTHROUGH
	)
	_mock_persistence.write(
		"ability.unlocked." + String(_sut.AbilityId.CONTROL_TIER_1_PARRY),
		_record_dict(1),  # STAT_THRESHOLD
	)

	# Act
	add_child_autofree(_sut)
	await get_tree().process_frame  # _ready ran in add_child; settle one frame (await _sut.ready hangs)

	# Assert — exactly the two persisted abilities are present.
	var unlocked: Dictionary = _sut.get_unlocked_abilities()
	assert_eq(unlocked.size(), 2, "AC-14: exactly the two persisted abilities load")
	assert_true(_sut.get_ability_state(_sut.AbilityId.STRIKE_TIER_1_JAB)["unlocked"],
		"AC-14: STRIKE_TIER_1_JAB loaded from persistence")
	assert_true(_sut.get_ability_state(_sut.AbilityId.CONTROL_TIER_1_PARRY)["unlocked"],
		"AC-14: CONTROL_TIER_1_PARRY loaded from persistence")


func test_boot_cooldown_table_is_empty_after_load() -> void:
	# Arrange — a persisted unlock.
	_mock_persistence.write(
		"ability.unlocked." + String(_sut.AbilityId.STRIKE_TIER_1_JAB),
		_record_dict(0),
	)

	# Act
	add_child_autofree(_sut)
	await get_tree().process_frame

	# Assert — cooldowns are transient (never persisted) — reset to empty on reload.
	assert_eq(_sut.get_ability_state(_sut.AbilityId.STRIKE_TIER_1_JAB)["cooldown_remaining"], 0.0,
		"AC-14: cooldowns are transient — an unlocked ability boots castable (0 remaining)")


func test_boot_empty_persistence_yields_empty_unlock_set() -> void:
	# Arrange — empty persistence (no ability.unlocked.* keys); done in before_each.
	# Act
	add_child_autofree(_sut)
	await get_tree().process_frame

	# Assert — first boot: nothing unlocked, boot still reaches READY.
	assert_eq(_sut.get_unlocked_abilities().size(), 0, "AC-14: a fresh install boots to an empty unlock set")
	assert_eq(_sut._substate, AbilitySystem.Substate.READY, "AC-14: boot reaches READY even with no keys")


func test_boot_all_nine_keys_load() -> void:
	# Arrange — every one of the 9 abilities persisted.
	for ability_id: StringName in _sut._ALL_ABILITY_IDS:
		_mock_persistence.write("ability.unlocked." + String(ability_id), _record_dict(0))

	# Act
	add_child_autofree(_sut)
	await get_tree().process_frame

	# Assert — all 9 load.
	assert_eq(_sut.get_unlocked_abilities().size(), 9, "AC-14: all nine persisted abilities load")


# --- AC-14b: defensive boot edge cases (boot NEVER blocks) ------------------------------------

func test_boot_partial_chain_loads_each_independently() -> void:
	# Arrange — EC-03: a TIER_2 key present WITHOUT its TIER_1 predecessor. Each key loads on its
	# own merits (the unlock table has no causal-chain requirement at boot).
	_mock_persistence.write(
		"ability.unlocked." + String(_sut.AbilityId.STRIKE_TIER_2_HOOK),
		_record_dict(1),
	)

	# Act
	add_child_autofree(_sut)
	await get_tree().process_frame

	# Assert — T2 present, T1 absent, boot completed.
	assert_true(_sut.get_ability_state(_sut.AbilityId.STRIKE_TIER_2_HOOK)["unlocked"],
		"AC-14b: a partial-chain TIER_2 key loads independently")
	assert_false(_sut.get_ability_state(_sut.AbilityId.STRIKE_TIER_1_JAB)["unlocked"],
		"AC-14b: the absent TIER_1 predecessor stays locked")
	assert_eq(_sut._substate, AbilitySystem.Substate.READY, "AC-14b: boot reaches READY")


func test_boot_corrupt_nan_timestamp_recovers_with_current_time() -> void:
	# Arrange — EC-04: a record whose timestamp is NaN. The reader restamps it with the current
	# time rather than failing the key. (to_dict stores int, so inject the corrupt dict directly.)
	var corrupt := _record_dict(0)
	corrupt["first_unlocked_at_unix"] = NAN
	_mock_persistence.write(
		"ability.unlocked." + String(_sut.AbilityId.STRIKE_TIER_1_JAB),
		corrupt,
	)

	# Act
	add_child_autofree(_sut)
	await get_tree().process_frame

	# Assert — the ability still loaded (recovered, not skipped) and the timestamp is finite.
	assert_true(_sut.get_ability_state(_sut.AbilityId.STRIKE_TIER_1_JAB)["unlocked"],
		"AC-14b: a NaN-timestamp record is recovered (restamped), not dropped")
	var record = _sut.get_unlocked_abilities()[_sut.AbilityId.STRIKE_TIER_1_JAB]
	assert_false(is_nan(float(record.first_unlocked_at_unix)),
		"AC-14b: the recovered timestamp is finite (restamped to current time)")


func test_boot_invalid_source_coerces_to_initial_state() -> void:
	# Arrange — EC-04: a record with an out-of-range source ordinal. from_dict already coerces an
	# unknown source STRING to INITIAL_STATE; inject a numeric out-of-range source to exercise the
	# reader's own ordinal-validity coercion.
	var bad := _record_dict(0)
	bad["source"] = 99  # not a UnlockSource string; from_dict → INITIAL_STATE fallback
	_mock_persistence.write(
		"ability.unlocked." + String(_sut.AbilityId.STRIKE_TIER_1_JAB),
		bad,
	)

	# Act
	add_child_autofree(_sut)
	await get_tree().process_frame

	# Assert — the record loaded with a valid (coerced) source.
	assert_true(_sut.get_ability_state(_sut.AbilityId.STRIKE_TIER_1_JAB)["unlocked"],
		"AC-14b: a record with an invalid source still loads (source coerced)")
	var record = _sut.get_unlocked_abilities()[_sut.AbilityId.STRIKE_TIER_1_JAB]
	assert_true(_sut.UnlockSource.values().has(record.source),
		"AC-14b: the loaded record's source is a valid UnlockSource ordinal")


func test_boot_non_dictionary_value_is_skipped() -> void:
	# Arrange — EC-02: a key whose value is not a Dictionary (corrupt write). It must be skipped,
	# not crash boot.
	_mock_persistence.write(
		"ability.unlocked." + String(_sut.AbilityId.STRIKE_TIER_1_JAB),
		"not-a-dict",
	)

	# Act
	add_child_autofree(_sut)
	await get_tree().process_frame

	# Assert — the corrupt key is skipped; boot still reaches READY.
	assert_false(_sut.get_ability_state(_sut.AbilityId.STRIKE_TIER_1_JAB)["unlocked"],
		"AC-14b: a non-Dictionary value is skipped, not loaded")
	assert_eq(_sut._substate, AbilitySystem.Substate.READY, "AC-14b: boot reaches READY despite a corrupt key")


# --- AC-14c: no ability_unlocked during boot + boot_completed once + subscriptions wired ------

func test_boot_emits_boot_completed_exactly_once() -> void:
	# Arrange — watch BEFORE _ready() fires.
	watch_signals(_sut)

	# Act
	add_child_autofree(_sut)
	await get_tree().process_frame

	# Assert
	assert_signal_emit_count(_sut, "boot_completed", 1, "AC-14c: boot_completed emits exactly once")


func test_boot_emits_no_ability_unlocked_during_ready() -> void:
	# Arrange — preload a key so boot DOES replay an unlock, and watch BEFORE _ready().
	_mock_persistence.write(
		"ability.unlocked." + String(_sut.AbilityId.STRIKE_TIER_1_JAB),
		_record_dict(0),
	)
	watch_signals(_sut)

	# Act
	add_child_autofree(_sut)
	await get_tree().process_frame

	# Assert — AC-14c: replaying a persisted unlock during boot is SILENT (subscribers connect
	# after boot via connect_for_initial_state).
	assert_signal_emit_count(_sut, "ability_unlocked", 0,
		"AC-14c: NO ability_unlocked fires during _ready() (boot replay is silent)")
	# The ability is still in the table (loaded), it just was not announced.
	assert_true(_sut.get_ability_state(_sut.AbilityId.STRIKE_TIER_1_JAB)["unlocked"],
		"AC-14c: the persisted ability is loaded even though no signal fired")


func test_boot_wires_stat_and_gsm_subscriptions_once_each() -> void:
	# Act
	add_child_autofree(_sut)
	await get_tree().process_frame

	# Assert — AC-14c: both subscriptions wired exactly once via connect_for_initial_state.
	assert_eq(_mock_stat.connect_for_initial_state_call_count, 1,
		"AC-14c: Stat subscription wired once via connect_for_initial_state")
	assert_eq(_mock_gsm.connect_for_initial_state_call_count, 1,
		"AC-14c: GSM subscription wired once via connect_for_initial_state")
	assert_true(_mock_stat.registered_callable.is_valid(), "AC-14c: a valid Stat callable is registered")
	assert_true(_mock_gsm.registered_callable.is_valid(), "AC-14c: a valid GSM callable is registered")
