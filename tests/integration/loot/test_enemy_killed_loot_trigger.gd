# LootDropSystem — Story 014 AC-44: enemy_killed → loot trigger (mock-scoped).
#
# Coverage:
#   AC-44a — _on_enemy_killed_payload adapter routes EnemyKilledPayload to _handle_enemy_killed.
#   AC-44b — transition_id flows verbatim into the loot RNG seed (ADR-0005 Pillar 1 chain):
#             emit enemy_killed(mini_boss payload) → loot_dropped carries same transition_id.
#   AC-44c — Regular enemy (non-mini-boss enemy_id) is silently skipped (no loot emitted).
#   AC-44d — _on_enemy_killed_payload guards: empty transition_id → no loot.
#   AC-44e — _on_workout_completed_forwarded adapter routes WST signal → _handle_workout_completed.
extends GutTest

const TX_ID := "TX-loot-014"
const MOCK_WST := preload("res://tests/helpers/mock_workout_state_tracker.gd")


## Minimal persistence stub — write() always succeeds.
## Prevents the optimistic-rollback path (Step 4) that would erase _drops_by_transition.
class StubPersistence:
	extends RefCounted
	var _data: Dictionary = {}
	func write(key: String, value: Variant, _flush: bool = false) -> bool:
		_data[key] = value
		return true
	func read(key: String) -> Variant:
		return _data.get(key, null)
	func is_private_mode() -> bool:
		return false


func before_each() -> void:
	await get_tree().process_frame
	# Inject a MockWST so _get_dominant_class() + _compute_workout_score_from_tracker() work.
	var wst := MOCK_WST.new()
	wst.dominant_ability_class = AbilitySystem.AbilityClass.STRIKE
	LootDropSystem.set(&"_workout_tracker", wst)
	# Inject a persistence stub so write() succeeds — prevents the rollback path (Step 4)
	# that would erase _drops_by_transition and make AC-44b unprovable.
	LootDropSystem.set(&"_persistence", StubPersistence.new())
	# Clear state / telemetry from prior tests.
	LootDropSystem.get(&"_pending_drops").clear()
	LootDropSystem.get(&"_drops_by_transition").clear()
	LootDropSystem.get(&"_telemetry_log").clear()
	LootDropSystem.get(&"_emit_counter_mini").clear()
	# Ensure LootDrop is in IDLE state (State.IDLE = 1, avoid BOOTING=0 which blocks triggers).
	LootDropSystem.set(&"_state", 1)  # State.IDLE ordinal


func after_each() -> void:
	await get_tree().process_frame
	LootDropSystem.set(&"_workout_tracker", null)
	LootDropSystem.set(&"_persistence", null)
	LootDropSystem.get(&"_pending_drops").clear()
	LootDropSystem.get(&"_drops_by_transition").clear()
	LootDropSystem.get(&"_telemetry_log").clear()
	LootDropSystem.get(&"_emit_counter_mini").clear()


func _make_mini_boss_payload(tx: String) -> EnemyKilledPayload:
	var p := EnemyKilledPayload.new()
	p.transition_id = tx
	p.enemy_id = &"MINI_BOSS_STRIKE_01"   # contains "mini" → tier = "mini_boss"
	p.killer_id = 0
	p.killing_ability = &"ABILITY_STRIKE_1"
	return p


func _make_regular_enemy_payload(tx: String) -> EnemyKilledPayload:
	var p := EnemyKilledPayload.new()
	p.transition_id = tx
	p.enemy_id = &"STRIKE_MOB_T1"   # no "mini" → tier = "enemy" → silent skip
	p.killer_id = 0
	p.killing_ability = &"ABILITY_STRIKE_1"
	return p


# ---------------------------------------------------------------------------
# AC-44a — adapter routing
# ---------------------------------------------------------------------------

func test_ac44a_on_enemy_killed_payload_calls_handle_enemy_killed_for_mini_boss() -> void:
	var payload := _make_mini_boss_payload(TX_ID)
	var telemetry_before: int = LootDropSystem.get(&"_telemetry_log").size()
	LootDropSystem.call("_on_enemy_killed_payload", payload)
	# A mini-boss hit that passes validation should have produced a loot trigger.
	# Either loot_dropped or telemetry shows _process_loot_trigger was reached.
	var telemetry_after: int = LootDropSystem.get(&"_telemetry_log").size()
	assert_gt(telemetry_after, telemetry_before,
		"AC-44a: _on_enemy_killed_payload for mini-boss must reach the loot trigger path (telemetry emitted)")


