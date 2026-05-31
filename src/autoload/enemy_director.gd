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
# Catch-up queue serialization (Rule 7 — Story 009)
# =====================================================================

## Per-frame ceiling for draining the catch-up queue. Protects the frame budget
## when a bfcache resume delivers a burst of buffered casts. Const (not var).
const CATCH_UP_HITS_PER_FRAME_CAP: int = 12

## Absolute backlog ceiling for the catch-up queue. On overflow the oldest entry
## is dropped (FIFO eviction) and a CLAMP_TRIGGERED anomaly is emitted. Const.
const CATCH_UP_QUEUE_HARD_CAP: int = 1000

# =====================================================================
# Wave archetype scheduler (Rule 12, Formula 1 — Story 011)
# =====================================================================

## Base spawn interval (s) before archetype cadence multiplier. Formula 1 input.
const BASE_SPAWN_INTERVAL: float = 4.0

## INV-1 floor: actual spawn interval must never drop below this. With the locked
## archetype mults (min 0.75) the computed floor is 4.0×0.75=3.0 ≥ 2.25. Enforced by a
## dev/CI assert (NOT a runtime clamp — anti-fabrication: a sub-floor value signals a
## data bug and must fail loudly rather than be silently corrected).
const MIN_SPAWN_INTERVAL: float = 2.25

## Max enemies alive on screen at once (mobile readability cap, EC-11). No spawn at/above.
const MAX_CONCURRENT_ENEMIES_ON_SCREEN: int = 6

## Off-screen-right spawn origin (px). Enemies enter from the right edge (Story 012).
const SPAWN_ORIGIN: Vector2 = Vector2(1200.0, 360.0)

## Spawn X jitter half-range (px) — deterministic offset from the per-spawn sub-RNG.
const SPAWN_JITTER_X: float = 50.0

## Tier index used for spawned enemy stats until tiered selection lands (Story 013+).
const DEFAULT_TIER_INDEX: int = 0

# =====================================================================
# Per-enemy AI state machine ranges (Rule 17 — Story 013)
# =====================================================================

## X-distance (px) at which an IDLE enemy begins PURSUING the avatar.
const PERCEPTION_RANGE: float = 600.0

## X-distance (px) at which a PURSUING enemy leashes back to IDLE.
## LEASH_RANGE > PERCEPTION_RANGE gives hysteresis (no flicker at the boundary).
const LEASH_RANGE: float = 900.0

## STAGGERED freeze duration (s) keyed by inflicted DamageTier (EC-35).
## HEAVY → 0.15s, CRITICAL → 0.30s. Lighter tiers do not stagger.
const STAGGER_DURATION_BY_TIER: Dictionary = {
	CombatResolver.DamageTier.HEAVY: 0.15,
	CombatResolver.DamageTier.CRITICAL: 0.30,
}

## Melee threat distance (px). Dodge swing must stay strictly inside this (INV-8).
const MELEE_RANGE: float = 80.0

# =====================================================================
# Locomotion + perception budget (Rule 18, Formula 6 — Story 014)
# =====================================================================

## Absolute per-enemy locomotion speed cap (px/s). Matches the move-cap CI lint (INV-7).
const ENEMY_MOVE_CAP: float = 420.0

## Locomotion acceleration multiplier — accel = _template_move_speed × this (Formula 6).
const ACCEL_MULTIPLIER: float = 10.0

## MOBILITY dodge sidestep half-amplitude (px). INV-8: DODGE_AMPLITUDE_PX×2 < MELEE_RANGE
## (30×2=60 < 80). CI lint check_dodge_amplitude_invariant.gd enforces.
const DODGE_AMPLITUDE_PX: float = 30.0

## MOBILITY dodge re-roll interval (s).
const DODGE_INTERVAL_SEC: float = 1.5

## Batch-perception cadence (s) — avatar position is read once per this window (4Hz).
const PERCEPTION_TICK_INTERVAL: float = 0.25

## Per-frame delta clamp (s) — guards physics against long frames (bfcache resume, tab switch).
const MAX_FRAME_DELTA: float = 0.1

## Max AOE targets resolved per cast (#13 Rule 14). Excess clamped to the nearest 8 (EC-21).
const MAX_TARGETS_PER_CAST: int = 8

# =====================================================================
# Particle concurrency cap + throttle hysteresis (Rule 11, Formula 3 — Story 015)
# =====================================================================

## Hard ceiling on concurrent particle emitters (ADR-0001 budget). MUST be const
## (CI lint check_particle_concurrency_cap.gd forbids the var form — a mutable cap
## could be raised mid-session and silently blow the budget).
const MAX_CONCURRENT_PARTICLE_EMITTERS: int = 8

## Frame-time emergency window size (immediate response, not EWMA).
const FRAME_TIME_SAMPLE_SIZE: int = 3

## Recovery window size (60 frames ≈ 1s at 60fps) — slow, hysteretic release.
const RECOVERY_SAMPLE_SIZE: int = 60

## Throttle ENGAGE threshold (ms). All FRAME_TIME_SAMPLE_SIZE samples above → throttle.
const FRAME_TIME_BUDGET_MS: float = 33.0

## Throttle RELEASE threshold (ms). All RECOVERY_SAMPLE_SIZE samples below → release.
const FRAME_TIME_RECOVERY_MS: float = 20.0

## Particle caller multiplier — normal spectacle vs throttled (reduced emission).
const CALLER_MULT_NORMAL: float = 1.5
const CALLER_MULT_THROTTLED: float = 1.0

## INV-4 minimum hysteresis gap (ms) between engage + release thresholds (anti-thrash).
const THROTTLE_HYSTERESIS_MIN_MS: float = 5.0

# =====================================================================
# Boss anchor pre-spawn + cascade params (Rule 13, Formula 5 — Story 016)
# =====================================================================

## At/under this planned-set count, the encounter uses the mini-boss path (EC-19).
const LIGHT_WORKOUT_THRESHOLD_SETS: int = 2

## set_progress threshold that triggers boss pre-spawn on the final set (Formula 5).
const BOSS_PRESPAWN_PROGRESS: float = 0.8

## Off-screen X (px, left) where a pre-spawned boss waits hidden until commit.
const BOSS_OFFSCREEN_X: float = -300.0

## Standard boss entry-cascade params (consumed by Story 017 commit cascade).
const BOSS_CASCADE_CAMERA_SEC: float = 0.6
const BOSS_CASCADE_SHAKE: float = 0.4
const BOSS_CASCADE_PARTICLE_MULT: float = 1.2

