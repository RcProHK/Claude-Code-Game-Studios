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
extends CharacterBody2D

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

# ---- Story 014: locomotion + MOBILITY dodge ----

## Max locomotion speed (px/s) for this enemy — set from its WaveDescriptor at spawn.
var _template_move_speed: float = 0.0

## Locomotion direction along X (+1 right / -1 left). Default left (toward an avatar on the left).
var _direction: int = -1

## True if this enemy is a MOBILITY archetype (enables the dodge sidestep).
var _is_mobility: bool = false

## Per-enemy deterministic dodge RNG (sub-stream keyed by transition_id + instance_id).
var _dodge_rng: RandomNumberGenerator = null

## Time (s) accumulated toward the next dodge re-roll.
var _dodge_accumulator: float = 0.0

## Last rolled dodge offset (px), observable for tests. In [-DODGE_AMPLITUDE_PX, +amp].
var dodge_offset_x: float = 0.0


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


## Engage trigger — used by the boss entry cascade (Story 017) to drop the boss into
## active combat. Maps to PURSUING (the boss now actively pursues the avatar).
func engage() -> void:
	_ai_state = EnemyDirector.EnemyAIState.PURSUING


## Configure locomotion/dodge for this enemy at spawn (Story 014).
## is_mobility enables the dodge sidestep with a deterministic per-instance sub-RNG.
func setup_locomotion(move_speed: float, direction: int, is_mobility: bool, transition_id: String) -> void:
	_template_move_speed = move_speed
	_direction = direction
	_is_mobility = is_mobility
	if is_mobility:
		_dodge_rng = EnemyDirector.RNGFactory.create_sub(transition_id, "dodge_%d" % get_instance_id())


func _physics_process(delta: float) -> void:
	if _ai_state == EnemyDirector.EnemyAIState.DYING:
		return  # terminal — no further behaviour
	if _ai_state == EnemyDirector.EnemyAIState.SPAWNING:
		_ai_state = EnemyDirector.EnemyAIState.IDLE  # spawn settled → active
		return
	if _ai_state == EnemyDirector.EnemyAIState.STAGGERED:
		_tick_stagger(delta)
		return  # frozen during stagger — no perception / locomotion
	_update_perception()
	_tick_dodge(delta)
	if _ai_state == EnemyDirector.EnemyAIState.PURSUING or _ai_state == EnemyDirector.EnemyAIState.ATTACKING:
		_apply_locomotion(delta)


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


# ---- Story 014: locomotion (Formula 6) + MOBILITY dodge ----

## Formula 6 velocity step (pure of move_and_slide): accelerate toward target speed,
## clamp to ENEMY_MOVE_CAP, zero vertical. Separated so AC-30 can assert velocity directly.
func _step_velocity(delta: float) -> void:
	var accel: float = _template_move_speed * EnemyDirector.ACCEL_MULTIPLIER
	velocity.x = move_toward(velocity.x, _template_move_speed * _direction, accel * delta)
	velocity.x = clampf(velocity.x, -EnemyDirector.ENEMY_MOVE_CAP, EnemyDirector.ENEMY_MOVE_CAP)
	velocity.y = 0.0


## Apply Formula 6 locomotion then resolve collisions (PURSUING/ATTACKING only).
func _apply_locomotion(delta: float) -> void:
	_step_velocity(delta)
	move_and_slide()


## MOBILITY dodge sidestep — every DODGE_INTERVAL_SEC re-roll a deterministic offset and
## apply it to X. Only while MOBILITY + PURSUING. Amplitude bounded by INV-8.
func _tick_dodge(delta: float) -> void:
	if not _is_mobility or _dodge_rng == null:
		return
	if _ai_state != EnemyDirector.EnemyAIState.PURSUING:
		return
	_dodge_accumulator += delta
	if _dodge_accumulator < EnemyDirector.DODGE_INTERVAL_SEC:
		return
	_dodge_accumulator -= EnemyDirector.DODGE_INTERVAL_SEC
	dodge_offset_x = _dodge_rng.randf_range(
		-EnemyDirector.DODGE_AMPLITUDE_PX, EnemyDirector.DODGE_AMPLITUDE_PX)
	global_position.x += dodge_offset_x
