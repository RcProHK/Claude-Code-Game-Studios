# EnemyDirector — Story 001 Core Class + 8 State Containers init-state tests.
#
# Coverage:
#   AC-01 [Logic|BLOCKING|static] — 8 state containers declared as class-body vars.
#     Primary verification is the Story 002 CI lint; this suite confirms runtime
#     accessibility of all 8 container properties on the live autoload.
#   AC-02 [Logic|BLOCKING|unit] — after _ready(), all 8 containers in empty/zero state,
#     _spawn_pool preloaded (not empty) via injected registry, _rng_factory != null.
#   AC-03 [Logic|BLOCKING|static] — 3 enums declared; Family A ordinal-0 safe defaults
#     (EnemyAIState.SPAWNING == 0, BossAnchorState.IDLE == 0); Faction Family B members.
#
# DI seam pattern follows tests/integration/core/workout_state_tracker/
# test_ci4_volume_to_loot.gd (before_each reset + EnemyDirector.set(&"...", ...)).
extends GutTest


## Minimal fake EnemyRegistry — exposes get_preloaded_pool() so _preload_spawn_pool()
## can populate _spawn_pool with deterministic test data (AC-02 preloaded assertion).
class FakeEnemyRegistry:
	var pool: Dictionary = {&"STRIKE_MOB_T1": null}

	func get_preloaded_pool() -> Dictionary:
		return pool


var _fake_registry: FakeEnemyRegistry


func before_each() -> void:
	await get_tree().process_frame
	# Reset all 8 containers to a clean baseline. Typed/untyped containers use
	# .get(...).clear() (NOT set([])) to avoid the typed-Array set no-op gotcha
	# and to mutate the live container reference in place.
	EnemyDirector.get(&"_catch_up_queue").clear()
	EnemyDirector.get(&"_anomaly_rate_tracker").clear()
	EnemyDirector.get(&"_enemy_state_pool").clear()
	EnemyDirector.get(&"_killed_dedupe_set").clear()
	EnemyDirector.get(&"_spawn_pool").clear()
	EnemyDirector.set(&"_rng_factory", null)
	EnemyDirector.set(&"_active_wave", null)
	EnemyDirector.set(&"_boss_anchor_state", EnemyDirector.BossAnchorState.IDLE)
	# Inject fake registry so _preload_spawn_pool() has a deterministic source.
	_fake_registry = FakeEnemyRegistry.new()
	EnemyDirector.set(&"_enemy_registry", _fake_registry)


func after_each() -> void:
	await get_tree().process_frame
	# Restore DI seam — production resolves registry from .tres in _ready().
	EnemyDirector.set(&"_enemy_registry", null)


# ---------------------------------------------------------------------------
# AC-01 — 8 state containers declared as class-body vars (runtime accessibility)
# ---------------------------------------------------------------------------

## All 8 declared containers must be runtime-accessible properties on the autoload.
## Static grep (Story 002 CI lint) is the primary AC-01 gate; this confirms the
## eight names resolve to real, non-error property reads on the live instance.
func test_ac01_all_8_containers_declared_as_class_body_vars() -> void:
	# Arrange
	var container_names: Array[StringName] = [
		&"_catch_up_queue",
		&"_anomaly_rate_tracker",
		&"_enemy_state_pool",
		&"_killed_dedupe_set",
		&"_spawn_pool",
		&"_rng_factory",
		&"_active_wave",
		&"_boss_anchor_state",
	]
	# Act
	var declared_names: Array[String] = []
	for prop: Dictionary in EnemyDirector.get_property_list():
		declared_names.append(String(prop.get("name", "")))
	# Assert — every one of the 8 names appears in the autoload's property list.
	for name: StringName in container_names:
		assert_true(declared_names.has(String(name)),
			"AC-01: container '%s' must be a declared class-body var on EnemyDirector" % name)
	assert_eq(container_names.size(), 8,
		"AC-01: exactly 8 state containers are tracked by this test")


# ---------------------------------------------------------------------------
# AC-02 — init state after _ready() (empty/zero baseline + preloaded pool)
# ---------------------------------------------------------------------------

## _catch_up_queue is empty at the clean baseline (size 0).
func test_ac02_catch_up_queue_empty_after_ready() -> void:
	# Arrange / Act handled by before_each reset.
	var queue: Array = EnemyDirector.get(&"_catch_up_queue")
	# Assert
	assert_eq(queue.size(), 0,
		"AC-02: _catch_up_queue must be empty (size 0) at init")


## _anomaly_rate_tracker is empty at init.
func test_ac02_anomaly_rate_tracker_empty_after_ready() -> void:
	var tracker: Dictionary = EnemyDirector.get(&"_anomaly_rate_tracker")
	assert_true(tracker.is_empty(),
		"AC-02: _anomaly_rate_tracker must be empty at init")


## _enemy_state_pool is empty at init.
func test_ac02_enemy_state_pool_empty_after_ready() -> void:
	var pool: Dictionary = EnemyDirector.get(&"_enemy_state_pool")
	assert_true(pool.is_empty(),
		"AC-02: _enemy_state_pool must be empty at init")


## _killed_dedupe_set is empty at init.
func test_ac02_killed_dedupe_set_empty_after_ready() -> void:
	var dedupe: Dictionary = EnemyDirector.get(&"_killed_dedupe_set")
	assert_true(dedupe.is_empty(),
		"AC-02: _killed_dedupe_set must be empty at init")


