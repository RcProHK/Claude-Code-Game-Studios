# Enemy AI — Story 013 AC-29: DYING priority over any state (EC-36).
extends GutTest

const EAS = EnemyDirector.EnemyAIState
const DT = CombatResolver.DamageTier

var _enemy: Enemy


func before_each() -> void:
	_enemy = Enemy.new()
	add_child_autofree(_enemy)
	_enemy.set_physics_process(false)


func _kill_hit(target_id: int):
	var p := CombatResolver.HitResolvedPayload.new()
	p.target_id = target_id
	p.damage_tier = DT.CRITICAL
	p.is_kill = true
	return p


# ---------------------------------------------------------------------------
# AC-29 — kill takes priority (incl. mid-ATTACKING)
# ---------------------------------------------------------------------------

func test_ac29_kill_during_attacking_transitions_to_dying() -> void:
	_enemy._ai_state = EAS.ATTACKING
	EnemyDirector.hit_resolved.emit(_kill_hit(_enemy.get_instance_id()))
	assert_eq(_enemy.get_ai_state(), EAS.DYING,
		"AC-29: kill hit during ATTACKING → DYING immediately (priority)")


func test_ac29_kill_interrupts_animation() -> void:
	_enemy._ai_state = EAS.ATTACKING
	assert_false(_enemy.animation_interrupted, "precondition: not interrupted")
	EnemyDirector.hit_resolved.emit(_kill_hit(_enemy.get_instance_id()))
	assert_true(_enemy.animation_interrupted, "AC-29: kill interrupts the in-progress animation")


## DYING is terminal — a later hit does not change state, no re-interrupt.
func test_ac29_dying_is_terminal() -> void:
	_enemy._ai_state = EAS.ATTACKING
	EnemyDirector.hit_resolved.emit(_kill_hit(_enemy.get_instance_id()))
	assert_eq(_enemy.get_ai_state(), EAS.DYING, "precondition: DYING")
	# Subsequent HEAVY hit must not move it out of DYING.
	var p := CombatResolver.HitResolvedPayload.new()
	p.target_id = _enemy.get_instance_id()
	p.damage_tier = DT.HEAVY
	EnemyDirector.hit_resolved.emit(p)
	assert_eq(_enemy.get_ai_state(), EAS.DYING, "AC-29: DYING is terminal — later hits ignored")


## DYING stops behaviour: _physics_process is a no-op (no perception resurrection).
func test_ac29_dying_physics_is_noop() -> void:
	_enemy._ai_state = EAS.DYING
	_enemy.set_avatar_distance(100.0)  # within perception, but DYING must not pursue
	_enemy.call("_physics_process", 0.016)
	assert_eq(_enemy.get_ai_state(), EAS.DYING, "AC-29: DYING _physics_process is a no-op")


## Kill from IDLE also goes straight to DYING (priority is unconditional).
func test_ac29_kill_from_idle_to_dying() -> void:
	_enemy._ai_state = EAS.IDLE
	EnemyDirector.hit_resolved.emit(_kill_hit(_enemy.get_instance_id()))
	assert_eq(_enemy.get_ai_state(), EAS.DYING, "AC-29: kill from any state → DYING")