## Mini-boss (light-workout) entry-cascade params — reduced intensity (EC-19).
const MINI_BOSS_CASCADE_CAMERA_SEC: float = 0.4
const MINI_BOSS_CASCADE_SHAKE: float = 0.25
const MINI_BOSS_CASCADE_PARTICLE_MULT: float = 1.0

## Legal forward edges of the boss-anchor FSM (IDLE rollback is always legal + direct).
## Forward moves MUST go through _transition_boss_anchor (CI lint forbids literal
## `_boss_anchor_state = BossAnchorState.<non-IDLE>` assignments — bypasses validation).
const BOSS_ANCHOR_LEGAL_EDGES: Dictionary = {
	BossAnchorState.IDLE: [BossAnchorState.PRE_SPAWN],
	BossAnchorState.PRE_SPAWN: [BossAnchorState.COMMIT_PENDING],
	BossAnchorState.COMMIT_PENDING: [BossAnchorState.COMMITTED],
	BossAnchorState.COMMITTED: [BossAnchorState.ENGAGED],
	BossAnchorState.ENGAGED: [],
}

## Boss entry-cascade fixed params (Story 017).
const BOSS_SHAKE_DURATION: float = 0.08
const BOSS_FOCAL_EASING: String = "quart_ease_out"
const BOSS_ENTRY_PARTICLE_PRESET: StringName = &"BOSS_ENTRY"

## A deferred ability_cast captured during catch-up drain (Rule 7 AOE mutex).
## Captures RAW cast params — at defer time (before the GSM gate) no CombatContext
## exists yet, so Story 018 re-runs the full pipeline on each drained entry.
class CatchUpEntry extends RefCounted:
	var ability_id: StringName
	var caster: Node2D
	var target: Node2D

	func _init(p_ability_id: StringName = &"", p_caster: Node2D = null, p_target: Node2D = null) -> void:
		ability_id = p_ability_id
		caster = p_caster
		target = p_target


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


## Runtime per-enemy state record (Story 012, Rule 3 caller-side state locality).
## Inner class (NOT global `class_name EnemyState` — that collides with the inner
## CombatResolver.EnemyState). Value stored in _enemy_state_pool (instance_id → EnemyState).
## RefCounted — transient, never serialized. Declared after the enums so EnemyAIState resolves.
class EnemyState extends RefCounted:
	var instance_id: int = 0
	var enemy_id: StringName = &""
	var hp: float = 0.0
	var max_hp: float = 0.0
	var defense: float = 0.0
	var faction: int = Faction.ENEMY
	var ai_state: int = EnemyAIState.SPAWNING  ## ordinal 0 — safe Family A default

	func _init(
		p_instance_id: int = 0,
		p_enemy_id: StringName = &"",
		p_hp: float = 0.0,
		p_max_hp: float = 0.0,
		p_defense: float = 0.0,
		p_faction: int = Faction.ENEMY,
		p_ai_state: int = EnemyAIState.SPAWNING,
	) -> void:
		instance_id = p_instance_id
		enemy_id = p_enemy_id
		hp = p_hp
		max_hp = p_max_hp
		defense = p_defense
		faction = p_faction
		ai_state = p_ai_state


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

## Wave scheduler pause flag (Story 011). TRUE by default — waves spawn only during
## COMBAT_ACTIVE (unpaused on state_changed → COMBAT_ACTIVE; re-paused on REST_PERIOD).
## Default-paused also stops the autoload _physics_process from running the scheduler
## during unrelated tests (determinism guard, same rationale as the catch-up drain).
var _wave_scheduler_paused: bool = true

## Time (s) accumulated since the last wave spawn (Formula 1 cadence accumulator).
var _spawn_cadence_accumulator: float = 0.0

## Monotonic spawn counter — feeds the per-spawn sub-RNG key "wave_spawn_{seq}" (Story 012).
var _wave_seq_counter: int = 0

## Time (s) accumulated toward the next 4Hz batch-perception read (Story 014).
var _perception_tick_accumulator: float = 0.0

## Injectable avatar reference (untyped DI seam — Story 014). Exposes global_position.
## null = no avatar (perception skipped); tests inject a mock with a global_position read.
var _avatar_source = null

# ---- Story 015: particle throttle hysteresis state ----

## Rolling FIFO of the last FRAME_TIME_SAMPLE_SIZE frame times (ms) — engage detection.
var _frame_time_window: Array[float] = []

## Rolling FIFO of the last RECOVERY_SAMPLE_SIZE frame times (ms) — release detection.
var _recovery_window: Array[float] = []

## True while the particle throttle is engaged.
var _throttle_active: bool = false

## Current particle caller multiplier (CALLER_MULT_NORMAL normally, _THROTTLED when active).
var _caller_mult: float = CALLER_MULT_NORMAL

# ---- Story 016: boss anchor pre-spawn state ----

## The pre-spawned (hidden, off-screen) boss node, or null when none. Owned PRE_SPAWN→COMMITTED.
var _boss_node = null

## Entry-cascade params selected at pre-spawn (mini vs standard) — consumed by Story 017.
var _boss_cascade_params: Dictionary = {}

## Injectable boss PackedScenes (untyped DI seams). Tests inject; production loads in Story 017.
var _boss_scene_mini = null
var _boss_scene_final = null

# ---- Story 017: entry-cascade autoload seams (untyped DI; ADR-0001 chokepoints) ----
## null = cascade step skipped (autoloads are stubs until their epics land); tests inject spies.
var _camera_source = null
var _screen_effects_source = null
var _particle_source = null

## Injectable combat resolver (untyped DI seam — Story 018). null → CombatResolver.resolve_hit
## static; tests inject a spy (the static func can't otherwise be mocked). Exposes resolve_hit(ctx).
var _combat_resolver = null

## Monotonic per-hit sequence counter (CombatContext.hit_seq) — Story 018.
var _hit_seq_counter: int = 0

# =====================================================================
# Dependency-injection seams
# =====================================================================

## Injectable EnemyRegistry resource (untyped DI seam per project convention).
## null = load from "res://assets/data/EnemyRegistry.tres" (created by Story 010).
## Tests inject a FakeEnemyRegistry via EnemyDirector.set(&"_enemy_registry", mock).
var _enemy_registry = null

