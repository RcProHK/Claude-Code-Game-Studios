extends GutTest
## Story 014: a11y — coach-mark screen-reader announce (UX-11, polite/non-interrupting),
## reduced-motion hard-cut derivation (UX-10), and the coach_marks_enabled=false escape
## hatch (silent latch, no announce, no card). See design/gdd/onboarding-flow.md UI §a11y.

const CoordScript := preload("res://src/autoload/onboarding_coordinator.gd")
const F := preload("res://src/core/onboarding_formulas.gd")


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


## Records announce_aria(text, assertive) calls.
class SpyPlatform:
	extends RefCounted
	var calls: Array = []
	func announce_aria(text: String, assertive: bool = true) -> void:
		calls.append({"text": text, "assertive": assertive})


func _coaching_latch() -> Dictionary:
	return {
		"completed": false, "step_connect": true, "step_preview": true,
		"step_class": false, "step_first_drop": false, "schema_version": 1,
	}


func _make(platform, persistence_extra: Dictionary = {}, config = null) -> Array:
	var gsm := FakeGSM.new()
	var wst := FakeWST.new()
	var persistence := MockPersistence.new()
	persistence.store["onboarding"] = _coaching_latch()
	for k in persistence_extra:
		persistence.store[k] = persistence_extra[k]
	var c = CoordScript.new()
	c._gsm = gsm
	c._workout = wst
	c._persistence = persistence
	c._loot_reveal = FakeLootReveal.new()
	c._exercise_class = RefCounted.new()
	c._platform = platform
	if config != null:
		c._config = config
	add_child_autofree(c)
	c.set_process(false)
	return [c, gsm, wst]


# --- UX-11 — polite announce on coach-mark show -------------------------------

func test_coach_mark_show_announces_politely() -> void:
	var platform := SpyPlatform.new()
	var arr := _make(platform)
	var c = arr[0]
	var wst = arr[2]

	# Act — class coach-mark shows.
	wst.dominant_class_changed.emit(0)  # STRIKE

	# Assert — announce_aria fired with the copy, polite (assertive=false, never interrupts).
	assert_gt(platform.calls.size(), 0, "UX-11: announce_aria fired on coach-mark show")
	var last = platform.calls[-1]
	assert_false(last["assertive"], "UX-11: polite region (assertive=false) — does not interrupt")
	assert_string_contains(String(last["text"]), "STRIKE", "UX-11: announced copy names the class")


# --- UX-10 — reduced-motion derives from motion_intensity == 0 ----------------

func test_reduced_motion_from_zero_motion_intensity() -> void:
	var platform := SpyPlatform.new()
	var arr := _make(platform, {"settings.motion_intensity": 0.0})
	var c = arr[0]
	assert_true(c._reduced_motion, "UX-10: motion_intensity==0 → reduced-motion (coach-mark hard cut)")


func test_default_motion_intensity_is_not_reduced() -> void:
	var platform := SpyPlatform.new()
	var arr := _make(platform)  # no motion_intensity key → default 1.0
	var c = arr[0]
	assert_false(c._reduced_motion, "default motion_intensity → motion on")


# --- coach_marks_enabled=false escape hatch -----------------------------------

func test_escape_hatch_silent_latches_no_announce_no_card() -> void:
	var platform := SpyPlatform.new()
	var cfg := OnboardingConfig.new()
	cfg.coach_marks_enabled = false  # escape hatch
	var arr := _make(platform, {}, cfg)
	var c = arr[0]
	var wst = arr[2]

	# Act — class trigger fires with coach-marks disabled.
	wst.dominant_class_changed.emit(0)

	# Assert — step silently latches; zero announce, zero card (degrades to a latch tracker).
	assert_true(c.is_step_latched(F.STEP_CLASS), "escape hatch: step still silently latches")
	assert_eq(c.get_active_coachmark_step(), -1, "escape hatch: no coach-mark shown")
	assert_eq(platform.calls.size(), 0, "escape hatch: zero screen-reader announce")
