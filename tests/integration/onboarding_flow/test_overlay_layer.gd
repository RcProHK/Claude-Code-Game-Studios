extends GutTest
## Story 013: OnboardingOverlayLayer (G-OB-3) — layer 63 in the captured band (<100),
## pre-warmed visible=false, NO BackBufferCopy (opacity-only, ADR-0001 #21/#24 ruling),
## single coach-mark slot. See ADR-0001 #27 amendment + design/ux/onboarding-flow.md.

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


func _make(latch: Dictionary = {}) -> Array:
	var gsm := FakeGSM.new()
	var wst := FakeWST.new()
	var loot := FakeLootReveal.new()
	var persistence := MockPersistence.new()
	if not latch.is_empty():
		persistence.store["onboarding"] = latch
	var c = CoordScript.new()
	c._gsm = gsm
	c._workout = wst
	c._persistence = persistence
	c._loot_reveal = loot
	c._exercise_class = RefCounted.new()
	c._platform = RefCounted.new()
	add_child_autofree(c)
	c.set_process(false)
	return [c, gsm, wst, loot]


func _coachmark_children(layer: CanvasLayer) -> Array:
	var out: Array = []
	for ch in layer.get_children():
		if ch is OnboardingCoachMark:
			out.append(ch)
	return out


# --- G-OB-3 — layer 63 captured band, pre-warmed hidden -----------------------

func test_overlay_layer_is_63_captured_band_prewarmed_hidden() -> void:
	var arr := _make()
	var c = arr[0]
	var layer: CanvasLayer = c._overlay_layer
	assert_not_null(layer, "G-OB-3: OnboardingOverlayLayer must exist")
	assert_eq(layer.layer, 63, "G-OB-3: OnboardingOverlayLayer at layer 63")
	assert_lt(layer.layer, 100, "G-OB-3: captured band (<100) — coach-mark defers during desaturation (R-2)")
	assert_false(layer.visible, "G-OB-3: pre-warmed visible=false (idle zero draw-call)")


func test_overlay_has_no_backbuffercopy() -> void:
	var arr := _make({
		"completed": false, "step_connect": true, "step_preview": true,
		"step_class": false, "step_first_drop": false, "schema_version": 1,
	})
	var c = arr[0]
	var wst = arr[2]
	# Show a coach-mark so the overlay actually has card content.
	wst.dominant_class_changed.emit(0)  # STRIKE
	var bbcopies = c._overlay_layer.find_children("*", "BackBufferCopy", true, false)
	assert_eq(bbcopies.size(), 0,
		"G-OB-3: opacity-only — NO BackBufferCopy under OnboardingOverlayLayer (ADR-0001 #21/#24 ruling)")


# --- Single-slot discipline ---------------------------------------------------

func test_single_coach_mark_slot() -> void:
	var arr := _make({
		"completed": false, "step_connect": true, "step_preview": true,
		"step_class": false, "step_first_drop": false, "schema_version": 1,
	})
	var c = arr[0]
	var wst = arr[2]
	var loot = arr[3]

	# Act — two triggers; single slot means only one card is built at a time.
	wst.dominant_class_changed.emit(0)        # class coach-mark shows
	loot.modal_dismissed.emit("d1", true)     # first-drop queued (not shown)

	# Assert — exactly one coach-mark card on the overlay.
	assert_eq(_coachmark_children(c._overlay_layer).size(), 1,
		"single-slot: at most one coach-mark card on the overlay at a time")


func test_coach_mark_copy_names_class() -> void:
	# Story 009 copy wiring — class coach-mark names the class (color-independent, a11y).
	var arr := _make({
		"completed": false, "step_connect": true, "step_preview": true,
		"step_class": false, "step_first_drop": false, "schema_version": 1,
	})
	var c = arr[0]
	var wst = arr[2]
	wst.dominant_class_changed.emit(0)  # STRIKE
	var cards := _coachmark_children(c._overlay_layer)
	assert_eq(cards.size(), 1, "class coach-mark present")
	assert_string_contains(cards[0].get_text(), "STRIKE",
		"AC-08: class coach-mark copy names the class (STRIKE), color-independent")
