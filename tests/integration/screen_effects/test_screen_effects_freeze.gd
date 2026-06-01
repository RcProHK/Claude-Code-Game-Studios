# ScreenEffects — Story 005: selective freeze + PROCESS_MODE_ALWAYS + hit_pause_started signal.
#
# Coverage:
#   AC-12 — hit_pause → get_tree().paused=true; SUT PROCESS_MODE_ALWAYS keeps ticking;
#           PAUSABLE sibling frozen; manual drain → paused=false.
#   AC-13 — HitPaused → Active: paused=false; hit_pause_started NOT re-emitted on exit.
#   AC-25 — entering HitPaused: hit_pause_started(duration_ms:int) emitted synchronously with
#           paused=true; duration_ms ≤ 120.
#
# GUT runs a REAL SceneTree headless — get_tree().paused is real + readable. Timer drain is
# driven by manual _sut._process(delta) (no reliance on auto frame loop). after_each MUST
# restore get_tree().paused=false or every later test is poisoned.
extends GutTest

const SE := preload("res://src/autoload/screen_effects.gd")


## PAUSABLE counter — proves the gameplay tree freezes while the autoload keeps ticking.
class _CounterNode:
	extends Node
	var count: int = 0
	func _process(_delta: float) -> void:
		count += 1


var _sut


func before_each() -> void:
	_sut = SE.new()
	add_child_autofree(_sut)
	await get_tree().process_frame
	_sut._lifecycle_state = SE.LifecycleState.ACTIVE
	_sut.set_process(false)  # drive the pause-timer drain manually (deterministic)


func after_each() -> void:
	# CRITICAL: never leak a paused tree into the next test.
	if get_tree().paused:
		get_tree().paused = false


# ---------------------------------------------------------------------------
# AC-12 — selective freeze + always-tick + drain
# ---------------------------------------------------------------------------

func test_hit_pause_freezes_tree_autoload_ticks_then_resumes() -> void:
	var sibling := _CounterNode.new()  # default PROCESS_MODE_INHERIT → PAUSABLE
	add_child_autofree(sibling)
	await get_tree().process_frame  # let sibling settle (_ready)
	_sut.hit_pause(0.12)
	assert_true(get_tree().paused, "AC-12: hit_pause engages selective freeze")
	assert_eq(_sut.process_mode, Node.PROCESS_MODE_ALWAYS, "AC-12: SUT is exempt from its own freeze")
	var before: int = sibling.count
	await get_tree().process_frame  # a real frame WHILE paused
	assert_eq(sibling.count, before, "AC-12: PAUSABLE sibling is frozen during hit pause")
	# Drain the pause timer manually (SUT keeps ticking via PROCESS_MODE_ALWAYS in production).
	for _i in 9:
		_sut._process(0.015)  # 9 × 0.015 = 0.135 > 0.12
	assert_false(get_tree().paused, "AC-12: tree auto-resumes once the pause timer drains")
	assert_almost_eq(_sut._pause_remaining_sec, 0.0, 0.001)


# ---------------------------------------------------------------------------
# AC-13 — exit no re-emit
# ---------------------------------------------------------------------------

func test_exit_does_not_reemit_signal() -> void:
	_sut.hit_pause(0.06)  # entry (emits once — before the watch below)
	watch_signals(_sut)   # baseline AFTER entry, so we only see exit-time emissions
	for _i in 6:
		_sut._process(0.015)  # drain → Active
	assert_eq(_sut._lifecycle_state, SE.LifecycleState.ACTIVE, "AC-13: returned to Active")
	assert_false(get_tree().paused, "AC-13: paused released")
	assert_signal_not_emitted(_sut, "hit_pause_started", "AC-13: signal fires on ENTER only, never on exit")


# ---------------------------------------------------------------------------
# AC-25 — synchronous signal + int duration_ms
# ---------------------------------------------------------------------------

func test_hit_pause_started_synchronous_int_payload() -> void:
	watch_signals(_sut)
	_sut.hit_pause(0.12)
	assert_signal_emitted(_sut, "hit_pause_started", "AC-25: signal emitted on entry")
	var params: Array = get_signal_parameters(_sut, "hit_pause_started", 0)
	assert_eq(typeof(params[0]), TYPE_INT, "AC-25: duration_ms is int, not float")
	assert_lte(params[0], 120, "AC-25: duration_ms ≤ MAX_PAUSE_SEC × 1000")
	assert_true(get_tree().paused, "AC-25: paused set synchronously in the same call (no call_deferred)")


func test_hit_pause_duration_ms_exact_conversion() -> void:
	watch_signals(_sut)
	_sut.hit_pause(0.06)
	var params: Array = get_signal_parameters(_sut, "hit_pause_started", 0)
	assert_eq(params[0], 60, "AC-25: 0.06s → 60ms (sec × 1000, int)")
