# Enemy AI — Story 013 AC-27: IDLE↔PURSUING perception with hysteresis.
extends GutTest

const EAS = EnemyDirector.EnemyAIState

var _enemy: Enemy


func before_each() -> void:
	_enemy = Enemy.new()
	add_child_autofree(_enemy)  # enters tree → _ready connects + sets instance_id
	_enemy.set_physics_process(false)  # drive _physics_process manually (determinism)


# ---------------------------------------------------------------------------
# AC-27 — perception + hysteresis
# ---------------------------------------------------------------------------

func test_ac27_idle_to_pursuing_within_perception_range() -> void:
	_enemy._ai_state = EAS.IDLE
	_enemy.set_avatar_distance(550.0)  # ≤ 600
	_enemy.call("_physics_process", 0.016)
	assert_eq(_enemy.get_ai_state(), EAS.PURSUING,
		"AC-27: IDLE → PURSUING when distance ≤ PERCEPTION_RANGE (600)")


func test_ac27_pursuing_to_idle_beyond_leash_range() -> void:
	_enemy._ai_state = EAS.PURSUING
	_enemy.set_avatar_distance(950.0)  # > 900
	_enemy.call("_physics_process", 0.016)
	assert_eq(_enemy.get_ai_state(), EAS.IDLE,
		"AC-27: PURSUING → IDLE when distance > LEASH_RANGE (900)")


## Hysteresis: between 600 and 900, neither transition fires (no flicker).
func test_ac27_hysteresis_band_no_transition() -> void:
	# IDLE stays IDLE at 750 (above perception, below leash).
	_enemy._ai_state = EAS.IDLE
	_enemy.set_avatar_distance(750.0)
	_enemy.call("_physics_process", 0.016)
	assert_eq(_enemy.get_ai_state(), EAS.IDLE,
		"AC-27: IDLE stays IDLE inside the hysteresis band (600 < d ≤ 900)")
	# PURSUING stays PURSUING at 750.
	_enemy._ai_state = EAS.PURSUING
	_enemy.set_avatar_distance(750.0)
	_enemy.call("_physics_process", 0.016)
	assert_eq(_enemy.get_ai_state(), EAS.PURSUING,
		"AC-27: PURSUING stays PURSUING inside the hysteresis band")


## Re-acquire after leashing — proves no oscillation at the 600 boundary.
func test_ac27_reacquire_after_leash() -> void:
	_enemy._ai_state = EAS.PURSUING
	_enemy.set_avatar_distance(950.0)
	_enemy.call("_physics_process", 0.016)
	assert_eq(_enemy.get_ai_state(), EAS.IDLE, "leashed to IDLE")
	_enemy.set_avatar_distance(550.0)
	_enemy.call("_physics_process", 0.016)
	assert_eq(_enemy.get_ai_state(), EAS.PURSUING, "AC-27: re-acquires PURSUING below perception")


## SPAWNING settles to IDLE on the first physics tick (no perception that frame).
func test_spawning_settles_to_idle() -> void:
	_enemy._ai_state = EAS.SPAWNING
	_enemy.set_avatar_distance(100.0)  # close, but SPAWNING settles first
	_enemy.call("_physics_process", 0.016)
	assert_eq(_enemy.get_ai_state(), EAS.IDLE, "SPAWNING → IDLE on first tick (settle before perception)")
