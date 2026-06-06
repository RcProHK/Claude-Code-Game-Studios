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

## Rule 2 input sanity bounds (GDD Tuning Knobs — world record ~500kg; the MIN
## kills the tiny-baseline seed: cable/band glitch weights never enter the pipeline).
const WEIGHT_SANITY_MAX: float = 500.0
const WEIGHT_SANITY_MIN: float = 1.0

## Formula 2 knobs (GDD Tuning Knobs).
const MIN_PR_MAGNITUDE: float = 0.01        ## noise floor (1%) — knob [0.005, 0.05]
const MAGNITUDE_EPS: float = 1e-9           ## float-boundary guard (const, not a knob)
const MAGNITUDE_CLAMP: float = 2.0          ## #11 Formula 2 input range upper bound
const SUSPECT_PR_MAGNITUDE: float = 0.30    ## D8 soft-confirm threshold — knob [0.15, 0.5]
const CORROBORATION_RATIO: float = 0.95     ## D8 corroboration tolerance — knob [0.85, 1.0]

## #11 StatSource ordinal for PR (stat_system.gd StatSource.PR_BREAKTHROUGH == 0).
const _STAT_SOURCE_PR: int = 0

## D4 class → base-stat routing (#17 Q-1 lesson: StatId VALUES are lowercase
## StringNames — the enum constant names are uppercase, the values are not).
## Keys are AbilityClass ordinals (ability_system.gd:49 {STRIKE, CONTROL, MOBILITY, UNKNOWN}).
const _CLASS_TO_STAT: Dictionary = {
	0: &"str",  # STRIKE
	1: &"dex",  # CONTROL
	2: &"vit",  # MOBILITY
}

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

## pr.state envelope (Story 003 — single key, PrState SerializableResource).
var _pr_state: PrState = PrState.new()

## D2 session-confirmed floor (Story 008) — e1rms confirmed THIS session; a
## stale server snapshot may never pull a baseline below these (the catch-up
## replay would re-judge the same PR → double-count race, EC-7b). In-memory only.
var _session_floor: Dictionary = {}

## True after the first successful server baseline sync this boot (BASELINE_SYNCING
## substate exit; INV-PR-1's "trusted" definition + the import-reveal one-shot).
var _server_sync_completed: bool = false


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
		_pr_state = PrState.from_dict(raw)
	# Rule 8a: stale candidates (mid-workout crash leftovers) are discarded at
	# boot — the establishment window reopens, which can never fake a PR (INV-PR-1).
	_pr_state.candidates.clear()


## Persist the envelope (Rule 6.6 — one write per PR, flush=true on anchor
## moments). On failure: keep in-memory state (signed-consistent with any stat
## already applied) + telemetry; next boot reconciles via server / re-establishes.
func _persist_state(flush: bool) -> bool:
	if _persistence == null:
		return false
	var ok: bool = _persistence.write("pr.state", _pr_state.to_dict(), flush)
	if not ok:
		_emit_telemetry("pr.persist_failed", {"flush": flush})
	return ok


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


## #2 set_logged handler — Rule 2 eligibility gate (Story 004) → judgment (Story 005).
func _on_set_logged(exercise_id: String, reps: int, weight: float) -> void:
	var stat_id: StringName = _eligibility_stat_id(exercise_id, reps, weight)
	if stat_id == &"":
		return  # gate already emitted the skip telemetry — zero side effects.
	_judge_set(exercise_id, reps, weight, stat_id)


## Rule 2 — ordered eligibility checks; returns the routed base StatId, or &""
## on skip (telemetry emitted here; NO side effects on skip — EC-1/EC-6).
## NOTE: high reps are NOT a skip condition (D7 — clamp happens in Formula 1).
func _eligibility_stat_id(exercise_id: String, reps: int, weight: float) -> StringName:
	if reps < 1 or weight <= 0.0:
		_emit_telemetry("pr.input_invalid", {"exercise_id": exercise_id, "reps": reps, "weight": weight})
		return &""
	if weight > WEIGHT_SANITY_MAX or weight < WEIGHT_SANITY_MIN:
		_emit_telemetry("pr.input_invalid", {"exercise_id": exercise_id, "weight": weight})
		return &""
	if _class_mapping == null:
		_emit_telemetry("pr.unknown_exercise", {"exercise_id": exercise_id, "reason": "no_mapping"})
		return &""
	var ability_class: int = _class_mapping.get_class_for_exercise(StringName(exercise_id))
	if not _CLASS_TO_STAT.has(ability_class):
		# UNKNOWN (or out-of-range) — Pillar 1 cardio gate (EC-1, #11 L39 binding).
		_emit_telemetry("pr.unknown_exercise", {"exercise_id": exercise_id})
		return &""
	return _CLASS_TO_STAT[ability_class]


