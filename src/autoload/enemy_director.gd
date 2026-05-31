# EnemyDirector — Autoload position 10 (#14)
#
# Status: Story 001 — core class + 8 state containers + 3 enums + DI seam.
# Driving GDD: design/gdd/enemy-director.md (Approved 2026-05-27; single-pass)
# Governing ADR: ADR-0006 Contracts 1/2/3/4/6 + ADR-0007 (enum families).
#
# Signal surface LOCK (Rule 5 + AC-07 + CI lint #3): exactly 3 emitted signals:
#   - hit_resolved(payload)
#   - enemy_killed(payload)
#   - combat_metric_anomaly(payload)
# NO `combat_started` / `combat_ended` — those don't exist (per Q-OQ2 resolution).
# Avatar Renderer + other combat-state consumers use GSM `state_changed` filtered by
# `to ∈ {COMBAT_ACTIVE, BOSS_ENCOUNTER}` instead.
## EnemyDirector is registered as an autoload singleton in project.godot.
## class_name NOT declared — Godot 4 disallows class_name that matches the
## autoload singleton name (Parse Error: Class hides an autoload singleton).
## Enums + signals accessible globally as EnemyDirector.Faction / EnemyDirector.EnemyAIState etc.
extends Node

# ---- Rule 1 caller-side state owner: EnemyDirector owns all its state as
# class-body containers, inverse of #13 stateless pure-function purity. ----

# =====================================================================
# Enums (ADR-0007 — two-family convention)
# =====================================================================

## Faction — ADR-0007 Family B (Classification enum).
## All members are real values. Zero-default fabrication FORBIDDEN per ADR-0007 Family B.
## Faction.NEUTRAL is a faction-relationship value per GDD Rule 3 (distinct from
## the retired AbilityClass.NEUTRAL — that retirement applies only to AbilityClass members).
enum Faction {
	PLAYER,   ## 0
	ENEMY,    ## 1
	BOSS,     ## 2
	NEUTRAL,  ## 3
}

## EnemyAIState — ADR-0007 Family A (Outcome/State enum).
## Ordinal 0 = SPAWNING = safe pre-_ready() default. Declaration order LOCKED.
enum EnemyAIState {
	SPAWNING,   ## 0 — spawn animation; collision disabled; no hit accepted
	IDLE,       ## 1 — off-screen or leash exit; not pursuing
	PURSUING,   ## 2 — within PERCEPTION_RANGE; X-axis locomotion toward avatar
	ATTACKING,  ## 3 — within MELEE_RANGE; attack animation active
	STAGGERED,  ## 4 — damage_tier >= HEAVY; short freeze
	DYING,      ## 5 — HP <= 0; death animation playing
}

## BossAnchorState — ADR-0007 Family A (Outcome/State enum).
## Ordinal 0 = IDLE = safe pre-_ready() default. Declaration order LOCKED.
enum BossAnchorState {
	IDLE,           ## 0 — no active boss sequence
	PRE_SPAWN,      ## 1 — pre-spawned off-screen (set_progress >= 0.8 trigger)
	COMMIT_PENDING, ## 2 — boss instance spawned off-screen, awaiting workout_completed
	COMMITTED,      ## 3 — visible reveal triggered (entry cascade in progress)
	ENGAGED,        ## 4 — boss in normal combat loop (handed off to #16 Boss System)
}

# =====================================================================
# Signals (LOCKED surface per GDD Rule 5 + AC-07)
# =====================================================================

## #13 FR-4 obligation d — exactly 3 broadcast signals, no more.
## Payload types defined in Story 005; declare surface now per AC-07.
signal hit_resolved(payload)
signal enemy_killed(payload)
signal combat_metric_anomaly(payload)

# =====================================================================
# Rule 1: 8 caller-side state containers
# =====================================================================
# ALL 8 must be declared here. CI lint check_enemy_director_state_locality.gd
# (Story 002) verifies none are migrated to other classes.

## Serialization queue: bfcache resume catch-up × AOE mutex (Rule 7, #13 Rule 18).
## Typed as Array for GDScript 4 — elements are CombatContext instances (Story 016).
var _catch_up_queue: Array = []

