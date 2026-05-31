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
# RNGFactory — Story 006 (Rule 4 / FR-3 / ADR-0005 seeded determinism)
# =====================================================================

## Seeded RandomNumberGenerator provisioner.
##
## Rule 4 (FR-3) requires every combat RNG draw to be reproducible from the
## owning transition_id so a replay of the same transition yields a byte-identical
## sequence (AC-15). ADR-0005 seeds its loot rng_roll on transition_id via this
## same factory, so create()/create_sub() are the single seeding authority.
##
## Determinism contract:
##   - create(transition_id) seeds with hash(transition_id). Two factories built
##     from the same transition_id produce identical sequences (AC-12).
##   - create_sub(transition_id, sub_key) seeds with hash("transition_id:sub_key"),
##     giving an independent stream per sub_key whose state never aliases the
##     primary stream or any other sub_key (AC-13).
##   - hash() accepts arbitrary UTF-8, so Unicode transition_ids are safe and
##     stay deterministic (AC-16).
##
## Accessed as EnemyDirector.RNGFactory.create(...) (EnemyDirector is an autoload).
class RNGFactory extends RefCounted:

	## Create the primary seeded RNG for a transition.
	## seed = hash(transition_id). Deterministic per transition_id (AC-12).
	static func create(transition_id: String) -> RandomNumberGenerator:
		var rng := RandomNumberGenerator.new()
		rng.seed = hash(transition_id)
		return rng

	## Create an independent sub-stream RNG for a transition.
	## seed = hash("transition_id:sub_key"). Independent of create() and of any
	## other sub_key for the same transition_id (AC-13). Used for per-purpose
	## streams (e.g. wave_spawn_0, dodge_<instance_id>) so advancing one stream
	## never perturbs another within the same replay (AC-15).
	static func create_sub(transition_id: String, sub_key: String) -> RandomNumberGenerator:
		var rng := RandomNumberGenerator.new()
		rng.seed = hash("%s:%s" % [transition_id, sub_key])
		return rng

# =====================================================================
# Anomaly rate-limiter (Rule 6, Formula 4, FR-5 — Story 007)
# =====================================================================

## Sliding-window duration for per-reason anomaly rate-limiting.
## Default 1000 ms (1 s). Safe range [500, 5000] per GDD Section G.
const RATE_WINDOW_MS: int = 1000

## Maximum anomaly emits per reason per sliding window.
## Excess calls are counted in RateWindow.dropped and emitted as an aggregate.
## Default 10. Safe range [3, 50] per GDD Section G / #13 Rule 17.
const RATE_CAP_PER_REASON: int = 10


## Sliding-window state for one anomaly reason, stored in _anomaly_rate_tracker.
##
## timestamps: front = oldest accepted emit (ms). Entries are evicted by
## rate_limit_check / walk_anomaly_rate_windows when ts <= now_ms - RATE_WINDOW_MS
## (half-open window — entries AT the boundary are considered expired).
## dropped: cumulative drop count since last aggregate emit.
class RateWindow extends RefCounted:
	var timestamps: Array[int] = []
	var dropped: int = 0


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

## Seeded-RNG provisioner — Story 006 RNGFactory inner class implemented (Rule 4, FR-3).
## Untyped DI seam: tests inject mock; production gets an RNGFactory instance.
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

## Injectable GameStateMachine reference for signal subscription (untyped DI seam).
## null = resolved to GameStateMachine autoload in _ready().
## Tests inject a mock via EnemyDirector.set(&"_gsm_source", mock).
## Named _gsm_source (not _gsm) to avoid clash with AbilitySystem's own _gsm field.
var _gsm_source = null

## Injectable AbilitySystem reference for signal subscription (untyped DI seam).
## null = resolved to AbilitySystem autoload in _ready().
## Tests inject a mock via EnemyDirector.set(&"_ability_source", mock).
var _ability_source = null

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

	# Story 006: real RNGFactory inner class (Rule 4 / FR-3 / ADR-0005).
	if _rng_factory == null:
		_rng_factory = RNGFactory.new()

	# Story 005: wire signal subscriptions — LAST lines of _ready() per GDD Rule 2.
	# Resolve DI seams to production autoloads if not injected by tests.
	if _gsm_source == null:
		_gsm_source = GameStateMachine
	if _ability_source == null:
		_ability_source = AbilitySystem
	# ADR-0006 Contract 6: use connect_for_initial_state (never raw .connect()).
	_gsm_source.connect_for_initial_state(_on_state_changed)
	_ability_source.connect_for_initial_state(_on_ability_cast)
	print_verbose("[EnemyDirector] initialized — autoload pos 10 (#14); core class ready")

