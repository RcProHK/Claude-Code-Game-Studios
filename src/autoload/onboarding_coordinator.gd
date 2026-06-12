extends Node
## OnboardingCoordinator (#27) — first-run choreography / coaching orchestrator.
##
## Owns ONLY: (1) the four-step first-run progress latch (onboarding.* namespace, #3
## backend-primary); (2) a peripheral, dismissible, non-blocking coach-mark overlay
## (OnboardingOverlayLayer); (3) a non-binding combat "試演" preview. It mutates ZERO
## gameplay state and requests ZERO GSM transitions — pure downstream observe-only
## consumer (Rule 8 / CI lint G-OB-2). Done → permanently DORMANT (zero runtime cost).
##
## Pillars: P2 coach-mark NEVER mid-set (Formula 1 workout-critical gate, 命脈) /
## P1 first item = real #15 daily drop only (never script/fabricate/client-trigger, 命脈).
##
## Boot order (ADR-0008 / G-OB-1): tail, after every prior autoload. All predecessors
## (#1 GSM, #2, #3, #9, #10, #21, #24, …) boot earlier; _ready() sync-reads NO upstream
## (only runtime signal observe + latch read), so tail-append is dependency-safe.
## See design/gdd/onboarding-flow.md.

const F := preload("res://src/core/onboarding_formulas.gd")
const PreviewDirectorScript := preload("res://src/ui/onboarding/preview_director.gd")
const CoachMarkScript := preload("res://src/ui/onboarding/coach_mark.gd")

# --- FSM (5 states; DORMANT=0 safe ordinal-0 default per ADR-0007) ------------
enum State { DORMANT, WELCOME, PREVIEW, COACHING, COMPLETE }

# --- Telemetry signals (#28 subscribes; emit-only — never drives anything) ----
## A step latched (step ∈ OnboardingFormulas.STEP_*). once-per-step (Rule 2).
signal step_latched(step: int)
## Onboarding fully complete → permanently DORMANT (AC-04).
signal onboarding_completed()
## A coach-mark became visible (step). For #28 / a11y announce wiring (story 014).
signal coachmark_shown(step: int)
## A coach-mark was dismissed (tap / auto / silent-expire). dismissed_by ∈ {"tap","auto","silent"}.
signal coachmark_dismissed(step: int, dismissed_by: String)

# --- Persistence (Rule 2, onboarding.* namespace via #3) -----------------------
const PERSIST_KEY := "onboarding"
const SCHEMA_VERSION := 1

# --- Config (data-driven knobs) -----------------------------------------------
const CONFIG_PATH := "res://assets/data/onboarding_config.tres"

## OnboardingOverlayLayer CanvasLayer value — PROVISIONAL. Story 013 (G-OB-3) pins the
## exact value via an ADR-0001 amendment (captured band <110, coach-mark never co-frames
## world desaturation so <100 is acceptable). 63 sits above the #22/#23/#24 PAUSABLE
## coordinator layers (60/61/62) and well under #21 loot 110 / #24 banner 111.
const OVERLAY_LAYER: int = 63

# --- Untyped DI seams (reference_gdscript_di_seam — typed Node breaks member check) ---
var _gsm = null              ## #1 GameStateMachine (HARD — observe state_changed, cfis)
var _persistence = null      ## #3 PersistenceLayer (HARD — onboarding.* latch)
var _workout = null          ## #9 WorkoutStateTracker (HARD — workout lifecycle signals)
var _loot_reveal = null      ## #21 LootRevealCoordinator (SOFT — modal_dismissed trigger)
var _exercise_class = null   ## #10 ExerciseClassMapping (SOFT — teaching copy lookup)
var _platform = null         ## PlatformDetect (SOFT — announce_aria gateway, story 014)
## Optional clock seam: an object exposing now_ms() -> int. Tests inject a controllable
## clock (Formula 2 timing); production falls back to Time.get_ticks_msec().
var _clock = null

# --- Config-backed knobs (loaded; integer-ms derived once) --------------------
var _config: OnboardingConfig = null
var _auto_dismiss_ms: int = 6000
var _max_defer_ms: int = 120000

# --- Persisted latch ----------------------------------------------------------
var _completed: bool = false
var _step_connect: bool = false
var _step_preview: bool = false
var _step_class: bool = false
var _step_first_drop: bool = false