## Injectable StatSystem reference (untyped DI seam per project convention).
## null = resolved to StatSystem autoload in _ready(). Tests inject a fake StatSystem
## spy via EnemyDirector.set(&"_stat_system", spy) to count get_stat() calls (Story 008 AC-4).
## Untyped — typed Node fails compile-time member check for StatSystem's custom API.
var _stat_system = null

## Anomaly reason StringName constants — locked 6-reason set per GDD Rule 6.
## Consumed by rate_limit_check() + CombatAnomalyPayload in _on_ability_cast pipeline.
const REASON_GSM_SUSPENDED: StringName = &"GSM_SUSPENDED"
const REASON_INVALID_ABILITY_ID: StringName = &"INVALID_ABILITY_ID"
const REASON_NEGATIVE_DAMAGE: StringName = &"NEGATIVE_DAMAGE"
const REASON_CLAMP_TRIGGERED: StringName = &"CLAMP_TRIGGERED"
const REASON_DEAD_TARGET_RESOLVE: StringName = &"DEAD_TARGET_RESOLVE"
const REASON_RNG_INJECTION_MISSING: StringName = &"RNG_INJECTION_MISSING"
## Future-extension anomaly reasons (Story 011 — GDD Rule 6 §162 sanctions extension).
const REASON_UNKNOWN_ABILITY_CLASS_FALLBACK: StringName = &"UNKNOWN_ABILITY_CLASS_FALLBACK"
const REASON_REGISTRY_LOOKUP_NULL: StringName = &"REGISTRY_LOOKUP_NULL"

## Injectable AOE-classification set (untyped DI seam — Story 009).
## A Dictionary used as a set: key = ability_id StringName the EnemyDirector should treat
## as AOE_RADIUS for the catch-up serialization mutex. null/empty = no abilities are AOE.
## Real ability-metadata taxonomy (a TargetType registry) is wired in Story 018; until then
## tests inject the set directly to exercise the AOE-defer path.
var _aoe_ability_set = null

## Injectable catch-up drain sink (untyped DI seam — Story 009).
## When set, `_process_catch_up_entry` forwards each drained entry to `_catch_up_sink.record(entry)`
## so integration tests can observe FIFO drain order. null in production until Story 018 fills
## the real AOE pipeline in `_process_catch_up_entry`. A sink-recorded entry has NOT passed the
## GSM gate — see the drain-time GSM invariant (Story 009 notes / EC-01).
var _catch_up_sink = null

## Injectable WorkoutStateTracker reference (untyped DI seam — Story 011).
## Drives wave archetype selection via get_dominant_ability_class() (anti-fabrication chain).
## null = resolved to WorkoutStateTracker autoload in _ready(); tests inject a fake.
var _wst_source = null

## Injectable spawn sink (untyped DI seam — Story 011). When set, `_spawn_enemy` forwards
## to `_spawn_sink.spawn(wave_descriptor)` so EC-11 pool-cap behaviour is observable in
## tests. null in production until Story 012 fills the real `_spawn_enemy` lifecycle.
var _spawn_sink = null

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
	# Story 008: StatSystem DI seam resolution.
	if _stat_system == null:
		_stat_system = StatSystem
	# Story 011: WorkoutStateTracker DI seam resolution + scheduler state reset.
	if _wst_source == null:
		_wst_source = WorkoutStateTracker
	_wave_scheduler_paused = true
	_spawn_cadence_accumulator = 0.0
	_wave_seq_counter = 0
	_perception_tick_accumulator = 0.0
	# Story 015: reset throttle state + assert INV-4 hysteresis gap (fail loud on bad tuning).
	_frame_time_window.clear()
	_recovery_window.clear()
	_throttle_active = false
	_caller_mult = CALLER_MULT_NORMAL
	# Story 016: reset boss anchor state.
	_boss_node = null
	_boss_cascade_params = {}
	# Story 018: reset hit sequence counter.
	_hit_seq_counter = 0
	assert(FRAME_TIME_BUDGET_MS > FRAME_TIME_RECOVERY_MS + THROTTLE_HYSTERESIS_MIN_MS,
		"INV-4 violated: throttle hysteresis gap (%f) ≤ %f ms" % [
			FRAME_TIME_BUDGET_MS - FRAME_TIME_RECOVERY_MS, THROTTLE_HYSTERESIS_MIN_MS])

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
func _on_state_changed(_from: int, to: int, _payload) -> void:
	# Story 011: wave-scheduler pause/resume gating (EC-13).
	match to:
		GameStateMachine.GameState.COMBAT_ACTIVE:
			# Resume wave spawning; fresh cadence window.
			_wave_scheduler_paused = false
			_spawn_cadence_accumulator = 0.0
		GameStateMachine.GameState.REST_PERIOD:
			# Pause spawning; idle existing enemies WITHOUT despawn (narrative continuity).
			_wave_scheduler_paused = true
			_idle_active_enemies()
		GameStateMachine.GameState.BOSS_ENCOUNTER:
			# Story 017: commit the pre-spawned boss if armed (COMMIT_PENDING).
			_wave_scheduler_paused = true
			if _boss_anchor_state == BossAnchorState.COMMIT_PENDING:
				_commit_boss_entry()
		GameStateMachine.GameState.IDLE, GameStateMachine.GameState.SUSPENDED:
			# Non-combat states also pause the scheduler (no enemy idling required here).
			_wave_scheduler_paused = true


