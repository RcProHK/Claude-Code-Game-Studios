# Enemy — per-instance AI state machine node (Story 013, GDD Rule 17).
#
# Driving GDD: design/gdd/enemy-director.md (Rule 17 — 6-state AI machine).
# Governing ADR: ADR-0006 (transition atomicity) + ADR-0007 Family A (EnemyAIState,
#   ordinal 0 = SPAWNING = safe boot default).
#
# AI state lives on EACH enemy node (NOT centralized in EnemyDirector) — the Director
# owns wave/pool orchestration; the node owns its own behaviour state. The node reads a
# cached avatar X-distance (pushed by EnemyDirector's 4Hz batch perception, Story 014)
# and reacts to EnemyDirector.hit_resolved (stagger / death).
#
# State graph (EnemyDirector.EnemyAIState):
#   SPAWNING → IDLE (spawn settled) → PURSUING (avatar within PERCEPTION_RANGE)
#   PURSUING → IDLE (avatar beyond LEASH_RANGE; hysteresis)
#   any non-DYING → STAGGERED (HEAVY/CRITICAL hit) → PURSUING (timer elapses)
#   any non-DYING → DYING (kill hit; highest priority, terminal)
class_name Enemy
extends Node2D

## Current AI state (EnemyDirector.EnemyAIState ordinal). SPAWNING is the safe default.
var _ai_state: int = EnemyDirector.EnemyAIState.SPAWNING

## Cached avatar X-distance (px). Pushed by EnemyDirector 4Hz batch perception (Story 014).
var _cached_avatar_distance: float = INF

## Cached own instance id (set in _ready) — used to filter hit_resolved by target.
var _instance_id: int = 0

## Remaining STAGGERED freeze time (s). > 0 only while STAGGERED.
var _stagger_remaining: float = 0.0

## Set true when a kill interrupts an in-progress animation (AC-29 observability).
## Story 014+ overrides _interrupt_animation() to drive a real AnimationPlayer.
var animation_interrupted: bool = false

## Injectable hit-signal source (untyped DI seam). null → real EnemyDirector autoload.
var _hit_source = null


func _ready() -> void:
	_instance_id = get_instance_id()
	if _hit_source == null:
		_hit_source = EnemyDirector
	_hit_source.hit_resolved.connect(_on_hit_resolved)


## Push the latest avatar X-distance (called by EnemyDirector 4Hz batch, Story 014).
func set_avatar_distance(distance: float) -> void:
	_cached_avatar_distance = distance


## Read the current AI state (test + EnemyDirector query).
func get_ai_state() -> int:
	return _ai_state


func _physics_process(delta: float) -> void:
	if _ai_state == EnemyDirector.EnemyAIState.DYING:
		return  # terminal — no further behaviour
	if _ai_state == EnemyDirector.EnemyAIState.SPAWNING:
		_ai_state = EnemyDirector.EnemyAIState.IDLE  # spawn settled → active
		return
	if _ai_state == EnemyDirector.EnemyAIState.STAGGERED:
		_tick_stagger(delta)
		return  # frozen during stagger — no perception
	_update_perception()


## IDLE↔PURSUING perception with hysteresis (AC-27).
func _update_perception() -> void:
	if _ai_state == EnemyDirector.EnemyAIState.IDLE:
		if _cached_avatar_distance <= EnemyDirector.PERCEPTION_RANGE:
			_ai_state = EnemyDirector.EnemyAIState.PURSUING
	elif _ai_state == EnemyDirector.EnemyAIState.PURSUING:
		if _cached_avatar_distance > EnemyDirector.LEASH_RANGE:
			_ai_state = EnemyDirector.EnemyAIState.IDLE


## Count down the STAGGERED timer; return to PURSUING when it elapses (AC-28).
func _tick_stagger(delta: float) -> void:
	_stagger_remaining -= delta
	if _stagger_remaining <= 0.0:
		_stagger_remaining = 0.0
		_ai_state = EnemyDirector.EnemyAIState.PURSUING


## hit_resolved handler — filters by target, applies DYING (priority) then STAGGER (EC-35/36).
func _on_hit_resolved(payload) -> void:
	if payload.target_id != _instance_id:
		return
	if _ai_state == EnemyDirector.EnemyAIState.DYING:
		return  # already terminal
	if payload.is_kill:
		_enter_dying()  # AC-29: kill takes priority over any state (incl. ATTACKING)
		return
	var tier: int = payload.damage_tier
	if tier == CombatResolver.DamageTier.HEAVY or tier == CombatResolver.DamageTier.CRITICAL:
		if _ai_state == EnemyDirector.EnemyAIState.STAGGERED:
			return  # already staggered — no re-trigger, no timer reset (EC-35)
		_ai_state = EnemyDirector.EnemyAIState.STAGGERED
		_stagger_remaining = EnemyDirector.STAGGER_DURATION_BY_TIER[tier]


## Transition to DYING immediately, interrupting any in-progress animation (AC-29).
func _enter_dying() -> void:
	_ai_state = EnemyDirector.EnemyAIState.DYING
	_interrupt_animation()


## Animation interrupt hook. Story 013 records the call for AC-29; Story 014+ overrides
## to drive a real AnimationPlayer.
func _interrupt_animation() -> void:
	animation_interrupted = true