## Judgment pipeline (Rules 4-7, Story 005). D8 corroboration check runs FIRST
## when a pending exists (story 007); no trusted baseline → establishment window
## (story 006); otherwise Formula 2 judgment → confirm (Rule 6).
func _judge_set(exercise_id: String, reps: int, weight: float, stat_id: StringName) -> void:
	var new_e1rm: float = PRDeltaCalc.e1rm(weight, reps)

	# D8 pipeline order: corroboration check BEFORE this set's own judgment (007).
	_check_pending_corroboration(exercise_id, new_e1rm, stat_id, weight, reps)

	# Rule 4 — no trusted baseline → INV-PR-1 establishment window (006), zero PR.
	if not _pr_state.baselines.has(exercise_id):
		_establishment_update(exercise_id, new_e1rm)
		return

	# Rule 5 — Formula 2 judgment against the trusted baseline.
	var best: float = _pr_state.baselines[exercise_id]
	var raw_magnitude: float = (new_e1rm - best) / best
	if raw_magnitude < MIN_PR_MAGNITUDE - MAGNITUDE_EPS:
		return  # not a PR (noise floor; epsilon guards the exact-1% boundary — AC-24)

	var magnitude: float = raw_magnitude
	if magnitude > MAGNITUDE_CLAMP:
		magnitude = MAGNITUDE_CLAMP
		_emit_telemetry("pr.magnitude_anomaly", {
			"exercise_id": exercise_id, "raw_magnitude": raw_magnitude})

	if raw_magnitude > SUSPECT_PR_MAGNITUDE:
		# D8 soft-confirm — typo-grade jump held pending corroboration (007).
		_open_pending(exercise_id, new_e1rm, weight, reps)
		return

	_confirm_pr(exercise_id, weight, reps, new_e1rm, magnitude, stat_id)


## Rule 6 — PR 生效, binding order; EC-3 all-or-nothing on apply failure.
func _confirm_pr(exercise_id: String, weight: float, reps: int, new_e1rm: float,
		magnitude: float, stat_id: StringName) -> void:
	# 6.2-6.3 — delta via shared calc; cap short-circuit (δ==0 skips the #11 call
	# but the recognition chain below still runs — Rule 6.3 / AC-13).
	var current_stat: float = 0.0
	if _stat_system != null:
		current_stat = float(_stat_system.get_stat(stat_id))
	var delta: float = PRDeltaCalc.compute(current_stat, magnitude)
	if delta > 0.0:
		var ok: bool = _stat_system != null and _stat_system.apply_stat_delta(
			stat_id, _STAT_SOURCE_PR, delta)
		if not ok:
			return  # EC-3: abort the whole event — baseline untouched, replay re-judges.

	# 6.4 — baseline ratchets to the raw e1rm (+ D2 session floor, Story 008).
	_pr_state.baselines[exercise_id] = new_e1rm
	_session_floor[exercise_id] = new_e1rm
	# 6.5 — counters + session summary (summary lands in story 010).
	_pr_state.lifetime_count += 1
	_pr_state.lifetime_pr_score += magnitude
	_record_confirmed_pr(exercise_id, weight, reps, new_e1rm, magnitude)
	# 6.6 — single flush for the whole event (anchor moment).
	_persist_state(true)
	# 6.7 — emit (gate + one-slot buffer = story 011) + telemetry.
	pr_breakthrough.emit(stat_id, magnitude)
	_emit_telemetry("pr.detected", {
		"exercise_id": exercise_id, "magnitude": magnitude,
		"stat_id": String(stat_id), "delta": delta})


## Formula 4 / INV-PR-1 (Story 006) — establishment window: with no trusted
## baseline this set only RAISES the candidate; it can never be a PR. The window
## spans the exercise's whole first workout (a single-set window would turn the
## warmup ramp 40→50→60 into a fake-PR cascade — Pass 1's top finding).
func _establishment_update(exercise_id: String, new_e1rm: float) -> void:
	var current: float = float(_pr_state.candidates.get(exercise_id, 0.0))
	if new_e1rm > current:
		_pr_state.candidates[exercise_id] = new_e1rm
		_persist_state(false)  # non-anchor write; commit flushes at workout_completed