## Called by AbilitySystem.ability_cast via connect_for_initial_state wrapper (Story 005).
## This is the primary entry point for all combat math in EnemyDirector (Rule 2 / ADR-0006).
## Steps 1-7 per GDD Rule 2 + Story 008 scope (gate + snapshot only; AOE dispatch in Story 018):
##   1. Sync read GSM state.
##   2. GSM Suspended gate (EC-01) — rate-limited anomaly if Suspended.
##   3. Null caster guard (EC-04) — anomaly on null caster.
##   4. Acquire transition_id from GSM (ADR-0006 Contract 2 sync read).
##   5. Empty transition_id guard (EC-45) — RNG_INJECTION_MISSING anomaly.
##   6. Create per-cast seeded RNG from RNGFactory (Rule 4 / FR-3).
##   7. Build StatSnapshot (Rule 8 — exactly 2 get_stat() calls; same reference for all AOE ctx).
## Story 009 (catch-up mutex), Story 018 (AOE dispatch + CombatResolver loop) continue from step 7.
func _on_ability_cast(ability_id: StringName, caster: Node2D, target: Node2D) -> void:
	# Step 0 — Catch-up × AOE serialization mutex (Rule 7 / Story 009 / AC-11).
	# While the catch-up queue is draining, AOE casts are deferred to the tail to
	# prevent interleaving with in-flight catch-up hits (hit-sequence corruption guard).
	# Non-AOE casts during drain proceed normally. Defer is a postponement, NOT a gate
	# bypass — Story 018's drain pipeline re-runs the GSM gate per entry (EC-01 invariant).
	if _catch_up_queue.size() > 0 and _is_aoe_cast(ability_id):
		_enqueue_catch_up(CatchUpEntry.new(ability_id, caster, target))
		return

	# Step 1 — Sync read GSM state (ADR-0006 Contract 2).
	var gsm_state: int = _gsm_source.get_current_state()

	# Step 2 — GSM Suspended gate (EC-01 / Rule 10).
	if gsm_state == GameStateMachine.GameState.SUSPENDED:
		var now_ms: int = Time.get_ticks_msec()
		if rate_limit_check(REASON_GSM_SUSPENDED, now_ms):
			var payload := CombatAnomalyPayload.new()
			payload.reason = REASON_GSM_SUSPENDED
			payload.context_dump = {"gsm_state": GameStateMachine.GameState.find_key(gsm_state)}
			combat_metric_anomaly.emit(payload)
		return

	# Step 3 — Null caster guard (EC-04).
	if caster == null:
		var now_ms: int = Time.get_ticks_msec()
		if rate_limit_check(REASON_INVALID_ABILITY_ID, now_ms):
			var payload := CombatAnomalyPayload.new()
			payload.reason = REASON_INVALID_ABILITY_ID
			payload.context_dump = {"caster": null, "ability_id": ability_id}
			combat_metric_anomaly.emit(payload)
		return

	# Step 4 — Acquire transition_id (ADR-0006 Contract 2 sync read at cast time).
	# GSM has no `current_transition_id` property; use acquire_transition_id(state, state)
	# to obtain a fresh collision-safe id for this cast's RNG seeding (ADR-0005 binding).
	var transition_id: String = _gsm_source.acquire_transition_id(
		_gsm_source.get_current_state(),
		_gsm_source.get_current_state()
	)

	# Step 5 — Empty transition_id guard (EC-45).
	if transition_id.is_empty():
		var now_ms: int = Time.get_ticks_msec()
		if rate_limit_check(REASON_RNG_INJECTION_MISSING, now_ms):
			var payload := CombatAnomalyPayload.new()
			payload.reason = REASON_RNG_INJECTION_MISSING
			payload.context_dump = {"transition_id": "", "ability_id": ability_id}
			combat_metric_anomaly.emit(payload)
		return

	# Step 6 — Create per-cast seeded RNG (Rule 4 / FR-3 / ADR-0005).
	var rng: RandomNumberGenerator = _rng_factory.create(transition_id)

	# Step 7 — Build StatSnapshot (Rule 8 — exactly 2 get_stat() calls per cast,
	# same snapshot reference shared across all AOE targets to prevent mid-cast drift).
	var snapshot: CombatResolver.StatSnapshot = _build_stat_snapshot()

	# Step 8 — Expand AOE targets: distance-sort + clamp to MAX_TARGETS_PER_CAST (Story 018).
	var origin: Vector2 = (caster as Node2D).global_position if caster is Node2D else Vector2.ZERO
	var target_ids: Array = _expand_targets(_get_ability_targets(caster), origin)

	# Step 9-11 — per target: resolve_hit → emit hit_resolved → apply HP (+ enemy_killed on kill).
	# All ctx share the SAME snapshot reference (AOE mid-cast stat drift prevention, AC-35d).
	for target_id: int in target_ids:
		var ctx := _build_combat_context(ability_id, caster, snapshot, rng, transition_id, target_id)
		var hit_result: CombatResolver.HitResult = _resolve_hit(ctx)
		_emit_hit_resolved(ctx, hit_result)        # hit_resolved before any kill emit
		_apply_hit_result(target_id, hit_result)   # HP update + dedup'd enemy_killed on kill


## Build a StatSnapshot capturing caster stats at cast time.
## Called ONCE per ability_cast; the returned snapshot is shared across all AOE targets
## (Rule 8 mid-cast stat drift prevention per #13 Rule 6).
## EXACTLY 2 StatSystem.get_stat() calls — CI lint check_enemy_director_stat_calls.gd
## enforces all get_stat() calls reside inside this method body.
func _build_stat_snapshot() -> CombatResolver.StatSnapshot:
	var snapshot := CombatResolver.StatSnapshot.new()
	snapshot.attack_power = _stat_system.get_stat(StatSystem.StatId.ATTACK_POWER)
	snapshot.crit_chance = _stat_system.get_stat(StatSystem.StatId.CRIT_CHANCE)
	return snapshot


# =====================================================================
# Catch-up queue serialization mutex (Rule 7 — Story 009)
# =====================================================================


## Classify an ability_id as AOE for the serialization mutex (Story 009).
## Reads the injectable `_aoe_ability_set` seam (Dictionary-as-set). null/missing → false.
## Story 018 replaces this with a real ability-metadata TargetType lookup.
func _is_aoe_cast(ability_id: StringName) -> bool:
	if _aoe_ability_set == null:
		return false
	return _aoe_ability_set.has(ability_id)


## Append a deferred cast to the catch-up queue tail with hard-cap protection (AC EC-25).
## At CATCH_UP_QUEUE_HARD_CAP the oldest entry is dropped (FIFO eviction) and a
## rate-limited CLAMP_TRIGGERED anomaly is emitted before the new entry is pushed.
func _enqueue_catch_up(entry: CatchUpEntry) -> void:
	if _catch_up_queue.size() >= CATCH_UP_QUEUE_HARD_CAP:
		_catch_up_queue.pop_front()  # drop oldest (FIFO eviction)
		var now_ms: int = Time.get_ticks_msec()
		if rate_limit_check(REASON_CLAMP_TRIGGERED, now_ms):
			var payload := CombatAnomalyPayload.new()
			payload.reason = REASON_CLAMP_TRIGGERED
			payload.context_dump = {"queue_overflow": true, "dropped": 1}
			combat_metric_anomaly.emit(payload)
	_catch_up_queue.push_back(entry)


