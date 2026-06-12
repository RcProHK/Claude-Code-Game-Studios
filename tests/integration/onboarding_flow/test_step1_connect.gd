extends GutTest
## Story 007: Step 1 Connect (WELCOME) — connect-landing detection → welcome coach-mark +
## step_connect latch + transition to PREVIEW (AC-06), connect-mid-workout skip to COACHING
## (AC-19/EC-02), login-failing stays WELCOME silent (EC-16). FakeGSM injected before add_child.

const CoordScript := preload("res://src/autoload/onboarding_coordinator.gd")
const F := preload("res://src/core/onboarding_formulas.gd")


class FakeGSM:
	extends RefCounted
	enum GameState {BOOTING, DISCONNECTED, IDLE, WORKOUT_ACTIVE, REST_PERIOD, COMBAT_ACTIVE, BOSS_ENCOUNTER, LOOT_DROP, SUSPENDED}
	signal state_changed(from_state, to_state, payload)
	var state: int = GameState.BOOTING
	func get_current_state() -> int:
		return state
	func connect_for_initial_state(c: Callable) -> void:
		state_changed.connect(c)
	func go(to_state: int) -> void:
		var prev := state
		state = to_state
		state_changed.emit(prev, to_state, null)


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


func _make(gsm) -> Node:
	var c = CoordScript.new()
	c._gsm = gsm
	c._workout = FakeWST.new()
	c._persistence = MockPersistence.new()
	c._loot_reveal = FakeLootReveal.new()
	c._exercise_class = RefCounted.new()
	c._platform = RefCounted.new()
	add_child_autofree(c)
	c.set_process(false)
	return c


# --- AC-06 — connect success → welcome + latch + PREVIEW ----------------------

func test_connect_landing_latches_connect_and_enters_preview() -> void:
	var gsm := FakeGSM.new()  # BOOTING
	var c := _make(gsm)
	assert_eq(c.get_state(), F.STATE_WELCOME, "precondition: WELCOME (BOOTING, not connected)")

	# Act — GSM lands in IDLE (connected, non-workout) → connect proxy.
	gsm.go(FakeGSM.GameState.IDLE)

	# Assert — welcome shown + step_connect latched + advanced to PREVIEW.
	assert_true(c.is_step_latched(F.STEP_CONNECT), "AC-06: step_connect latched on connect landing")
	assert_eq(c.get_state(), F.STATE_PREVIEW, "AC-06: WELCOME → PREVIEW (no active real workout)")


# --- AC-19 / EC-02 — connect mid-workout skips PREVIEW ------------------------

func test_connect_mid_workout_skips_preview_to_coaching() -> void:
	var gsm := FakeGSM.new()  # BOOTING
	var c := _make(gsm)

	# Act — player connects already mid-workout (GSM lands in WORKOUT_ACTIVE).
	gsm.go(FakeGSM.GameState.WORKOUT_ACTIVE)

	# Assert — preview skipped (done-by-workout), advanced to COACHING (AC-19/EC-02).
	assert_true(c.is_step_latched(F.STEP_PREVIEW), "AC-19: step_preview latched done-by-workout")
	assert_eq(c.get_state(), F.STATE_COACHING, "AC-19/EC-02: skip PREVIEW → COACHING (real beats demo)")


# --- EC-16 — login failing → stay WELCOME silent ------------------------------

func test_login_failing_stays_welcome_silent() -> void:
	var gsm := FakeGSM.new()  # BOOTING
	var c := _make(gsm)

	# Act — login keeps failing: GSM bounces BOOTING ↔ DISCONNECTED, never connects.
	gsm.go(FakeGSM.GameState.DISCONNECTED)
	gsm.go(FakeGSM.GameState.BOOTING)
	gsm.go(FakeGSM.GameState.DISCONNECTED)

	# Assert — never latch connect, never show, stay WELCOME (EC-16; #24 owns login error UX).
	assert_false(c.is_step_latched(F.STEP_CONNECT), "EC-16: no connect latch while login fails")
	assert_eq(c.get_state(), F.STATE_WELCOME, "EC-16: stay WELCOME, observing silently")
	assert_eq(c.get_active_coachmark_step(), -1, "EC-16: zero coach-mark while not connected")
