# ParticleSystemWrapper — Story 001: play() API + ParticleHandle contract + arg validation.
#
# Coverage:
#   AC-01 — play() in Active returns a valid live ParticleHandle (sync, generation>0,
#           pool_index>=0, preset match, != INVALID); generation monotonicity on reuse;
#           INVALID sentinel is dead.
#   AC-02 — argument validation: NaN/INF position → INVALID + no burst_started;
#           multiplier clamp to [0.1, 1.5] (>1.5 clamp+warn, <0.1 short-circuit,
#           NaN reject); boundaries accepted with no warning.
#
# A fresh PSW.new() instance with a stub node factory is used (NOT the autoload
# singleton) so the GPU node is never driven and the pool is deterministic.
extends GutTest

const PSW := preload("res://src/autoload/particle_system_wrapper.gd")


## Duck-typed GPU node stub. Defines emitting/amount/restart — none of which are
## native Node methods, so this does NOT override any native method (GUT
## phantom-pass guard, see [[project_wst_epic_status]]).
class _StubParticleNode:
	extends Node
	var emitting: bool = false
	var amount: int = 0
	var restart_count: int = 0
	var last_keep_seed: bool = true
	func restart(keep_seed: bool = false) -> void:
		restart_count += 1
		last_keep_seed = keep_seed


var _sut


func before_each() -> void:
	_sut = PSW.new()
	_sut._node_factory = func() -> Node: return _StubParticleNode.new()
	add_child_autofree(_sut)
	await get_tree().process_frame


# ---------------------------------------------------------------------------
# AC-01 — play() returns a valid live handle
# ---------------------------------------------------------------------------

func test_play_in_active_returns_live_handle() -> void:
	var h: ParticleHandle = _sut.play(PSW.PresetId.HIT_LIGHT, Vector2(100, 100), 1.0)
	assert_true(h.alive(), "AC-01: handle must be alive")
	assert_gt(h._generation, 0, "AC-01: _generation must be > 0")
	assert_gte(h._pool_index, 0, "AC-01: _pool_index must be >= 0 (not the -1 sentinel)")
	assert_eq(h.preset_id, PSW.PresetId.HIT_LIGHT, "AC-01: preset_id must match")
	assert_ne(h, ParticleHandle.INVALID, "AC-01: must not be the INVALID sentinel")


func test_play_returns_sync_particle_handle_not_coroutine() -> void:
	var h = _sut.play(PSW.PresetId.HIT_HEAVY, Vector2(10, 10), 1.0)
	# A coroutine would return a GDScriptFunctionState, not a ParticleHandle.
	assert_true(h is ParticleHandle, "AC-01: return value must be a ParticleHandle (sync, not a coroutine)")
	assert_eq(h.get_script().get_global_name(), &"ParticleHandle",
		"AC-01: script global name must be ParticleHandle")


func test_play_reused_slot_bumps_generation_invalidates_old() -> void:
	# Exhaust HIT_LIGHT's capacity tier so the only way to acquire is to reclaim a
	# stopped slot — this forces same-slot reuse and exercises generation invalidation.
	# Tier-agnostic: fill until play() starts rejecting.
	var h1: ParticleHandle = _sut.play(PSW.PresetId.HIT_LIGHT, Vector2(1, 1), 1.0)
	var g1: int = h1._generation
	var idx1: int = h1._pool_index
	var guard: int = 0
	while guard < 100:
		var h: ParticleHandle = _sut.play(PSW.PresetId.HIT_LIGHT, Vector2(9, 9), 1.0)
		if not h.alive():
			break  # tier is full
		guard += 1
	# Stop h1's slot, then play again — only h1's slot can be reclaimed in that tier.
	h1.stop()
	var h2: ParticleHandle = _sut.play(PSW.PresetId.HIT_LIGHT, Vector2(2, 2), 1.0)
	assert_eq(h2._pool_index, idx1, "AC-01: the reclaimed (stopped) slot is reused")
	assert_gt(h2._generation, g1, "AC-01: reused slot generation must increase")
	assert_false(h1.alive(), "AC-01: stale handle to reused slot must be dead")
	assert_true(h2.alive(), "AC-01: new handle to reused slot must be alive")