## Per-physics-frame entry point.
## Story 015 will drain the particle dispatch queue BEFORE the catch-up queue
## (visual responsiveness priority) — that queue does not exist yet.
func _physics_process(delta: float) -> void:
	var clamped_delta: float = minf(delta, MAX_FRAME_DELTA)  # long-frame guard (Story 014)
	_drain_catch_up_queue()
	_spawn_cadence_tick(clamped_delta)
	_perception_tick(clamped_delta)


## 4Hz batch perception (Rule 18 / Story 014). Reads the avatar position ONCE per
## PERCEPTION_TICK_INTERVAL and pushes the distance to every live enemy node — a single
## avatar read per 250ms instead of one read per enemy per frame (ADR-0001 budget).
func _perception_tick(delta: float) -> void:
	if _avatar_source == null:
		return
	_perception_tick_accumulator += delta
	if _perception_tick_accumulator < PERCEPTION_TICK_INTERVAL:
		return
	_perception_tick_accumulator = 0.0
	var avatar_pos: Vector2 = _avatar_source.global_position  # ONE read per window
	for instance_id: int in _enemy_state_pool:
		var node: Object = instance_from_id(instance_id)
		if node != null and node.has_method("set_avatar_distance"):
			node.set_avatar_distance(avatar_pos.distance_to(node.global_position))
	_poll_boss_anchor()  # Story 016: 4Hz-gated boss anchor Formula 5 check


## Drain up to CATCH_UP_HITS_PER_FRAME_CAP entries from the FRONT (FIFO) per call (EC-24).
## Bounds per-frame work so a large bfcache-resume backlog cannot blow the frame budget;
## the queue size decreases monotonically across successive frames.
func _drain_catch_up_queue() -> void:
	var processed: int = 0
	while _catch_up_queue.size() > 0 and processed < CATCH_UP_HITS_PER_FRAME_CAP:
		var entry: CatchUpEntry = _catch_up_queue.pop_front()
		_process_catch_up_entry(entry)
		processed += 1


## Process one drained catch-up entry. Story 018 fills the real AOE pipeline here
## (and MUST re-run the GSM Suspended gate per entry — defer is not a gate bypass, EC-01).
## For Story 009 this forwards to the optional `_catch_up_sink` seam so tests can observe
## FIFO drain order; null in production → no-op until Story 018.
func _process_catch_up_entry(entry: CatchUpEntry) -> void:
	if _catch_up_sink != null:
		_catch_up_sink.record(entry)


# =====================================================================
# Wave archetype scheduler (Rule 12, Formula 1 — Story 011)
# =====================================================================


## Formula 1: actual spawn interval (s) = BASE_SPAWN_INTERVAL × archetype_cadence_mult.
## INV-1: the result must be ≥ MIN_SPAWN_INTERVAL. The assert fails loudly on a data bug
## (e.g. a new archetype with an out-of-range mult) instead of silently clamping.
func _compute_spawn_interval(wave: WaveDescriptor) -> float:
	var interval: float = BASE_SPAWN_INTERVAL * wave.archetype_cadence_mult
	assert(interval >= MIN_SPAWN_INTERVAL,
		"INV-1 violated: spawn interval %f < MIN_SPAWN_INTERVAL %f (archetype_cadence_mult=%f)" % [
			interval, MIN_SPAWN_INTERVAL, wave.archetype_cadence_mult,
		])
	return interval


## Map a WST dominant AbilityClass ordinal to an EnemyRegistry archetype key.
## UNKNOWN (or any unrecognised ordinal) → STRIKE fallback + rate-limited anomaly (EC-09).
func _select_archetype_key() -> StringName:
	var cls: int = _wst_source.get_dominant_ability_class()
	match cls:
		AbilitySystem.AbilityClass.STRIKE:
			return &"STRIKE"
		AbilitySystem.AbilityClass.CONTROL:
			return &"CONTROL"
		AbilitySystem.AbilityClass.MOBILITY:
			return &"MOBILITY"
		_:
			# EC-09: UNKNOWN / unrecognised → STRIKE fallback (Pillar 4 — better than no wave).
			var now_ms: int = Time.get_ticks_msec()
			if rate_limit_check(REASON_UNKNOWN_ABILITY_CLASS_FALLBACK, now_ms):
				var payload := CombatAnomalyPayload.new()
				payload.reason = REASON_UNKNOWN_ABILITY_CLASS_FALLBACK
				payload.context_dump = {"dominant_class": cls}
				combat_metric_anomaly.emit(payload)
			return &"STRIKE"


## Resolve the WaveDescriptor for the current archetype, updating `_active_wave`.
## EC-10: a null registry lookup logs an error, emits REGISTRY_LOOKUP_NULL, and returns
## null (caller skips the wave and the scheduler stays idle — never crashes).
func _resolve_active_wave() -> WaveDescriptor:
	var key: StringName = _select_archetype_key()
	var wave: Variant = null
	if _enemy_registry != null:
		wave = _enemy_registry.archetypes.get(key, null)
	if wave == null:
		push_error("[EnemyDirector] EnemyRegistry lookup returned null for archetype '%s'" % key)
		var now_ms: int = Time.get_ticks_msec()
		if rate_limit_check(REASON_REGISTRY_LOOKUP_NULL, now_ms):
			var payload := CombatAnomalyPayload.new()
			payload.reason = REASON_REGISTRY_LOOKUP_NULL
			payload.context_dump = {"archetype_key": key}
			combat_metric_anomaly.emit(payload)
		return null
	_active_wave = wave
	return wave


## Per-frame wave cadence tick (Formula 1). No-op while paused (non-combat states).
## Pool cap (EC-11) skips the spawn without emitting an anomaly (legitimate cap behaviour).
func _spawn_cadence_tick(delta: float) -> void:
	if _wave_scheduler_paused:
		return
	_spawn_cadence_accumulator += delta
	var wave: WaveDescriptor = _resolve_active_wave()
	if wave == null:
		_spawn_cadence_accumulator = 0.0  # EC-10: skip wave, stay idle
		return
	var interval: float = _compute_spawn_interval(wave)
	if _spawn_cadence_accumulator < interval:
		return
	_spawn_cadence_accumulator -= interval
	# EC-11: pool cap — pause spawning while at/above the on-screen ceiling (no anomaly).
	if _enemy_state_pool.size() >= MAX_CONCURRENT_ENEMIES_ON_SCREEN:
		return
	_spawn_enemy(wave)


