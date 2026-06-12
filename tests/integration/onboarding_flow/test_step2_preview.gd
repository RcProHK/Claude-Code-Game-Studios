extends GutTest
## Story 008: Step 2 non-binding preview — finish/skip → COACHING (AC-07), real-workout abort
## (AC-18/EC-03), scene-load-failure graceful skip (AC-21/EC-15), preview_enabled=false skip,
## and the 試演 watermark visible while presenting (Pillar 1 anti-deception). The non-binding
## guarantee (AC-16) is enforced statically by the G-OB-2 lint (story 012).

const CoordScript := preload("res://src/autoload/onboarding_coordinator.gd")
const PreviewScript := preload("res://src/ui/onboarding/preview_director.gd")
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


## Records the coordinator callback (preview-director-direct tests).
class SpyCoordinator:
	extends RefCounted
	var finished: int = 0
	func notify_preview_finished() -> void:
		finished += 1


func _cfg(enabled: bool = true) -> OnboardingConfig:
	var c := OnboardingConfig.new()
	c.preview_enabled = enabled
	c.preview_duration_sec = 24.0
	return c


func _coord() -> Array:
	var gsm := FakeGSM.new()
	var wst := FakeWST.new()
	var c = CoordScript.new()
	c._gsm = gsm
	c._workout = wst
	c._persistence = MockPersistence.new()
	c._loot_reveal = FakeLootReveal.new()
	c._exercise_class = RefCounted.new()
	c._platform = RefCounted.new()
	add_child_autofree(c)
	c.set_process(false)
	return [c, gsm, wst]


# --- AC-07 — skip / finish → COACHING -----------------------------------------

func test_skip_preview_advances_to_coaching() -> void:
	var arr := _coord()
	var c = arr[0]
	var gsm = arr[1]
	gsm.go(FakeGSM.GameState.IDLE)  # connect → PREVIEW (preview director started)
	assert_eq(c.get_state(), F.STATE_PREVIEW, "precondition: PREVIEW with running preview")

	# Act — player taps skip.
	c.skip_preview()

	# Assert — step_preview latched, advanced to COACHING (AC-07).
	assert_true(c.is_step_latched(F.STEP_PREVIEW), "AC-07: skip latches step_preview")
	assert_eq(c.get_state(), F.STATE_COACHING, "AC-07: skip → COACHING")


# --- AC-18 / EC-03 — real workout aborts the preview --------------------------

func test_real_workout_aborts_preview() -> void:
	var arr := _coord()
	var c = arr[0]
	var gsm = arr[1]
	var wst = arr[2]
	gsm.go(FakeGSM.GameState.IDLE)
	assert_eq(c.get_state(), F.STATE_PREVIEW, "precondition: PREVIEW")

	# Act — a real workout starts.
	wst.workout_started_forwarded.emit()

	# Assert — preview aborted, step_preview latched done-by-workout, COACHING (AC-18/EC-03).
	assert_true(c.is_step_latched(F.STEP_PREVIEW), "AC-18: step_preview latched done-by-workout")
	assert_eq(c.get_state(), F.STATE_COACHING, "AC-18/EC-03: real workout → COACHING (real beats demo)")


# --- AC-21 / EC-15 — scene load failure → graceful skip -----------------------

func test_missing_scene_finishes_gracefully() -> void:
	var spy := SpyCoordinator.new()
	var pd := PreviewScript.new()
	autofree(pd)

	# Act — start with a non-existent scene path.
	pd.start(spy, _cfg(true), "res://nonexistent_preview_scene.tscn")

	# Assert — graceful immediate finish, zero crash, never running (AC-21/EC-15).
	assert_eq(spy.finished, 1, "AC-21: missing scene → graceful finish (notify_preview_finished)")
	assert_false(pd.is_running(), "AC-21: never enters running state on load failure")


func test_preview_disabled_finishes_immediately() -> void:
	var spy := SpyCoordinator.new()
	var pd := PreviewScript.new()
	autofree(pd)

	# Act — preview_enabled=false.
	pd.start(spy, _cfg(false), "")

	# Assert — step skipped immediately (knob off).
	assert_eq(spy.finished, 1, "preview_enabled=false → immediate finish")
	assert_false(pd.is_running(), "preview_enabled=false → never runs")


# --- 試演 watermark (Pillar 1 anti-deception) ---------------------------------

func test_watermark_visible_while_presenting() -> void:
	var spy := SpyCoordinator.new()
	var pd := PreviewScript.new()
	autofree(pd)

	# Act — start a normal (enabled, no scene path → placeholder timer) preview.
	pd.start(spy, _cfg(true), "")

	# Assert — running + watermark visible (Pillar 1: never let the player think it was real).
	assert_true(pd.is_running(), "preview running")
	assert_true(pd.is_watermark_visible(), "試演 watermark visible throughout the preview")
	# And after skip → not visible.
	pd.skip()
	assert_false(pd.is_watermark_visible(), "watermark hidden after preview ends")
