# ParticleSystemWrapper — Story 006: burst_started emit ordering + re-entry guard.
#
# Coverage:
#   AC-12 — emit ordering apply_preset → restart(keep_seed=false) → burst_started → emitting=true;
#           position applied before the signal; restart called once.
#   AC-13 — re-entrant play() from a burst_started handler is queued (PENDING, _pool_index=-1),
#           executed at frame end via _flush_deferred, _emit_depth returns to 0, no overflow.
#
# AC-14 (build-time CI lint check_particle_preset_magic.gd) is covered separately by
# tests/static/test_particle_ci_lint.gd (regex/fixture verification — not a GUT runtime test).
extends GutTest

const PSW := preload("res://src/autoload/particle_system_wrapper.gd")


## Node2D stub (global_position for _apply_preset) that records an ordered call log so the
## emit sequence can be asserted. restart()/emitting are not native Node2D members → no
## native-method override (GUT phantom-pass guard).
class _LogStubNode:
	extends Node2D
	var log_ref: Array = []
	var amount: int = 0  # boot-set by _build_tier (Node2D has no native `amount`)
	var restart_count: int = 0
	var _emitting: bool = false
	var emitting: bool:
		set(v):
			_emitting = v
			if v:
				log_ref.append("emitting_true")
		get:
			return _emitting
	func restart(keep_seed: bool = false) -> void:
		restart_count += 1
		log_ref.append("restart:%s" % str(keep_seed))


var _sut
var _log: Array = []


func before_each() -> void:
	_log = []
	_sut = PSW.new()
	_sut._node_factory = func() -> Node:
		var n := _LogStubNode.new()
		n.log_ref = _log
		return n
	add_child_autofree(_sut)
	await get_tree().process_frame
	_log.clear()  # discard any boot noise (none expected — boot sets amount only)


# ---------------------------------------------------------------------------
# AC-12 — emit ordering
# ---------------------------------------------------------------------------

func test_emit_order_is_restart_then_signal_then_emitting() -> void:
	_sut.burst_started.connect(func(_pid, _pos): _log.append("signal"))
	var h: ParticleHandle = _sut.play(PSW.PresetId.HIT_LIGHT, Vector2(100, 50), 1.0)
	assert_true(h.alive(), "AC-12: play succeeds")
	assert_eq(_log, ["restart:false", "signal", "emitting_true"],
		"AC-12: ordering must be restart(keep_seed=false) → burst_started → emitting=true")


func test_apply_preset_sets_position_before_emit() -> void:
	var pos_at_signal := {"p": null}
	_sut.burst_started.connect(func(_pid, _pos):
		# At signal time the node is configured (position applied) but not yet emitting.
		pass)
	var h: ParticleHandle = _sut.play(PSW.PresetId.HIT_LIGHT, Vector2(123, 456), 1.0)
	assert_eq(h._slot.node.global_position, Vector2(123, 456),
		"AC-12: _apply_preset set the node position before the burst")
	assert_eq(h._slot.node.restart_count, 1, "AC-12: restart called exactly once")
	pos_at_signal.clear()


func test_listener_sees_node_not_yet_emitting() -> void:
	# Rule 11 core guarantee: at the burst_started callback, emitting is still false
	# (the "emitting_true" log entry comes AFTER "signal").
	_sut.burst_started.connect(func(_pid, _pos): _log.append("signal"))
	_sut.play(PSW.PresetId.HIT_LIGHT, Vector2(0, 0), 1.0)
	var signal_idx: int = _log.find("signal")
	var emitting_idx: int = _log.find("emitting_true")
	assert_gt(signal_idx, -1, "AC-12: signal fired")
	assert_gt(emitting_idx, signal_idx, "AC-12: emitting=true happens strictly after the signal")


# ---------------------------------------------------------------------------
# AC-13 — re-entry guard
# ---------------------------------------------------------------------------

func test_reentrant_play_is_queued_and_resolved_on_flush() -> void:
	var nested := {"h": null}
	_sut.burst_started.connect(func(_pid, _pos):
		if nested["h"] == null:
			nested["h"] = _sut.play(PSW.PresetId.HIT_HEAVY, Vector2(5, 5), 1.0))
	var outer: ParticleHandle = _sut.play(PSW.PresetId.HIT_LIGHT, Vector2(0, 0), 1.0)
	assert_true(outer.alive(), "AC-13: outer play succeeds")
	var n: ParticleHandle = nested["h"]
	assert_not_null(n, "AC-13: the listener re-entered play()")
	assert_eq(n._pool_index, -1, "AC-13: nested play returns a PENDING handle (_pool_index == -1)")
	assert_false(n.alive(), "AC-13: PENDING handle is not alive before flush")
	assert_eq(_sut._emit_depth, 0, "AC-13: _emit_depth returns to 0 after the outer play")

	_sut._flush_deferred()
	assert_true(n.alive(), "AC-13: PENDING handle resolved to a live slot after flush")
	assert_eq(_sut._emit_depth, 0, "AC-13: _emit_depth back to 0 after flush (no leak)")


func test_no_depth_leak_subsequent_play_succeeds() -> void:
	_sut.burst_started.connect(func(_pid, _pos):
		if _sut._emit_depth == 1:  # only re-enter from the very first (outer) emit
			_sut.play(PSW.PresetId.HIT_HEAVY, Vector2(5, 5), 1.0))
	_sut.play(PSW.PresetId.HIT_LIGHT, Vector2(0, 0), 1.0)
	_sut._flush_deferred()
	# After all re-entry handling, a fresh non-nested play must work and depth be 0.
	var after: ParticleHandle = _sut.play(PSW.PresetId.PARRY, Vector2(1, 1), 1.0)
	assert_true(after.alive(), "AC-13: subsequent non-nested play works (no depth leak)")
	assert_eq(_sut._emit_depth, 0, "AC-13: _emit_depth is 0 after all activity")