## Spawn one enemy for the given wave archetype (Story 012 + Rule 3).
## Test-observability mode: if `_spawn_sink` is injected, forward + return (no real
## instantiation — Story 011 cadence/cap tests). Production runs the real path below.
## Atomicity (ADR-0006): the node is added to the tree AND its EnemyState is inserted into
## the pool together, and a one-shot tree_exited connection guarantees pool cleanup.
func _spawn_enemy(wave: WaveDescriptor) -> void:
	if _spawn_sink != null:
		_spawn_sink.spawn(wave)
		return
	if wave.enemy_templates.is_empty():
		return
	var enemy_id: StringName = wave.enemy_templates[DEFAULT_TIER_INDEX] if wave.enemy_templates.size() > DEFAULT_TIER_INDEX else wave.enemy_templates[0]
	if not _spawn_pool.has(enemy_id):
		return  # no preloaded scene (production until enemy art ships) — nothing to spawn

	# (a) Per-spawn deterministic sub-RNG for position jitter (Rule 4 / ADR-0005).
	var transition_id: String = _gsm_source.acquire_transition_id(
		_gsm_source.get_current_state(), _gsm_source.get_current_state())
	var sub_rng: RandomNumberGenerator = _rng_factory.create_sub(
		transition_id, "wave_spawn_%d" % _wave_seq_counter)
	var jitter_x: float = sub_rng.randf_range(-SPAWN_JITTER_X, SPAWN_JITTER_X)

	# (b) Instantiate the preloaded PackedScene.
	var packed: PackedScene = _spawn_pool[enemy_id]
	var enemy: Node = packed.instantiate()
	if enemy is Node2D:
		(enemy as Node2D).position = SPAWN_ORIGIN + Vector2(jitter_x, 0.0)
	add_child(enemy)

	# (c) Insert EnemyState (hp = max_hp at spawn). Tier stats from the WaveDescriptor.
	var instance_id: int = enemy.get_instance_id()
	var tier: int = DEFAULT_TIER_INDEX
	var max_hp: float = float(wave.max_hp[tier]) if wave.max_hp.size() > tier else 0.0
	var defense: float = float(wave.defense[tier]) if wave.defense.size() > tier else 0.0
	_enemy_state_pool[instance_id] = EnemyState.new(
		instance_id, enemy_id, max_hp, max_hp, defense, wave.faction, EnemyAIState.SPAWNING)

	# (d) One-shot despawn cleanup — auto-disconnects after the first tree_exited.
	enemy.tree_exited.connect(_on_enemy_despawned.bind(instance_id), CONNECT_ONE_SHOT)
	_wave_seq_counter += 1


## Despawn cleanup (EC-38). Erase BOTH the pool entry and the dedupe-set entry so a
## long session never leaks (EC-47). Bound to the enemy's one-shot tree_exited.
func _on_enemy_despawned(instance_id: int) -> void:
	_enemy_state_pool.erase(instance_id)
	_killed_dedupe_set.erase(instance_id)


## Apply a resolved hit to the live enemy's pool state (Rule 3 mutation).
## Guard: a hit for an instance no longer in the pool (already despawned) is a no-op.
func _apply_hit_result(instance_id: int, hit_result: CombatResolver.HitResult) -> void:
	if not _enemy_state_pool.has(instance_id):
		return
	_enemy_state_pool[instance_id].hp = hit_result.target_hp_after
	# Story 017 AC-19: a kill emits enemy_killed in the SAME frame (synchronous, no defer).
	# Non-boss enemies are untouched (no force-despawn — narrative continuity, Rule 13).
	# Story 019 hardens this with the dedupe guard + idempotency.
	if hit_result.is_kill:
		_emit_enemy_killed(instance_id, hit_result)


## Set every live enemy's AI state to IDLE without despawning (EC-13 RestPeriod).
## Pool entries are duck-typed with an `ai_state` field until Story 012's EnemyState.
func _idle_active_enemies() -> void:
	for instance_id: int in _enemy_state_pool:
		var enemy: Variant = _enemy_state_pool[instance_id]
		if enemy != null and enemy.get(&"ai_state") != null:
			enemy.set(&"ai_state", EnemyAIState.IDLE)


# =====================================================================
# Particle throttle hysteresis (Rule 11, Formula 3 — Story 015)
# =====================================================================


## Record one frame time (ms) and re-evaluate the throttle. Public + injectable —
## the game's frame-time monitor feeds this; the throttle logic itself reads NO clock
## (deterministic / testable). EC-29 engage, EC-30 release.
func _record_frame_time(frame_time_ms: float) -> void:
	_frame_time_window.push_back(frame_time_ms)
	while _frame_time_window.size() > FRAME_TIME_SAMPLE_SIZE:
		_frame_time_window.pop_front()
	_recovery_window.push_back(frame_time_ms)
	while _recovery_window.size() > RECOVERY_SAMPLE_SIZE:
		_recovery_window.pop_front()
	_evaluate_throttle()


## Engage (all emergency samples above budget) / release (all recovery samples below
## recovery) with hysteresis. Emits a rate-limited anomaly on each transition only.
func _evaluate_throttle() -> void:
	if not _throttle_active:
		if _frame_time_window.size() == FRAME_TIME_SAMPLE_SIZE \
				and _all_above(_frame_time_window, FRAME_TIME_BUDGET_MS):
			_throttle_active = true
			_caller_mult = CALLER_MULT_THROTTLED
			_emit_throttle_anomaly(&"PARTICLE_THROTTLE_ENGAGED")
	else:
		if _recovery_window.size() == RECOVERY_SAMPLE_SIZE \
				and _all_below(_recovery_window, FRAME_TIME_RECOVERY_MS):
			_throttle_active = false
			_caller_mult = CALLER_MULT_NORMAL
			_emit_throttle_anomaly(&"PARTICLE_THROTTLE_RELEASED")


## True while the particle throttle is engaged (AC-23).
func _is_throttle_active() -> bool:
	return _throttle_active


## Current particle caller multiplier (1.5 normal / 1.0 throttled).
func get_caller_mult() -> float:
	return _caller_mult


func _all_above(window: Array[float], threshold: float) -> bool:
	for v: float in window:
		if v <= threshold:
			return false
	return true


