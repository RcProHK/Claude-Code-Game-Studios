## WorkoutSnapshotRO — Immutable snapshot of WorkoutStateTracker state
##
## Driving GDD: design/gdd/workout-state-tracker.md Rule 1 / Story 005
## Governing ADR: ADR-0006 Contract 3 (SerializableResource envelope)
##
## Read-only after seal() is called by WorkoutStateTracker._build_snapshot().
## Immutability enforced via inline GDScript 4 property setters (setter/getter pair).
## Pattern: each public field has an underscore-prefixed backing var + an @export var
## with inline set(v)/get that gate writes via _sealed. Setters write ONLY to the
## backing var (never to the property itself — that would be infinite recursion).
##
## Usage (after receiving from get_workout_snapshot()):
##   snap.current_phase          # OK — read
##   snap.current_phase = 99     # push_error + no-op (immutable after seal)
class_name WorkoutSnapshotRO extends SerializableResource

# ---- Sealed flag (declared first so inline setters can reference it) ----

## True after seal() is called. Blocks all property writes.
var _sealed: bool = false

# ---- Backing storage vars (underscore-prefixed, no external API) ----
## These are the actual storage; @export properties delegate to them.

var _current_phase: int = 0
var _set_progress: float = 0.0
var _set_progress_is_estimated: bool = true
var _dominant_class: int = 3   # AbilityClass.UNKNOWN ordinal (ADR-0007)
var _completed_exercises_count: int = 0
var _workout_id: String = ""
var _is_suspended: bool = false
var _is_stale_due_to_poll_failure: bool = false

# ---- Public @export properties with inline setter/getter ----
## Each setter: if sealed, push_error + return; else write backing var.
## Each getter: return backing var.
## NOTE: setters MUST NOT assign to the property itself (infinite recursion).

## WorkoutPhase int (WorkoutStateTracker.WorkoutPhase enum). Ordinal 0 = IDLE default.
@export var current_phase: int = 0:
	get:
		return _current_phase
	set(v):
		if _sealed:
			push_error("WorkoutSnapshotRO is immutable — cannot set 'current_phase' after seal()")
			return
		_current_phase = v

## set_progress in [0.0, 1.0]. Monotonically non-decreasing within a workout.
@export var set_progress: float = 0.0:
	get:
		return _set_progress
	set(v):
		if _sealed:
			push_error("WorkoutSnapshotRO is immutable — cannot set 'set_progress' after seal()")
			return
		_set_progress = v

## True when set_progress uses estimated fallback (no planned_total_sets). CI-2 binding.
@export var set_progress_is_estimated: bool = true:
	get:
		return _set_progress_is_estimated
	set(v):
		if _sealed:
			push_error("WorkoutSnapshotRO is immutable — cannot set 'set_progress_is_estimated' after seal()")
			return
		_set_progress_is_estimated = v

## Dominant AbilityClass int (AbilitySystem.AbilityClass). UNKNOWN = 3 per ADR-0007 Family B.
@export var dominant_class: int = 3:
	get:
		return _dominant_class
	set(v):
		if _sealed:
			push_error("WorkoutSnapshotRO is immutable — cannot set 'dominant_class' after seal()")
			return
		_dominant_class = v

## Number of distinct exercise_ids logged in this workout (not set count). CI-5.
@export var completed_exercises_count: int = 0:
	get:
		return _completed_exercises_count
	set(v):
		if _sealed:
			push_error("WorkoutSnapshotRO is immutable — cannot set 'completed_exercises_count' after seal()")
			return
		_completed_exercises_count = v

## Client-derived workout_id for this snapshot (may be "" between workouts).
@export var workout_id: String = "":
	get:
		return _workout_id
	set(v):
		if _sealed:
			push_error("WorkoutSnapshotRO is immutable — cannot set 'workout_id' after seal()")
			return
		_workout_id = v

## True when WST substate is SUSPENDED. Values reflect cached state.
@export var is_suspended: bool = false:
	get:
		return _is_suspended
	set(v):
		if _sealed:
			push_error("WorkoutSnapshotRO is immutable — cannot set 'is_suspended' after seal()")
			return
		_is_suspended = v

## True when _is_frozen (poll_failed not yet recovered). HUD banner trigger.
@export var is_stale_due_to_poll_failure: bool = false:
	get:
		return _is_stale_due_to_poll_failure
	set(v):
		if _sealed:
			push_error("WorkoutSnapshotRO is immutable — cannot set 'is_stale_due_to_poll_failure' after seal()")
			return
		_is_stale_due_to_poll_failure = v


## Seal this resource against further modification. Called by WorkoutStateTracker._build_snapshot()
## after all fields are populated. After seal(), any property assignment triggers push_error + no-op.
func seal() -> void:
	_sealed = true


# ---------------------------------------------------------------------------
# SerializableResource contract (ADR-0006 Contract 3)
# ---------------------------------------------------------------------------

## Serialize to Dictionary for PersistenceLayer / tombstone storage.
## Enum values serialized as string names per ADR-0007 / control-manifest line 71
## (integer ordinals are migration-fragile and IndexedDB-debug-hostile).
func to_dict() -> Dictionary:
	return {
		"payload_type": get_script().get_global_name(),
		"current_phase": WorkoutStateTracker.WorkoutPhase.find_key(_current_phase),
		"set_progress": _set_progress,
		"set_progress_is_estimated": _set_progress_is_estimated,
		"dominant_class": AbilitySystem.AbilityClass.find_key(_dominant_class),
		"completed_exercises_count": _completed_exercises_count,
		"workout_id": _workout_id,
		"is_suspended": _is_suspended,
		"is_stale_due_to_poll_failure": _is_stale_due_to_poll_failure,
	}


## Restore from Dictionary (ADR-0006 Contract 3 forward-recovery path).
## Returns a SEALED snapshot — consistent with _build_snapshot() behavior.
static func from_dict(data: Dictionary) -> SerializableResource:
	var snap := WorkoutSnapshotRO.new()
	# Deserialize string enum names back to int ordinals (inverse of to_dict)
	var phase_name: String = data.get("current_phase", "IDLE")
	var class_name_str: String = data.get("dominant_class", "UNKNOWN")
	snap.current_phase = WorkoutStateTracker.WorkoutPhase.get(phase_name,
			WorkoutStateTracker.WorkoutPhase.IDLE)
	snap.set_progress = float(data.get("set_progress", 0.0))
	snap.set_progress_is_estimated = bool(data.get("set_progress_is_estimated", true))
	snap.dominant_class = AbilitySystem.AbilityClass.get(class_name_str,
			AbilitySystem.AbilityClass.UNKNOWN)
	snap.completed_exercises_count = int(data.get("completed_exercises_count", 0))
	snap.workout_id = str(data.get("workout_id", ""))
	snap.is_suspended = bool(data.get("is_suspended", false))
	snap.is_stale_due_to_poll_failure = bool(data.get("is_stale_due_to_poll_failure", false))
	snap.seal()  # Sealed on return — consistent with _build_snapshot()
	return snap