# --- Runtime FSM + coach-mark slot --------------------------------------------
var _state: int = State.DORMANT
var _ready_complete: bool = false
## Single-slot coach-mark discipline. -1 = none pending/active.
var _pending_step: int = -1
var _pending_since_ms: int = 0
var _active_step: int = -1
var _coachmark_shown_at_ms: int = 0
var _coachmark_tapped: bool = false
## The last known (non-UNKNOWN) class from #9 — feeds the Step 3 coach-mark copy.
var _pending_class: int = -1
## True between workout_started_forwarded and workout_completed_forwarded.
var _real_workout_active: bool = false
## reduced-motion → coach-mark hard cut (set by story 014 a11y wiring; default off).
var _reduced_motion: bool = false

# --- Owned overlay ------------------------------------------------------------
var _overlay_layer: CanvasLayer = null
## The single live coach-mark card (single-slot discipline).
var _coach_mark = null

# --- Step 2 preview presenter (Q-OB-1 scene path deferred → MVP placeholder timer) ---
var _preview_director = null
var _preview_scene_path: String = ""


func _ready() -> void:
	if _gsm == null:
		_gsm = _node_or_null(&"GameStateMachine")
	if _persistence == null:
		_persistence = _node_or_null(&"PersistenceLayer")
	if _workout == null:
		_workout = _node_or_null(&"WorkoutStateTracker")
	if _loot_reveal == null:
		_loot_reveal = _node_or_null(&"LootRevealCoordinator")
	if _exercise_class == null:
		_exercise_class = _node_or_null(&"ExerciseClassMapping")
	if _platform == null:
		_platform = _node_or_null(&"PlatformDetect")

	_load_config_or_crash()
	_read_persistence()
	_read_reduced_motion()
	_instantiate_overlay()

	# Formula 3 — pick the boot resume state from the persisted latches (completed-first).
	_state = F.resume_state(_completed, _step_connect, _step_preview, _step_class, _step_first_drop)

	if _state == State.DORMANT:
		# AC-05 — done (or self-heal corruption): zero subscriptions, zero surface, terminal.
		_ready_complete = true
		set_process(false)
		return
	if _state == State.COMPLETE:
		# EC-09 self-heal: four latches set but completed unwritten → write + DORMANT.
		_finish()
		_ready_complete = true
		set_process(false)
		return

	# Active first-run: wire the observe-only subscription set (Rule 8).
	_wire_subscriptions()
	_ready_complete = true
	# EC-05 — resuming directly into PREVIEW replays the (non-binding) preview.
	if _state == State.PREVIEW:
		_start_preview()


func _process(_delta: float) -> void:
	if not _ready_complete or _state == State.DORMANT or _state == State.COMPLETE:
		return
	if _state == State.PREVIEW and _preview_director != null and _preview_director.is_running():
		_preview_director.tick()  # duration-driven finish (Step 2)
	_service_coachmark()


# --- Config / persistence -----------------------------------------------------

func _load_config_or_crash() -> void:
	# Respect a pre-injected config (test seam — a fresh OnboardingConfig.new() avoids mutating
	# the shared cached .tres resource, reference_test_persistence_isolation family).
	if _config == null:
		_config = load(CONFIG_PATH) as OnboardingConfig
	assert(_config != null, "[Onboarding] config missing at " + CONFIG_PATH)
	var err := _config.validate()
	assert(err == "", "[Onboarding] config invalid: " + err)
	# Integer-ms discipline: convert float-sec knobs to ms once (Formula 2).
	_auto_dismiss_ms = int(_config.coach_auto_dismiss_sec * 1000.0)
	_max_defer_ms = int(_config.coach_max_defer_sec * 1000.0)


func _read_persistence() -> void:
	# EC-07/AC-22: read failure / first boot → all-false (show onboarding); NEVER fabricate
	# completed=true (that would rob a real new player of onboarding).
	var raw = _persistence.read(PERSIST_KEY) if _persistence != null else null
	if raw == null or not (raw is Dictionary):
		return
	var d: Dictionary = raw
	_completed = bool(d.get("completed", false))
	_step_connect = bool(d.get("step_connect", false))
	_step_preview = bool(d.get("step_preview", false))
	_step_class = bool(d.get("step_class", false))
	_step_first_drop = bool(d.get("step_first_drop", false))


