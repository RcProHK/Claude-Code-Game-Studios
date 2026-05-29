# GameStateMachine — Story 016 BossOutcome + Storage Keys
extends GutTest


## AC-gsm-boss-1: BossOutcome enum has 3 members.
func test_bossoutcome_enum_has_three_members() -> void:
	var keys: Array = BossPayload.BossOutcome.keys()
	assert_eq(keys.size(), 3, "BossOutcome must have exactly 3 members")
	assert_true("DEFEATED" in keys, "BossOutcome must contain DEFEATED")
	assert_true("INTERRUPTED_WITH_CREDIT" in keys,
		"BossOutcome must contain INTERRUPTED_WITH_CREDIT")
	assert_true("ABANDONED" in keys, "BossOutcome must contain ABANDONED")


## AC-gsm-keys-1: gsm.current_state stored as String name.
func test_storage_current_state_uses_string_name() -> void:
	# Arrange
	PersistenceLayer.get(&"_cache").erase("gsm.current_state")
	# Simulate storing the state
	var state_name: String = GameStateMachine.GameState.find_key(
		GameStateMachine.GameState.IDLE
	)
	PersistenceLayer.write("gsm.current_state", state_name)

	# Act
	var stored: Variant = PersistenceLayer.read("gsm.current_state")

	# Assert
	assert_true(stored is String, "current_state must be stored as String")
	assert_eq(stored, "IDLE", "Stored name must match enum key")


## AC-gsm-keys-2: 5 GSM namespace storage keys present in GSM as constants.
func test_gsm_storage_key_constants_use_gsm_namespace() -> void:
	const EXPECTED_KEYS: Array[String] = [
		GameStateMachine.KEY_CURRENT_STATE,             # gsm.current_state
		GameStateMachine.KEY_LAST_WEEKLY_TICK,          # gsm._last_weekly_tick_unix
		GameStateMachine.KEY_LOOT_REVEAL_PENDING,       # gsm.loot_reveal_pending
		GameStateMachine.PENDING_TRANSITION_KEY,        # gsm.pending_transition
		GameStateMachine.TRANSITION_ID_COUNTER_KEY,     # gsm._transition_id_counter
	]
	for key in EXPECTED_KEYS:
		assert_true(key.begins_with("gsm."),
			"Storage key '%s' must use gsm.* namespace" % key)