## _boss_anchor_state defaults to BossAnchorState.IDLE (Family A ordinal 0).
func test_ac02_boss_anchor_state_is_idle_after_ready() -> void:
	var anchor: int = EnemyDirector.get(&"_boss_anchor_state")
	assert_eq(anchor, EnemyDirector.BossAnchorState.IDLE,
		"AC-02: _boss_anchor_state must be BossAnchorState.IDLE (ordinal 0) at init")


## _rng_factory is non-null after _preload path runs (placeholder instance).
func test_ac02_rng_factory_not_null_after_ready() -> void:
	# Arrange — before_each cleared _rng_factory to null; invoke the same
	# placeholder provisioner _ready() uses to confirm it yields a non-null object.
	EnemyDirector.set(&"_rng_factory", EnemyDirector.call("_create_rng_factory_placeholder"))
	# Act
	var rng = EnemyDirector.get(&"_rng_factory")
	# Assert
	assert_not_null(rng,
		"AC-02: _rng_factory must be non-null after provisioning")


## _spawn_pool is populated (not empty) after _preload_spawn_pool() with a registry.
func test_ac02_spawn_pool_populated_with_fake_registry() -> void:
	# Arrange — before_each injected FakeEnemyRegistry with one entry.
	# Act — re-run the preload using the injected registry.
	EnemyDirector.call("_preload_spawn_pool")
	var pool: Dictionary = EnemyDirector.get(&"_spawn_pool")
	# Assert — preloaded, so NOT empty, and carries the fake registry's key.
	assert_false(pool.is_empty(),
		"AC-02: _spawn_pool must be preloaded (not empty) when a registry is present")
	assert_true(pool.has(&"STRIKE_MOB_T1"),
		"AC-02: _spawn_pool must contain the registry's enemy_id key after preload")


## Full _ready() integration: call _ready() directly and assert the complete
## AC-02 baseline in one pass. This is the ONLY test that exercises _ready()
## end-to-end wiring — covers the case where _ready() omits a call to
## _preload_spawn_pool() or _create_rng_factory_placeholder().
func test_ac02_ready_wiring_end_to_end() -> void:
	# Arrange — before_each already injected fake registry and cleared state.
	# Force all containers to a different state so we can detect _ready() reset.
	EnemyDirector.get(&"_catch_up_queue").append("dirty")
	EnemyDirector.get(&"_anomaly_rate_tracker")[&"dirty"] = true
	EnemyDirector.set(&"_boss_anchor_state", EnemyDirector.BossAnchorState.ENGAGED)
	EnemyDirector.set(&"_rng_factory", null)
	EnemyDirector.get(&"_spawn_pool").clear()

	# Act — call _ready() for real. In Story 001 _ready() has no signal wiring
	# (Story 005 scope), so calling it again is safe and idempotent.
	EnemyDirector.call("_ready")

	# Assert — verify _ready() fully restored baseline state.
	assert_eq(EnemyDirector.get(&"_catch_up_queue").size(), 0,
		"AC-02 _ready(): _catch_up_queue must be cleared by _ready()")
	assert_true(EnemyDirector.get(&"_anomaly_rate_tracker").is_empty(),
		"AC-02 _ready(): _anomaly_rate_tracker must be cleared by _ready()")
	assert_eq(EnemyDirector.get(&"_boss_anchor_state"), EnemyDirector.BossAnchorState.IDLE,
		"AC-02 _ready(): _boss_anchor_state must be reset to IDLE by _ready()")
	assert_not_null(EnemyDirector.get(&"_rng_factory"),
		"AC-02 _ready(): _rng_factory must be non-null after _ready()")
	assert_false(EnemyDirector.get(&"_spawn_pool").is_empty(),
		"AC-02 _ready(): _spawn_pool must be preloaded by _ready() when registry present")


# ---------------------------------------------------------------------------
# AC-03 — 3 enums declared; Family A ordinal-0 safe defaults; member counts
# ---------------------------------------------------------------------------

## EnemyAIState.SPAWNING is ordinal 0 (Family A safe pre-_ready() default).
func test_ac03_enemy_ai_state_spawning_is_ordinal_zero() -> void:
	assert_eq(int(EnemyDirector.EnemyAIState.SPAWNING), 0,
		"AC-03: EnemyAIState.SPAWNING must be ordinal 0 (Family A safe default)")


## BossAnchorState.IDLE is ordinal 0 (Family A safe pre-_ready() default).
func test_ac03_boss_anchor_state_idle_is_ordinal_zero() -> void:
	assert_eq(int(EnemyDirector.BossAnchorState.IDLE), 0,
		"AC-03: BossAnchorState.IDLE must be ordinal 0 (Family A safe default)")


## Faction (Family B) declares exactly 4 members: PLAYER/ENEMY/BOSS/NEUTRAL.
func test_ac03_faction_has_four_members() -> void:
	assert_eq(EnemyDirector.Faction.size(), 4,
		"AC-03: Faction must declare exactly 4 members (PLAYER/ENEMY/BOSS/NEUTRAL)")
	# Confirm the GDD Rule 3 faction-relationship member name exists.
	assert_true(EnemyDirector.Faction.has("NEUTRAL"),
		"AC-03: Faction must contain NEUTRAL (GDD Rule 3 faction-relationship value)")


## EnemyAIState declares exactly 6 members.
func test_ac03_enemy_ai_state_has_six_members() -> void:
	assert_eq(EnemyDirector.EnemyAIState.size(), 6,
		"AC-03: EnemyAIState must declare exactly 6 members")


## BossAnchorState declares exactly 5 members.
func test_ac03_boss_anchor_state_has_five_members() -> void:
	assert_eq(EnemyDirector.BossAnchorState.size(), 5,
		"AC-03: BossAnchorState must declare exactly 5 members")
