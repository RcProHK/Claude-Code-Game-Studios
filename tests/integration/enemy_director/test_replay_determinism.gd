# EnemyDirector — Story 006 AC-15: replay determinism (integration).
#
# Coverage:
#   AC-15 [Integration|BLOCKING] — a replay of the same transition_id reproduces a
#     byte-identical multi-stream RNG sequence (primary + sub-streams interleaved);
#     different transition_ids diverge. Exercises the live autoload through a full
#     before_each/after_each reset + _ready() cycle (Contract 6 subscription pattern).
#
# Accessed as EnemyDirector.RNGFactory.* (autoload inner class).
extends GutTest


## Minimal fake GameStateMachine — has connect_for_initial_state + state_changed.
class FakeGSM:
	signal state_changed(from_state: int, to_state: int, payload)
	func connect_for_initial_state(callable: Callable) -> void:
		state_changed.connect(callable)


## Minimal fake AbilitySystem — has connect_for_initial_state + ability_cast.
class FakeAbilitySystem:
	signal ability_cast(ability_id: StringName, caster: Node2D, target: Node2D)
	func connect_for_initial_state(callable: Callable) -> void:
		ability_cast.connect(callable)


## Minimal fake EnemyRegistry (needed because _ready() calls _preload_spawn_pool).
class FakeEnemyRegistry:
	func get_preloaded_pool() -> Dictionary:
		return {&"STRIKE_MOB_T1": null}


var _fake_gsm: FakeGSM
var _fake_ability: FakeAbilitySystem
var _fake_registry: FakeEnemyRegistry


func before_each() -> void:
	await get_tree().process_frame
	# Reset all 8 EnemyDirector state containers (test_contract6_subscription.gd pattern).
	EnemyDirector.get(&"_catch_up_queue").clear()
	EnemyDirector.get(&"_anomaly_rate_tracker").clear()
	EnemyDirector.get(&"_enemy_state_pool").clear()
	EnemyDirector.get(&"_killed_dedupe_set").clear()
	EnemyDirector.get(&"_spawn_pool").clear()
	EnemyDirector.set(&"_rng_factory", null)
	EnemyDirector.set(&"_active_wave", null)
	EnemyDirector.set(&"_boss_anchor_state", EnemyDirector.BossAnchorState.IDLE)
	# Inject DI fakes.
	_fake_gsm = FakeGSM.new()
	_fake_ability = FakeAbilitySystem.new()
	_fake_registry = FakeEnemyRegistry.new()
	EnemyDirector.set(&"_gsm_source", _fake_gsm)
	EnemyDirector.set(&"_ability_source", _fake_ability)
	EnemyDirector.set(&"_enemy_registry", _fake_registry)
	# Re-run _ready() to wire subscriptions + provision the real RNGFactory.
	EnemyDirector.call("_ready")


func after_each() -> void:
	await get_tree().process_frame
	EnemyDirector.set(&"_gsm_source", null)
	EnemyDirector.set(&"_ability_source", null)
	EnemyDirector.set(&"_enemy_registry", null)


## Build a multi-stream interleaved RNG sequence for a transition_id.
## Creates 4 streams — the primary create(tid) plus 3 sub-streams — and draws
## n_draws from each in round-robin order, mirroring how _on_ability_cast would
## interleave combat + spawn + dodge rolls within a single transition.
func _simulate_rng_pipeline(transition_id: String, n_draws: int) -> Array[float]:
	var streams: Array[RandomNumberGenerator] = [
		EnemyDirector.RNGFactory.create(transition_id),
		EnemyDirector.RNGFactory.create_sub(transition_id, "wave_spawn_0"),
		EnemyDirector.RNGFactory.create_sub(transition_id, "wave_spawn_1"),
		EnemyDirector.RNGFactory.create_sub(transition_id, "dodge_1234"),
	]
	var sequence: Array[float] = []
	for draw_index in range(n_draws):
		for stream in streams:
			sequence.append(stream.randf())
	return sequence


# ---------------------------------------------------------------------------
# AC-15 — identical transition_id produces identical RNG sequences
# ---------------------------------------------------------------------------

## Two runs of the same transition_id, each through a full _ready() + reset cycle,
## must produce byte-identical interleaved multi-stream sequences.
func test_ac15_identical_transition_id_produces_identical_rng_sequences() -> void:
	# Arrange / Act — first run.
	var run_one := _simulate_rng_pipeline("TX-replay-001", 20)

	# Re-run the full reset + _ready() cycle between runs.
	before_each()

	# Act — second run, same transition_id.
	var run_two := _simulate_rng_pipeline("TX-replay-001", 20)

	# Assert — identical length and element-by-element equality.
	assert_eq(run_one.size(), run_two.size(),
		"AC-15: replayed sequences must have identical length")
	for i in range(run_one.size()):
		assert_eq(run_one[i], run_two[i],
			"AC-15: replayed sequence must be byte-identical at index %d" % i)


# ---------------------------------------------------------------------------
# AC-15 — different transition_ids produce different sequences
# ---------------------------------------------------------------------------

## Two different transition_ids must diverge on at least one element.
func test_ac15_different_transition_ids_produce_different_sequences() -> void:
	# Arrange / Act
	var seq_a := _simulate_rng_pipeline("TX-replay-001", 20)
	var seq_b := _simulate_rng_pipeline("TX-replay-002", 20)

	# Assert — at least one position must differ.
	var any_difference := false
	for i in range(min(seq_a.size(), seq_b.size())):
		if seq_a[i] != seq_b[i]:
			any_difference = true
			break
	assert_true(any_difference,
		"AC-15: different transition_ids must produce at least one differing value")
