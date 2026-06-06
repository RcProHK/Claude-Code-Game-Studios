## PrDetection — #18 PR Detection & Avatar Progression (autoload skeleton, Story 002).
##
## Driving GDD: design/gdd/pr-detection.md (Rule 10 boot / States / Rule 11 signals)
## Driving Story: production/epics/pr-detection/story-002-autoload-wiring-gates.md
## Governing ADRs: ADR-0011 §D-4 (caller path = THIS file — CI whitelist), ADR-0008
## (G-PR-3: tail append after AttentionBudget; constraint
## #2 ≺ #10 ≺ StatSystem ≺ {AbilitySystem, WST} ≺ PrDetection), ADR-0006 C4/C6.
##
## Boot contract (AC-27): _ready() is SYNCHRONOUS — load `pr.state` BEFORE
## subscribing #2, READY by end of frame (INITIALISING never spans frames).
## #2 events all arrive via async HTTP callbacks after the boot frame, so there
## is structurally no pre-READY window. Server baseline rides the first polling
## state response (ADR-0011 §D-2.4) — no separate request is issued here.
##
## Reverse-wiring (G-PR-4 pinned): #18 connects its OWN pr_breakthrough signal
## into AbilitySystem._on_pr_breakthrough (ability_system.gd:895 — the shipped
## comment L884-888 reserves that handler as #18's stable entry point) and into
## the #9 G-PR-2 handler (story 014; guarded until it ships).
extends Node


## PR confirmed — consumed by #12 (Path A unlock) + #9 (G-PR-2 daily count).
## magnitude = clamped pr_magnitude ∈ [MIN_PR_MAGNITUDE, 2.0] (relative ratio, NOT delta).
signal pr_breakthrough(stat_id: StringName, magnitude: float)

## Baseline Forged moment (Rule 11 / AC-28) — establishment window commit, per new exercise.
signal baseline_established(exercise_id: String, e1rm: float)

## Veteran import reveal hook (Rule 11) — first server sync with non-empty history.
signal baseline_import_completed(exercise_count: int)

## Lifetime PR count crossed a PRMilestoneConfig threshold (Rule 9 — MVP telemetry only).
signal pr_milestone_reached(count: int)


enum SystemState { INITIALISING, READY }

var _system_state: int = SystemState.INITIALISING

# --- DI seams (untyped — typed autoload seams fail compile-time member checks) ---
var _persistence            ## seam ⑥ #3 IPersistence (default /root/PersistenceLayer)
var _gym_sys                ## seam ① #2 signal source (set_logged / workout_started / workout_completed)
var _class_mapping          ## seam ③ #10 get_class_for_exercise
var _stat_system            ## seam ④ #11 apply_stat_delta / get_stat
var _gsm                    ## seam ⑧ #1 GSM (connect_for_initial_state)
var _ability_handler: Callable = Callable()   ## seam ⑦ #12 reverse-wire target (G-PR-4)
var _wst_handler: Callable = Callable()       ## seam ⑦ #9 G-PR-2 handler (story 014)

## seam ⑤ — telemetry append-log (#15/#17 verbatim pattern; future #28 forwarding).
var _telemetry_log: Array[Dictionary] = []

## pr.state envelope working copy (story 003 owns the full schema + round-trip).
var _state_data: Dictionary = {}


func _ready() -> void:
	_resolve_default_seams()
	# AC-27 binding order: load local state BEFORE subscribing the #2 stream.
	_load_state()
	_wire_consumers()
	_subscribe_sources()
	_system_state = SystemState.READY


## True once boot completed (synchronous in _ready — Contract 4 friendly getter).
func is_ready() -> bool:
	return _system_state == SystemState.READY


## Test/telemetry surface (seam ⑤) — append-log, never cleared at runtime.
func get_telemetry() -> Array[Dictionary]:
	return _telemetry_log


func _resolve_default_seams() -> void:
	if _persistence == null:
		_persistence = get_node_or_null("/root/PersistenceLayer")
	if _gym_sys == null:
		_gym_sys = get_node_or_null("/root/GymSysBackendClient")
	if _class_mapping == null:
		_class_mapping = get_node_or_null("/root/ExerciseClassMapping")
	if _stat_system == null:
		_stat_system = get_node_or_null("/root/StatSystem")
	if _gsm == null:
		_gsm = get_node_or_null("/root/GameStateMachine")
	if not _ability_handler.is_valid():
		var ability := get_node_or_null("/root/AbilitySystem")
		if ability != null and ability.has_method("_on_pr_breakthrough"):
			# G-PR-4 pinned entry point (ability_system.gd:895).
			_ability_handler = Callable(ability, "_on_pr_breakthrough")
	if not _wst_handler.is_valid():
		var wst := get_node_or_null("/root/WorkoutStateTracker")
		# G-PR-2 handler ships in story 014 — guard until then.
		if wst != null and wst.has_method("_on_pr_breakthrough"):
			_wst_handler = Callable(wst, "_on_pr_breakthrough")


func _load_state() -> void:
	if _persistence == null:
		return
	var raw: Variant = _persistence.read("pr.state")
	if raw is Dictionary:
		_state_data = raw
	# Full envelope validation/round-trip + stale-candidates discard = story 003.


func _wire_consumers() -> void:
	# Reverse-wire (G-PR-4): #18 connects its own signal into the consumers'
	# handlers — emitter-after-consumer boot order makes this the safe direction.
	if _ability_handler.is_valid():
		pr_breakthrough.connect(_ability_handler)
	if _wst_handler.is_valid():
		pr_breakthrough.connect(_wst_handler)


func _subscribe_sources() -> void:
	# #2 is currently a stub with no signals — has_signal guards keep boot safe
	# (WorkoutAudioAdapter precedent); tests inject a mock source with the signals.
	if _gym_sys != null:
		if _gym_sys.has_signal("set_logged"):
			_gym_sys.set_logged.connect(_on_set_logged)
		if _gym_sys.has_signal("workout_started"):
			_gym_sys.workout_started.connect(_on_workout_started)
		if _gym_sys.has_signal("workout_completed"):
			_gym_sys.workout_completed.connect(_on_workout_completed)
	if _gsm != null and _gsm.has_method("connect_for_initial_state"):
		_gsm.connect_for_initial_state(_on_gsm_state_changed)


## #2 set_logged handler — judgment pipeline lands in stories 004/005.
func _on_set_logged(_exercise_id: String, _reps: int, _weight: float) -> void:
	pass  # Story 004 (eligibility) + 005 (judgment pipeline).


## #2 workout_started — summary clear + workout_seq increment (story 010 / 003).
func _on_workout_started() -> void:
	pass  # Story 010 (summary clear) + 003 (workout_seq).


## #2 workout_completed — establishment-window commit (story 006).
func _on_workout_completed(_completed_at: int) -> void:
	pass  # Story 006 (Formula 4 commit + Baseline Forged).


## GSM listener — telemetry-silent (Rule 10); pending-emit buffer flush = story 011.
## Signature matches GSM `state_changed(from_state: GameState, to_state: GameState,
## payload: StateTransitionPayload)` — third arg is the typed payload OBJECT
## (game_state_machine.gd:158), untyped here per the DI-seam discipline.
func _on_gsm_state_changed(_from_state: int, _to_state: int, _payload) -> void:
	pass  # Story 011 (Rule 6.7 one-slot buffer flush on leave-SUSPENDED).


func _emit_telemetry(event: String, data: Dictionary) -> void:
	_telemetry_log.append({"event": event, "data": data})