## D8 (Story 007) — pending corroboration check; runs BEFORE this set's own
## judgment. A corroborating set (e1rm ≥ pending × ratio) commits the pending PR
## with a COMMIT-TIME magnitude recompute against the CURRENT baseline — the
## stored magnitude may be stale (interleaved smaller PRs raised the baseline)
## and committing it as-stored would break the INV-PR-2 upper bound (AC-29).
func _check_pending_corroboration(exercise_id: String, new_e1rm: float,
		stat_id: StringName, corroborating_weight: float = 0.0,
		corroborating_reps: int = 0) -> void:
	if not _pr_state.pending.has(exercise_id):
		return
	var entry: Dictionary = _pr_state.pending[exercise_id]
	var pending_raw: float = float(entry["e1rm_raw"])
	if new_e1rm < pending_raw * CORROBORATION_RATIO:
		return  # not corroborating — the deadline (_discard_expired_pending) handles expiry
	_pr_state.pending.erase(exercise_id)
	if not _pr_state.baselines.has(exercise_id):
		return  # defensive — a suspect requires a baseline to have existed
	var best: float = _pr_state.baselines[exercise_id]
	var recomputed: float = (pending_raw - best) / best
	if recomputed < MIN_PR_MAGNITUDE - MAGNITUDE_EPS:
		# Interleaved progress superseded the pending claim — nothing left to credit.
		_emit_telemetry("pr.pending_discarded", {
			"exercise_id": exercise_id, "reason": "superseded"})
		return
	var magnitude: float = minf(recomputed, MAGNITUDE_CLAMP)
	# EC-15 audit trail: record the corroborating set (replay self-corroboration
	# residual is accepted — server-truth self-heals corrected typos).
	_emit_telemetry("pr.pending_corroborated", {
		"exercise_id": exercise_id, "pending_e1rm": pending_raw,
		"corroborating_weight": corroborating_weight,
		"corroborating_reps": corroborating_reps})
	# Commit with the PENDING set's raw tuple (summary shows the real PR set);
	# baseline rises to the pending RAW e1rm (corroborated = real — no poison).
	_confirm_pr(exercise_id, float(entry["weight"]), int(entry["reps"]),
		pending_raw, magnitude, stat_id)


## D8 (Story 007) — open / keep-highest replace.
func _open_pending(exercise_id: String, e1rm_raw: float, weight: float, reps: int) -> void:
	if _pr_state.pending.has(exercise_id):
		var existing: Dictionary = _pr_state.pending[exercise_id]
		if e1rm_raw <= float(existing["e1rm_raw"]):
			return  # keep-highest — the bigger claim keeps the higher corroboration bar
		_emit_telemetry("pr.pending_replaced", {
			"exercise_id": exercise_id, "old": existing["e1rm_raw"], "new": e1rm_raw})
	else:
		_emit_telemetry("pr.pending_opened", {
			"exercise_id": exercise_id, "e1rm_raw": e1rm_raw})
	_pr_state.pending[exercise_id] = {
		"e1rm_raw": e1rm_raw, "weight": weight, "reps": reps,
		"opened_seq": _pr_state.workout_seq,
	}
	_persist_state(false)  # pending survives crashes; non-anchor write


## Story 010 — session PR summary (Formula 5 max-magnitude tuple).
func _record_confirmed_pr(_exercise_id: String, _weight: float, _reps: int,
		_e1rm: float, _magnitude: float) -> void:
	pass  # Story 010.


## #2 workout_started — workout_seq increment (D8 discard deadline clock);
## summary clear lands in story 010.
func _on_workout_started() -> void:
	_pr_state.workout_seq += 1
	# Story 010: session summary clear (next-workout-started semantics).


## #2 workout_completed — establishment-window commit (Formula 4, Story 006)
## + D8 pending discard deadline (story 007).
func _on_workout_completed(_completed_at: int) -> void:
	var established: Array = []
	for exercise_id: Variant in _pr_state.candidates:
		var e1rm: float = _pr_state.candidates[exercise_id]
		_pr_state.baselines[exercise_id] = e1rm
		established.append([String(exercise_id), e1rm])
	_pr_state.candidates.clear()
	if not established.is_empty():
		_persist_state(true)  # baseline establishment is an anchor moment
		for entry: Variant in established:
			# Baseline Forged moment (Rule 11 / AC-28) — player-visible consumer
			# channel is a binding forward contract (#20); never telemetry-only.
			baseline_established.emit(entry[0], entry[1])
			_emit_telemetry("pr.baseline_established", {
				"exercise_id": entry[0], "e1rm": entry[1]})
	_discard_expired_pending()