# =====================================================================
# Signal handlers — stub implementations (full logic in Story 008)
# =====================================================================


## Called by GameStateMachine.state_changed via connect_for_initial_state.
## Full implementation in Story 008 (GSM Suspended gate + EnemyDirector state machine).
## Signature matches ADR-0006 Contract 6: 3 positional args (from, to, payload).
func _on_state_changed(_from: int, _to: int, _payload) -> void:
	pass  # Story 008: GSM Suspended gate, WaveActive/BossEncounter state transitions


## Called by AbilitySystem.ability_cast via connect_for_initial_state wrapper (Story 005).
## Full implementation in Story 008 (_on_ability_cast pipeline: Rule 10 GSM gate, Rule 8
## StatSnapshot, Rule 4 RNG, Rule 7 catch-up mutex, CombatResolver.resolve_hit loop).
## Signature matches AbilitySystem.ability_cast: ability_id, caster, target.
func _on_ability_cast(_ability_id: StringName, _caster: Node2D, _target: Node2D) -> void:
	pass  # Story 008: full 5-obligation _on_ability_cast pipeline


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


## Sliding-window rate-limit gate for anomaly emission (Formula 4, Rule 6, FR-5).
##
## Returns true if the caller should emit `combat_metric_anomaly` for this reason;
## false if the call is rate-limited (dropped). Dropped calls are accumulated in the
## window's `dropped` counter; walk_anomaly_rate_windows() will emit an aggregate
## CombatAnomalyPayload when the window expires (FR-5 silent-fail prevention).
##
## IMPORTANT: the caller MUST pass now_ms (typically Time.get_ticks_msec()).
## NEVER call Time.get_ticks_msec() inside this function — injectable time only (ADR-0006).
## Eviction uses a half-open window: ts <= now_ms - RATE_WINDOW_MS is expired.
func rate_limit_check(reason: StringName, now_ms: int) -> bool:
	if not _anomaly_rate_tracker.has(reason):
		_anomaly_rate_tracker[reason] = RateWindow.new()
	var window: RateWindow = _anomaly_rate_tracker[reason]
	# Evict expired entries (half-open: ts at boundary is considered expired).
	while window.timestamps.size() > 0 and window.timestamps[0] <= now_ms - RATE_WINDOW_MS:
		window.timestamps.pop_front()
	# Cap check.
	if window.timestamps.size() >= RATE_CAP_PER_REASON:
		window.dropped += 1
		return false
	# Accept.
	window.timestamps.append(now_ms)
	return true


## Evict expired entries across all reason windows and emit aggregate anomaly signals
## for fully-expired windows that accumulated drops (FR-5 binding).
##
## Call from _physics_process with Time.get_ticks_msec() as now_ms.
## An aggregate CombatAnomalyPayload{aggregate:true, dropped_count:N} is emitted once
## per reason whose window has fully expired (empty) with accumulated drops.
func walk_anomaly_rate_windows(now_ms: int) -> void:
	for reason: StringName in _anomaly_rate_tracker.keys():
		var window: RateWindow = _anomaly_rate_tracker[reason]
		# Evict expired entries.
		while window.timestamps.size() > 0 and window.timestamps[0] <= now_ms - RATE_WINDOW_MS:
			window.timestamps.pop_front()
		# Emit aggregate when window is fully expired and drops > 0 (FR-5).
		if window.dropped > 0 and window.timestamps.is_empty():
			var payload := CombatAnomalyPayload.new()
			payload.reason = reason
			payload.aggregate = true
			payload.dropped_count = window.dropped
			payload.context_dump = {}
			combat_metric_anomaly.emit(payload)
			window.dropped = 0


## DEPRECATED by Story 006 — superseded by the RNGFactory inner class (now wired
## directly in _ready() as RNGFactory.new()). Kept because test_init_state.gd's
## AC-02 test calls this provisioner directly; it now returns a real RNGFactory
## so the non-null guarantee is identical to the production path.
func _create_rng_factory_placeholder() -> RefCounted:
	return RNGFactory.new()