func _write_persistence() -> bool:
	if _persistence == null:
		return false
	return _persistence.write(PERSIST_KEY, {
		"completed": _completed,
		"step_connect": _step_connect,
		"step_preview": _step_preview,
		"step_class": _step_class,
		"step_first_drop": _step_first_drop,
		"schema_version": SCHEMA_VERSION,
	})


# --- Subscription bootstrap (observe-only, Rule 8) ----------------------------

func _wire_subscriptions() -> void:
	# #1 GSM via connect_for_initial_state (ADR-0006 C6) — boot-current state replayed so the
	# connect landing / workout-critical gating sees the initial state even if it fired pre-boot.
	# Guarded against double-connect so the whole bootstrap is idempotent (EC double-subscribe).
	if _gsm != null and _gsm.has_method("connect_for_initial_state"):
		if not (_gsm.has_signal("state_changed") and _gsm.is_connected("state_changed", _on_gsm_state_changed)):
			_gsm.connect_for_initial_state(_on_gsm_state_changed)
	# #9 / #21 are plain domain-event broadcasts (not GSM-style initial-state delivery) →
	# has_signal-guarded connect, idempotent (loot_drop / #25 raw-connect precedent).
	_connect_guarded(_workout, "workout_started_forwarded", _on_workout_started)
	_connect_guarded(_workout, "dominant_class_changed", _on_dominant_class_changed)
	_connect_guarded(_workout, "workout_completed_forwarded", _on_workout_completed)
	_connect_guarded(_loot_reveal, "modal_dismissed", _on_modal_dismissed)


func _connect_guarded(obj, signal_name: String, cb: Callable) -> void:
	if obj == null or not obj.has_signal(signal_name):
		return
	if not obj.is_connected(signal_name, cb):
		obj.connect(signal_name, cb)


func _disconnect_all() -> void:
	# AC-04 — on completion: disconnect every signal so a DORMANT coordinator is inert.
	if _gsm != null and _gsm.has_signal("state_changed") and _gsm.is_connected("state_changed", _on_gsm_state_changed):
		_gsm.disconnect("state_changed", _on_gsm_state_changed)
	_disconnect_guarded(_workout, "workout_started_forwarded", _on_workout_started)
	_disconnect_guarded(_workout, "dominant_class_changed", _on_dominant_class_changed)
	_disconnect_guarded(_workout, "workout_completed_forwarded", _on_workout_completed)
	_disconnect_guarded(_loot_reveal, "modal_dismissed", _on_modal_dismissed)


func _disconnect_guarded(obj, signal_name: String, cb: Callable) -> void:
	if obj != null and obj.has_signal(signal_name) and obj.is_connected(signal_name, cb):
		obj.disconnect(signal_name, cb)


# --- Signal handlers (observe-only — never request a transition / mutate) ------

func _on_gsm_state_changed(_from_state, to_state, _payload) -> void:
	if not _ready_complete:
		return
	# Step 1 — connect detection (WELCOME): GSM left BOOTING into a connected landing.
	if _state == State.WELCOME and not _step_connect and _is_connected_state(to_state):
		_enqueue_coachmark(F.STEP_CONNECT)
		# FSM transition is connect-driven (latch-orthogonal): skip PREVIEW if already mid-workout.
		if _workout_in_progress():
			_step_preview = true  # done-by-workout (EC-02 / AC-19)
			_write_persistence()
			_state = State.COACHING
		else:
			_enter_preview()


func _on_workout_started() -> void:
	if not _ready_complete:
		return
	_real_workout_active = true
	# EC-03 / AC-18 — real workout always beats the demo: abort PREVIEW, latch step_preview
	# as done-by-workout, advance to COACHING.
	if _state == State.PREVIEW and not _step_preview:
		_stop_preview()
		_latch_step(F.STEP_PREVIEW, false)  # done-by-workout, no coach-mark
		_state = State.COACHING


func _on_workout_completed(_completed_at: int, _transition_id: String) -> void:
	if not _ready_complete:
		return
	_real_workout_active = false


