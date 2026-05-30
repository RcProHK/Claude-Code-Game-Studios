## test_daily_token_gate_second_workout_same_day.gd — Story 011 AC-43
##
## Governing story: production/epics/loot-drop-system/story-011-daily-token-trigger-routing.md
## Governing ADRs : ADR-0005 (daily token gate); ADR-0009 §2 (late-bind workout_id)
##
## AC-43: when the daily token for today is already consumed, a second
## workout_completed for the same UTC day must be skipped with
## loot_daily_token_skipped telemetry. Boss/enemy triggers remain active.
##
## Also covers: first token claim, EC-15 (non-mini-boss silent drop),
## handler disabled-state guards, and INV-12 (late-bound workout_id null branch).
extends GutTest


# ── Fixtures ────────────────────────────────────────────────────────────────────

var _sut: LootDropSystem
var _mock_persistence: MockPersistenceLayer
var _config: LootRarityConfig
var _loot_dropped_signals: Array = []

const _FIXED_DATE: String = "2026-05-30"  # deterministic UTC date for all tests
const _TOKEN_KEY: String = "loot.daily_token_used." + _FIXED_DATE


func _make_config() -> LootRarityConfig:
	var c := LootRarityConfig.new()
	c.workout_weight = 0.75
	c.rng_weight = 0.25
	c.target_exercises = 5
	c.pr_bonus_per_pr = 0.12
	c.max_pr_factor = 1.25
	c.streak_scale = 28.0
	c.max_streak_bonus = 0.20
	c.tier_thresholds = [0.0, 0.35, 0.55, 0.72, 0.88]
	c.tier_values = [0, 1, 2, 3, 4]
	return c


func before_each() -> void:
	_loot_dropped_signals.clear()
	_mock_persistence = MockPersistenceLayer.new()
	_config = _make_config()

	_sut = LootDropSystem.new()
	_sut._config = _config
	_sut._persistence = _mock_persistence
	_sut._gymsys_client = null   # Offline mode — claim always succeeds
	_sut._gsm = null
	_sut._today_override = _FIXED_DATE  # Pin UTC date for determinism

	_sut.loot_dropped.connect(func(di, rt, it, tid): _loot_dropped_signals.append(di))

	add_child_autofree(_sut)
	await get_tree().process_frame
	_sut.clear_telemetry()


func after_each() -> void:
	_sut = null
	_mock_persistence = null
	_config = null


# ── AC-43: second workout same day skipped ─────────────────────────────────────

func test_ac43_second_workout_emits_daily_token_skipped_telemetry() -> void:
	# Arrange: pre-consume today's token.
	_mock_persistence.write(_TOKEN_KEY, {"used_at": 1748563200})
	# Act: second workout fires.
	_sut._handle_workout_completed("W-B-second", 5)
	# Assert: skip telemetry emitted.
	var skip_events := _sut.get_telemetry("loot_daily_token_skipped")
	assert_eq(skip_events.size(), 1,
		"AC-43: second workout_completed must emit loot_daily_token_skipped")
	assert_eq(skip_events[0]["data"]["workout_id"], "W-B-second",
		"AC-43: skip telemetry must carry workout_id of the skipped workout")
	assert_eq(skip_events[0]["data"]["reason"], "already_consumed_today",
		"AC-43: skip reason must be 'already_consumed_today'")


func test_ac43_second_workout_does_not_emit_loot_dropped() -> void:
	# Arrange: token already consumed.
	_mock_persistence.write(_TOKEN_KEY, {"used_at": 1748563200})
	# Act.
	_sut._handle_workout_completed("W-B-second", 5)
	# Assert: no loot_dropped for daily source.
	assert_eq(_loot_dropped_signals.size(), 0,
		"AC-43: second workout_completed must NOT emit loot_dropped (daily source skipped)")


func test_ac43_daily_token_does_not_block_enemy_killed() -> void:
	# Arrange: token consumed. Mini-boss enemy kill should still work.
	_mock_persistence.write(_TOKEN_KEY, {"used_at": 1748563200})
	# Act: mini-boss kill.
	_sut._handle_enemy_killed("T-enemy-001", "goblin", "mini_boss")
	# Assert: loot_dropped CAN be emitted (independent budget from daily token).
	# We can't guarantee loot_dropped because ceremony cap etc., but we verify
	# no loot_daily_token_skipped was emitted (enemy_killed is independent).
	var skip_events := _sut.get_telemetry("loot_daily_token_skipped")
	assert_eq(skip_events.size(), 0,
		"AC-43: enemy_killed must NOT trigger daily token gate (independent budget)")


