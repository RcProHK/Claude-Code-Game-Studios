extends GutTest
## Story 002: OnboardingCoordinator scaffold — fresh-boot WELCOME (AC-01), cfis subscription
## set (#1 GSM via connect_for_initial_state + #9 ×3 + #21), and observe-only (Rule 8 — zero
## GSM transition request). Fully isolated via injected fakes added BEFORE add_child
## (reference_test_persistence_isolation). See design/gdd/onboarding-flow.md.

const CoordScript := preload("res://src/autoload/onboarding_coordinator.gd")
const F := preload("res://src/core/onboarding_formulas.gd")


# --- Fakes --------------------------------------------------------------------

class FakeGSM:
	extends RefCounted
	enum GameState {BOOTING, DISCONNECTED, IDLE, WORKOUT_ACTIVE, REST_PERIOD, COMBAT_ACTIVE, BOSS_ENCOUNTER, LOOT_DROP, SUSPENDED}
	signal state_changed(from_state, to_state, payload)
	var state: int = GameState.IDLE
	## Observe-only spy: any mutating call would land here (coordinator must NEVER call these).
	var transition_calls: Array = []
	func get_current_state() -> int:
		return state
	func connect_for_initial_state(c: Callable) -> void:
		state_changed.connect(c)
	func go(to_state: int) -> void:
		var prev := state
		state = to_state
		state_changed.emit(prev, to_state, null)
	func request_transition(_to) -> void:
		transition_calls.append(_to)
	func enqueue_event(_e) -> void:
		transition_calls.append(_e)


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


# --- Helpers ------------------------------------------------------------------

## Build + boot a coordinator with all seams injected (no autoload fallback, manual _process).
func _make(gsm, wst, persistence, loot = null, clock = null) -> Node:
	var c = CoordScript.new()
	c._gsm = gsm
	c._workout = wst
	c._persistence = persistence
	c._loot_reveal = loot if loot != null else FakeLootReveal.new()
	c._exercise_class = RefCounted.new()  # no lookup needed at boot
	c._platform = RefCounted.new()        # no announce at boot
	c._clock = clock if clock != null else FakeClock.new()
	add_child_autofree(c)
	c.set_process(false)
	return c


# --- AC-01 — fresh-boot WELCOME -----------------------------------------------

func test_fresh_boot_enters_welcome_with_overlay_prewarmed_hidden() -> void:
	# Arrange — empty persistence (genuine first run: completed + 4 latches all unset).
	var gsm := FakeGSM.new()
	var wst := FakeWST.new()
	var persistence := MockPersistence.new()

	# Act
	var c := _make(gsm, wst, persistence)

	# Assert — Formula 3 picks WELCOME; overlay exists, pre-warmed, hidden.
	assert_eq(c.get_state(), F.STATE_WELCOME, "AC-01: fresh boot must enter WELCOME")
	assert_true(c.has_overlay(), "AC-01: OnboardingOverlayLayer must be instantiated (pre-warmed)")
	assert_false(c.is_overlay_visible(), "AC-01: overlay must be pre-warmed visible==false")
	assert_false(c.is_completed(), "AC-01: fresh boot is not completed")


# --- cfis subscription set ----------------------------------------------------

func test_boot_wires_observe_only_subscription_set() -> void:
	# Arrange
	var gsm := FakeGSM.new()
	var wst := FakeWST.new()
	var loot := FakeLootReveal.new()
	var persistence := MockPersistence.new()

	# Act
	var c := _make(gsm, wst, persistence, loot)
	assert_not_null(c)

	# Assert — every observe-only signal in Rule 8's minimal set has a live connection.
	assert_gt(gsm.get_signal_connection_list("state_changed").size(), 0,
		"GSM state_changed must be connected via connect_for_initial_state (ADR-0006 C6)")
	assert_gt(wst.get_signal_connection_list("workout_started_forwarded").size(), 0,
		"#9 workout_started_forwarded must be connected (real-priority interrupt)")
	assert_gt(wst.get_signal_connection_list("dominant_class_changed").size(), 0,
		"#9 dominant_class_changed must be connected (Step 3 trigger)")
	assert_gt(wst.get_signal_connection_list("workout_completed_forwarded").size(), 0,
		"#9 workout_completed_forwarded must be connected (context)")
	assert_gt(loot.get_signal_connection_list("modal_dismissed").size(), 0,
		"#21 modal_dismissed must be connected (Step 4 trigger)")


func test_boot_is_idempotent_no_double_connect() -> void:
	# Arrange
	var gsm := FakeGSM.new()
	var wst := FakeWST.new()
	var persistence := MockPersistence.new()
	var c := _make(gsm, wst, persistence)

	# Act — re-run the subscription bootstrap (simulating a second _ready path).
	c._wire_subscriptions()

	# Assert — exactly one connection per signal (idempotent guard, EC double-subscribe).
	assert_eq(wst.get_signal_connection_list("workout_started_forwarded").size(), 1,
		"idempotent: workout_started_forwarded connected exactly once after re-wire")
	assert_eq(wst.get_signal_connection_list("dominant_class_changed").size(), 1,
		"idempotent: dominant_class_changed connected exactly once after re-wire")


# --- Observe-only (Rule 8) ----------------------------------------------------

func test_observe_only_never_requests_gsm_transition() -> void:
	# Arrange
	var gsm := FakeGSM.new()
	var wst := FakeWST.new()
	var persistence := MockPersistence.new()
	var c := _make(gsm, wst, persistence)

	# Act — drive a realistic sequence of state edges + workout signals.
	gsm.go(FakeGSM.GameState.IDLE)
	wst.workout_started_forwarded.emit()
	gsm.go(FakeGSM.GameState.WORKOUT_ACTIVE)
	wst.dominant_class_changed.emit(0)  # STRIKE
	gsm.go(FakeGSM.GameState.IDLE)
	wst.workout_completed_forwarded.emit(123, "t-1")

	# Assert — coordinator NEVER calls a GSM mutating method (pure observer).
	assert_eq(gsm.transition_calls.size(), 0,
		"Rule 8: onboarding must never request a GSM transition (observe-only)")
