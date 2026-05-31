## WorkoutSummaryRO — Immutable sealed summary of a completed workout
##
## Driving GDD: design/gdd/workout-state-tracker.md Rule 10 / Story 006
## Governing ADR: ADR-0006 Contract 3 (SerializableResource) + Contract 2 (transition_id)
##
## Built by WorkoutStateTracker._build_summary() at workout_completed time.
## Sealed immediately after construction — no field may be mutated post-seal.
## Emitted via workout_summary_available(summary) signal BEFORE workout_completed_forwarded.
##
## Consumers (#14 EnemyDirector, #15 LootDrop) cache this snapshot; it does not change.
## ADR-0009 §2: callers needing workout_id late-bind via WorkoutStateTracker.get_active_workout_id().
class_name WorkoutSummaryRO extends SerializableResource

# ---- Sealed flag ----
var _sealed: bool = false

# ---- Backing vars ----
var _completed_at: int = 0
var _transition_id: String = ""
var _dominant_class: int = 3  # AbilityClass.UNKNOWN
var _completed_exercises_count: int = 0
var _final_set_progress: float = 0.0
var _total_sets_logged: int = 0
var _total_volume: float = 0.0

# ---- Public @export properties (inline setter/getter — see WorkoutSnapshotRO pattern) ----

## Unix timestamp (ms) when workout_completed fired.
@export var completed_at: int = 0:
	get: return _completed_at
	set(v):
		if _sealed: push_error("WorkoutSummaryRO is immutable — cannot set 'completed_at'"); return
		_completed_at = v

## Opaque transition_id from GameStateMachine.acquire_transition_id() (ADR-0006 Contract 2).
## Used by #15 LootDrop as idempotency key and RNG seed (ADR-005).
@export var transition_id: String = "":
	get: return _transition_id
	set(v):
		if _sealed: push_error("WorkoutSummaryRO is immutable — cannot set 'transition_id'"); return
		_transition_id = v

## Dominant AbilityClass int (AbilitySystem.AbilityClass) at workout completion.
@export var dominant_class: int = 3:
	get: return _dominant_class
	set(v):
		if _sealed: push_error("WorkoutSummaryRO is immutable — cannot set 'dominant_class'"); return
		_dominant_class = v

## Distinct exercise_id count for this workout (CI-5). Sourced from #9 _completed_exercises.
@export var completed_exercises_count: int = 0:
	get: return _completed_exercises_count
	set(v):
		if _sealed: push_error("WorkoutSummaryRO is immutable — cannot set 'completed_exercises_count'"); return
		_completed_exercises_count = v

## set_progress value at workout_completed time (CF-2 binding).
@export var final_set_progress: float = 0.0:
	get: return _final_set_progress
	set(v):
		if _sealed: push_error("WorkoutSummaryRO is immutable — cannot set 'final_set_progress'"); return
		_final_set_progress = v

## Total number of set_logged events in this workout.
@export var total_sets_logged: int = 0:
	get: return _total_sets_logged
	set(v):
		if _sealed: push_error("WorkoutSummaryRO is immutable — cannot set 'total_sets_logged'"); return
		_total_sets_logged = v

## Σ (reps × weight) over all sets (Formula 4). Bodyweight sets (weight=0) contribute 0.
## Sourced from #9 set_history. Never mutated after seal (CF-5).
@export var total_volume: float = 0.0:
	get: return _total_volume
	set(v):
		if _sealed: push_error("WorkoutSummaryRO is immutable — cannot set 'total_volume'"); return
		_total_volume = v


## Seal against further modification.
func seal() -> void:
	_sealed = true


# ---------------------------------------------------------------------------
# SerializableResource contract (ADR-0006 Contract 3)
# ---------------------------------------------------------------------------

func to_dict() -> Dictionary:
	return {
		"payload_type": get_script().get_global_name(),
		"completed_at": _completed_at,
		"transition_id": _transition_id,
		"dominant_class": AbilitySystem.AbilityClass.find_key(_dominant_class),
		"completed_exercises_count": _completed_exercises_count,
		"final_set_progress": _final_set_progress,
		"total_sets_logged": _total_sets_logged,
		"total_volume": _total_volume,
	}


static func from_dict(data: Dictionary) -> SerializableResource:
	var s := WorkoutSummaryRO.new()
	s.completed_at = int(data.get("completed_at", 0))
	s.transition_id = str(data.get("transition_id", ""))
	s.dominant_class = AbilitySystem.AbilityClass.get(
		str(data.get("dominant_class", "UNKNOWN")), AbilitySystem.AbilityClass.UNKNOWN)
	s.completed_exercises_count = int(data.get("completed_exercises_count", 0))
	s.final_set_progress = float(data.get("final_set_progress", 0.0))
	s.total_sets_logged = int(data.get("total_sets_logged", 0))
	s.total_volume = float(data.get("total_volume", 0.0))
	s.seal()
	return s