func _all_below(window: Array[float], threshold: float) -> bool:
	for v: float in window:
		if v >= threshold:
			return false
	return true


func _emit_throttle_anomaly(reason: StringName) -> void:
	var now_ms: int = Time.get_ticks_msec()
	if rate_limit_check(reason, now_ms):
		var payload := CombatAnomalyPayload.new()
		payload.reason = reason
		payload.context_dump = {"caller_mult": _caller_mult}
		combat_metric_anomaly.emit(payload)


# =====================================================================
# Boss anchor pre-spawn + rollback (Rule 13 part 1, Formula 5 — Story 016)
# =====================================================================


## Select entry-cascade params by planned-set count (EC-19). Light workouts (≤ threshold)
## get the reduced mini-boss cascade; otherwise the standard cascade. Pure — Story 017
## consumes the returned params when executing the actual Camera/ScreenEffects/Particle cascade.
func _select_boss_cascade_params(total_planned_sets: int) -> Dictionary:
	var is_mini: bool = total_planned_sets <= LIGHT_WORKOUT_THRESHOLD_SETS
	if is_mini:
		return {
			"is_mini": true,
			"camera_sec": MINI_BOSS_CASCADE_CAMERA_SEC,
			"shake": MINI_BOSS_CASCADE_SHAKE,
			"particle_mult": MINI_BOSS_CASCADE_PARTICLE_MULT,
		}
	return {
		"is_mini": false,
		"camera_sec": BOSS_CASCADE_CAMERA_SEC,
		"shake": BOSS_CASCADE_SHAKE,
		"particle_mult": BOSS_CASCADE_PARTICLE_MULT,
	}


## Pre-spawn the boss hidden off-screen (Formula 5). Selects the mini/final scene by
## planned-set count, instantiates hidden, adds to the tree (NOT the enemy pool — pool
## insertion is the COMMITTED step, Story 017), records cascade params, → PRE_SPAWN.
func pre_spawn_boss(total_planned_sets: int) -> void:
	_boss_cascade_params = _select_boss_cascade_params(total_planned_sets)
	var scene: Variant = _boss_scene_mini if _boss_cascade_params["is_mini"] else _boss_scene_final
	if scene != null:
		_boss_node = scene.instantiate()
		if _boss_node is Node2D:
			(_boss_node as Node2D).position = Vector2(BOSS_OFFSCREEN_X, SPAWN_ORIGIN.y)
		if _boss_node is CanvasItem:
			(_boss_node as CanvasItem).visible = false
		add_child(_boss_node)
	_transition_boss_anchor(BossAnchorState.PRE_SPAWN)


## Silent rollback (EC-15) — the pre-spawned boss never entered COMMITTED/ENGAGED, so it is
## freed with NO enemy_killed and NO anomaly (rollback is expected, not an error).
func despawn_boss_silently() -> void:
	if _boss_node != null and is_instance_valid(_boss_node):
		_boss_node.queue_free()
	_boss_node = null
	_boss_anchor_state = BossAnchorState.IDLE


## Formula 5 FSM core (parameterized for deterministic unit testing).
##   IDLE + final set + set_progress ≥ threshold → pre_spawn_boss (→ PRE_SPAWN).
##   PRE_SPAWN + set_progress dropped below threshold → despawn_boss_silently (→ IDLE).
func _check_boss_anchor_state(set_progress: float, is_final_set: bool, total_planned_sets: int) -> void:
	if _boss_anchor_state == BossAnchorState.IDLE:
		if is_final_set and set_progress >= BOSS_PRESPAWN_PROGRESS:
			pre_spawn_boss(total_planned_sets)
	elif _boss_anchor_state == BossAnchorState.PRE_SPAWN:
		if set_progress < BOSS_PRESPAWN_PROGRESS:
			despawn_boss_silently()


## 4Hz-gated poll: reads boss-trigger inputs from the WST seam and runs the FSM core.
## Defensive about which queries the WST exposes (real WST integration completes in Story 017).
func _poll_boss_anchor() -> void:
	if _wst_source == null or not _wst_source.has_method("get_set_progress"):
		return
	var set_progress: float = _wst_source.get_set_progress()
	var is_final: bool = _wst_source.has_method("is_final_set") and _wst_source.is_final_set()
	var total: int = 0
	if _wst_source.has_method("get_planned_total_sets"):
		total = _wst_source.get_planned_total_sets()
	_check_boss_anchor_state(set_progress, is_final, total)


# =====================================================================
# Boss anchor commit + entry cascade (Rule 13 part 2 — Story 017)
# =====================================================================


## Boss-anchor FSM forward transition (ADR-0006 atomicity). Validates the edge against
## BOSS_ANCHOR_LEGAL_EDGES then commits via a parameterised local (NOT a literal
## BossAnchorState.<value> assignment — that is the CI-forbidden bypass). IDLE rollback
## stays a direct assignment in despawn_boss_silently (the always-legal reset target).
func _transition_boss_anchor(to_state: int) -> void:
	assert(to_state in BOSS_ANCHOR_LEGAL_EDGES.get(_boss_anchor_state, []),
		"illegal boss-anchor transition %d -> %d" % [_boss_anchor_state, to_state])
	_boss_anchor_state = to_state


## Arm the pre-spawned boss for commit (PRE_SPAWN → COMMIT_PENDING). Called when the
## workout nears completion; the actual commit fires on GSM → BOSS_ENCOUNTER.
func arm_boss_commit() -> void:
	if _boss_anchor_state == BossAnchorState.PRE_SPAWN:
		_transition_boss_anchor(BossAnchorState.COMMIT_PENDING)


## Boss entry cascade (AC-33) — 5 steps in EXACT order, all in this synchronous frame
## (no await / no call_deferred). All Camera/ScreenEffects/Particle calls route through
## their autoload seams (ADR-0001 chokepoints). COMMIT_PENDING → COMMITTED → ENGAGED.
func _commit_boss_entry() -> void:
	_transition_boss_anchor(BossAnchorState.COMMITTED)
	var params: Dictionary = _boss_cascade_params if not _boss_cascade_params.is_empty() \
		else _select_boss_cascade_params(0)  # default standard if unset
	var boss_pos: Vector2 = Vector2.ZERO
	if _boss_node != null:
		# Step 1 — reveal.
		if _boss_node is CanvasItem:
			(_boss_node as CanvasItem).visible = true
		# Step 2 — engage the boss AI.
		if _boss_node.has_method("engage"):
			_boss_node.engage()
		if _boss_node is Node2D:
			boss_pos = (_boss_node as Node2D).global_position
	# Step 3 — camera focal request.
	if _camera_source != null:
		_camera_source.focal_request(_boss_node, params["camera_sec"], BOSS_FOCAL_EASING)
	# Step 4 — screen shake.
	if _screen_effects_source != null:
		_screen_effects_source.shake(params["shake"], BOSS_SHAKE_DURATION)
	# Step 5 — boss-entry particles (caller_mult = boss spectacle override).
	if _particle_source != null:
		_particle_source.play(BOSS_ENTRY_PARTICLE_PRESET, boss_pos, params["particle_mult"])
	_transition_boss_anchor(BossAnchorState.ENGAGED)