## Sliding-window anomaly rate counter per reason (Rule 6, Formula 4).
## Key: StringName reason; Value: RateWindow resource (Story 007).
var _anomaly_rate_tracker: Dictionary = {}

## Live enemy lookup: instance_id → EnemyState struct (Rule 3, Story 012).
var _enemy_state_pool: Dictionary = {}

## Once-per-instance kill guard (Rule 15): instance_id → bool.
var _killed_dedupe_set: Dictionary = {}

## Preloaded PackedScene per enemy_id from EnemyRegistry.tres (Rule 12, Story 012).
## Key: StringName enemy_id (e.g., &"STRIKE_MOB_T1"); Value: PackedScene.
var _spawn_pool: Dictionary = {}

## Seeded-RNG provisioner — Story 006 implements RNGFactory class (Rule 4, FR-3).
## Untyped DI seam: tests inject mock; production gets RNGFactory instance.
var _rng_factory = null

## Current wave archetype descriptor (Rule 12, Story 011).
## Untyped: WaveDescriptor Resource; null = no active wave.
var _active_wave = null

## Boss encounter anchor state machine (Rule 13, Formula 5).
## Initialised to BossAnchorState.IDLE (ordinal 0, safe Family A default).
var _boss_anchor_state: int = BossAnchorState.IDLE

# =====================================================================
# Dependency-injection seams
# =====================================================================

## Injectable EnemyRegistry resource (untyped DI seam per project convention).
## null = load from "res://assets/data/EnemyRegistry.tres" (created by Story 010).
## Tests inject a FakeEnemyRegistry via EnemyDirector.set(&"_enemy_registry", mock).
var _enemy_registry = null

# =====================================================================
# Built-in virtual methods
# =====================================================================


func _ready() -> void:
	# _boss_anchor_state already = IDLE at declaration (Family A ordinal 0).
	# Explicit clear for all containers (AC-02 init guarantee).
	_catch_up_queue.clear()
	_anomaly_rate_tracker.clear()
	_enemy_state_pool.clear()
	_killed_dedupe_set.clear()
	_spawn_pool.clear()
	_rng_factory = null
	_active_wave = null
	_boss_anchor_state = BossAnchorState.IDLE

	# Resolve EnemyRegistry (DI seam — Story 010 creates the actual .tres).
	if _enemy_registry == null:
		var registry_path := "res://assets/data/EnemyRegistry.tres"
		if ResourceLoader.exists(registry_path):
			_enemy_registry = load(registry_path)

	# Preload spawn pool. Story 012 implements full preload; this stub
	# populates _spawn_pool if the injected/loaded registry exposes it.
	_preload_spawn_pool()

	# RNGFactory placeholder — Story 006 replaces with full implementation.
	if _rng_factory == null:
		_rng_factory = _create_rng_factory_placeholder()

	# Signal subscriptions are the LAST two lines of _ready() per GDD Rule 2.
	# Story 005 implements connect_for_initial_state wiring (out of scope here).
	print_verbose("[EnemyDirector] initialized — autoload pos 10 (#14); core class ready")

# =====================================================================
# Private methods
# =====================================================================


## Populate _spawn_pool from _enemy_registry if available.
## Full implementation in Story 012 (EnemyRegistry.tres + PackedScene preload).
## Tests: inject FakeEnemyRegistry with get_preloaded_pool() returning test data.
func _preload_spawn_pool() -> void:
	_spawn_pool.clear()
	if _enemy_registry == null:
		return
	if _enemy_registry.has_method("get_preloaded_pool"):
		var pool: Dictionary = _enemy_registry.get_preloaded_pool()
		for key: StringName in pool:
			_spawn_pool[key] = pool[key]


## Placeholder RNGFactory object — Story 006 replaces with seeded RNGFactory class.
## Returns a RefCounted instance so _rng_factory != null check passes (AC-02).
func _create_rng_factory_placeholder() -> RefCounted:
	return RefCounted.new()