func _on_dominant_class_changed(new_class: int) -> void:
	if not _ready_complete or _state != State.COACHING or _step_class:
		return
	# EC-11 / AC-20 — never name UNKNOWN; wait for a known class (STRIKE/CONTROL/MOBILITY).
	if new_class == _ABILITY_UNKNOWN:
		return
	_pending_class = new_class  # feeds the coach-mark copy ("…→ STRIKE 着燈")
	_enqueue_coachmark(F.STEP_CLASS)


func _on_modal_dismissed(_drop_id: String, terminal: bool) -> void:
	if not _ready_complete or _state != State.COACHING or _step_first_drop:
		return
	# Step 4 — first terminal loot reveal dismissal (AC-09). The coach-mark fires AFTER the
	# ceremony dismiss (never overlaid on the sacred #21 surface, Pillar 3).
	if terminal:
		_enqueue_coachmark(F.STEP_FIRST_DROP)


# --- Preview control (Step 2; called by the preview presenter — story 008) -----

## Preview finished / skipped / disabled → latch step_preview, advance to COACHING (AC-07).
## Called by OnboardingPreviewDirector (timeout / skip / load-fail) or directly in tests.
func notify_preview_finished() -> void:
	if _state != State.PREVIEW or _step_preview:
		return
	_stop_preview()
	_latch_step(F.STEP_PREVIEW, false)
	_state = State.COACHING


## Player tapped the preview skip affordance (UX-07). Delegates to the director.
func skip_preview() -> void:
	if _preview_director != null and _preview_director.is_running():
		_preview_director.skip()


func _enter_preview() -> void:
	_state = State.PREVIEW
	_start_preview()


func _start_preview() -> void:
	# Instantiate the non-binding preview presenter (Step 2). preview_enabled=false OR a
	# load failure inside start() finishes immediately → notify_preview_finished → COACHING.
	if _preview_director != null:
		return
	_preview_director = PreviewDirectorScript.new()
	_preview_director._clock = _clock
	_preview_director.name = "OnboardingPreviewDirector"
	add_child(_preview_director)
	_preview_director.start(self, _config, _preview_scene_path)
	# UX-11 — announce the 試演 framing so SR users know it is NOT real progress (Pillar 1).
	if _preview_director.is_running():
		_announce("試演 / Preview — 非真實 progress")


func _stop_preview() -> void:
	if _preview_director != null and is_instance_valid(_preview_director):
		_preview_director.queue_free()
	_preview_director = null


# --- Coach-mark slot service (Formula 1/2, EC-12/13) --------------------------

func _enqueue_coachmark(step: int) -> void:
	# Single-slot, step-ordered queue (EC-13). A lower step index wins the slot; a higher
	# one waits. If nothing pending, take the slot; if a lower step is pending, keep it.
	if _pending_step == -1 or step < _pending_step:
		if _pending_step != -1 and _pending_step != step:
			# Displaced higher-order pending stays implicitly re-enqueued on its own trigger;
			# MVP single trigger-per-step means this path is defensive only.
			pass
		_pending_step = step
		_pending_since_ms = _now_ms()
	# Try to service immediately (so a non-critical window shows without waiting a frame).
	_service_coachmark()


func _service_coachmark() -> void:
	# Auto-dismiss / tap-dismiss the active coach-mark first (Formula 2).
	if _active_step != -1:
		if F.is_dismissed(_now_ms(), _coachmark_shown_at_ms, _auto_dismiss_ms, _coachmark_tapped):
			var by := "tap" if _coachmark_tapped else "auto"
			_dismiss_active(by)
		else:
			return  # slot occupied — hold pending

	if _pending_step == -1:
		return

	# coach_marks_enabled=false escape hatch → silent latch, no display (Tuning Knobs).
	if not _config.coach_marks_enabled:
		_silent_latch_pending()
		return

	# Formula 1 — may we show this frame?
	var latch_done := _is_step_latched(_pending_step)
	if latch_done:
		_pending_step = -1
		return
	if F.may_show(_state, latch_done, _is_workout_critical(), _active_step != -1):
		_show_pending()
	elif F.defer_expired(_now_ms(), _pending_since_ms, _max_defer_ms):
		# EC-12 / AC-13 — deferred too long → silent latch (stale teaching worse than none).
		_silent_latch_pending()
	# else: stay pending, re-judged next frame / next state change.


