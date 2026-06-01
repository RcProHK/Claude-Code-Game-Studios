# ParticleSystemWrapper — Story 004: LRU eviction + hybrid LOOT carve-out.
#
# Coverage:
#   AC-08 — non-LOOT evicts oldest slot above the 150ms floor; protects <150ms;
#           evicted node emitting=false (NOT restart/queue_free); ledger decremented.
#   AC-09 — LOOT carve-out: a LOOT request bypasses the floor that a non-LOOT request
#           cannot; a YOUNG LOOT burst is never evicted; an OLD LOOT (>150ms) is
#           evictable (so a new loot moment always lands — Pillar 3).
#   AC-10 — combat all-protected: INVALID, no burst_started, _dropped_play_calls +1,
#           warning throttled to ≤1 per WARNING_THROTTLE_MS.
#
# NOTE (spec discovery): with the tier-segmented pool (Rule 4/5), LOOT presets always
# use the LARGE tier and no combat/status preset ever reaches LARGE (max DEATH
# 28×1.5=42 → MEDIUM). So the carve-out's cross-tier "LOOT evicts a HIT_LIGHT" is
# architecturally unreachable; _try_evict is tier-aware and the is_loot floor-bypass is
# tested directly on a tier. LOOT is effectively capped at 2 concurrent (LARGE size).
extends GutTest

const PSW := preload("res://src/autoload/particle_system_wrapper.gd")


class _StubParticleNode:
	extends Node
	var emitting: bool = false
	var amount: int = 0
	var restart_count: int = 0
	func restart(_keep_seed: bool = false) -> void:
		restart_count += 1


var _sut
var _clock: Dictionary = {"t": 0}


func before_each() -> void:
	_clock = {"t": 0}
	_sut = PSW.new()
	_sut._node_factory = func() -> Node: return _StubParticleNode.new()
	_sut._now_provider = func() -> int: return _clock["t"]
	add_child_autofree(_sut)
	await get_tree().process_frame


func _count_free_slots(tier: String) -> int:
	var n: int = 0
	for s in _sut._pool:
		if s.tier == tier and not s.is_emitting:
			n += 1
	return n


# ---------------------------------------------------------------------------
# AC-08 — non-LOOT eviction: oldest above floor, protect below
# ---------------------------------------------------------------------------

func test_ac08_evicts_oldest_above_floor_protects_below() -> void:
	# 7 HIT_LIGHT at t=0, 1 at t=100 → SMALL tier (8 nodes) full.
	for i in 7:
		_sut.play(PSW.PresetId.HIT_LIGHT, Vector2(i, i), 1.0)
	_clock["t"] = 100
	var young: ParticleHandle = _sut.play(PSW.PresetId.HIT_LIGHT, Vector2(99, 99), 1.0)
	var total_before: int = _sut._active_particle_total  # 8 × 8 = 64
	# Advance: old bursts age 200ms (> floor), young ages 100ms (< floor).
	_clock["t"] = 200
	var ok: bool = _sut._try_evict("SMALL", 8, false)
	assert_true(ok, "AC-08: eviction frees a slot when an above-floor victim exists")
	assert_true(young._slot.is_emitting, "AC-08: young (<150ms) slot is floor-protected (not evicted)")
	assert_eq(_count_free_slots("SMALL"), 1, "AC-08: exactly one SMALL slot evicted")
	# Inspect the victim slot (the only freed SMALL slot).
	var victim = null
	for s in _sut._pool:
		if s.tier == "SMALL" and not s.is_emitting:
			victim = s
	assert_false(victim.node.emitting, "AC-08: evicted node.emitting == false (natural fade)")
	assert_eq(victim.node.restart_count, 1, "AC-08: evicted node NOT re-restarted (no restart() on evict)")
	assert_true(is_instance_valid(victim.node), "AC-08: evicted node NOT queue_free'd")
	assert_eq(_sut._active_particle_total, total_before - 8, "AC-08: ledger decremented by the evicted count")


