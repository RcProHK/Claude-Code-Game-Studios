# Enemy AI — Story 013 AC-28: STAGGER on HEAVY/CRITICAL hit (EC-35).
extends GutTest

const EAS = EnemyDirector.EnemyAIState
const DT = CombatResolver.DamageTier

var _enemy: Enemy


func before_each() -> void:
	_enemy = Enemy.new()
	add_child_autofree(_enemy)
	_enemy.set_physics_process(false)


func _hit(target_id: int, tier: int, is_kill: bool = false):
	var p := CombatResolver.HitResolvedPayload.new()
	p.target_id = target_id
	p.damage_tier = tier
	p.is_kill = is_kill
	return p


# ---------------------------------------------------------------------------
# AC-28 — stagger HEAVY / CRITICAL
# ---------------------------------------------------------------------------

func test_ac28_heavy_hit_triggers_stagger() -> void:
	_enemy._ai_state = EAS.PURSUING
	EnemyDirector.hit_resolved.emit(_hit(_enemy.get_instance_id(), DT.HEAVY))
	assert_eq(_enemy.get_ai_state(), EAS.STAGGERED, "AC-28: HEAVY hit → STAGGERED")


func test_ac28_heavy_stagger_expires_to_pursuing_after_duration() -> void:
	_enemy._ai_state = EAS.PURSUING
	EnemyDirector.hit_resolved.emit(_hit(_enemy.get_instance_id(), DT.HEAVY))
	assert_eq(_enemy.get_ai_state(), EAS.STAGGERED, "precondition: staggered")
	# Elapse 0.15s (HEAVY duration).
	_enemy.call("_physics_process", 0.15)
	assert_eq(_enemy.get_ai_state(), EAS.PURSUING, "AC-28: HEAVY stagger (0.15s) elapses → PURSUING")


func test_ac28_critical_stagger_uses_longer_duration() -> void:
	_enemy._ai_state = EAS.PURSUING
	EnemyDirector.hit_resolved.emit(_hit(_enemy.get_instance_id(), DT.CRITICAL))
	assert_eq(_enemy.get_ai_state(), EAS.STAGGERED, "CRITICAL → STAGGERED")
	# Not yet elapsed at 0.15s (CRITICAL = 0.30s).
	_enemy.call("_physics_process", 0.15)
	assert_eq(_enemy.get_ai_state(), EAS.STAGGERED, "AC-28: CRITICAL stagger still active at 0.15s")
	# Elapsed after a further 0.15s (total 0.30s).
	_enemy.call("_physics_process", 0.15)
	assert_eq(_enemy.get_ai_state(), EAS.PURSUING, "AC-28: CRITICAL stagger (0.30s) elapses → PURSUING")


## Re-trigger guard: a second HEAVY while STAGGERED does NOT reset the timer (EC-35).
func test_ac28_no_retrigger_while_staggered() -> void:
	_enemy._ai_state = EAS.PURSUING
	EnemyDirector.hit_resolved.emit(_hit(_enemy.get_instance_id(), DT.HEAVY))
	_enemy.call("_physics_process", 0.10)  # 0.10 of 0.15 elapsed
	# Second HEAVY hit while STAGGERED.
	EnemyDirector.hit_resolved.emit(_hit(_enemy.get_instance_id(), DT.HEAVY))
	assert_eq(_enemy.get_ai_state(), EAS.STAGGERED, "still STAGGERED")
	# Only 0.05 remained; if the timer had reset it would still be staggered after 0.05.
	_enemy.call("_physics_process", 0.06)
	assert_eq(_enemy.get_ai_state(), EAS.PURSUING,
		"AC-28: timer NOT reset by re-trigger — original 0.15s still governs")


## Light/medium hits do not stagger.
func test_ac28_light_hit_does_not_stagger() -> void:
	_enemy._ai_state = EAS.PURSUING
	EnemyDirector.hit_resolved.emit(_hit(_enemy.get_instance_id(), DT.LIGHT))
	assert_eq(_enemy.get_ai_state(), EAS.PURSUING, "AC-28: LIGHT hit does not stagger")


## A hit targeting a different instance is ignored.
func test_ac28_hit_for_other_target_ignored() -> void:
	_enemy._ai_state = EAS.PURSUING
	EnemyDirector.hit_resolved.emit(_hit(_enemy.get_instance_id() + 9999, DT.HEAVY))
	assert_eq(_enemy.get_ai_state(), EAS.PURSUING, "AC-28: hit for another target_id is ignored")