func _show_pending() -> void:
	var step := _pending_step
	_active_step = step
	_coachmark_shown_at_ms = _now_ms()
	_coachmark_tapped = false
	_pending_step = -1
	_build_coach_mark(step)
	_latch_step(step, true)  # AC-06/08/09 — show THEN latch (atomic from the player's view)
	coachmark_shown.emit(step)


func _dismiss_active(by: String) -> void:
	var step := _active_step
	_active_step = -1
	_coachmark_tapped = false
	_teardown_coach_mark()
	coachmark_dismissed.emit(step, by)


# --- Coach-mark card (single-slot UI on OnboardingOverlayLayer) ----------------

func _build_coach_mark(step: int) -> void:
	if _overlay_layer == null or not is_instance_valid(_overlay_layer):
		return
	if _config != null and not _config.coach_marks_enabled:
		return
	_teardown_coach_mark()
	_coach_mark = CoachMarkScript.new()
	_coach_mark.name = "OnboardingCoachMark"
	_overlay_layer.add_child(_coach_mark)
	var fade := _config.coach_fade_sec if _config != null else 0.25
	var copy := _coach_copy(step)
	_coach_mark.setup(copy, fade, _reduced_motion)
	_overlay_layer.visible = true
	_announce(copy)  # UX-11 — SR polite announce (never interrupts), color-independent copy


func _teardown_coach_mark() -> void:
	if _coach_mark != null and is_instance_valid(_coach_mark):
		_coach_mark.fade_out_and_free()
	_coach_mark = null
	if _overlay_layer != null and is_instance_valid(_overlay_layer):
		_overlay_layer.visible = false


## Localized coach-mark copy (廣東話 witness 語氣; class name is color-independent — a11y).
func _coach_copy(step: int) -> String:
	match step:
		F.STEP_CONNECT:
			return "連好喇 — 睇下你個角色"
		F.STEP_CLASS:
			var cls := _class_name(_pending_class)
			if cls == "":
				return "你嘅訓練決定你嘅 class"  # AC-20 generic (never names UNKNOWN)
			return "你今日嘅訓練 → %s 着燈" % cls
		F.STEP_FIRST_DROP:
			return "頭先爆嗰件係你真實做嘢換返嚟 — 以後日日做日日有"
	return ""


## #12 AbilityClass int → display name (STRIKE/CONTROL/MOBILITY; UNKNOWN/other → "").
func _class_name(c: int) -> String:
	match c:
		0: return "STRIKE"
		1: return "CONTROL"
		2: return "MOBILITY"
	return ""


func _silent_latch_pending() -> void:
	var step := _pending_step
	_pending_step = -1
	_latch_step(step, false)
	coachmark_dismissed.emit(step, "silent")


## Public — the overlay UI (story 013) calls this on tap-anywhere (AC-12).
func notify_coachmark_tapped() -> void:
	if _active_step == -1:
		return
	_coachmark_tapped = true
	_service_coachmark()


# --- Latch / completion -------------------------------------------------------

func _latch_step(step: int, _shown: bool) -> void:
	if _set_step_latch(step):
		_write_persistence()
		step_latched.emit(step)
		_check_completion()


## Sets the per-step latch; returns true if it flipped false→true (AC-03 idempotency).
func _set_step_latch(step: int) -> bool:
	match step:
		F.STEP_CONNECT:
			if _step_connect:
				return false
			_step_connect = true
		F.STEP_PREVIEW:
			if _step_preview:
				return false
			_step_preview = true
		F.STEP_CLASS:
			if _step_class:
				return false
			_step_class = true
		F.STEP_FIRST_DROP:
			if _step_first_drop:
				return false
			_step_first_drop = true
		_:
			return false
	return true


func _check_completion() -> void:
	if _step_connect and _step_preview and _step_class and _step_first_drop:
		_finish()


func _finish() -> void:
	# AC-04 — write completed, disconnect all, hide overlay, terminal DORMANT.
	_completed = true
	_write_persistence()
	_disconnect_all()
	_active_step = -1
	_pending_step = -1
	_teardown_coach_mark()
	_stop_preview()
	_state = State.DORMANT
	set_process(false)
	onboarding_completed.emit()


# --- Overlay ------------------------------------------------------------------