func test_invalid_sentinel_is_dead() -> void:
	assert_false(ParticleHandle.INVALID.alive(), "AC-01: INVALID.alive() must be false")
	assert_eq(ParticleHandle.INVALID._pool_index, -1, "AC-01: INVALID._pool_index must be -1")


# ---------------------------------------------------------------------------
# AC-02 — argument validation
# ---------------------------------------------------------------------------

func test_play_nan_position_returns_invalid_no_signal() -> void:
	watch_signals(_sut)
	var h: ParticleHandle = _sut.play(PSW.PresetId.HIT_LIGHT, Vector2(NAN, 100), 1.0)
	assert_false(h.alive(), "AC-02: NaN position must return a dead handle")
	assert_eq(h, ParticleHandle.INVALID, "AC-02: NaN position must return INVALID")
	assert_signal_not_emitted(_sut, "burst_started", "AC-02: no burst_started on reject (ghost-shake guard)")


func test_play_inf_position_returns_invalid_no_signal() -> void:
	watch_signals(_sut)
	var h_x: ParticleHandle = _sut.play(PSW.PresetId.HIT_LIGHT, Vector2(INF, 0), 1.0)
	var h_y: ParticleHandle = _sut.play(PSW.PresetId.HIT_LIGHT, Vector2(0, -INF), 1.0)
	assert_false(h_x.alive(), "AC-02: +INF.x position must be rejected")
	assert_false(h_y.alive(), "AC-02: -INF.y position must be rejected")
	assert_signal_not_emitted(_sut, "burst_started", "AC-02: no burst_started on INF reject")


func test_play_high_multiplier_clamps_and_emits() -> void:
	var warnings: Array = []
	_sut._warn_sink = func(m): warnings.append(m)
	watch_signals(_sut)
	var h: ParticleHandle = _sut.play(PSW.PresetId.HIT_LIGHT, Vector2(50, 50), 9999.0)
	assert_true(h.alive(), "AC-02: clamp path still produces a live handle")
	assert_almost_eq(_sut._last_caller_mult, 1.5, 0.0001, "AC-02: multiplier clamped to MAX_CALLER_MULTIPLIER")
	assert_eq(warnings.size(), 1, "AC-02: exactly one clamp warning fired")
	assert_signal_emitted(_sut, "burst_started", "AC-02: clamp path emits burst_started")


func test_play_low_multiplier_short_circuits_no_signal() -> void:
	watch_signals(_sut)
	var h: ParticleHandle = _sut.play(PSW.PresetId.HIT_LIGHT, Vector2(50, 50), 0.05)
	assert_false(h.alive(), "AC-02: multiplier < 0.1 short-circuits to INVALID")
	assert_eq(h, ParticleHandle.INVALID, "AC-02: low multiplier returns INVALID")
	assert_signal_not_emitted(_sut, "burst_started", "AC-02: no burst_started on low-multiplier reject")


func test_play_nan_multiplier_returns_invalid() -> void:
	watch_signals(_sut)
	var h: ParticleHandle = _sut.play(PSW.PresetId.HIT_LIGHT, Vector2(50, 50), NAN)
	assert_false(h.alive(), "AC-02: NaN multiplier must be rejected (treated as < 0.1)")
	assert_signal_not_emitted(_sut, "burst_started", "AC-02: no burst_started on NaN multiplier")


func test_play_multiplier_boundaries_accepted_no_warning() -> void:
	var warnings: Array = []
	_sut._warn_sink = func(m): warnings.append(m)
	var h_min: ParticleHandle = _sut.play(PSW.PresetId.HIT_LIGHT, Vector2(1, 1), 0.1)
	var h_max: ParticleHandle = _sut.play(PSW.PresetId.HIT_LIGHT, Vector2(2, 2), 1.5)
	assert_true(h_min.alive(), "AC-02: multiplier == 0.1 (min) accepted")
	assert_true(h_max.alive(), "AC-02: multiplier == 1.5 (max) accepted")
	assert_almost_eq(_sut._last_caller_mult, 1.5, 0.0001, "AC-02: max-boundary multiplier preserved (no clamp warning)")
	assert_eq(warnings.size(), 0, "AC-02: no warning at the accepted boundaries")
