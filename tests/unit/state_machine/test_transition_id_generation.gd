# GameStateMachine — Story 003 transition_id Generation Tests
#
# Scope: verifies ADR-0006 Contract 2 — counter persistence, collision-safety,
# opaque-string round-trip.
#
# AC-gsm-tid-1: fresh boot → counter=1, ID format matches regex
# AC-gsm-tid-2: counter survives + increments across calls
# AC-gsm-tid-3: ID byte-identical after PersistenceLayer round-trip
#
# Framework: GUT (Godot Unit Testing) v7.x
# Governing ADRs: ADR-0006 Contract 2
extends GutTest


const COUNTER_KEY: String = "gsm._transition_id_counter"


func before_each() -> void:
	# Clear counter to simulate fresh boot.
	PersistenceLayer.get(&"_cache").erase(COUNTER_KEY)


## AC-gsm-tid-1: fresh boot generates counter=1 with valid format.
func test_transition_id_fresh_boot_returns_counter_one_with_valid_format() -> void:
	# Act
	var tid: String = GameStateMachine._generate_transition_id(
		GameStateMachine.GameState.BOOTING,
		GameStateMachine.GameState.IDLE
	)

	# Assert — format matches "WALL_MS_COUNTER_FROM_TO"
	assert_true(tid.length() > 0, "transition_id must be non-empty")
	# Counter should be 1 after first call
	assert_eq(PersistenceLayer.read(COUNTER_KEY), 1,
		"Counter must be 1 after first transition_id generation")
	# String must contain both state names
	assert_true(tid.contains("BOOTING"), "ID must contain from-state name")
	assert_true(tid.contains("IDLE"), "ID must contain to-state name")


## AC-gsm-tid-2: counter increments across calls; same-ms calls get distinct IDs.
func test_transition_id_counter_increments_across_calls() -> void:
	# Act
	var tid1: String = GameStateMachine._generate_transition_id(
		GameStateMachine.GameState.IDLE, GameStateMachine.GameState.WORKOUT_ACTIVE
	)
	var tid2: String = GameStateMachine._generate_transition_id(
		GameStateMachine.GameState.WORKOUT_ACTIVE, GameStateMachine.GameState.REST_PERIOD
	)
	var tid3: String = GameStateMachine._generate_transition_id(
		GameStateMachine.GameState.REST_PERIOD, GameStateMachine.GameState.IDLE
	)

	# Assert — all distinct
	assert_ne(tid1, tid2, "Consecutive IDs must be distinct")
	assert_ne(tid2, tid3, "Consecutive IDs must be distinct")
	# Counter ended at 3
	assert_eq(PersistenceLayer.read(COUNTER_KEY), 3,
		"Counter must be 3 after 3 transitions")


## AC-gsm-tid-2 cross-reload: counter resumes from persisted value.
func test_transition_id_counter_resumes_from_persisted_value() -> void:
	# Arrange — simulate prior session left counter at 42
	PersistenceLayer.write(COUNTER_KEY, 42)

	# Act
	var tid: String = GameStateMachine._generate_transition_id(
		GameStateMachine.GameState.IDLE, GameStateMachine.GameState.WORKOUT_ACTIVE
	)

	# Assert
	assert_eq(PersistenceLayer.read(COUNTER_KEY), 43,
		"Counter must resume + increment: 42 → 43")
	assert_true(tid.contains("_43_"),
		"ID must embed counter=43")


## AC-gsm-tid-3: ID round-trips byte-identically through PersistenceLayer.
func test_transition_id_round_trips_byte_identical_through_persistence() -> void:
	# Arrange
	var tid: String = GameStateMachine._generate_transition_id(
		GameStateMachine.GameState.BOSS_ENCOUNTER, GameStateMachine.GameState.LOOT_DROP
	)

	# Act — store + retrieve
	PersistenceLayer.write("test_tid_storage", tid)
	var retrieved: Variant = PersistenceLayer.read("test_tid_storage")

	# Assert
	assert_true(retrieved is String, "Retrieved value must be a String")
	assert_eq(retrieved, tid, "Round-tripped ID must be byte-identical")


## Additional: ID format follows the documented schema.
func test_transition_id_format_matches_documented_schema() -> void:
	# Act
	var tid: String = GameStateMachine._generate_transition_id(
		GameStateMachine.GameState.IDLE, GameStateMachine.GameState.WORKOUT_ACTIVE
	)

	# Assert — split on underscores; expect at least 4 segments
	# Format: WALL_MS + _ + COUNTER + _ + FROM_NAME + _ + TO_NAME
	# Note: state names contain underscores → can't simply split! Just verify
	# the format starts with digits (wall_clock_ms) and contains the
	# digit-pattern counter section.
	var parts: PackedStringArray = tid.split("_")
	assert_true(parts.size() >= 4,
		"ID must have at least 4 underscore-separated segments")
	# First segment must be numeric (wall_clock_ms)
	assert_true(parts[0].is_valid_int(),
		"First segment must be wall_clock_ms (numeric)")
	# Second segment must be numeric (counter)
	assert_true(parts[1].is_valid_int(),
		"Second segment must be counter (numeric)")
