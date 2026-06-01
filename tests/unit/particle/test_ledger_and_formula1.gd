# ParticleSystemWrapper — Story 003: CPU ledger + Formula 1 multiplier composition.
#
# Coverage:
#   AC-05 — ledger O(1) incremental: total tracks sum of live entries; over-estimate
#           only (never under-counts); double-expire no-op; 50 paired cycles drift→0.
#   AC-06 — Formula 1 canonical worked examples (8 cases) exact.
#   AC-07 — Formula 1 clamp + round boundaries (ceiling 256, floor 1, round half-away,
#           exact boundaries no clamp).
#
# AC-06/07 hit the pure static func compute_final_count — no node/stub needed.
extends GutTest

const PSW := preload("res://src/autoload/particle_system_wrapper.gd")


## Minimal duck-typed GPU node stub (no native-method override).
class _StubParticleNode:
	extends Node
	var emitting: bool = false
	var amount: int = 0
	func restart(_keep_seed: bool = false) -> void:
		pass


var _sut


func before_each() -> void:
	_sut = PSW.new()
	_sut._node_factory = func() -> Node: return _StubParticleNode.new()
	add_child_autofree(_sut)
	await get_tree().process_frame


func _ledger_sum() -> int:
	var s: int = 0
	for entry in _sut._ledger.values():
		s += int(entry.count)
	return s


# ---------------------------------------------------------------------------
# AC-05 — CPU ledger
# ---------------------------------------------------------------------------

func test_ledger_total_equals_sum_of_live_entries() -> void:
	var ids: Array = []
	for i in 5:
		var h: ParticleHandle = _sut.play(PSW.PresetId.HIT_LIGHT, Vector2(i, i), 1.0)
		ids.append(h.handle_id)
	# 5 × HIT_LIGHT (base 8, desktop, caller 1.0) = 40.
	assert_eq(_sut._active_particle_total, 40, "AC-05: total = 5 × 8 = 40")
	assert_eq(_sut._active_particle_total, _ledger_sum(), "AC-05: total equals ledger sum")
	_sut._on_expire(ids[0])
	_sut._on_expire(ids[1])
	assert_eq(_sut._active_particle_total, _ledger_sum(), "AC-05: total tracks ledger after expiry")
	assert_eq(_sut._active_particle_total, 24, "AC-05: 40 - 2×8 = 24")


func test_ledger_never_under_estimates_over_50_cycles() -> void:
	for _i in 50:
		var h: ParticleHandle = _sut.play(PSW.PresetId.HIT_LIGHT, Vector2(0, 0), 1.0)
		if h.alive():
			_sut._on_expire(h.handle_id)
		# Invariant after every op: total never drops below the live ledger sum.
		assert_gte(_sut._active_particle_total, _ledger_sum(),
			"AC-05: total must never under-estimate the live ledger sum")
	assert_eq(_sut._active_particle_total, _ledger_sum(), "AC-05: paired play+expire reconcile exactly")
	assert_eq(_sut._ledger.size(), 0, "AC-05: all entries expired")
	assert_eq(_sut._active_particle_total, 0, "AC-05: total returns to 0")


func test_double_expire_is_noop() -> void:
	var h: ParticleHandle = _sut.play(PSW.PresetId.HIT_LIGHT, Vector2(0, 0), 1.0)
	var before: int = _sut._active_particle_total
	_sut._on_expire(h.handle_id)
	var after_first: int = _sut._active_particle_total
	_sut._on_expire(h.handle_id)  # second time — must be a no-op
	assert_eq(_sut._active_particle_total, after_first, "AC-05: double expire must not double-decrement")
	assert_eq(after_first, before - 8, "AC-05: first expire decremented by the burst count")


func test_expire_unknown_handle_id_is_noop() -> void:
	var before: int = _sut._active_particle_total
	_sut._on_expire(99999)  # never issued
	assert_eq(_sut._active_particle_total, before, "AC-05: expiring an unknown id is a no-op")


# ---------------------------------------------------------------------------
# AC-06 — Formula 1 canonical worked examples (pure static)
# ---------------------------------------------------------------------------

func test_formula1_canonical_cases_exact() -> void:
	assert_eq(PSW.compute_final_count(8, 1.0, 1.0, 1.0), 8, "AC-06: Desktop HIT_LIGHT → 8")
	assert_eq(PSW.compute_final_count(18, 1.0, 0.5, 1.0), 9, "AC-06: Mobile HIT_HEAVY (18×0.5) → 9")
	assert_eq(PSW.compute_final_count(24, 3.0, 1.0, 1.0), 72, "AC-06: Desktop LOOT_BURST (24×3) → 72")
	assert_eq(PSW.compute_final_count(24, 3.0, 0.5, 1.0), 36, "AC-06: Mobile LOOT_BURST (24×3×0.5) → 36")
	assert_eq(PSW.compute_final_count(48, 3.0, 1.0, 1.0), 144, "AC-06: Desktop LOOT_RARE_BURST (48×3) → 144")
	assert_eq(PSW.compute_final_count(48, 3.0, 1.0, 1.5), 216, "AC-06: LOOT_RARE_BURST caller1.5 (48×3×1.5) → 216")
	# caller 2.0 is clamped to 1.5 upstream in play() (Story 001); compose receives 1.5.
	assert_eq(PSW.compute_final_count(48, 3.0, 1.0, 1.5), 216, "AC-06: caller2.0 clamped → 216")
	assert_eq(PSW.compute_final_count(8, 1.0, 0.5, 1.0), 4, "AC-06: Mobile HIT_LIGHT (8×0.5) → 4")


# ---------------------------------------------------------------------------
# AC-07 — clamp + round boundaries (pure static)
# ---------------------------------------------------------------------------

func test_formula1_ceiling_clamp_to_256() -> void:
	assert_eq(PSW.compose_raw_count(96, 3.0, 1.0, 1.0), 288, "AC-07: raw pre-clamp = 288")
	assert_eq(PSW.compute_final_count(96, 3.0, 1.0, 1.0), 256, "AC-07: 288 clamped to 256 ceiling")


func test_formula1_floor_clamp_to_1() -> void:
	assert_eq(PSW.compute_final_count(4, 1.0, 0.5, 0.1), 1, "AC-07: 0.2 → round 0 → floor 1")


func test_formula1_round_half_away_from_zero() -> void:
	assert_eq(PSW.compose_raw_count(1, 1.0, 1.0, 0.5), 1, "AC-07: 0.5 → 1 (half away from zero)")
	assert_eq(PSW.compose_raw_count(3, 1.0, 1.0, 0.5), 2, "AC-07: 1.5 → 2 (half away from zero)")


func test_formula1_exact_boundaries_unchanged() -> void:
	assert_eq(PSW.compute_final_count(256, 1.0, 1.0, 1.0), 256, "AC-07: exactly 256 unchanged")
	assert_eq(PSW.compute_final_count(1, 1.0, 1.0, 1.0), 1, "AC-07: exactly 1 unchanged")
