extends GutTest
## Story 011: coach-mark defer loop + stale silent-latch (AC-13/EC-12) + single-slot queue
## order (EC-13). FakeClock drives the defer timeout; GSM critical-toggle drives the defer
## window. Injected before add_child; _process ticked manually.

const CoordScript := preload("res://src/autoload/onboarding_coordinator.gd")
const F := preload("res://src/core/onboarding_formulas.gd")
const MAX_DEFER_MS := 120000  # int(coach_max_defer_sec 120.0 * 1000)


class FakeGSM:
	extends RefCounted
	enum GameState {BOOTING, DISCONNECTED, IDLE, WORKOUT_ACTIVE, REST_PERIOD, COMBAT_ACTIVE, BOSS_ENCOUNTER, LOOT_DROP, SUSPENDED}
	signal state_changed(from_state, to_state, payload)
	var state: int = GameState.IDLE
	func get_current_state() -> int:
		return state
	func connect_for_initial_state(c: Callable) -> void:
		state_changed.connect(c)


class FakeWST:
	extends RefCounted
	signal workout_started_forwarded()
	signal dominant_class_changed(new_class)
	signal workout_completed_forwarded(completed_at, transition_id)


class FakeLootReveal:
	extends RefCounted
	signal modal_dismissed(drop_id, terminal)


class MockPersistence:
	extends RefCounted
	var store: Dictionary = {}
	func read(key: String):
		return store.get(key, null)
	func write(key: String, value, _flush: bool = false) -> bool:
		store[key] = value.duplicate(true) if value is Dictionary else value
		return true


class FakeClock:
	extends RefCounted
	var ms: int = 0
	func now_ms() -> int:
		return ms


func _coaching(gsm, clock) -> Node:
	var persistence := MockPersistence.new()
	persistence.store["onboarding"] = {
		"completed": false, "step_connect": true, "step_preview": true,
		"step_class": false, "step_first_drop": false, "schema_version": 1,
	}
	var c = CoordScript.new()
	c._gsm = gsm
	c._workout = FakeWST.new()
	c._persistence = persistence
	c._loot_reveal = FakeLootReveal.new()
	c._exercise_class = RefCounted.new()
	c._platform = RefCounted.new()
	c._clock = clock
	add_child_autofree(c)
	c.set_process(false)
	return c


# --- AC-13 / EC-12 — defer too long → silent latch ----------------------------

func test_defer_beyond_max_silently_latches() -> void:
	var gsm := FakeGSM.new()
	gsm.state = FakeGSM.GameState.WORKOUT_ACTIVE  # critical → coach-mark defers
	var clock := FakeClock.new()
	var c := _coaching(gsm, clock)

	# Act — class trigger fires while mid-set → pending (deferred, not shown).
	c._workout.dominant_class_changed.emit(0)  # STRIKE
	assert_eq(c.get_active_coachmark_step(), -1, "deferred: nothing shown mid-set")
	assert_false(c.is_step_latched(F.STEP_CLASS), "deferred: not yet latched")

	# Act — time passes well past the defer ceiling, still mid-set.
	clock.ms = MAX_DEFER_MS
	c._process(0.0)

	# Assert — silent latch: step completes WITHOUT ever showing stale teaching (AC-13/EC-12).
	assert_true(c.is_step_latched(F.STEP_CLASS), "AC-13: step silently latched after max defer")
	assert_eq(c.get_active_coachmark_step(), -1, "AC-13: never shown (stale teaching suppressed)")


func test_defer_then_window_clears_shows_not_silent() -> void:
	# Boundary — deferred but the critical window clears before max_defer → shows (not silent).
	var gsm := FakeGSM.new()
	gsm.state = FakeGSM.GameState.WORKOUT_ACTIVE
	var clock := FakeClock.new()
	var c := _coaching(gsm, clock)
	c._workout.dominant_class_changed.emit(0)
	assert_eq(c.get_active_coachmark_step(), -1, "deferred while critical")

	# Act — window clears (back to IDLE) before the defer ceiling.
	gsm.state = FakeGSM.GameState.IDLE
	clock.ms = 5000
	c._process(0.0)

	# Assert — now it shows (not a stale silent latch).
	assert_eq(c.get_active_coachmark_step(), F.STEP_CLASS, "window cleared → coach-mark shows")


# --- EC-13 — single-slot queue order (class before first-drop) ----------------

func test_two_triggers_same_frame_queue_by_step_order() -> void:
	var gsm := FakeGSM.new()  # IDLE
	var clock := FakeClock.new()
	var c := _coaching(gsm, clock)

	watch_signals(c)

	# Act — two triggers "same frame": class (step order earlier) + first-drop.
	c._workout.dominant_class_changed.emit(0)        # STEP_CLASS
	c._loot_reveal.modal_dismissed.emit("d1", true)  # STEP_FIRST_DROP

	# Assert — class wins the single slot first; first-drop waits (not yet shown/latched).
	assert_eq(c.get_active_coachmark_step(), F.STEP_CLASS, "EC-13: class shows first (step order)")
	assert_true(c.is_step_latched(F.STEP_CLASS), "EC-13: class latched on show")
	assert_false(c.is_step_latched(F.STEP_FIRST_DROP), "EC-13: first-drop queued, not yet shown")

	# Act — dismiss class → first-drop takes the slot, shows, latches (the 4th → completes).
	c.notify_coachmark_tapped()

	# Assert — first-drop WAS shown (not silent-latched), then completion cleared the slot.
	# (4th arg of assert_signal_emitted_with_parameters is the emission index, not a message.)
	assert_signal_emitted_with_parameters(c, "coachmark_shown", [F.STEP_FIRST_DROP])
	assert_true(c.is_step_latched(F.STEP_FIRST_DROP), "EC-13: first-drop latched on show (took the slot)")
	assert_true(c.is_completed(), "EC-13: 4th latch → onboarding complete + DORMANT")
