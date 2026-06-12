extends GutTest
## Story 009: Step 3 muscle=class coach-mark — first known dominant_class_changed shows +
## latches step_class (AC-08); UNKNOWN never names "UNKNOWN 着燈", waits for a known class
## (AC-20/EC-11). FakeGSM/FakeWST injected before add_child.

const CoordScript := preload("res://src/autoload/onboarding_coordinator.gd")
const F := preload("res://src/core/onboarding_formulas.gd")
const ABILITY_UNKNOWN := 3  # #12 AbilityClass.UNKNOWN (ability_system.gd:49)


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


## Boot into COACHING (connect+preview already done), GSM IDLE (non-critical display window).
func _coaching() -> Array:
	var gsm := FakeGSM.new()
	var wst := FakeWST.new()
	var persistence := MockPersistence.new()
	persistence.store["onboarding"] = {
		"completed": false, "step_connect": true, "step_preview": true,
		"step_class": false, "step_first_drop": false, "schema_version": 1,
	}
	var c = CoordScript.new()
	c._gsm = gsm
	c._workout = wst
	c._persistence = persistence
	c._loot_reveal = FakeLootReveal.new()
	c._exercise_class = RefCounted.new()
	c._platform = RefCounted.new()
	add_child_autofree(c)
	c.set_process(false)
	return [c, gsm, wst]


# --- AC-08 — known class shows + latches --------------------------------------

func test_known_class_shows_coachmark_and_latches() -> void:
	var arr := _coaching()
	var c = arr[0]
	var wst = arr[2]
	assert_eq(c.get_state(), F.STATE_COACHING, "precondition: COACHING")

	# Act — first dominant_class_changed with a known class (STRIKE=0).
	wst.dominant_class_changed.emit(0)

	# Assert — class coach-mark shown + step_class latched (AC-08).
	assert_eq(c.get_active_coachmark_step(), F.STEP_CLASS, "AC-08: class coach-mark shown")
	assert_true(c.is_step_latched(F.STEP_CLASS), "AC-08: step_class latched")


# --- AC-20 / EC-11 — UNKNOWN never names, waits for a known class -------------

func test_unknown_class_defers_until_known() -> void:
	var arr := _coaching()
	var c = arr[0]
	var wst = arr[2]

	# Act — an unmapped exercise emits UNKNOWN.
	wst.dominant_class_changed.emit(ABILITY_UNKNOWN)

	# Assert — never name UNKNOWN: nothing shown, step_class not latched (AC-20/EC-11).
	assert_eq(c.get_active_coachmark_step(), -1, "AC-20: UNKNOWN shows no coach-mark")
	assert_false(c.is_step_latched(F.STEP_CLASS), "AC-20: UNKNOWN does not latch step_class")

	# Act — a later known class arrives.
	wst.dominant_class_changed.emit(1)  # CONTROL

	# Assert — now it shows + latches.
	assert_eq(c.get_active_coachmark_step(), F.STEP_CLASS, "EC-11: known class after UNKNOWN shows")
	assert_true(c.is_step_latched(F.STEP_CLASS), "EC-11: step_class latched on first known class")