# ---------------------------------------------------------------------------
# AC-44b — transition_id verbatim in loot_dropped (Pillar 1 chain)
# ---------------------------------------------------------------------------

func test_ac44b_transition_id_flows_verbatim_into_loot_dropped() -> void:
	watch_signals(LootDropSystem)
	var payload := _make_mini_boss_payload(TX_ID)
	LootDropSystem.call("_on_enemy_killed_payload", payload)
	# If loot_dropped was emitted, the transition_id in the signal payload must match.
	var emit_count: int = get_signal_emit_count(LootDropSystem, "loot_dropped")
	if emit_count > 0:
		var params: Array = get_signal_parameters(LootDropSystem, "loot_dropped")
		# loot_dropped(drop_id, rarity_tier, item_type, transition_id)
		var emitted_tx: String = params[3]
		assert_eq(emitted_tx, TX_ID,
			"AC-44b: loot_dropped.transition_id must equal the source enemy_killed.transition_id (ADR-0005 Pillar 1 chain)")
	else:
		# May be in pending queue OR the idempotency-by-transition dict.
		# _drops_by_transition maps transition_id → LootDrop directly.
		var by_tx: Dictionary = LootDropSystem.get(&"_drops_by_transition")
		var pending: Dictionary = LootDropSystem.get(&"_pending_drops")
		var found_tx := by_tx.has(TX_ID)
		if not found_tx:
			for drop in pending.values():
				var ld := drop as LootDrop
				if ld != null and ld.transition_id == TX_ID:
					found_tx = true
		assert_true(found_tx,
			"AC-44b: transition_id must appear in loot_dropped, _drops_by_transition, or pending_drops (verbatim)")


# ---------------------------------------------------------------------------
# AC-44c — regular enemy silently skipped (no loot)
# ---------------------------------------------------------------------------

func test_ac44c_regular_enemy_silently_skipped() -> void:
	watch_signals(LootDropSystem)
	var payload := _make_regular_enemy_payload("TX-regular-001")
	var before_pending: int = LootDropSystem.get(&"_pending_drops").size()
	LootDropSystem.call("_on_enemy_killed_payload", payload)
	var after_pending: int = LootDropSystem.get(&"_pending_drops").size()
	assert_eq(get_signal_emit_count(LootDropSystem, "loot_dropped"), 0,
		"AC-44c: regular enemy (non-mini) must not trigger loot_dropped")
	assert_eq(before_pending, after_pending,
		"AC-44c: regular enemy must not add to pending_drops")


# ---------------------------------------------------------------------------
# AC-44d — empty transition_id guard
# ---------------------------------------------------------------------------

func test_ac44d_empty_transition_id_no_loot() -> void:
	watch_signals(LootDropSystem)
	var payload := _make_mini_boss_payload("")   # empty TX
	LootDropSystem.call("_on_enemy_killed_payload", payload)
	assert_eq(get_signal_emit_count(LootDropSystem, "loot_dropped"), 0,
		"AC-44d: empty transition_id must be rejected (no loot)")


# ---------------------------------------------------------------------------
# AC-44e — workout_completed_forwarded adapter
# ---------------------------------------------------------------------------

func test_ac44e_on_workout_completed_forwarded_routes_to_handler() -> void:
	watch_signals(LootDropSystem)
	# Inject daily-token state so the handler doesn't skip.
	# (Force _daily_token_used = false by clearing any tracking state.)
	LootDropSystem.get(&"_telemetry_log").clear()
	LootDropSystem.call("_on_workout_completed_forwarded", 1700000000, TX_ID)
	# The adapter should have reached _handle_workout_completed — verify via telemetry or pending.
	var telem: Array = LootDropSystem.get(&"_telemetry_log")
	var pending: Dictionary = LootDropSystem.get(&"_pending_drops")
	var reached := telem.size() > 0 or pending.size() > 0
	assert_true(reached,
		"AC-44e: _on_workout_completed_forwarded must route to _handle_workout_completed (telemetry or pending drop produced)")
