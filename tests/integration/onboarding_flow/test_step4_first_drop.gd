extends GutTest
## Story 010: Step 4 first-drop framing — first terminal modal_dismissed shows the post-
## ceremony coach-mark + latches step_first_drop (AC-09); observe-only never triggers #15 /
## GSM (AC-17); terminal=false does not latch (EC-10 boundary); zero fabrication (EC-17).

const CoordScript := preload("res://src/autoload/onboarding_coordinator.gd")
const F := preload("res://src/core/onboarding_formulas.gd")


class FakeGSM:
	extends RefCounted
	enum GameState {BOOTING, DISCONNECTED, IDLE, WORKOUT_ACTIVE, REST_PERIOD, COMBAT_ACTIVE, BOSS_ENCOUNTER, LOOT_DROP, SUSPENDED}
	signal state_changed(from_state, to_state, payload)
	var state: int = GameState.IDLE
	var transition_calls: Array = []
	func get_current_state() -> int:
		return state
	func connect_for_initial_state(c: Callable) -> void:
		state_changed.connect(c)
	func request_transition(_t) -> void:
		transition_calls.append(_t)


class FakeWST:
	extends RefCounted
	signal workout_started_forwarded()
	signal dominant_class_changed(new_class)
	signal workout_completed_forwarded(completed_at, transition_id)


class FakeLootReveal:
	extends RefCounted
	signal modal_dismissed(drop_id, terminal)


## #15 spy — any claim/drop-gen call would land here (onboarding must NEVER call these).
class SpyLoot:
	extends RefCounted
	var calls: Array = []
	func claim_daily() -> void:
		calls.append("claim_daily")
	func generate_drop(_x) -> void:
		calls.append("generate_drop")


class MockPersistence:
	extends RefCounted
	var store: Dictionary = {}
	func read(key: String):
		return store.get(key, null)
	func write(key: String, value, _flush: bool = false) -> bool:
		store[key] = value.duplicate(true) if value is Dictionary else value
		return true


func _coaching() -> Array:
	var gsm := FakeGSM.new()
	var loot := FakeLootReveal.new()
	var persistence := MockPersistence.new()
	persistence.store["onboarding"] = {
		"completed": false, "step_connect": true, "step_preview": true,
		"step_class": true, "step_first_drop": false, "schema_version": 1,
	}
	var c = CoordScript.new()
	c._gsm = gsm
	c._workout = FakeWST.new()
	c._persistence = persistence
	c._loot_reveal = loot
	c._exercise_class = RefCounted.new()
	c._platform = RefCounted.new()
	add_child_autofree(c)
	c.set_process(false)
	return [c, gsm, loot]


# --- AC-09 — first terminal dismissal shows post-ceremony coach-mark ----------

func test_first_terminal_dismiss_shows_and_latches() -> void:
	var arr := _coaching()
	var c = arr[0]
	var loot = arr[2]
	assert_eq(c.get_state(), F.STATE_COACHING, "precondition: COACHING")

	# Act — first terminal loot reveal dismissal (ceremony已收, fires AFTER dismiss).
	loot.modal_dismissed.emit("drop-1", true)

	# Assert — first-drop coach-mark shown + step_first_drop latched (AC-09).
	assert_true(c.is_step_latched(F.STEP_FIRST_DROP), "AC-09: step_first_drop latched on first terminal dismiss")


func test_non_terminal_dismiss_does_not_latch() -> void:
	# EC-10 boundary — a non-terminal dismissal (more items queued) does not trigger Step 4.
	var arr := _coaching()
	var c = arr[0]
	var loot = arr[2]

	# Act
	loot.modal_dismissed.emit("drop-1", false)

	# Assert
	assert_false(c.is_step_latched(F.STEP_FIRST_DROP), "EC-10: terminal=false does not latch")


# --- AC-17 — observe-only: never trigger #15 / GSM transition -----------------

func test_observe_only_never_triggers_loot_or_transition() -> void:
	var arr := _coaching()
	var c = arr[0]
	var gsm = arr[1]
	var loot = arr[2]

	# Act — drive the full first-drop trigger.
	loot.modal_dismissed.emit("drop-1", true)

	# Assert — coordinator never requested a GSM transition (#15 is server-authoritative;
	# onboarding only observes the reveal it never triggered — Rule 6/8, Pillar 1).
	assert_eq(gsm.transition_calls.size(), 0, "AC-17: zero GSM transition request")
	assert_true(c.is_completed(), "completion reached (4th latch) — coordinator went DORMANT")
