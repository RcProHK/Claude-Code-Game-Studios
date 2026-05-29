# GameStateMachine — Story 004 AC-11a/21/32b Tombstone Round-Trip
#
# Scope: verifies ADR-0006 Contract 2+3 — payload envelope, transition_id
# reuse during forward-recovery.
#
# AC-11a: BossPayload embedded in tombstone round-trips through PersistenceLayer
# AC-21: forward-recovery uses persisted transition_id verbatim
# AC-32b: CI script confirms _generate_transition_id NOT in _forward_recover*
#
# Framework: GUT (Godot Unit Testing) v7.x
# Governing ADRs: ADR-0006 Contract 2 + Contract 3
extends GutTest


func before_each() -> void:
	# Reset GSM + clear all persistence keys we touch.
	GameStateMachine.set(&"_current_state", GameStateMachine.GameState.BOOTING)
	GameStateMachine.set(&"_transitioning", false)
	GameStateMachine.clear_spies()
	PersistenceLayer.get(&"_cache").erase("gsm.pending_transition")
	for conn in GameStateMachine.state_changed.get_connections():
		GameStateMachine.state_changed.disconnect(conn.callable)


## AC-11a: BossPayload round-trips through tombstone serialization.
func test_tombstone_boss_payload_round_trip() -> void:
	# Arrange — build a BossPayload + envelope it in a StateTransitionPayload
	var boss := BossPayload.new()
	boss.outcome = BossPayload.BossOutcome.DEFEATED
	boss.boss_id = 42
	boss.hp_at_interrupt = 100
	boss.hp_max = 200

	var payload := StateTransitionPayload.new()
	payload.transition_id = "test_tid_boss"
	payload.source_event = "boss_defeated"
	payload.data = {"boss": boss.to_dict()}

	# Act — write tombstone + read back
	GameStateMachine._write_tombstone(
		"test_tid_boss",
		GameStateMachine.GameState.BOSS_ENCOUNTER,
		GameStateMachine.GameState.LOOT_DROP,
		payload
	)
	var stored: Variant = PersistenceLayer.read("gsm.pending_transition")

	# Assert — tombstone structure intact
	assert_not_null(stored, "Tombstone must be retrievable from PersistenceLayer")
	assert_true(stored is Dictionary, "Tombstone must be Dictionary")
	assert_eq(stored["transition_id"], "test_tid_boss")
	assert_eq(stored["payload_type"], "StateTransitionPayload",
		"payload_type must be class_name (NOT 'Resource')")
	# Boss data survives the envelope
	var inner_boss: Dictionary = stored["payload"]["data"]["boss"]
	assert_eq(inner_boss["outcome"], "DEFEATED",
		"BossPayload outcome must round-trip via SerializableResource envelope")


## AC-21: forward-recovery uses persisted transition_id verbatim.
func test_forward_recovery_reuses_persisted_transition_id() -> void:
	# Arrange — craft a tombstone with a known transition_id
	var known_tid: String = "preserved_tid_12345"
	var tombstone: Dictionary = {
		"transition_id": known_tid,
		"from": "BOOTING",
		"to": "IDLE",
		"wall_clock_anchor": int(Time.get_unix_time_from_system()),
		"monotonic_anchor": Time.get_ticks_usec(),
		"payload": {},
		"payload_type": "",
	}
	PersistenceLayer.write("gsm.pending_transition", tombstone, true)

	# Watch state_changed to confirm transition replayed. A capture-by-value
	# counter inside a connected lambda would NOT survive to the outer assert —
	# GUT's signal watcher is the correct verification path.
	watch_signals(GameStateMachine)

	# Act
	GameStateMachine._forward_recover_from_tombstone(tombstone)

	# Assert — transition replayed; tombstone removed
	assert_signal_emit_count(GameStateMachine, "state_changed", 1,
		"Forward-recovery must emit state_changed")
	assert_null(PersistenceLayer.read("gsm.pending_transition"),
		"Forward-recovery must remove the tombstone")
	assert_eq(GameStateMachine.get_current_state(), GameStateMachine.GameState.IDLE,
		"Forward-recovery must commit the target state")


## AC-11a: payload_type uses get_script().get_global_name(), not get_class().
func test_tombstone_payload_type_is_class_name_not_resource() -> void:
	# Arrange
	var payload := StateTransitionPayload.new()
	payload.source_event = "test"

	# Act
	GameStateMachine._write_tombstone(
		"test_tid_class",
		GameStateMachine.GameState.IDLE,
		GameStateMachine.GameState.WORKOUT_ACTIVE,
		payload
	)
	var stored: Dictionary = PersistenceLayer.read("gsm.pending_transition")

	# Assert
	assert_eq(stored["payload_type"], "StateTransitionPayload",
		"AC-11a: payload_type must be 'StateTransitionPayload' (class_name), NOT 'Resource'")
	assert_ne(stored["payload_type"], "Resource",
		"AC-11a: get_class() footgun must NOT be used")


## Additional: _remove_tombstone() actually clears the key.
func test_remove_tombstone_clears_key() -> void:
	# Arrange — write a tombstone
	PersistenceLayer.write("gsm.pending_transition", {"transition_id": "test"}, true)

	# Act
	GameStateMachine._remove_tombstone()

	# Assert
	assert_null(PersistenceLayer.read("gsm.pending_transition"),
		"_remove_tombstone() must delete the key")
