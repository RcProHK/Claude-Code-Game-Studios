## test_ceremony_cap_micro_ack_and_final_reservation.gd
## Story 004 AC-06: mini pool → MICRO_ACK at cap=5; FINAL_BOSS pool is independent.
##
## Governing story: production/epics/loot-drop-system/story-004-formula-2-ceremony-cap.md
## Governing ADRs : ADR-0005 (primary), ADR-0009 §2 (ambient-context null branch)
## Coverage       : AC-06 (micro_ack + final reservation independence) + null branch.
extends GutTest

## Autoload script preloaded as a const (shadows the LootDropSystem autoload
## global so tests can call .new() / access enums + constants on the class).
const LootDropSystem := preload("res://src/autoload/loot_drop_system.gd")

var _sut: LootDropSystem


func before_each() -> void:
	_sut = LootDropSystem.new()
	add_child_autofree(_sut)
	await get_tree().process_frame
	# Pre-seed: W-42 already has 5 mini-boss ceremonies (at cap).
	_sut._emit_counter_mini["W-42"] = 5
	_sut._emit_counter_final["W-42"] = 0


func after_each() -> void:
	_sut = null


# ─── AC-06: 6th mini-boss → MICRO_ACK ────────────────────────────────────────

func test_ac06_sixth_mini_boss_returns_micro_ack() -> void:
	# Arrange — W-42 pre-seeded at cap (5).
	# Act
	var decision: int = _sut._ceremony_cap_check(LootEnums.SourceEventKind.MINI_BOSS, "W-42")
	# Assert
	assert_eq(decision, LootEnums.CeremonyDecision.MICRO_ACK,
		"6th mini-boss on a capped workout returns MICRO_ACK")


func test_ac06_sixth_mini_boss_persists_drop_no_ceremony_signal() -> void:
	# A MICRO_ACK path must NOT fire a full-ceremony loot reveal signal. There is no
	# loot_dropped signal on the Story 004 surface — assert the only ceremony signal
	# (loot_ceremony_capped) is the capped variant, never a full-reveal emit.
	# Arrange
	watch_signals(_sut)
	# Act
	var decision: int = _sut._ceremony_cap_check(LootEnums.SourceEventKind.MINI_BOSS, "W-42")
	# Assert — MICRO_ACK is the cap-degrade route; no FULL_CEREMONY reveal.
	assert_eq(decision, LootEnums.CeremonyDecision.MICRO_ACK,
		"capped drop still resolves (MICRO_ACK), no full-ceremony reveal path taken")
	assert_signal_emitted(_sut, "loot_ceremony_capped",
		"the cap signal fires; a full-reveal signal is never emitted on this route")


func test_ac06_loot_ceremony_capped_signal_fires_once() -> void:
	# Arrange
	watch_signals(_sut)
	# Act
	_sut._ceremony_cap_check(LootEnums.SourceEventKind.MINI_BOSS, "W-42")
	# Assert
	assert_signal_emit_count(_sut, "loot_ceremony_capped", 1,
		"loot_ceremony_capped emitted exactly once on the 6th (capped) call")


func test_ac06_telemetry_loot_ceremony_capped_fires_once() -> void:
	# Act
	_sut._ceremony_cap_check(LootEnums.SourceEventKind.MINI_BOSS, "W-42")
	# Assert
	var events: Array[Dictionary] = _sut.get_telemetry("loot_ceremony_capped")
	assert_eq(events.size(), 1,
		"_telemetry_log contains loot_ceremony_capped exactly once")


func test_ac06_telemetry_loot_micro_ack_triggered_seq_num_6() -> void:
	# Act
	_sut._ceremony_cap_check(LootEnums.SourceEventKind.MINI_BOSS, "W-42")
	# Assert
	var events: Array[Dictionary] = _sut.get_telemetry("loot_micro_ack_triggered")
	assert_eq(events.size(), 1, "loot_micro_ack_triggered fires exactly once")
	var data: Dictionary = events[0].get("data", {})
	assert_eq(data.get("mini_boss_seq_num"), 6,
		"mini_boss_seq_num is 6 (1-indexed current+1 at cap=5)")
	assert_eq(data.get("workout_id"), "W-42", "telemetry carries workout_id W-42")


func test_ac06_final_boss_independent_pool_returns_full_ceremony() -> void:
	# Arrange — W-42 mini pool is at cap, but the final pool is empty (0).
	# Act
	var decision: int = _sut._ceremony_cap_check(LootEnums.SourceEventKind.FINAL_BOSS, "W-42")
	# Assert — final pool is independent of the mini cap pressure.
	assert_eq(decision, LootEnums.CeremonyDecision.FULL_CEREMONY,
		"FINAL_BOSS on the same workout returns FULL_CEREMONY (independent pool)")
	assert_eq(int(_sut._emit_counter_final.get("W-42", 0)), 1,
		"final pool counter increments 0→1")


# ─── null workout_id branch (ADR-0009 §2) ────────────────────────────────────

func test_null_workout_id_returns_non_ceremony_route() -> void:
	# Act
	var decision: int = _sut._ceremony_cap_check(LootEnums.SourceEventKind.MINI_BOSS, null)
	# Assert
	assert_eq(decision, LootEnums.CeremonyDecision.NON_CEREMONY_ROUTE,
		"null workout_id routes to NON_CEREMONY_ROUTE (drop persists, no ceremony)")


func test_null_workout_id_emits_loot_drop_unbound_telemetry() -> void:
	# Act
	_sut._ceremony_cap_check(LootEnums.SourceEventKind.MINI_BOSS, null)
	# Assert
	var events: Array[Dictionary] = _sut.get_telemetry("loot_drop_unbound")
	assert_eq(events.size(), 1, "loot_drop_unbound telemetry emitted exactly once")
	assert_eq(events[0].get("data", {}).get("reason"), "no_active_workout",
		"loot_drop_unbound carries reason=no_active_workout")


func test_null_workout_id_does_not_crash() -> void:
	# Act — calling the null branch must complete without error.
	var decision: int = _sut._ceremony_cap_check(LootEnums.SourceEventKind.MINI_BOSS, null)
	# Assert — reaching here means no crash; pin the return for good measure.
	assert_eq(decision, LootEnums.CeremonyDecision.NON_CEREMONY_ROUTE,
		"null branch completes without crashing and returns NON_CEREMONY_ROUTE")