# ── First token claim ─────────────────────────────────────────────────────────

func test_first_workout_writes_token_to_persistence() -> void:
	# Arrange: no token yet.
	assert_null(_mock_persistence.read(_TOKEN_KEY),
		"Precondition: token key must not exist before first workout")
	# Act.
	_sut._handle_workout_completed("W-A-first", 5)
	# Assert: token key written.
	var token_data := _mock_persistence.read(_TOKEN_KEY)
	assert_not_null(token_data,
		"First workout_completed must write loot.daily_token_used.<today> to PL")


func test_first_workout_emits_loot_dropped() -> void:
	# No pre-existing token → daily drop should generate.
	_sut._handle_workout_completed("W-A-first", 5)
	assert_eq(_loot_dropped_signals.size(), 1,
		"First workout_completed must emit loot_dropped (daily drop generated)")


func test_first_workout_no_skip_telemetry() -> void:
	_sut._handle_workout_completed("W-A-first", 5)
	var skip_events := _sut.get_telemetry("loot_daily_token_skipped")
	assert_eq(skip_events.size(), 0,
		"First workout_completed must NOT emit loot_daily_token_skipped")


# ── EC-15: non-mini-boss enemy silent drop ────────────────────────────────────

func test_ec15_normal_mob_tier_returns_silently_no_telemetry() -> void:
	_sut._handle_enemy_killed("T-mob-001", "goblin", "normal_mob")
	# No telemetry, no drop.
	assert_eq(_loot_dropped_signals.size(), 0,
		"EC-15: normal_mob tier must produce no loot_dropped")
	assert_eq(_sut._telemetry_log.size(), 0,
		"EC-15: normal_mob tier must produce no telemetry (hygiene)")


func test_ec15_mini_boss_tier_proceeds() -> void:
	# Mini-boss tier must pass through (unlike normal_mob).
	_sut._handle_enemy_killed("T-miniboss-001", "goblin", "mini_boss")
	# At minimum, the transition was processed (not silently dropped).
	# With FULL_CEREMONY: loot_dropped emitted.
	# We just verify no silent-drop telemetry gap.
	assert_true(
		_loot_dropped_signals.size() > 0 or _sut._pending_drops.size() > 0,
		"EC-15: mini_boss tier must produce a LootDrop (not silently filtered)"
	)


# ── Handler disabled-state guards ──────────────────────────────────────────────

func test_workout_completed_skipped_when_state_disabled() -> void:
	# Force disabled state.
	_sut._state = LootDropSystem.State.DISABLED
	_sut._handle_workout_completed("W-disabled", 5)
	assert_eq(_loot_dropped_signals.size(), 0,
		"_handle_workout_completed must be a no-op in Disabled state")


func test_enemy_killed_skipped_when_state_disabled() -> void:
	_sut._state = LootDropSystem.State.DISABLED
	_sut._handle_enemy_killed("T-disabled", "goblin", "mini_boss")
	assert_eq(_loot_dropped_signals.size(), 0,
		"_handle_enemy_killed must be a no-op in Disabled state")


func test_boss_killed_skipped_when_state_disabled() -> void:
	_sut._state = LootDropSystem.State.DISABLED
	_sut._handle_boss_killed("T-boss-disabled", "boss_id", "final")
	assert_eq(_loot_dropped_signals.size(), 0,
		"_handle_boss_killed must be a no-op in Disabled state")


# ── INV-12: late-bound workout_id with null branch ────────────────────────────

func test_workout_completed_null_tracker_proceeds_without_crash() -> void:
	# _workout_tracker = null → get_active_workout_id() returns null → NON_CEREMONY_ROUTE
	_sut._workout_tracker = null
	_sut._handle_workout_completed("W-null-tracker", 5)
	pass_test("_handle_workout_completed with null _workout_tracker must not crash")


func test_enemy_killed_null_tracker_null_workout_id_branch() -> void:
	# null workout_id → _ceremony_cap_check returns NON_CEREMONY_ROUTE (loot persists, no ceremony).
	_sut._workout_tracker = null
	_sut._handle_enemy_killed("T-null-tracker", "goblin", "mini_boss")
	# Drop should be in _pending_drops (NON_CEREMONY_ROUTE = no ceremony, but drop generated).
	# Or may have no drop if NON_CEREMONY_ROUTE = silent generate.
	pass_test("_handle_enemy_killed with null _workout_tracker must not crash")