## D8 (Story 007) — discard deadline: a pending that survives past the END of
## the workout AFTER the one that opened it (current_seq > opened_seq at
## workout_completed) is dropped — no corroboration arrived. GymSys-corrected
## typos never redeliver, so this also self-heals fixed entry mistakes.
func _discard_expired_pending() -> void:
	var expired: Array = []
	for exercise_id: Variant in _pr_state.pending:
		if _pr_state.workout_seq > int(_pr_state.pending[exercise_id]["opened_seq"]):
			expired.append(exercise_id)
	for exercise_id: Variant in expired:
		_pr_state.pending.erase(exercise_id)
		_emit_telemetry("pr.pending_discarded", {
			"exercise_id": String(exercise_id), "reason": "deadline"})
	if not expired.is_empty():
		_persist_state(false)


## GSM listener — telemetry-silent (Rule 10); pending-emit buffer flush = story 011.
## Signature matches GSM `state_changed(from_state: GameState, to_state: GameState,
## payload: StateTransitionPayload)` — third arg is the typed payload OBJECT
## (game_state_machine.gd:158), untyped here per the DI-seam discipline.
func _on_gsm_state_changed(_from_state: int, _to_state: int, _payload) -> void:
	pass  # Story 011 (Rule 6.7 one-slot buffer flush on leave-SUSPENDED).


## ADR-0011 §D-2 client half (Story 008) — server baselines ride the #2 polling
## state response (G-PR-1; never a separate request). Called by the #2 client
## when the response carries the baseline field; tests drive it directly
## (capture-and-release seam ②).
##
## Reconcile rules (D2): per-entry validation → reject invalid (keep local);
## server wins the PRE-session truth — but a session-confirmed PR e1rm is a
## FLOOR the reconcile may never pull below (EC-7b double-count race).
func apply_server_baselines(server_baselines: Dictionary) -> void:
	var adopted: int = 0
	for key: Variant in server_baselines:
		var exercise_id: String = str(key)
		var raw: Variant = server_baselines[key]
		# §D-2.2 per-entry validation — the near-zero lower bound is WEIGHT_SANITY_MIN
		# (0 → ÷0 fake-max-PR; 0.5 → tiny-baseline sibling); the upper bound mirrors
		# the client formula ceiling without hardcoding (knob coupling).
		var valid: bool = (raw is float or raw is int)
		var value: float = float(raw) if valid else 0.0
		if valid:
			valid = is_finite(value) \
				and value >= WEIGHT_SANITY_MIN \
				and value <= WEIGHT_SANITY_MAX * (1.0 + float(PRDeltaCalc.REP_CAP) / PRDeltaCalc.E1RM_DIVISOR)
		if not valid:
			_emit_telemetry("pr.baseline_invalid", {"exercise_id": exercise_id, "value": raw})
			continue
		var new_baseline: float = value
		if _session_floor.has(exercise_id):
			var floor_value: float = _session_floor[exercise_id]
			if value != floor_value:
				_emit_telemetry("pr.baseline_conflict", {
					"exercise_id": exercise_id, "server": value, "floor": floor_value})
			new_baseline = maxf(value, floor_value)  # EC-7b: never pull below the floor
		# Formula 4 window termination: an in-window candidate is superseded —
		# keep the HIGHER of the two ratchet heights (never lose height; the lost
		# celebration is a deliberate, narrow-reachability accept).
		if _pr_state.candidates.has(exercise_id):
			var candidate: float = _pr_state.candidates[exercise_id]
			if candidate > new_baseline:
				_emit_telemetry("pr.candidate_supersession", {
					"exercise_id": exercise_id, "candidate": candidate, "server": new_baseline})
				new_baseline = candidate
			_pr_state.candidates.erase(exercise_id)
		_pr_state.baselines[exercise_id] = new_baseline
		adopted += 1
	var first_sync: bool = not _server_sync_completed
	_server_sync_completed = true
	if adopted > 0:
		_persist_state(false)
		if first_sync:
			# Rule 11 — veteran import reveal hook ("你嘅真實力量已鍛入").
			baseline_import_completed.emit(adopted)


func _emit_telemetry(event: String, data: Dictionary) -> void:
	_telemetry_log.append({"event": event, "data": data})
