extends GutTest
## Story 004: onboarding.* latch schema + per-step latch idempotency (AC-03) + DORMANT
## completion 收口 (AC-04) + read-fail conservative default (AC-22/EC-07) + step_preview
## latch-on-finish-not-on-enter (EC-05). MockPersistence injected BEFORE add_child
## (reference_test_persistence_isolation). See design/gdd/onboarding-flow.md.

const CoordScript := preload("res://src/autoload/onboarding_coordinator.gd")
const F := preload("res://src/core/onboarding_formulas.gd")


# --- Fakes --------------------------------------------------------------------

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


## read always returns null (offline first boot / read error — AC-22).
class NullReadPersistence:
	extends RefCounted
	var writes: Array = []
	func read(_key: String):
		return null
	func write(key: String, value, _flush: bool = false) -> bool:
		writes.append({"key": key, "value": value})
		return true


func _make(gsm, wst, persistence, loot) -> Node:
	var c = CoordScript.new()
	c._gsm = gsm
	c._workout = wst
	c._persistence = persistence
	c._loot_reveal = loot
	c._exercise_class = RefCounted.new()
	c._platform = RefCounted.new()
	add_child_autofree(c)
	c.set_process(false)
	return c


func _latch_dict(connect_v: bool, preview_v: bool, class_v: bool, first_drop_v: bool) -> Dictionary:
	return {
		"completed": false, "step_connect": connect_v, "step_preview": preview_v,
		"step_class": class_v, "step_first_drop": first_drop_v, "schema_version": 1,
	}


# --- AC-03 — idempotent latch -------------------------------------------------

func test_relatched_step_does_not_reshow() -> void:
	# Arrange — boot into COACHING with step_class already latched.
	var gsm := FakeGSM.new()
	var wst := FakeWST.new()
	var persistence := MockPersistence.new()
	persistence.store["onboarding"] = _latch_dict(true, true, true, false)
	var c := _make(gsm, wst, persistence, FakeLootReveal.new())
	assert_eq(c.get_state(), F.STATE_COACHING, "precondition: COACHING")

	# Act — the already-latched step's trigger fires again.
	wst.dominant_class_changed.emit(0)  # STRIKE

	# Assert — no coach-mark shown, latch stays true (恰好一次, AC-03).
	assert_eq(c.get_active_coachmark_step(), -1, "AC-03: re-fired trigger shows nothing")
	assert_true(c.is_step_latched(F.STEP_CLASS), "AC-03: latch stays true")


# --- AC-04 — DORMANT completion 收口 ------------------------------------------

func test_final_latch_completes_and_goes_dormant() -> void:
	# Arrange — three steps done, boot into COACHING; GSM IDLE (non-critical display window).
	var gsm := FakeGSM.new()
	var wst := FakeWST.new()
	var loot := FakeLootReveal.new()
	var persistence := MockPersistence.new()
	persistence.store["onboarding"] = _latch_dict(true, true, true, false)
	var c := _make(gsm, wst, persistence, loot)
	assert_eq(c.get_state(), F.STATE_COACHING, "precondition: COACHING")

	# Act — the last step's trigger fires (first terminal loot reveal dismissal).
	loot.modal_dismissed.emit("drop-1", true)

	# Assert — completed persisted, terminal DORMANT, signals disconnected.
	assert_true(c.is_completed(), "AC-04: onboarding.completed written")
	assert_eq(c.get_state(), F.STATE_DORMANT, "AC-04: terminal DORMANT")
	assert_true(bool(persistence.store["onboarding"]["completed"]), "AC-04: completed persisted true")
	assert_eq(wst.get_signal_connection_list("dominant_class_changed").size(), 0,
		"AC-04: all signals disconnected on completion")


# --- AC-22 / EC-07 — read-fail conservative default ---------------------------

func test_read_failure_defaults_all_false_never_fabricates_completed() -> void:
	# Arrange — persistence read always returns null (offline first boot / error).
	var gsm := FakeGSM.new()
	var wst := FakeWST.new()
	var persistence := NullReadPersistence.new()

	# Act
	var c := _make(gsm, wst, persistence, FakeLootReveal.new())

	# Assert — show onboarding (WELCOME), NEVER fabricate completed=true.
	assert_eq(c.get_state(), F.STATE_WELCOME, "AC-22: read fail → show onboarding (WELCOME)")
	assert_false(c.is_completed(), "AC-22: NEVER fabricate completed=true on read failure")


# --- EC-05 — step_preview latches on finish, not on PREVIEW enter -------------

func test_step_preview_not_latched_on_preview_enter() -> void:
	# Arrange — connect done, preview pending → boot resumes into PREVIEW.
	var gsm := FakeGSM.new()
	var wst := FakeWST.new()
	var persistence := MockPersistence.new()
	persistence.store["onboarding"] = _latch_dict(true, false, false, false)
	var c := _make(gsm, wst, persistence, FakeLootReveal.new())
	assert_eq(c.get_state(), F.STATE_PREVIEW, "precondition: PREVIEW")

	# Assert — entering PREVIEW must NOT latch step_preview (EC-05: crash-and-go still replays).
	assert_false(c.is_step_latched(F.STEP_PREVIEW), "EC-05: step_preview unlatched on PREVIEW enter")

	# Act — preview finishes → now it latches, advance to COACHING.
	c.notify_preview_finished()
	assert_true(c.is_step_latched(F.STEP_PREVIEW), "EC-05: step_preview latches on finish")
	assert_eq(c.get_state(), F.STATE_COACHING, "preview finish → COACHING")
