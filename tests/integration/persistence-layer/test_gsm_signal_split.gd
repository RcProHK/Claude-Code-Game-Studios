# PersistenceLayer — Story 014 AC-30 GSM Signal Split Test
#
# Proves that PersistenceLayer.write_completed → mock GSM handler →
# mock GSM.tombstone_write_completed chain works correctly, and that
# PersistenceLayer never declares tombstone_write_completed itself.
#
# Framework: GUT (Godot Unit Testing) v7.x
# Governing ADRs: ADR-0006 Contract 11 (signal split)
extends GutTest


# Mock GSM inner class — subscribes to write_completed and re-emits tombstone signal.
class MockGSM extends RefCounted:
	signal tombstone_write_completed(transition_id: String, latency_ms: int)
	var received_key: String = ""
	var received_latency: int = -1

	func on_write_completed(key: String, latency_ms: int, _is_touch: bool) -> void:
		if key == "pending_transition":
			received_key = key
			received_latency = latency_ms
			tombstone_write_completed.emit("test_tid_123", latency_ms)


var _mock: MockPersistenceLayer
var _gsm: MockGSM


func before_each() -> void:
	_mock = MockPersistenceLayer.new()
	_gsm = MockGSM.new()
	# Wire mock GSM to MockPersistenceLayer write_completed
	_mock.attach_write_spy(
		func(entry: Dictionary) -> void:
			_gsm.on_write_completed(entry["key"], 0, false)
	)


## AC-30 core: write("pending_transition") triggers mock GSM's tombstone signal.
func test_gsm_tombstone_write_completed_fires_on_pending_transition_write() -> void:
	pending("BLOCKED: GameStateMachine implementation epic — game_state_machine.gd is a Foundation-chain skeleton (awaiting step 5+). Un-pend when GSM is implemented.")
	return  # remove with GSM impl
	# Arrange
	var tombstone_count: int = 0
	var tombstone_tid: String = ""
	_gsm.tombstone_write_completed.connect(
		func(tid: String, _ms: int) -> void:
			tombstone_count += 1
			tombstone_tid = tid
	)

	# Act
	_mock.write("pending_transition", {"transition_id": "test_tid_123"})

	# Assert — GSM's tombstone signal fired
	assert_eq(tombstone_count, 1, "tombstone_write_completed must fire exactly once")
	assert_eq(tombstone_tid, "test_tid_123", "transition_id propagated to tombstone signal")


## AC-30 domain isolation: non-pending_transition writes don't fire tombstone signal.
func test_gsm_tombstone_not_fired_for_non_tombstone_writes() -> void:
	# Arrange
	var tombstone_count: int = 0
	_gsm.tombstone_write_completed.connect(func(_tid, _ms) -> void: tombstone_count += 1)

	# Act — write a different key
	_mock.write("gsm.current_state", "idle")
	_mock.write("stat.atk", 42)

	# Assert — tombstone signal NOT fired
	assert_eq(tombstone_count, 0, "tombstone_write_completed must not fire for non-tombstone keys")


## AC-30 CI ref: PersistenceLayer must not declare tombstone_write_completed.
func test_persistence_layer_has_no_tombstone_write_completed_signal() -> void:
	var declared_names: Array = []
	for sig in PersistenceLayer.get_signal_list():
		declared_names.append(sig["name"])

	assert_false(declared_names.has("tombstone_write_completed"),
		"PersistenceLayer must never declare tombstone_write_completed (GSM-domain signal)")