# ---------------------------------------------------------------------------
# AC-09 — hybrid LOOT carve-out
# ---------------------------------------------------------------------------

func test_ac09_loot_request_bypasses_floor_that_nonloot_cannot() -> void:
	# Fill SMALL with 8 young HIT_LIGHT (all < 150ms).
	for i in 8:
		_sut.play(PSW.PresetId.HIT_LIGHT, Vector2(i, i), 1.0)
	_clock["t"] = 50  # all bursts age 50ms → floor-protected
	assert_false(_sut._try_evict("SMALL", 8, false),
		"AC-09: a non-LOOT request cannot bypass the floor (all young → no eviction)")
	assert_true(_sut._try_evict("SMALL", 8, true),
		"AC-09: a LOOT request bypasses the floor to evict a young non-LOOT victim")


func test_ac09_young_loot_is_never_evicted() -> void:
	# LARGE tier: 2 young LOOT bursts; a new LOOT request cannot evict either → reject.
	_sut.play(PSW.PresetId.LOOT_BURST, Vector2(0, 0), 1.0)
	_sut.play(PSW.PresetId.LOOT_RARE_BURST, Vector2(1, 1), 1.0)
	_clock["t"] = 50  # both young (< 150ms)
	assert_false(_sut._try_evict("LARGE", 100, true),
		"AC-09: a young LOOT burst is never evicted (even by another LOOT) → reject")


func test_ac09_old_loot_is_evictable_so_new_loot_lands() -> void:
	# LARGE: 2 LOOT aged > floor; a new LOOT evicts the oldest (Pillar 3 — loot moment lands).
	_sut.play(PSW.PresetId.LOOT_BURST, Vector2(0, 0), 1.0)
	_sut.play(PSW.PresetId.LOOT_RARE_BURST, Vector2(1, 1), 1.0)
	_clock["t"] = 500  # both old (> 150ms)
	assert_true(_sut._try_evict("LARGE", 100, true),
		"AC-09: an old (>150ms) LOOT burst is evictable so a fresh loot moment always lands")


# ---------------------------------------------------------------------------
# AC-10 — combat all-protected reject + throttle
# ---------------------------------------------------------------------------

func test_ac10_combat_all_protected_returns_invalid_no_signal() -> void:
	watch_signals(_sut)
	for i in 8:
		_sut.play(PSW.PresetId.HIT_LIGHT, Vector2(i, i), 1.0)
	_clock["t"] = 50  # all young → floor-protected
	var sig_before: int = get_signal_emit_count(_sut, "burst_started")
	var dropped_before: int = _sut._dropped_play_calls
	var h: ParticleHandle = _sut.play(PSW.PresetId.HIT_HEAVY, Vector2(9, 9), 1.0)
	assert_false(h.alive(), "AC-10: combat play returns INVALID when all slots are protected")
	assert_eq(h, ParticleHandle.INVALID, "AC-10: returns the INVALID sentinel")
	assert_eq(_sut._dropped_play_calls, dropped_before + 1, "AC-10: _dropped_play_calls += 1")
	assert_eq(get_signal_emit_count(_sut, "burst_started"), sig_before,
		"AC-10: no burst_started on reject (ghost-shake guard)")


func test_ac10_dropped_warning_throttled_to_one_per_window() -> void:
	var warnings: Array = []
	_sut._warn_sink = func(m): warnings.append(m)
	for i in 8:
		_sut.play(PSW.PresetId.HIT_LIGHT, Vector2(i, i), 1.0)
	_clock["t"] = 50  # fixed within one throttle window
	for i in 5:
		_sut.play(PSW.PresetId.HIT_HEAVY, Vector2(i, i), 1.0)  # 5 consecutive rejects
	assert_eq(_sut._dropped_play_calls, 5, "AC-10: all 5 drops counted")
	assert_lte(warnings.size(), 1, "AC-10: dropped warning throttled to ≤1 per WARNING_THROTTLE_MS")