func _instantiate_overlay() -> void:
	# Rule 1 — pre-warmed hidden CanvasLayer (idle zero draw-call, #21/#22/#23/#24 precedent).
	# No BackBufferCopy / no blur (ADR-0001 #21/#24 precedent). Story 013 builds the coach-mark
	# child UI + pins the exact layer value (G-OB-3 ADR-0001 amendment).
	_overlay_layer = CanvasLayer.new()
	_overlay_layer.name = "OnboardingOverlayLayer"
	_overlay_layer.layer = OVERLAY_LAYER
	_overlay_layer.visible = false
	# PAUSABLE — captured-band coordinator-layer convention (#22/#23/#24 60/61/62); coach-marks
	# only show in non-critical windows so the layer never needs to run while the tree pauses.
	_overlay_layer.process_mode = Node.PROCESS_MODE_PAUSABLE
	add_child(_overlay_layer)


# --- Read-only introspection (tests / debug — no gameplay setter API) ----------

func get_state() -> int:
	return _state

func is_completed() -> bool:
	return _completed

func is_step_latched(step: int) -> bool:
	return _is_step_latched(step)

func get_active_coachmark_step() -> int:
	return _active_step

func has_overlay() -> bool:
	return _overlay_layer != null

func is_overlay_visible() -> bool:
	return _overlay_layer != null and _overlay_layer.visible


# --- Helpers ------------------------------------------------------------------

func _is_step_latched(step: int) -> bool:
	match step:
		F.STEP_CONNECT: return _step_connect
		F.STEP_PREVIEW: return _step_preview
		F.STEP_CLASS: return _step_class
		F.STEP_FIRST_DROP: return _step_first_drop
	return false


## WORKOUT_CRITICAL = {WORKOUT_ACTIVE, REST_PERIOD, LOOT_DROP} (all #1 GSM GameState).
func _is_workout_critical() -> bool:
	if _gsm == null or not _gsm.has_method("get_current_state"):
		return false
	var s: int = _gsm.get_current_state()
	return s == _gsm_state(&"WORKOUT_ACTIVE") \
		or s == _gsm_state(&"REST_PERIOD") \
		or s == _gsm_state(&"LOOT_DROP")


func _workout_in_progress() -> bool:
	if _real_workout_active:
		return true
	if _gsm != null and _gsm.has_method("get_current_state"):
		var s: int = _gsm.get_current_state()
		return s == _gsm_state(&"WORKOUT_ACTIVE") or s == _gsm_state(&"REST_PERIOD")
	return false


## Connected landing = anything past BOOTING / DISCONNECTED / SUSPENDED (Q-OB-6 MVP proxy).
func _is_connected_state(s: int) -> bool:
	return s != _gsm_state(&"BOOTING") \
		and s != _gsm_state(&"DISCONNECTED") \
		and s != _gsm_state(&"SUSPENDED")


## #12 AbilityClass.UNKNOWN ordinal (=3) — resolved via the #10/#12 enum if exposed, else 3.
var _ABILITY_UNKNOWN: int = 3


## GSM GameState enum ordinal via the injected seam (untyped). -1 if seam absent.
func _gsm_state(name: StringName) -> int:
	if _gsm != null and "GameState" in _gsm:
		return int(_gsm.GameState[String(name)])
	return -1


## UX-10 — reduced-motion derives from settings.motion_intensity == 0 (the project-wide
## Motion Safety signal, #22/#26 convention). Missing/corrupt → default 1.0 → motion on.
func _read_reduced_motion() -> void:
	if _persistence == null or not _persistence.has_method("read"):
		return
	var v = _persistence.read("settings.motion_intensity")
	if v == null or not (v is float or v is int):
		return  # fresh / corrupt → keep default (_reduced_motion = false)
	_reduced_motion = (float(v) == 0.0)


## UX-11 — screen-reader announce via PlatformDetect (polite region: assertive=false, so it
## never interrupts other announces — #24/#19 precedent). No-op when the gateway is absent.
func _announce(text: String) -> void:
	if _platform != null and _platform.has_method("announce_aria") and text != "":
		_platform.announce_aria(text, false)


func _node_or_null(autoload_name: StringName):
	var root := get_node_or_null("/root")
	if root == null:
		return null
	return root.get_node_or_null(NodePath(String(autoload_name)))


func _now_ms() -> int:
	if _clock != null and _clock.has_method("now_ms"):
		return int(_clock.now_ms())
	return Time.get_ticks_msec()