## Emit enemy_killed synchronously (AC-19 same-frame). Builds the payload from the pool
## entry + resolved hit. Story 019 wraps this with the dedupe / idempotency guard.
func _emit_enemy_killed(instance_id: int, hit_result: CombatResolver.HitResult) -> void:
	# Idempotency guard (AC-35e / Story 019): at most one enemy_killed per instance_id.
	if _killed_dedupe_set.has(instance_id):
		return
	_killed_dedupe_set[instance_id] = true
	var payload := EnemyKilledPayload.new()
	payload.enemy_instance_id = instance_id
	if _enemy_state_pool.has(instance_id):
		payload.enemy_id = _enemy_state_pool[instance_id].enemy_id
	payload.killing_ability = hit_result.ability_id
	payload.transition_id = hit_result.transition_id
	payload.is_overkill = hit_result.overkill_excess > 0
	enemy_killed.emit(payload)


# =====================================================================
# Full AOE handler pipeline (Rule 14 — Story 018)
# =====================================================================


## Resolve a hit through the injectable resolver seam, falling back to the static
## CombatResolver.resolve_hit (the static func is otherwise un-mockable in tests).
func _resolve_hit(ctx: CombatResolver.CombatContext) -> CombatResolver.HitResult:
	if _combat_resolver != null:
		return _combat_resolver.resolve_hit(ctx)
	return CombatResolver.resolve_hit(ctx)


## Targets for an AOE cast — every live enemy in the pool. (Ability-radius filtering is a
## future refinement; for now the wave size is bounded by MAX_CONCURRENT_ENEMIES_ON_SCREEN.)
func _get_ability_targets(_caster: Node2D) -> Array:
	return _enemy_state_pool.keys()


## Distance-sort + clamp targets to MAX_TARGETS_PER_CAST nearest the origin (AC-34 / EC-21).
## ≤ cap: returned unchanged (no position lookup). > cap: keep the 8 nearest + CLAMP anomaly.
func _expand_targets(target_ids: Array, origin: Vector2) -> Array:
	if target_ids.size() <= MAX_TARGETS_PER_CAST:
		return target_ids
	var sorted: Array = target_ids.duplicate()
	sorted.sort_custom(func(a: int, b: int) -> bool:
		return _target_dist_sq(a, origin) < _target_dist_sq(b, origin))
	var capped: Array = sorted.slice(0, MAX_TARGETS_PER_CAST)
	var now_ms: int = Time.get_ticks_msec()
	if rate_limit_check(REASON_CLAMP_TRIGGERED, now_ms):
		var payload := CombatAnomalyPayload.new()
		payload.reason = REASON_CLAMP_TRIGGERED
		payload.context_dump = {"requested": target_ids.size(), "capped": MAX_TARGETS_PER_CAST}
		combat_metric_anomaly.emit(payload)
	return capped


## Squared distance (cheaper than distance) from a target node to the cast origin; INF if
## the instance is gone / not a Node2D (sorts such entries last).
func _target_dist_sq(instance_id: int, origin: Vector2) -> float:
	var node: Object = instance_from_id(instance_id)
	if node is Node2D:
		return (node as Node2D).global_position.distance_squared_to(origin)
	return INF


## Build a CombatContext for one target, mapping the pool EnemyState → CombatResolver.EnemyState.
## caster_stats is the SHARED snapshot reference (not copied) — AOE drift prevention (AC-35d).
func _build_combat_context(ability_id: StringName, caster: Node2D,
		snapshot: CombatResolver.StatSnapshot, rng: RandomNumberGenerator,
		transition_id: String, target_id: int) -> CombatResolver.CombatContext:
	var ctx := CombatResolver.CombatContext.new()
	ctx.ability_id = ability_id
	ctx.caster = caster
	var target_node: Object = instance_from_id(target_id)
	if target_node is Node2D:
		ctx.target = target_node
	ctx.caster_stats = snapshot
	ctx.target_state = _map_target_state(target_id)
	ctx.rng = rng
	ctx.transition_id = transition_id
	ctx.gsm_state = GameStateMachine.GameState.find_key(_gsm_source.get_current_state())
	ctx.hit_seq = _hit_seq_counter
	_hit_seq_counter += 1
	return ctx


## Map a pool EnemyState to the resolver's CombatResolver.EnemyState struct (faction int→name).
func _map_target_state(target_id: int) -> CombatResolver.EnemyState:
	var ts := CombatResolver.EnemyState.new()
	if _enemy_state_pool.has(target_id):
		var es = _enemy_state_pool[target_id]
		ts.instance_id = target_id
		ts.hp = int(es.hp)
		ts.max_hp = maxi(1, int(es.max_hp))
		ts.defense = es.defense
		ts.faction = Faction.find_key(es.faction)
	return ts


## Emit a hit_resolved broadcast (Rule 5) built from the ctx + resolved hit.
func _emit_hit_resolved(ctx: CombatResolver.CombatContext, hit_result: CombatResolver.HitResult) -> void:
	var payload := CombatResolver.HitResolvedPayload.new()
	payload.ability_id = ctx.ability_id
	payload.caster_id = ctx.caster.get_instance_id() if ctx.caster != null else 0
	payload.target_id = ctx.target_state.instance_id if ctx.target_state != null else 0
	payload.outcome = hit_result.outcome
	payload.damage_tier = hit_result.damage_tier
	payload.damage_dealt = hit_result.damage_dealt
	payload.target_hp_after = hit_result.target_hp_after
	payload.is_crit = hit_result.is_crit
	payload.is_kill = hit_result.is_kill
	payload.transition_id = ctx.transition_id
	hit_resolved.emit(payload)


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
